---
title: 使用dbutils作为pymysql的连接池时，setsession偶尔失效的问题
date: 2019-12-23 00:03:14
tags:
    - python
    - mysql
---

> 版本情况dbutils:1.1; pymysql:0.9.3; python:2.7.13

## 线上情景

最近线上维护时，由于只需要更改数据库配置，所以就重启了数据库，而python应用没有重启。在重启数据库后，日志显示正常，也能成功入库。后来接到反馈表示有部分数据没有入库，紧急重启python应用，后续数据入库正常。而我则负责找出原因以及修复bug的工作。

## 调研原因

在排查完其他问题后，最异常的是对于有部分请求，日志显示处理成功了，但是却没入库，排查了好几天找不到原因。为此写了demo来帮助排查，为了可以自动commit，采用的是setsession=["set autocommit=1"]方式设置每个底层的连接为自动提交。在测试demo期间，数据库重启后之后的sql就无法入库。demo代码如下：

```python
# -*- coding: utf-8 -*-

import pymysql
import time
import traceback
from DBUtils.PooledDB import PooledDB
from pymysql import MySQLError

pymysql.install_as_MySQLdb()
con = None
pooledDB = None

def try_insert():
    i = 0
    while i < 60:
        print "============ {0} ============".format(i)
        # 除了第一次从库中拿，不用ping，直接接初始化链接
        # 后面如果有cache connection，则从cache中并且进行ping，如果失败则用_create()重新初始化connection
        # con 类型为 PooledDedicatedDBConnection
        # con._con 类型为 SteadyDBConnection
        # con._con._con 类型为 pymysql中的Connection类型
        # con._con._con._sock 类型为 mysql 连接
        con = pooledDB.connection()
        # con._con._con.autocommit(True)
        print "con._con id = {0}".format(id(con._con))
        print "con._con._con id = {0}".format(id(con._con._con))
        print "con._con._con._sock id = {0}".format(id(con._con._con._sock))
        try:
            cursor = con.cursor(pymysql.cursors.DictCursor)
            if not cursor:
                print "cursor is {0}".format(cursor)
            select_sql = "insert into user2(name,age) values('zhang', 20)"
            ret_rows = cursor.execute(select_sql)
            print cursor._last_executed
            print "ret_rows is {0}".format(ret_rows)

        except MySQLError as e:
            print "MySQLError error: {0}".format(e)
            print traceback.format_exc()
        except Exception as e:
            print "Exception error: {0}".format(e)
            print traceback.format_exc()

        i = i + 1
        time.sleep(1)
        con.close()


if __name__ == "__main__":
    db_conf = {'user':'root','passwd':'zhang','host':'127.0.0.1','port':3306,'connect_timeout':5,'db':'test_dbutils'}
    # db_conf = {'user':'root','passwd':'zhang','host':'127.0.0.1','port':3306,'connect_timeout':5,'db':'test_dbutils',"autocommit":True}


    pooledDB = PooledDB(
        creator=pymysql,  # 使用数据库连接的模块
        maxconnections=4,  # 连接池允许的最大连接数，0和None表示不限制连接数
        mincached=0,  # 初始化时，连接池中至少创建的空闲的链接，0表示不创建
        maxcached=0,  # 连接池中最多闲置的链接，0和None不限制
        maxshared=0,  # 连接池中最多共享的链接数量，0表示不共享。PS: 无用，因为pymysql和MySQLdb等模块的 threadsafety都为1，此值只有在creator.threadsafety > 1时设置才有效，否则创建的都是dedicated connection，即此连接是线程专用的。
        blocking=True,  # 连接池中如果没有可用连接后，是否阻塞等待。True，等待；False，不等待然后报错
        maxusage=None,  # 一个连接最多被重复使用的次数，None表示无限制
        setsession=["set autocommit=1"],  # 开始会话前执行的命令列表。如：["set datestyle to ...", "set time zone ..."]；务必要设置autocommit，否则可能导致该session的sql未提交
        ping=1,  # 每次从pool中取连接时ping一次检查可用性
        reset=False,  # 每次将连接放回pool时，将未提交的内容回滚；False时只对事务操作进行回滚
        **db_conf
    )

    try_insert()

```

<!--more-->

同时分析dbutils的关键源码:

- PooledDB：代表线程池，负责控制连接的数量、达到上限时是否阻塞、取出连接、放回连接等连接管理层面的工作。
- PooledDedicatedDBConnection：池专用连接的辅助代理类，调用pooledDB.connection()时，返回的就是这个链接。它保存了底层连接SteadyDBConnection，调用PooledDedicatedDBConnection的任何方法，除了close，都会直接调用SteadyDBConnection对应的方法。
- SteadyDBConnection：稳定数据库连接，负责封装驱动层面（如pymql）的数据库连接、创建数据库连接、执行数据库连接的ping方法、执行execute方法。

SteadyDBConnection的`_ping_check()`方法有重连机制，对这部分源码添加debug信息帮助排查问题：

```python
def _ping_check(self, ping=1, reconnect=True):
    """Check whether the connection is still alive using ping().

    If the the underlying connection is not active and the ping
    parameter is set accordingly, the connection will be recreated
    unless the connection is currently inside a transaction.

    """
    if ping & self._ping:
        try: # if possible, ping the connection
            my_reconnect = True
            alive = self._con.ping(reconnect=my_reconnect)
            # 源码为: alive = self._con.ping() 
            # print "try to ping by pymysql(reconnect={0})".format(my_reconnect)
            # my_reconnect = False
            # try:
            #     print "try to ping by pymysql(reconnect={0})".format(my_reconnect)
            #     alive = self._con.ping(False)  # do not reconnect
            # except TypeError:
            #     print "try to ping by pymysql(reconnect={0}) did not have ping(False)".format(my_reconnect)
            #     alive = self._con.ping()
        except (AttributeError, IndexError, TypeError, ValueError):
            print "ping method is not available"
            self._ping = 0 # ping() is not available
            alive = None
            reconnect = False
        except Exception,e :
            print "try to ping by pymysql(reconnect={0}) fail".format(my_reconnect)
            alive = False
        else:
            if alive is None:
                alive = True
            if alive:
                reconnect = False
            print "try to ping by pymysql(reconnect={0}) success".format(my_reconnect)
        if reconnect and not self._transaction:
            try: # try to reopen the connection
                print "try to reconnect by dbutils"
                con = self._create()
            except Exception:
                print "try to reconnect by dbutils fail"
                pass
            else:
                print "try to reconnect by dbutils success"
                self._close()
                self._store(con)
                alive = True
        return alive

```

分别修改myreconnect的值进行测试：

- 测试1：my_reconnect=True（对于pymysql的ping默认值为True），运行demo期间重启数据库。

```
异常开始：
try to ping by pymysql(reconnect=True)
try to ping by pymysql(reconnect=True) fail
try to reconnect by dbutils
try to reconnect by dbutils fail

异常恢复：
try to ping by pymysql(reconnect=True)
try to ping by pymysql(reconnect=True) success

恢复后，不能入库
```

- 测试2：my_reconnect=False，运行demo期间重启数据库。

```
异常开始：
try to ping by pymysql(reconnect=False)
try to ping by pymysql(reconnect=False) fail
try to reconnect by dbutils
try to reconnect by dbutils fail

异常恢复：
try to ping by pymysql(reconnect=False)
try to ping by pymysql(reconnect=False) fail
try to reconnect by dbutils
try to reconnect by dbutils success

恢复后，能够入库
```

经过调试发现，pymysql的ping方法默认情况会进行重连，而不是dbutils的重连。所以在dbuitils的`_ping_check`方法的重连机制有几率会不执行，因为pymysql的ping已经重连了，从而导致 setsession 中的配置没有在拿连接的时候设置进去。

原因总结：

1. pymysl的ping有个默认参数reconect，并且为true，即reconnect=True
2. dbutils的ping机制依赖于pymysql原生的ping，并且默认不设置任何参数，即在目前版本的dbutil下其ping默认会自动reconnect
3. dbutils的ping默认调用时机：只要从pool中拿连接就会进行ping
4. 始化PooledDB时，通过setsession参数的方式，设置自动commit，即 setsession=["set autocommit=1"]。因此只要是从dbutil拿连接的时候，都会预先配置该session，即执行业务sql前，先执行setsession的内容
5. 在连接丢失或者其他异常时，由于pymysql的ping默认进行重连，故dbutils层面无法感知已经重连，setsession也不会再次执行，故后续该连接执行的sql不会进行commit。
6. 这是个bug，已经提issue给dbutils的作者，在最近的版本会修复这个bug。问题的重现以及修复方法详见：[When use pymsql driver, the setsession params for PooledDB is not work after mysql server restart](https://github.com/Cito/DBUtils/issues/23)

## 解决方案

在dbutils未修复该bug前，可以通过PoolDB的kwargs参数透传{"autocommit":True}到pymysql中，这样即使通过pymysql的ping方法重连的连接也会保留自动提交的功能。