---
title: 浅谈golang对mysql时间类型数据转换的问题
date: 2019-11-09 22:19:22
tags:
    - go
    - mysql
---

部门某些业务需要在海外上线，涉及到数据库时区、应用时区的转换。本文将讨论golang针对数据库时区的处理问题。

> 为了方便讨论，避免混淆，本文对“时间”的表达方式作出约定：时间=时区时间+时区。如时间 2019-05-21 15:48:38 CST ,则其时区时间为2019-05-21 15:48:38，时区为CST。如果没有特别说明，本文提到的“时间”都包含时区。

## 一、golang中mysql数据库驱动的时区配置

mysql中关于时间日期的概念数据模型有`DATE`、`DATETIME`、`TIMESTAMP`，golang程序根据数据链接DSN（Data Source Name）配置，数据库驱动 github.com/go-sql-driver/mysql 可以对这三种类型的值转换成go中的time.Time类型，关键配置如下：

* parseTime
	* 默认为false，把mysql中的 `DATE`、`DATETIME`、`TIMESTAMP` 转为golang中的[]byte类型
	* 设置为true，将会转为golang中的 `time.Time` 类型
* loc
	* 默认为UTC，表示转换`DATE`、`DATETIME`、`TIMESTAMP` 为 `time.Time` 时所使用的时区
	* 设置成Local，则与系统设置的时区一致
	* 如果想要设置成中国时区可以设置成 `Asia/Shanghai` ，更多的时区可以参考 `/usr/share/zoneinfo/` 或者`$GOROOT/lib/time/zoneinfo.zip`。

在实际的使用中，我们往往会配置成 `parseTime=true` 和 `loc=Local`，这样避免了手动转换`DATE`、`DATETIME`、`TIMESTAMP`。

## 二、golang如何转换mysql的时间类型
> 在涉及到不同时区时，我们golang程序应该怎么处理mysql的 DATE、DATETIME、TIMESTAMP 数据类型？是否只要配置了parseTime=true&loc=xxx就不会有问题？我们来做两个小实验。

### 实验一：应用和数据库在同一时区

#### 1.timestamp  
a.系统时区设置为CST，mysql和golang在同一个时区的机器上。（如何设置和查看时区可以参考本文第五节内容。）

- golang在程序中连接数据库使用的配置DSN是parseTime=true&loc=xxx，xxx分别为UTC、Asia/Shanghai、Europe/London、Local。
- mysql终端中insert一条timestamp【时区时间】为2019-04-02 13:18:17的记录，其UNIX_TIMESTAMP(timestamp)=1554182297。

以下1~5行均为golang程序读取刚插入数据库的数据结果，第一列输出分别为链接数据库DSN配置，第二列为转换为time.Time后的输出。

```
parseTime=true&loc=UTC:                  2019-04-02 13:18:17 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 13:18:17 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 13:18:17 +0100 BST
parseTime=true&loc=Local:                2019-04-02 13:18:17 +0800 CST
```

b.同样的机器，修改系统时区为BST，在mysql终端中select上一步插入的数据，timestamp【时区时间】为2019-04-02 06:18:17，UNIX_TIMESTAMP(timestamp)=1554182297。程序输出为：

```
parseTime=true&loc=UTC:                  2019-04-02 06:18:17 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 06:18:17 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 06:18:17 +0100 BST
parseTime=true&loc=Local:                2019-04-02 06:18:17 +0100 BST
```

c.小结：

- UNIX_TIMESTAMP可以把mysql的timstamp转为距离 1970-01-01 00:00:00 UTC 的秒数，这个经过转换后的值无论mysql在任何时区都不会变。
- 即使同一条数据库记录，由于时区不同，mysql终端中直接select出的timestamp的【时区时间】也不同。也侧面说明了mysql内部实现的timstamp结构体中包含了时区信息，在输出时根据当前时区做转换，输出当前【时区时间】。
- golang程序获取到的time.Time等于：mysql【时区时间】+ 时区，时区为loc指定的时区，与mysql时区没有关系。

<!--more-->

#### 2.date
a.系统时区设置为CST，mysql和golang在同一个时区的机器上。

- golang在程序中连接数据库使用的配置DSN是parseTime=true&loc=xxx，xxx分别为UTC、Asia/Shanghai、Europe/London、Local。
- mysql中insert一条【时区时间】为date=2019-04-02。

程序输出为：

```
parseTime=true&loc=UTC:                  2019-04-02 00:00:00 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 00:00:00 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 00:00:00 +0100 BST
parseTime=true&loc=Local:                2019-04-02 00:00:00 +0800 CST
```

b.同样的机器，修改系统时区为BST，在mysql终端中select上一步插入的数据，date【时区时间】为2019-04-02。程序输出为：

```
parseTime=true&loc=UTC:                  2019-04-02 00:00:00 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 00:00:00 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 00:00:00 +0100 BST
parseTime=true&loc=Local:                2019-04-02 00:00:00 +0100 BST
```

c.小结

- 同一条数据库记录，不管时区golang一不一样，mysql终端中select出的date始终一样。
- golang程序获取到的time.Time等于：mysql时区时间 + 时区，时区为loc指定的时区，与mysql时区没有关系。

#### 3.datetime
a.系统时区设置为CST，mysql和golang在同一个时区的机器上。

- golang在程序中连接数据库使用的配置DSN是parseTime=true&loc=xxx，xxx分别为UTC、Asia/Shanghai、Europe/London、Local。
- mysql中insert一条【时区时间】为datetime=2019-04-02 13:03:01。

程序输出为：

```
parseTime=true&loc=UTC:                  2019-04-02 13:03:01 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 13:03:01 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 13:03:01 +0100 BST
parseTime=true&loc=Local:                2019-04-02 13:03:01 +0800 CST
```

b.同样的机器，修改系统时区为BST，在mysql终端中select上一步插入的数据，datetime【时区时间】为2019-04-02 13:03:01。程序输出为：

```
parseTime=true&loc=UTC:                  2019-04-02 13:03:01 +0000 UTC
parseTime=true&loc=Asia/Shanghai:        2019-04-02 13:03:01 +0800 CST
parseTime=true&loc=Europe/London:        2019-04-02 13:03:01 +0100 BST
parseTime=true&loc=Local:                2019-04-02 13:03:01 +0100 BST
```

c.小结

- 同一条数据库记录，不管时区一不一样，mysql终端中select出的datetime始终一样。
- golang程序获取到的time.Time等于：mysql时区时间 + 时区，时区为loc指定的时区，与mysql时区没有关系。

### 实验二：应用和数据库不在同一时区
我们的国内应用需要访问海外数据库数据，假设国内机器操作系统设置为北京时间，golang程序在国内并且loc设置为Local，海外机器操作系统设置为UTC时间，海外数据库时区设置为跟随操作系统时间。

1.如果在海外mysql终端直接insert date、datetime、timestamp，在国内golang程序获取到的time.Time为 mysql【时区时间】+ CST时区，与实验一一致。

2.如果在国内golang程序中insert date、datetime、timestamp，在海外mysql客户端读取的结果为 国内【时区时间】。

3.如果在国内golang程序中insert timestamp 是通过列字段 自动更新或者通过 CURRENT\_TIMESTAMP() 插入，在海外mysql客户端读取的结果为 mysql【时区时间】。

4.小结

- date和datetime类型不包含时区信息， __mysql不会对其进行转换，存取时在mysql中相当于一个字符串__ 。
- timestamp包含时区信息，使用时需要特别注意：
  - 在golang中如果插入/更新timestamp时，显式指定其时区时间，插入数据库，再取出来拼接上原来时区信息，这样存的和取的time.Time是一样的，前后不变。此时，在存取timestamp过程中也相当于一个字符串。
  - 如果不显示指定timestamp的时区时间，而是通过 `CURRENT_TIMESTAMP` 自动更新或者通过 `CURRENT_TIMESTAMP()` 插入，那么mysql存进去的timestamp为 mysql的时区时间，取出来映射到time.Time为 mysql的时区时间+golang时区。这里有一个潜在的问题是，假设数据有A和B两个字段，它们分别是datetime类型和自动更新CURRENT_TIMESTAMP的timstamp类型，time.Now()对应数据库字段A，数据B字段不设置值，insert到数据库。在下次select出来的时候，两个字段会相差时区差个小时，这两个字段值本来应该指明同一个时间（忽略传输导致的误差）， __因为时区的原因引起了数据不一致__ 。 
- 总结：
  - 在insert的时候，当time.Time映射到date、datetime和timestamp时，都可以认为是字符串。如果 timstamp 由mysql sever端更新，可能会有数据的一致性问题。
  - 在select的时候，当date、datetime和timestamp 映射到时 time.Time 时，time.Time的地区时间为其字面量，时区为DSN配置的时区。

## 三、源码分析
> 实验已经做完了，大概已经知道golang对mysql时间类型数据转换的方式以及可能存在的问题。那么一起从源码的角度分析此问题，加深我们对其的理解。

1.golang中time.Time存入mysql的分析：  
跟踪golang运行sql的源码，在运行DB.Exec()时会调用interpolateParams()方法，其调用堆栈如下。  

```
database/sql/sql.go : DB.Exec()-->DB.ExecContext()-->DB.exec()-->DB.execDC()
database/sql/ctxutil.go : ctxDriverExec()-->execer.Exec()  
github.com/go-sql-driver/mysql/connection.go : mysqlConn.Exec() --> mysqlConn.interpolateParams()
```

它对time.Time类型的变量会经过如下截图逻辑。可以看到golang对于time.Time类型，只会对其时区时间转为字符串，丢弃其时区信息，然后拼接到sql字符串中，所以golang存进数据库时区时间跟golang所在时区时间一致。 

![golang存time.Time源码](golang存time.Time源码.png)

2.golang中取出mysql的date、datetime、timestamp映射到time.Time的分析：  
跟踪golang运行sql的源码，发现在运行rows.Next()时会调用readRow()方法，其调用堆栈如下。

```
database/sql/sql.go: Rows.Next()-->Rows.nextLocked()  
github.com/go-sql-driver/mysql/rows.go: textRows.Next()--> textRows.readRow()
github.com/go-sql-driver/mysql/packets.go: textRows.readRow()
```

对mysql的date、datetime、timestamp的变量经过如下逻辑。当程序发现其属于date、datetime、timestamp几种类型的一种时，就把其当成字符串进行解析，并且设置其时区为loc指定的时区。

![golang取time.Time源码](golang取time.Time源码.png)


## 四、总结
1.可以认为timestamp在mysql中值以 UTC时区时间+UTC时区 保存。存储时对当前接受到的时间字符串进行转化，把时区时间根据当前的时区转为UTC时间再进行存储，检索时再转换回当前的时区。  

2.在mysql中date、datetime均没有时区概念。  

3.在go-sql-driver驱动中：

- timestamp、date、datetime在转为time.Time时，时区信息是用parseTime=true&loc=xxx中loc的值指定，需要特别注意的是timestamp在mysql中的时区信息被loc替代了。  
- 在time.Time转为timestamp、date、datetime时，将会把它们当做字符串，丢弃time.Time的时区信息。


## 五、参考资料
1.查看mysql的时区  
参考 https://dev.mysql.com/doc/refman/5.7/en/time-zone-support.html 

```
SELECT @@GLOBAL.time_zone, @@SESSION.time_zone;  
// or  
show variables like "system_time_zone";  
```

2.linux修改时区  
参考 http://coolnull.com/235.html  

```
查看时区：  
zhang@debian-salmon-gb:~/Workspace/go/src/test_time$ ll /etc/localtime  
lrwxrwxrwx 1 root root 33 Nov 27 11:54 /etc/localtime -> /usr/share/zoneinfo/Asia/Shanghai  

修改时区：  
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime  
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime 
 
如何查具体的时区，如Europe/London、Asia/Shangha：  
tzselect  
```

3.MySQL中有关TIMESTAMP和DATETIME的总结  
https://www.cnblogs.com/ivictor/p/5028368.html  

4.timestamp显示为int  
使用UNIX_TIMESTAMP(timestamp)可以把timestamp显示为数字类型的值，如1554182297，时区的改变并不会影响此值的显示；如果显示为日期时间，mysql会根据设定的时区显示时间，如CST时区显示为2019-04-02 13:18:17，东一区显示时间为2019-04-02 06:18:17  

5.go-mysql-driver中时区问题  
https://github.com/go-sql-driver/mysql/issues/203  

6.golang中的时间和时区  
https://studygolang.com/articles/14933  

7.golang mysql中timestamp,datetime,int类型的区别与优劣  
https://studygolang.com/articles/6265  
