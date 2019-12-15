---
title: golang数据库连接broken pipe异常原因分析及解决
date: 2019-11-10 21:57:03
tags:
    - go
    - mysql
---

> 在golang开发中，在使用mysql数据库时一般使用数据库驱动包为 go-sql-driver/mysql，该包是按照go官方包database/sql定义规范实现的。我们线上的程序偶尔会在标准错误输出 "broken pip"，为了究其原因做了些调研，并给出了解决方法。

## 线上场景
目前 __项目A__ 使用的go-sql-driver/mysql版本为 __3654d25ec346ee8ce71a68431025458d52a38ac0__ ， __项目B__ 使用的版本为 __v1.3.0__ ，其中 __项目A__ 的版本低于v1.3.0。它们线上标准错误输出都有类似以下的日志，但是程序的业务逻辑却没有影响。

```
[mysql] 2019/08/01 17:12:18 packets.go:33: unexpected EOF
[mysql] 2019/08/01 17:12:18 packets.go:130: write tcp 127.0.0.1:59722->127.0.0.1:3306: write: broken pipe
```

通过日志输出以及堆栈可以找到 `go-sql-driver/mysql/packets.go` 对应的源码，可以发现第一条日志是以下第8行代码打印，第二条是第9行调用`mc.Close()`关闭连接时报错。

```go
// Read packet to buffer 'data'
func (mc *mysqlConn) readPacket() ([]byte, error) {
    var prevData []byte
    for {
        // read packet header
        data, err := mc.buf.readNext(4)
        if err != nil {
            errLog.Print(err)
            mc.Close()
            return nil, driver.ErrBadConn
        }
     // 省略部分代码
}
```

## 问题复现

> 通过网上搜索能够大概猜出是mysql server主动关闭的原因，我们可以通过设置mysql server主动关闭连接来复现线上场景，并且通过tcpdump观察其原因。

### 1.设置mysql server主动关闭连接时间

mysql server默认设置的关闭不活跃连接时间为28800秒（8小时），我们通过 `set global wait_time=10` 设置为10秒，便于问题重现。

### 2.运行tcpdump和测试demo

1.通过tcpdump可以收集tcp数据包的发送接收情况，尤其是的在mysql server关闭连接后，go程序如何和mysql server交互是我们关注的重点，tcpdump命令如下：

`sudo tcpdump -s 0 -t -i lo -l port 3306 -w lo.cap`

2.运行一个简单的测试demo

```go
package main
import (
    "database/sql"
    "log"
    "time"
    _ "github.com/go-sql-driver/mysql"
)
func main() {
    // before you run this test program, please run the script in your mysql
    // "set global wait_timeout=10;"
    // 表示mysql server关闭不活跃连接的等待时间
    // 参考 https://github.com/go-sql-driver/mysql/issues/657
    db, err := sql.Open("mysql", "root:zhang@tcp(127.0.0.1:3306)/?charset=latin1&autocommit=1&parseTime=true&loc=Local&timeout=3s")
    if err != nil {
        log.Fatal(err)
    }
    defer db.Close()
    //db.SetConnMaxLifetime(5 * time.Second)
    err = db.Ping()
    if err != nil {
        log.Fatal(err)
    }
    go func() {
        for {
            _, err := db.Exec("select * from test_time.A")
            if err != nil {
                log.Fatal(err)
            }
            // Wait for 11 seconds. This should be enough to timeout the conn, since `wait_timeout` is 10s
            time.Sleep(11 * time.Second)
        }
    }()
    time.Sleep(1000 * time.Second)
}

```

<!--more-->

### 3.分析tcp数据包

通过wireshark打开lo.cap文件可以更加直观观察其交互情况，截图如下二图：
![tcpdump1](./img/tcpdump1.png)
![tcpdump2](./img/tcpdump2.png)

可以看到10秒的第222号数据包中，mysql server发送的FIN信号并且收到了golang程序第223号的ack后，进入到tcp连接中FIN\_WAIT\_2状态，golang程序则进入到CLOSE_WAIT状态，此时mysql server不再接受任何查询请求。同时由于golang程序应用层无法感知mysql server关闭了连接，在11秒第224号的数据包中依然向mysql server发送了查询请求，mysql server应用层发现错误，直接返回重置连接。应用程序也打印出对应的日志。

### 小结

通过复现和分析，可知根本原因是golang尝试去使用一个被mysql server主动关闭的连接。通过代码堆栈分析，还分析出`unexpected EOF`是发送查询给mysql server后读取返回结果报错，而`write tcp 127.0.0.1:59722->127.0.0.1:3306: write: broken pipe`则是读取结果报错后尝试关闭连接时失败的报错。

## mysql server连接和golang数据库连接池的复用时间

> 通过上一节，基本能确定是mysql server主动关闭连接的原因导致的，那么mysql server的 `wait_timeout`具体的定义和golang怎么解决这种问题的？对我们的业务有无影响？

### 1.mysql连接复用时间

mysql server在一定时间后将自动关闭不活跃连接。这个时间由`wait_timeout`决定，表示mysql server关闭 __不活跃__ 连接的等待时间。`wait_timeout`配置官方说明如下。

```
wait_timeout: 
The number of seconds the server waits for 
activity on a noninteractive connection before closing it.

https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_wait_timeout
```

### 2.golang数据库连接池复用时间

go的默认连接池不会自动关闭连接，除非通过 `DB.SetConnMaxLifetime()` 设置了连接最长的时间，一般建议该配置远小于mysql server的`wait_timeout`。

```
// SetConnMaxLifetime sets the maximum amount 
// of time a connection may be reused.
//
// Expired connections may be closed lazily before reuse.
//
// If d <= 0, connections are reused forever.
func (db *DB) SetConnMaxLifetime(d time.Duration)
```

如果某个连接已经被mysql server关闭，而go程序无法感知，在复用该数据库连接时则会输出上述的错误日志。目前 __项目A__ 和 __项目B__ 的mysql驱动版本将这种错误情况返回 `driver.ErrBadConn`。

### 3.对业务的影响

> 这种mysql server主动关闭连接的情况，对我们的业务有没影响？

go的官方 `database/sql` 包会对返回 `driver.ErrBadConn` 的错误进行重试，这点可以通过看源码 `database/sql/sql.go` 验证。可以看到只要驱动包返回了`drvier.ErrBadConn`，那么就会进行重试2次。因此如果第一次执行失败了，那么还会进行重试，所以最终对业务不会有影响，只是标准错误输出有对应的日志输出。

```go
// maxBadConnRetries is the number of maximum retries if the driver returns
// driver.ErrBadConn to signal a broken connection before forcing a new
// connection to be opened.
const maxBadConnRetries = 2

// ExecContext executes a query without returning any rows.
// The args are for any placeholder parameters in the query.
func (db *DB) ExecContext(ctx context.Context, query string, args ...interface{}) (Result, error) {
    var res Result
    var err error
    for i := 0; i < maxBadConnRetries; i++ {
        res, err = db.exec(ctx, query, args, cachedOrNewConn)
        if err != driver.ErrBadConn {
            break
        }
    }
    if err == driver.ErrBadConn {
        return db.exec(ctx, query, args, alwaysNewConn)
    }
    return res, err
}

```


## 解决方案

> 测试demo见问题复现章节
 
### 解决方案一：更新mysql驱动到目前最新release版本-v1.4.1

目前最新release的版本v1.4.1包含了修改以前 __激进重试策略__ 的提交（代码修改逻辑见 [commit](https://github.com/go-sql-driver/mysql/commit/26471af196a17ee75a22e6481b5a5897fb16b081)），将 __许多__ 情况下从返回 `driver.ErrBadConn` 改为返回 `ErrInvalidConn`，减少滥用官方sql包的重试逻辑。本章讨论的mysql server主动关闭连接也在此次修改中。

跟踪源代码调用栈发现，由于连接为非阻塞socket，在mysql server关闭连接后，`go-sql-driver/mysql`还能继续write数据到socket的buffer中，并且不会立即返回错误。在`go-sql-driver/mysql`读取返回值时才从系统内核socket读取mysql server返回的错误，此时`go-sql-driver/mysql`知道mysql server返回错误了。这个时候有两个策略：

- 一是返回driver.ErrBadConn，在官方`go-sql-driver/mysql`包进行重试，release版本-v1.3.0使用这种策略。
- 二是返回db error，因为从mysql应用层面来说，它认为已经发送sql成功，只是读取的时候返回错误了，这个时候它不需要重试逻辑，__避免sql被重复执行__。目前release版本-v1.4.0和v1.4.1就是这种策略。

使用release版本-v1.4.1，经测试mysql server关闭连接后，再执行sql会输出以下日志，其中第一行为`go-sql-driver/mysql`包的标准错误输出，第二行和第三行是程序逻辑的日志输出，执行sql时返回db error，官方sql包没有进行重试。

```
[mysql] 2019/08/01 17:09:41 packets.go:36: unexpected EOF
2019/08/01 17:09:41 invalid connection
exit status 1
```

小结：

- 优点：
	- 避免了使用激进的重试策略，符合golang定义的规范。
	- 可以通过SetConnMaxLifetime主动设置DB使用每条连接的时间，只要SetConnMaxLifetime设置的时间比`wait_timeout`小，`go-sql-driver/msyql`就能主动关闭连接。

- 缺点：
	- 在不设置SetConnMaxLifetime时，在mysql server关闭连接后再使用该连接机会返回db error，对目前代码冲击比较大。

### 解决方案二：更新mysql驱动到最新的master

> 目前master的最新提交为 877a9775f06853f611fb2d4e817d92479242d1cd，本节讨论的master基于版本

由于mysql驱动release的版本v1.4.0和v1.4.1废除了原来激进的重试策略，不活跃连接被关闭后仍然会被golang使用，并且不再重试导致直接返回db error。故本小结探讨两个点：

- 能否在使用连接前确认连接是否被关闭。如果已经被关闭或者有异常数据，则返回`driver.ErrBadConn`便于`database/sql`进行重试；如果没有关闭，则复用该连接。
- 通过某种机制避免重复执行sql。

为此vicent提出了[mr](https://github.com/go-sql-driver/mysql/pull/934) ，目前已经被merge到[master](https://github.com/go-sql-driver/mysql/commit/bc5e6eaa6d4fc8a7c8668050c7b1813afeafcabe)中，但是未发布release版本，目前还在不断的优化中。简单描述一下vicent的修改要点：

- 从pool刚拿出的连接均为不活跃的连接。
- 刚从pool拿出的连接，如果直接从socket读取一个字节的内容，那么一定不会从mysql服务端收到信息，因为该连接原先是不活跃连接，与mysql server没有实际的数据交换，仅仅是保持连接。如果能读到数据则表示连接有异常，返回`driver.ErrBadConn`便于`database/sql`进行重试。
- 由于Go的runtime使用的是非阻塞（O_NONBLOCK）的socket，可以在向mysql server发送数据包前，先调用read()方法做探测：
    - 1.当read返回 n=0&&err==nil，表示对端的socket已经关闭，这种情况下返回driver.ErrBadConn，便于go的sql包进行重试。
    - 2.当read会返回n>0，表示对端的socket有异常，依然能够读取到数据，也意味连接异常，返回driver.ErrBadConn，便于go的sql包进行重试。
    - 3.当read返回 err=EAGAIN(linux) 或者 EWOULDBLOCK(windows)，表示对端的socket未关闭，这种情况下可以复用该连接。由于是非阻塞的read，当对端没有数据可读，程序不会阻塞起来等待数据就绪，而是返回EAGAIN和EWOULDBLOCK提示目前没有数据可读，请稍后再试。

- 刚从pool拿出的连接，如果探测结果为是上面第1和第2种情况，则返回`driver.ErrBadConn`给上层go官方包便于进行重试；如果探测结果为 EAGAIN 或者 EWOULDBLOCK则可以继续使用此连接。
- 没有放进pool的连接不需要进行探测，直接复用。

使用最新的master，经测试mysql server关闭连接后，再执行sql会输出以下日志，其为mysql驱动输出，并且程序不报错。在mysql client执行 `show full processlist` 能够看到两条连接的建立，即第一条连接被sever关闭后，由于探测发现连接被关闭，所以不会使用原先的连接而是重新建立连接。

```
[mysql] 2019/08/01 19:45:15 packets.go:122: closing bad idle connection: EOF
```

小结：

- 优点：
	- 避免了使用激进的重试策略，符合golang定义的规范。
	- 通过探测机制避免了在mysql server关闭连接后再使用该连接机会返回db error的影响。
	- 可以不用设置SetConnMaxLifetime。
- 缺点：
	- 目前master版本仍然可能对探测机制进行优化中，可以等下一个release发布再更新。

### 解决方案三：不升级mysql驱动版本

由于目前的重试逻辑存在，我们可以不升级mysql驱动版本。虽然目前日志有错误输出，如果确认是mysql server __主动关闭连接__ 导致的可以忽略这种错误，毕竟`database/sql`会进行重试。也可以通过SetConnMaxLifetime设置连接复用时间，到期`go-sql-driver/msyql`可以自动关闭连接。

小结：

- 优点：
	- 在mysql server关闭连接后再使用该连接机不会返回db error，`database/sql`能够进行重试。
	- 可以通过SetConnMaxLifetime主动设置DB使用每条连接的时间，只要SetConnMaxLifetime设置的时间比`wait_timeout`小，`go-sql-driver/msyql`就能主动关闭连接。
- 缺点：
	- 使用激进的重试策略，不符合golang定义的规范，在极端情况下sql仍然可能会被执行多次。

## 总结

本文分析线上报错的原因以及线下重现问题，通过研究golang源码解释了重试逻辑以及重试逻辑变更原因，解释了vicent探测socket改进的基本思路，最后给出了对应的解决方案：

1.如果要更新到v1.4.1版本，一定要通过SetConnMaxLifetime设置DB最长使用连接时间，并且要比mysql的`wait_timeout`小。

2.如果要使用具有探测socket功能版本，等下一个release版本，可以不用设置SetConnMaxLifetime。

3.如果暂时不需要更新，能够接受重复执行sql的风险，也最好通过SetConnMaxLifetime设置DB最长使用连接时间，并且要比mysql的`wait_timeout`小。

## 参考链接
 
- Server timeouts broken since #302 [https://github.com/go-sql-driver/mysql/issues/657](https://github.com/go-sql-driver/mysql/issues/657)
- packets: Check connection liveness before writing query [https://github.com/go-sql-driver/mysql/pull/934](https://github.com/go-sql-driver/mysql/pull/934)
- Go SQL client attempts write against broken connections [https://github.com/go-sql-driver/mysql/issues/529](https://github.com/go-sql-driver/mysql/issues/529)
- Check connection liveness before sending query [https://github.com/go-sql-driver/mysql/issues/882](https://github.com/go-sql-driver/mysql/issues/882)
- Golang网络库中socket阻塞调度源码剖析 [https://studygolang.com/articles/4977](https://studygolang.com/articles/4977)
- Linux中的EAGAIN含义 [https://www.cnblogs.com/pigerhan/archive/2013/02/27/2935403.html](https://www.cnblogs.com/pigerhan/archive/2013/02/27/2935403.html)

