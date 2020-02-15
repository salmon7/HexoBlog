---
title: Spark学习系列之一：新手常见问题
date: 2019-12-16 02:00:19
tags:    
    - spark
    - scala
---

> 如无特别说明，本文源码版本为 spark 2.3.4

学习spark有一段时间了，最近想动动手写个demo出来，大致的功能是从kafka读取用户点击记录，用spark streaming对这些数据进行读取并统计用户一段时间的点击记录，期望最后能落盘到redis中供需求方调用。

这个demo看似简单，但是作为一个新手，我也遇到了一些看起来比较奇怪的问题。再此总结一下我遇到的一些问题，希望能给遇到同样问题的人带来一些帮助。

## 问题一：spark的并行度是多少？

我相信一开始接触的初学者对此肯定有疑惑，并行度指的什么？我认为在spark中，这个并行度指的是partition的数量，无论是通过parallelize初始化rdd，还是通过join和reduceByKey等shuffle操作，都意味着需要确定这个新rdd的paritition数量。这里涉及到一个参数`spark.default.parallelism`，该参数__大多数情况下__是parallelize、join、reducdeByKey等操作的__默认__并行度。如果不定义这个参数，默认情况下分区数量在不同情景的情况下有所不同：

- 对于join和reduceByKey等shuffle操作，分区数一般为多个父rdd中partition数目最大的一个。
- 对于parallelize进行初始化操作，分区数在不同部署模式下不同：
	- local[*]：本地cpu的core数量，local[N]则为N，local则为1
	- meos：默认为8
	- other：一般为executor个数 * 每个executor的core个数
- 当然如果定义了`spark.default.parallelism`参数，其默认分区数也不一定是其值，具体分析见[Spark学习系列之二：rdd分区数量分析](/2019/12/22/Spark学习系列之二：rdd分区数量分析.html)。实际api中也能通过传递numPartitions参数覆盖`spark.default.parallelism`，自行决定并行度。
- 比如正在使用的mac是四核，假设向yarn申请executor个数为2，每个executor的core数量为1，那么spark.default.parallelism的值为2，这时一般情况下是不能充分利用其申请核数资源的，最好是申请核数的2~3倍。可以通过 --conf 传入参数 `--conf spark.default.parallelism = 4` 或者 `--conf spark.default.parallelism = 6`，使其默认值为申请核数的2~3倍。如果有的task执行比较快，core就空闲出来了，为了多利用core就设置task数量为2~3倍。当然最后的并行度还需要根据实际情况进行分析。

> 如何确定本机核数？通过local[*]模式进行parallelize初始化rdd，再输出myrdd.partitions.size即可得，也可以通过java代码Runtime.getRuntime.availableProcessors()获得

参考：  
[https://spark.apache.org/docs/latest/configuration.html](https://spark.apache.org/docs/latest/configuration.html)  
[http://spark.apache.org/docs/latest/tuning.html](http://spark.apache.org/docs/latest/tuning.html)

## 问题二：standalone模式下，executor个数和executor核数如何确定？

由于需要通过spark streaming读取kafka，如果对应topic的partition数量已知，那么应该启动对应个数的executor，因为kafka的一个parition同一时间只允许同一个groupid的consumer读取，如果topic的partition为1，申请的executor为2，那么将只有一个executor的资源得到了利用。

既然executor个数比较重要，yarn模式可以通过`--num-executors`确定executor个数，那standalone模式如何确定的呢？直接先说结论：

- executor的数量 = total-executor-cores/executor-cores
- `--total-executor-cores` 对应配置 `spark.cores.max` (default: `spark.deploy.defaultCores`)，表示一个application最大能用的core数目；如果没有设置则默认上限为`spark.deploy.defaultCores`，该配置的值默认为infinite（不限）
- `--executor-cores` 对应配置 `spark.executor.cores`，表示每个executor的core数目
- 可以看到standalone的executor数量并不能直接指定，而是通过core的换算得到的，如果对executor数目有要求的话，可以额外关注一下。

> 以下是我写demo过程遇到问题，以及解决问题的大致流程。

在写demo过程中通过spark-sumbit提交任务时，忘了写master，但是通过`--executor-cores`指定了每个executor的core数量。等应用跑起来后，发现spark ui上，发现worker上有1个executor，每个executor4个core，这显然不符合的预期。明明通过`--executor-cores`指定了executor的core数量，为什么申请到的core数目不符合预期？即使spark-submit的script中没包含master，但是程序是指定了master（spark://zhangqilongdeMacBook-Air.local:7077）。我决定进行多次调整参数，验证每种情况下申请到executor数量和每个executor的core数量，总结如下：

- master和executor-cores，只配置一个或者两个都不配，则只申请一个executor，并且executor将尽量使用worker的所有core。
- master和executor-cores两个都配，则申请的executor数量 = workder core的总数/executor-cores，每个executor的core数量和executor-cores一致。

通过源码可以发现：

- `--executor-cores`只有在--master为standalone、yarn、kubernetes模式下才会生效，如果不是这些模式，将会通过__默认配置文件__指定缺失的值。即如果不指定master的情况下（默认为local[*]），`--executor-cores`并不会生效，并且使用 `SPAKR_HOME/conf/spark-defaults.conf`配置文件中的值对其赋值，如果该配置文件中依然不存在，则为spark系统默认对该变量的值，即infinite（不限）。
- `--total-executor-cores`可以配置standalone每个application可以用的核总数（其实通过spark-submit命令行的提示也能看出来，因为yarn模式下该值不可配所以一开始这个配置被我忽略了）

```scala
org.apache.spark.deploy.Submit

...省略部分代码
	//可以看到spark.executor.cores只在某些情况下才会被赋值
	OptionAssigner(args.executorCores, STANDALONE | YARN | KUBERNETES, ALL_DEPLOY_MODES, confKey = "spark.executor.cores"),
	OptionAssigner(args.totalExecutorCores, STANDALONE | MESOS | KUBERNETES, ALL_DEPLOY_MODES, confKey = "spark.cores.max")

...省略部分代码
    // Load any properties specified through --conf and the default properties file
    // 通过sparkProperties（已经读取了spark-defaluts.conf内动）hashMap对缺失配置进行填充。
    for ((k, v) <- args.sparkProperties) {
      sparkConf.setIfMissing(k, v)
    }

...省略部分代码
```

参考：  
[https://spark.apache.org/docs/latest/spark-standalone.html](https://spark.apache.org/docs/latest/spark-standalone.html)

<!--more-->

## 问题三：yarn的container个数和container核数如何确定？

对于executor数量，相比较standalone，yarn模式下会简单很多。它会在container中运行一个executor，并且可以通过 `--num-executors` 控制executor的数量。另外由于yarn需要Application Master向集群申请资源等操作，需要额外创建一个container运行Application Master进程。所以yarn的container数量= num-executors + 1。

而对于yarn container的vcores数量，发现spark-submit的`--executor-cores`参数始终没有生效，但是从spark-submit的提示语中该参数是对yarn模式生效的，为什么会没有生效？网上很多文章都没说清楚原因，直到我找到__cloudera__的一篇文章。大致总结一下：

- yarn默认的资源调度器（`DefaultResourceCalculator`）是只考虑memory的，cpu不在考虑范围内；
- 只有改了capacity-scheduler.xml中的`yarn.scheduler.capacity.resource-calculator`配置为`DominantResourceCalculator`，那么yarn调度器的时候会同时考虑memory和cpu两个维度。
- 改了默认的调度器可能带来的问题是，能够运行的container数量会较少，内存利用也会大大降低，集群吞吐量也会随之降低。

我在本地机器上改了默认的调度器的前后对比如下：

- DefaultResourceCalculator默认调度器：

```
container面板：
Resource:	2048 Memory, 1 VCores

About the Cluster面板
Scheduler Type | Scheduling Resource Type | Minimum Allocation | Maximum Allocation
Capacity Scheduler | [MEMORY] | <memory:1024, vCores:1> | <memory:8192, vCores:32>

```

- DominantResourceCalculator调度器：

```
container面板：
Resource:	2048 Memory, 2 VCores

About the Cluster面板
Scheduler Type | Scheduling Resource Type | Minimum Allocation | Maximum Allocation
Capacity Scheduler | [MEMORY, CPU] | <memory:1024, vCores:1> | <memory:8192, vCores:8>
```

可以看到通过修改默认的调度器实现了vcores的正确分配。

> - 即使当yarn的vcore数目跟`--executor-cores`对不上时，在spark ui的Environment页面spark.executor.cores依然是和`--executor-cores`相等的，可以看到在spark层面它依然认为有executor-cores个core，内部应该会初始化对应个数的线程去处理task。  
> - 后面有时间的话，可以写一篇文章分析一下这两个资源计算器的算法。

参考:  
[Managing CPU Resources in your Hadoop YARN Clusters](https://blog.cloudera.com/managing-cpu-resources-in-your-hadoop-yarn-clusters/)  
[Understanding Resource Allocation configurations for a Spark application](http://site.clairvoyantsoft.com/understanding-resource-allocation-configurations-spark-application/)  
[Spark on YARN too less vcores used](https://stackoverflow.com/questions/38368985/spark-on-yarn-too-less-vcores-used)  
[yarn is not honouring yarn.nodemanager.resource.cpu-vcores](https://stackoverflow.com/questions/25563736/yarn-is-not-honouring-yarn-nodemanager-resource-cpu-vcores)  
[How-to: Tune Your Apache Spark Jobs (Part 1)](https://blog.cloudera.com/how-to-tune-your-apache-spark-jobs-part-1/)  
[How-to: Tune Your Apache Spark Jobs (Part 2)](https://blog.cloudera.com/how-to-tune-your-apache-spark-jobs-part-2/)


## 问题四：spark sterming的checkpoint

spark streaming的checkpoint数据包含两种，第一种是元数据，包括配置、DStream的操作链、未完成的批次，这些主要是用来重启driver；第二种是rdd，一般对于无状态的rdd其实可以不用checkpoint，当然这样子可能会造成已接收但未处理的数据丢失，而对于__跨批次有状态__的rdd需要记忆之前的状态，同时也为了避免rdd血统过长导致存储空间过大，需要定时进行checkpoint。

- 从源码上看，updateStateByKey和reduceByKeyAndWindow (有inverse函数) 的底层实现均为StateDStream
- StateDStream的 checkpoint 间隔为BatchInterval（即每个batch的间隔）的整数倍（默认为1倍），并且最小为10s
    - 即 StateDstream的checkpoint Interval = max(BatchInterval*n, 10), n=1,2,3,4....
    - 官网原话：For stateful transformations that require RDD checkpointing, the default interval is a multiple of the batch interval that is at least 10 seconds. 这里说明了checkpoint interval 的最小为10，并且必须为BatchInterval的整数倍，__其实还可以加上默认等于BatchInterval__，不然还以为一定要手动调用StateDstream的`checkpoint`方法，如The default checkpoint interval of statefull dstream is same as batch interval。
    - 从源码看的话，StateDStream覆盖了DStream的`mustCheckpoint`，并且指定为true，这也侧面说明StateDStream会默认进行checkpoint，并且不指定checkpoint directory时会报错。

- 除了定时checkpoint外，还需要定时清理保存的数据
    - 这个周期一般为checkpoint间隔的两倍，Remember Duartion = checkpoint\_interval * 2
    - 如果其上游有额外进行checkpoint的话，那么该值应该等于其最近上游的remember duration * 2 和 当前checkpoint inteval * 2的最大值
    - 即Remember Duartion = max( father.checkpoint\_interval, checkpoint\_interval) * 2
    - `DStream.scala` 关键源码如下。可以看出，当不主动设置DStream的remember duration时，其大小为checkpoint interval的两倍。同时还会递归地为父stream设置remember duration如果子类的比父类本身remember duration大。

```scala
private[streaming] def initialize(time: Time) {
  if (zeroTime != null && zeroTime != time) {
    throw new SparkException(s"ZeroTime is already initialized to $zeroTime"
      + s", cannot initialize it again to $time")
  }
  zeroTime = time
  // Set the checkpoint interval to be slideDuration or 10 seconds, which ever is larger
  if (mustCheckpoint && checkpointDuration == null) {
    checkpointDuration = slideDuration * math.ceil(Seconds(10) / slideDuration).toInt
    logInfo(s"Checkpoint interval automatically set to $checkpointDuration")
  }
  // Set the minimum value of the rememberDuration if not already set
  var minRememberDuration = slideDuration
  if (checkpointDuration != null && minRememberDuration <= checkpointDuration) {
    // times 2 just to be sure that the latest checkpoint is not forgotten (#paranoia)
    minRememberDuration = checkpointDuration * 2
  }
  if (rememberDuration == null || rememberDuration < minRememberDuration) {
    rememberDuration = minRememberDuration
  }
  // Initialize the dependencies
  dependencies.foreach(_.initialize(zeroTime))
}

private[streaming] def remember(duration: Duration) {
  if (duration != null && (rememberDuration == null || duration > rememberDuration)) {
    rememberDuration = duration
    logInfo(s"Duration for remembering RDDs set to $rememberDuration for $this")
  }
  dependencies.foreach(_.remember(parentRememberDuration))
}

```
	
- 假设BatchInterval=10s，在DAG图中有 A->B->C，A为DirectKafkaInputDStream，B为MappedDStream，其中C为StateDStream。
    - 默认情况下，只有StateDStream会进行checkpoint：
    	- DirectKafkaInputDStream：checkpoint interval = N/A ，remember duration = 20s
    	- MappedDStream：checkpoint interval = N/A ，remember duration = 20s
       - StateDStream：checkpoint interval = 10s ，remember duration = 20s
    - 如果对MappedDStream进行了checkpoint，即 MappedDStream.checkpoint(Seconds(20))
    	- DirectKafkaInputDStream：checkpoint interval = N/A ，remember duration = 40s      
       - MappedDStream：checkpoint interval = 20s ，remember duration = 40s
       - StateDStream：checkpoint interval = 10s ，remember duration = 20s

    - BatchInterval = 5s，如果对MappedDStream进行了checkpoint，即 MappedDStream.checkpoint(Seconds(5))
        - DirectKafkaInputDStream：checkpoint interval = N/A ，remember duration = 20s
        - MappedDStream：checkpoint interval = 5s ，remember duration = 20s
        - StateDStream：checkpoint interval = 10s ，remember duration = 20s

    - 如果对DirectKafkaInputDStream进行了checkpoint，即 DirectKafkaInputDStream.checkpoint(Seconds(30))
        - DirectKafkaInputDStream：checkpoint interval = 30s，remember duration = 60s        
        - MappedDStream：checkpoint interval = N/A ，remember duration = 20s
        - StateDStream：checkpoint interval = 10s ，remember duration = 20s

    - 这也为我们提供了一种调优策略，如果上游dstream设置的checkpoint间隔很短，但是占用内存很大，而下游dstream设置的checkpoint间隔很长，但是占用的内存很小。这个时候可以会以为设置上游checkpoint间隔短点，可以使其remember duration小一点，尽快清理占用的大量内存，但是很可能忽略了可能会使用下游的remember duration作为上游的remember duration，从而导致大量内存没有被释放。（当然，对于大内存也不应该频繁的进行checkpoint，这里只是举个例子说明可能出现的问题）


## 问题五：reduceByKeyAndWindow 消费kafka报多线程消费错误

在使用spark 2.3.0版本 reduceByKeyAndWindow 时，在某些情况下会报错多线程消费kafka错误（"java.util.ConcurrentModificationException: KafkaConsumer is not safe for multi-threaded access"）。经测试在满足以下两个条件时会出现：

- spark stream context 的 batch interval < windows slide Duration 
- executor使用的core数目>1 (yarn模式下，需要注意vcore的数目)
- kafka topic 对应的 parition 个数为1

在网上找了挺多资料，挺多人遇到同样的问题，也看了部分reduceByKeyAndWindow的源码，最后发现是spark实现的一个bug，只要升到2.4.0版本就不会与这个问题。

> 这个问题其实花了挺长时间去找问题的原因，也试过先cache或checkpoint，但是依然无法解决这个问题。源码实现方面，reduceByKeyAndWindow的底层流实现为ReducedWindowedDStream，里面分析了previous window、current window、new rdd、old rdd等等，对old rdd运行invReduceFunc，对new rdd运行reduceFunc。    
> 最终有人重写了kafka consumer解决了此问题，详见githu的pr [Avoid concurrent use of cached consumers in CachedKafkaConsumer](https://github.com/apache/spark/pull/20997)，核心是避免使用同时一个consumer读取TopicPartition。

参考：  
[2.4.0修复bug](https://issues.apache.org/jira/browse/SPARK-23636)  
[KafkaConsumer is not safe for multi-threaded access](https://blog.csdn.net/xianpanjia4616/article/details/82811414)  
[https://issues.apache.org/jira/browse/SPARK-19185](https://issues.apache.org/jira/browse/SPARK-19185)  
[spark各种报错汇总以及解决方法](https://blog.csdn.net/xianpanjia4616/article/details/86703595)


