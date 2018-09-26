---
title: gitlab ci && docker-compose中容器启动先后顺序问题
date: 2018-09-26 01:27:33
tags:
    - docker
    - gitlabci
---


## docker-compose容器启动先后顺序问题

App应用程序容器需要连接一个mysql容器，使用docker-compose启动容器组，应该怎么做？在docker-compose中，容器A依赖容器B，B容器会先启动，然后再启动A容器，但是B容器不一定初始化完毕对外服务。

先来看一段mysql官方对于这种问题的两段说明

> No connections until MySQL init completes
> * If there is no database initialized when the container starts, then a default database will be created. While this is the expected behavior, this means that it will not accept incoming connections until such initialization completes. This may cause issues when using automation tools, such as docker-compose, which start several containers simultaneously.
> * If the application you're trying to connect to MySQL does not handle MySQL downtime or waiting for MySQL to start gracefully, then a putting a connect-retry loop before the service starts might be necessary. For an example of such an implementation in the official images, see WordPress or Bonita.

所以一般有两种方法解决类似的问题

* 程序层面改进，程序连接mysql部分需要有重连机制
* 连接容器改进，在shell命令中判断mysql容器是否启动，如果未启动设定时间等待，如果启动了再启动应用程序

_这里只说明第二种方法_

### 使用wait-for-it.sh

```yml
# docker-compose.yml
version: '3'

services:
  app:
    build:
      context: .
      dockerfile: DockerfileAPP
    image: app:latest
    ports:
      - "127.0.0.1:8080:8080"
    depends_on:
      - mysql_db
    command: /go/src/app/wait-for-it.sh mysql_db:3306 -s -t 30 -- /go/src/app/app-release start

  mysql_db:
    #build:
    #  context: .
    #  dockerfile: DockerfileMySQL
    #image: mysql_db:latest
    image: "mysql:5.7.22"
    environment:
      - MYSQL_ROOT_PASSWORD=test
    expose:
      - "3306"
    volume:
      - ./init_sql_script/:/docker-entrypoint-initdb.d/
```

注意这行代码

> command: /go/src/app/wait-for-it.sh mysql_db:3306 -s -t 30 -- /go/src/app/app-release start

-s 表示如果没有检测到host为mysql_db的3306端口，则不执行后面的命令；-t 30表示超时时间为30秒，更多配置见参考。wait-for-it.sh可以使用多次，比如需要等待msyql和redis，可以这么写`command: /go/src/app/wait-for-it.sh mysql_db:3306 -s -t 30 -- command: /go/src/app/wait-for-it.sh redis:6379 -s -t 30 -- /go/src/app/app-release start`

参考：

mysql官方docker说明 https://hub.docker.com/_/mysql/

Control startup order in Compose https://docs.docker.com/compose/startup-order/

vishnubob/wait-for-it https://github.com/vishnubob/wait-for-it