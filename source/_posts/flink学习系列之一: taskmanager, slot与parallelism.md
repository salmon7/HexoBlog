---
title: 'flink学习系列之一: taskmanager, slot与parallelism'
date: 2020-07-12 22:15:43
tags:
    - flink
    - spark
---

> 如无特别说明，本文讨论的内容均基于 flink 1.7.1

> 最近一段时间用 flink 写一些 etl 作业，做数据的收集清洗入库，也遇到一些性能问题需要进一步解决，于是计划学习部分flink底层知识。第一篇，跟以前学习spark一样，从flink的并行度说起。

## flink作业的启动模式

通过 [flink YARN Setup](https://ci.apache.org/projects/flink/flink-docs-release-1.7/ops/deployment/yarn_setup.html) 文档我们能够了解到，flink的启动方式大致有两种，
一种是先分配jobmanager、taskmanager的资源，等待后续提交作业，另一种是在提交的时候申请资源并运行。下面将简单介绍一下这两种启动方式的区别，并着重关注其并行度的计算，最后和spark并行度的计算对对比。

### 部署方式一：在yarn中启动一个flink session，提交job到该session

* 启动flink session
    * ./bin/yarn-session.sh -tm 8192 -s 32
    * 关键配置：
        * -n，指定 container 数量（即taskmanager的数量，不过已经不建议使用，对应的[源码](https://github.com/apache/flink/blob/release-1.7.1/flink-yarn/src/main/java/org/apache/flink/yarn/cli/FlinkYarnSessionCli.java#L373) 
        * -tm，分配 taskmanager 内存大小
        * -jm，分配 jobmanager 内存大小
        * -s，每个taskmanager分配slot个数（如果配置了将会覆盖yarn的 parallelism.default 配置，parallelism.default 值默认为1）
        * -Dyarn.containers.vcores，在yarn中分配的vcore个数，默认和slot个数一致，即一个slot一个vcore
        * 默认 taskmanager 的数量为1，并行度为 slot * taskmanager ，[源码](https://github.com/apache/flink/blob/release-1.7.1/flink-yarn/src/main/java/org/apache/flink/yarn/cli/FlinkYarnSessionCli.java#L619)
    * 一旦 flink session在yarn中启动成功，将会展示有关 jobmanager 连接的详细信息，通过CTRL+C 或者 在client中输入stop关闭 flink session
* 提交job到该session
    * ./bin/flink run ./examples/batch/WordCount.jar 
    * 关键配置：
        * -c，指定入口class
        * -m，指定jobmanager地址
        * -p，指定作业的并行度
    * client能够自动识别对应的 jobmanager 地址
    * 并行度的确定：
        * 如果不指定 -p ，则作业并行度为 1 （parallelism.default 的配置值，默认为1）
        * 如果指定-p，则作业则在该session下，以 -p 指定值的并行度运行。如果作业的并行度大于session的并行度，则会报异常，作业启动失败。

### 部署方式二：在yarn中启动一个单独的作业

* ./bin/flink run -m yarn-cluster ./examples/batch/WordCount.jar
* flink session的配置同样适用于启动单独的作业，需要加前缀 y 或者 yarn
* 关键配置：
    * -n ，允许加载savepoint失败时启动程序
    * -d，client非阻塞模式启动作业
    * -p，指定作业并行度
    * -ytm，分配 taskmanager 内存大小
    * -yjm，分配 jobmanager 内存大小
    * -ys，指定每个taskmanager分配slot个数
    * -yn，指定container数量，和taskmanager数量一致
* 并行度的确定
    * 如果指定了-m yarn-cluster，并且是 -d 或者 -yd 模式，不通过 -yid 指定 applicationid，则其并行度由 -p 决定。
    * flink会启动多少个taskmanager？我们知道flink作业的实际并行度是由 taskmanager * slot 决定的，默认情况下每个taskmanager的slot数量为1，所以yarn最终为了实现并行度为 -p 的作业，需要启动p个taskmanager。num( taskmanenger ) = p / slot 


## spark on yarn vs. flink on yarn

> spark相关的executor以及并行的计算见 Spark学习系列之一和之二

* executor vs. taskmanager
    * spark submit 通过 --num-executors 控制executor数量
    * flink run 通过 -p 和 -ys 控制taskmanager数量

> 另外spark on standalone模式下，其executor数量的计算方式和flink run差不多，它也是通过总的核数和每个executor核数反算所需的executor数目，可以把 total-executor-cores 类比 -p，executor-cores 类比 -ys）

<!--more-->

* executor core vs. slot
    * spark submit 通过--executor-cores控制每个executor的core数量，在默认yarn资源调度器（DefaultResourceCalculator）的情况下，并不能保证每个executor实际分配到的core为指定值，但是每个executor会依然认为自己有指定个core，类似于cpu的超卖。
    * flink run 中，一个作业的slot总数即为其最大的并行度，而每个slot可以通过 yarn.containers.vcores 配置实际分配到的vcore数量。

## 总结

可以看出 flink 的并行度要比 spark 灵活，它可以通过taskmanger, slot, 算子设置并行度决定实际的运行的并行度。不过这样会导致flink上手难度可能会更高，而一个taskmanager的内存会被slot平均分配，
也进一步给作业带来不稳定性。

参考：  
[flink的slot 和parallelism](https://zhuanlan.zhihu.com/p/92721430)   
[flink YARN Setup](https://ci.apache.org/projects/flink/flink-docs-release-1.7/ops/deployment/yarn_setup.html)  
[flink Configuration](https://ci.apache.org/projects/flink/flink-docs-release-1.7/ops/config.html)  
[Flink 集群运行原理兼部署及Yarn运行模式深入剖析-Flink牛刀小试](https://juejin.im/post/5bf8dd7a51882507e94b8b15)  
[flink 单独运行作业源码](https://github.com/apache/flink/blob/release-1.7.1/flink-clients/src/main/java/org/apache/flink/client/cli/CliFrontend.java)  


> 本文为学习过程中产生的总结，由于学艺不精可能有些观点或者描述有误，还望各位同学帮忙指正，共同进步。
