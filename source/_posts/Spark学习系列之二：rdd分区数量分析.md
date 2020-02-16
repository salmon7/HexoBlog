---
title: Spark学习系列之二：rdd分区数量分析
date: 2019-12-22 01:43:42
tags:    
    - spark
    - scala
---
> 如无特别说明，本文源码版本为 spark 2.3.4

创建rdd有三种方式，一种是通过SparkContext.textFile()访问外部存储创建，一种是通过输入数据集合通过调用 SparkContext.parallelize() 方法来创建，最后一种是通过转换已有的rdd生成新的rdd。

## 通过parallelize创建rdd的分区数量分析

通过parallelize的方式比较简单，相信也是大部分初学者第一次接触创建rdd的方法，那么通过这个方法创建的rdd的默认分区数是多少呢？我们通过源码进行分析。

```scala
package org.apache.spark.SparkContext

class SparkContext(config: SparkConf) extends Logging {
  /** Default level of parallelism to use when not given by user (e.g. parallelize and makeRDD). */
  def defaultParallelism: Int = {
    assertNotStopped()
    taskScheduler.defaultParallelism
  }
  
  def parallelize[T: ClassTag](
      seq: Seq[T],
      numSlices: Int = defaultParallelism): RDD[T] = withScope {
    assertNotStopped()
    new ParallelCollectionRDD[T](this, seq, numSlices, Map[Int, Seq[String]]())
  }
}
```

我们先看看parallelize是如何生成rdd的。可以看到它是通过 ParallelCollectionRDD 类创建一个rdd，其内部返回的partitioner是通过ParallelCollectionRDD伴生对象的slice方法分割seq为一个二维的Seq[Seq[T]]，并把这个二维的序列传递到ParallelCollectionPartition中实例化的。

接下来是关键，`defaultParallelism`的默认值确定了分区的数量。

<!--more-->

```scala
package org.apache.spark.SparkContext

class SparkContext(config: SparkConf) extends Logging {
  private var _taskScheduler: TaskScheduler = _
  
  // 等于task调度器的defaultParallelism
  def defaultParallelism: Int = {
    assertNotStopped()
    taskScheduler.defaultParallelism
  }
}
  
--------
package org.apache.spark.scheduler

// 特质TaskScheduler，定义task调度器的方法
private[spark] trait TaskScheduler {
  // 定义获取默认并行度的接口
  def defaultParallelism(): Int
}
--------
package org.apache.spark.scheduler

// TaskScheduler的具体实现类
private[spark] class TaskSchedulerImpl(
    val sc: SparkContext,
    val maxTaskFailures: Int,
    isLocal: Boolean = false)
  extends TaskScheduler with Logging {
  
  // 后台调度器特质
  var backend: SchedulerBackend = null
  // 实现了TaskScheduler中的defaultParallelism接口，并返回从成员变量后台调度器特质backend返回backend.defaultParallelism()
  override def defaultParallelism(): Int = backend.defaultParallelism()

}

--------
package org.apache.spark.scheduler

// 定义后台调度器特质
private[spark] trait SchedulerBackend {
  // 定义抽象方法
  def defaultParallelism(): Int
}

--------
package org.apache.spark.scheduler.local

// 本地后台调度器，为SchedulerBackend特质的一种具体实现
private[spark] class LocalSchedulerBackend(
    conf: SparkConf,
    scheduler: TaskSchedulerImpl,
    val totalCores: Int)
  extends SchedulerBackend with ExecutorBackend with Logging {
  
  // 实现SchedulerBackend中的defaultParallelism方法，返回配置中的"spark.default.parallelism"，
  // 如果没有定义则返回从SparkContext传入的totalCores。SparkContex的master为 local 则totalCores=1；
  // master为local[*] 则totalCores=Runtime.getRuntime.availableProcessors()；
  // master为local[N]，则totalCores=N
  // 传入totalcores的计算见org.apache.spark.SparkContext.createTaskScheduler()方法
  override def defaultParallelism(): Int =
    scheduler.conf.getInt("spark.default.parallelism", totalCores)
}

--------
package org.apache.spark.scheduler.cluster

// 为StandaloneSchedulerBackend调度器的父类，适用于standalone模式
private[spark]
class CoarseGrainedSchedulerBackend(scheduler: TaskSchedulerImpl, val rpcEnv: RpcEnv)
  extends ExecutorAllocationClient with SchedulerBackend with Logging {
  
  // Use an atomic variable to track total number of cores in the cluster for simplicity and speed
  // totalCoreCount会根据注册/解注册的executor的core数量动态进行增减
  protected val totalCoreCount = new AtomicInteger(0)
  protected val conf = scheduler.sc.conf
  
  // 实现SchedulerBackend中的defaultParallelism方法，返回配置中的"spark.default.parallelism"，
  // 如果没有定义则返回 max(totalCoreCount, 2)，注意totalCoreCount并不一定是运行命令时`--total-executor-cores`申请spark.cores.max值
  // totalCoreCount小于spark.cores.max，当集群资源不够或者超时时，也会直接运行：
  // 1. 计算totalCoreCount > spark.cores.max * spark.scheduler.minRegisteredResourcesRatio（默认为0）
  // 2. 计算等待时间 maxRegisteredWaitingTimeMs，当其大于spark.scheduler.maxRegisteredResourcesWaitingTime（默认为30s）时
  override def defaultParallelism(): Int = {
    conf.getInt("spark.default.parallelism", math.max(totalCoreCount.get(), 2))
  }
}

```

通过以上分析，我们可知通过parallelize创建rdd时，分区数量根据以下情况确定

- 如果部署模式为local：
	- 如果定义了`spark.default.parallelism`则以其值作为分区大小
	- 如果没有定义`spark.default.parallelism`，则以解析master参数中指定的值为分区大小
- 如果部署模式为standalone：
	- 如果定义了`spark.default.parallelism`则以其值作为分区大小
	- 如果没有定义`spark.default.parallelism`，则为math.max(totalCoreCount, 2)，其中totalCoreCount为executor注册的所拥有core数量，不一定是申请core的总数。

> TODO yarn模式的还未考虑，以后有时间加进来

## 对现有rdd进行transformation后分区数量分析

上一小节通过分析后台调度器的相关源码，我们已经知道通过parallelize创建rdd时partition的确定方法。这一节我们探讨通过转换前后分区数量如何确定。

### 以map()为例

```scala
package org.apache.spark.rdd

// map等转换的底层实现是MapPartitionsRDD
private[spark] class MapPartitionsRDD[U: ClassTag, T: ClassTag](
    var prev: RDD[T],
    f: (TaskContext, Int, Iterator[T]) => Iterator[U],  // (TaskContext, partition index, iterator)
    preservesPartitioning: Boolean = false,
    isOrderSensitive: Boolean = false)
  extends RDD[U](prev) {
  // 这里需要注意，实例化MapPartitionsRDD时，会调用RDD的单参数rdd的构造方法。
  
  // 分区器继承血统中第一个父类的partitioner（对于map来说只有一个父rdd），如果有的话
  override val partitioner = if (preservesPartitioning) firstParent[T].partitioner else None

  // 分区继承血统中第一个父类的partitions（对于map来说只有一个父rdd）
  override def getPartitions: Array[Partition] = firstParent[T].partitions

  override def compute(split: Partition, context: TaskContext): Iterator[U] =
    f(context, split.index, firstParent[T].iterator(split, context))
  
}

abstract class RDD[T: ClassTag](
    @transient private var _sc: SparkContext,
    @transient private var deps: Seq[Dependency[_]]
  ) extends Serializable with Logging {

  /** Construct an RDD with just a one-to-one dependency on one parent */
  // 实现单参数rdd的构造方法
  def this(@transient oneParent: RDD[_]) =
    this(oneParent.context, List(new OneToOneDependency(oneParent)))

  /**
   * Implemented by subclasses to return how this RDD depends on parent RDDs. This method will only
   * be called once, so it is safe to implement a time-consuming computation in it.
   */
  // getDependencies等于rdd构造方法参数中的deps
  protected def getDependencies: Seq[Dependency[_]] = deps

  /**
   * Get the list of dependencies of this RDD, taking into account whether the
   * RDD is checkpointed or not.
   */
  final def dependencies: Seq[Dependency[_]] = {
    checkpointRDD.map(r => List(new OneToOneDependency(r))).getOrElse {
      if (dependencies_ == null) {
        // 先不考虑checkpoint的情况，则dependencies= dependencies_ = getDependencies
        dependencies_ = getDependencies
      }
      dependencies_
    }
  }
  
  /** Returns the first parent RDD */
  protected[spark] def firstParent[U: ClassTag]: RDD[U] = {
    // firstParent为dependencies容器中第一个元素
    dependencies.head.rdd.asInstanceOf[RDD[U]]
  }
}
```

这里需要注意区分Partitioner和Partition。Partitioner是分区器，需要定义分区的数量numPartitions，以及通过传入key决定其在哪个partition的getPartition(key: Any)方法。而Partition则描述了当前rdd的分区状态，对于map而言其分区状态和父rdd一致。当然rdd也可以没有Partitioner就有Parition的情况，如默认情况下经过map转换的rdd，以及本文第一部分描述通过parallelize创建rdd，都是没有partitioner，其partitioner为None。

通过追溯firstParent，可知firstParent <- dependencies.head <- dependencies_.head <- getDependencies.head <- deps.head <- List(new OneToOneDependency(pre).head (这里完成rdd到dependency的转换)，其中pre为调用map方法的rdd，即 MapPartitionsRDD 的父rdd。

回到map的paritions数量为多少的问题，从源码中也能看到其partitions将保持血统中第一个的父类的partition，不会改变原有的分区情况。但是也不会保留原有的分区器。

而类似的，flatMap的实现也和map一致。filter也差不多，由于其不会更改父rdd的key，所以preservesPartitioning为true，保留了血统中第一个父类的partitioner。

### 以reduceByKey()为例

```scala
package org.apache.spark.rdd

class PairRDDFunctions[K, V](self: RDD[(K, V)])
    (implicit kt: ClassTag[K], vt: ClassTag[V], ord: Ordering[K] = null)
  extends Logging with Serializable {

  def reduceByKey(func: (V, V) => V): RDD[(K, V)] = self.withScope {
    // 通过org.apache.spark.Partitioner.defaultPartitioner创建分区器
    reduceByKey(defaultPartitioner(self), func)
  }
}

--------
package org.apache.spark

/**
 * An object that defines how the elements in a key-value pair RDD are partitioned by key.
 * Maps each key to a partition ID, from 0 to `numPartitions - 1`.
 *
 * Note that, partitioner must be deterministic, i.e. it must return the same partition id given
 * the same partition key.
 */
 // 抽象分区器
abstract class Partitioner extends Serializable {
  // 需要分多少个区
  def numPartitions: Int
  // 传入key，就返回其应该存在哪个分区
  def getPartition(key: Any): Int
}

object Partitioner {
  /**
   * Choose a partitioner to use for a cogroup-like operation between a number of RDDs.
   *
   * If spark.default.parallelism is set, we'll use the value of SparkContext defaultParallelism
   * as the default partitions number, otherwise we'll use the max number of upstream partitions.
   *
   * When available, we choose the partitioner from rdds with maximum number of partitions. If this
   * partitioner is eligible (number of partitions within an order of maximum number of partitions
   * in rdds), or has partition number higher than default partitions number - we use this
   * partitioner.
   *
   * Otherwise, we'll use a new HashPartitioner with the default partitions number.
   *
   * Unless spark.default.parallelism is set, the number of partitions will be the same as the
   * number of partitions in the largest upstream RDD, as this should be least likely to cause
   * out-of-memory errors.
   *
   * We use two method parameters (rdd, others) to enforce callers passing at least 1 RDD.
   */
  // 传入一个rdd以及传入可变长rdd参数 other（即可以不传，也可以传一个或者多个）
  def defaultPartitioner(rdd: RDD[_], others: RDD[_]*): Partitioner = {
    // 拼接两个rdd到序列
    val rdds = (Seq(rdd) ++ others)
    // 过滤rdds序列中有partitioner并且对应的numPartitions>0的rdds序列
    val hasPartitioner = rdds.filter(_.partitioner.exists(_.numPartitions > 0))
	
    // 从rdds序列中选择partitioner中partition数量的rdd，称为最大分区器rdd
    val hasMaxPartitioner: Option[RDD[_]] = if (hasPartitioner.nonEmpty) {
      Some(hasPartitioner.maxBy(_.partitions.length))
    } else {
      None
    }

    // 定义默认的分区数量
    val defaultNumPartitions = if (rdd.context.conf.contains("spark.default.parallelism")) {
      // 如果定义了"spark.default.parallelism"，则为其值
      rdd.context.defaultParallelism
    } else {
      // 否则为rdds序列中各个rdd分区数的最大值
      rdds.map(_.partitions.length).max
    }

    // If the existing max partitioner is an eligible one, or its partitions number is larger
    // than the default number of partitions, use the existing partitioner.
    if (hasMaxPartitioner.nonEmpty && (isEligiblePartitioner(hasMaxPartitioner.get, rdds) ||
        defaultNumPartitions < hasMaxPartitioner.get.getNumPartitions)) {
      // 如果有最大分区器rdd，并且其分区数是合理的；或者有最大分区器rdd，并且其分区数量大于默认的分区数量defaultNumPartitions；返回最大分区器rdd的partitioner
      // 这个if-else语句嵌套到上一个if-else语句的话，代码会更加清晰？
      hasMaxPartitioner.get.partitioner.get
    } else {
      // 否则将以默认分区数量defaultNumPartitions实例化一个HashPartitioner，并返回
      new HashPartitioner(defaultNumPartitions)
    }
  }

  /**
   * Returns true if the number of partitions of the RDD is either greater than or is less than and
   * within a single order of magnitude of the max number of upstream partitions, otherwise returns
   * false.
   */
  // 判断最大分区器的rdd的分区数目对于其他rdd是否合理
  private def isEligiblePartitioner(
     hasMaxPartitioner: RDD[_],
     rdds: Seq[RDD[_]]): Boolean = {
    // 获取rdds序列中最大的分区数量
    val maxPartitions = rdds.map(_.partitions.length).max
    // 如果rdds序列中最大的分区数量不大于最大分区器分区数量一个数量级，则返回true；否则返回false
    log10(maxPartitions) - log10(hasMaxPartitioner.getNumPartitions) < 1
  }
}

```

对于reduceByKey方法，当不传numPartitions参数时，其默认的分区器由defaultPartitioner()方法决定，分区器就决定了分区数。

defaultPartitioner()的决定分区器规则总结如下：

- 如果定义了"spark.default.parallelism"，则defaultNumPartitions = "spark.default.parallelism" ；如果未定义，则defaultNumPartitions等于所有rdd分区中最大的分区数
- 如果在所有rdd中有对应的partitioner，则选出分区数量最大的partitioner，并且该partitioner的分区数满足以下两个条件之一，则返回该partitioner作为API的partitioner
	- 分区数量是合理的
	- 分区数量大于defaultNumPartitions
- 否则，返回HashPartitioner(defaultNumPartitions)

总结，对于reduceByKey等类似的API而言，只要是通过defaultPartitioner()定义分区器的，其分区数量有三种情况：

- 等于默认值spark.default.parallelism
- 等于所有rdd中最大partition数量
- 等于所有partitioner中最大partition数量

也可以看出此类型的转换，partition数量总是趋向于变大，而"spark.default.parallelism"是个平衡点。

如果定义了"spark.default.parallelism"：

- 如果它定义的很小，对于没有分区器则分区数量很小。对于有分区器，defaultNumPartitions < hasMaxPartitioner.get.getNumPartitions几乎永远为true，将保持最大分区器的分区数量，不会主动干预原来的分区情况。
- 如果它定义的很大，对于没有分区器则分区数量很大。对于有分区器，defaultNumPartitions < hasMaxPartitioner.get.getNumPartitions几乎永远为false，结果依赖于最大分区器的分区数量小于分区数量最大的rdd的程度，如果相差不大则保留原来的分区器，如果相差很大，则以"spark.default.parallelism"作为新分区大小。

如果没定义"spark.default.parallelism"：

- 对于没有分区器，则分区数量等于所有rdd中最大partition数量。
- 对于有分区器，defaultNumPartitions < hasMaxPartitioner.get.getNumPartitions永远为false，结果依赖于最大分区器的分区数小于分区数量最大的rdd的程度，如果相差不大则保留原来的分区器，如果相差很大，则以所有rdd的最大分区数为新分区大小。

## 保持partitioner的transformation

如上所述，rdd的parittioner是决定分区数量的重要因素，对于以下transformation __默认__ 将会保留和传播partitioner: 

- cogroup
- groupWith
- join
- leftOuterJoin
- rightOuterJoin
- groupByKey
- reduceByKey
- foldByKey
- combineByKey
- partitionBy
- mapValues 
- flatMapValues 
- filter 

其他transfermation将默认不保持分区器。因为其他操作（比如map）可能会修改key，修改了key后，原来的分区器就失去了它的意义。相反的，mapValues只修改value不修改key，所以其保留和传播分区器是合理的。

## 参考

[https://github.com/rohgar/scala-spark-4/wiki/Partitioning](https://github.com/rohgar/scala-spark-4/wiki/Partitioning)

> TODO 通过文件创建rdd还未考虑，以后有时间加进来  
> 本文为学习过程中产生的总结，由于学艺不精可能有些观点或者描述有误，还望各位同学帮忙指正，共同进步。
