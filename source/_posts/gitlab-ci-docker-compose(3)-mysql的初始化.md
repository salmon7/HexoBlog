---
title: gitlab ci && docker-compose(3)-mysql的初始化
date: 2018-09-18 23:19:20
tags:
    - docker
    - gitlabci
---

## mysql 容器初始化：

* 根据官方文档可以使用docker启动时bind主机包含sql、sh文件的目录到容器/docker-entrypoint-initdb.d/目录，在使用mysql镜像启动容器时会自动读取该文件夹下的内容对数据库初始化。可以使用以下两种方式在命令行启动，在低版本中可能只支持-v选项，在docker 17.03.0-ce版本(不含)以上支持--mount选项。

```
--mount选项
sudo docker run -it --name=mysql_db --mount type=bind,src=/home/zhang/Workspace/go/src/app/init_sql_script/,dst=/docker-entrypoint-initdb.d/ -e MYSQL_ROOT_PASSWORD=test -d mysql:5.7.22

-v选项
sudo docker run -it --name=mysql_db -v /home/zhang/Workspace/go/src/app/init_sql_script/:/docker-entrypoint-initdb.d/ -e MYSQL_ROOT_PASSWORD=test -d mysql:5.7.22
```

* 另外一种方法使用dockerfile的方式。直接在dockerfile中复制相应的sql,sh文件到/docker-entrypoint-initdb.d/目录下，再根据dockerfile build出对应的镜像，docker run的时候也会直接初始化对应的数据。

```
# DockerfileMySQL
FROM mysql:5.7.22

COPY ./init_sql_script/ /docker-entrypoint-initdb.d/
```

```
sudo docker build -t app_mysql_db:init-data . 
sudo docker run --name=app_mysql_db app_mysql_db:init-data
```

## docker-compose启动容器组：

<!--more-->

* 可以使用docker-compose启动容器组，先写好 docker-compose.yml后，在build和run。

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
    command: app start

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

```
sudo docker-compose build 
sudo docker-compose up --force-recreate
```

## gitlab ci 启动容器组:

* gitlab ci 对于使用bind(--monut or -v)方式初始化数据库有还未有很好的支持。在gitlab ci中使用docker-compose中启动容器组时，docker-compose.yml中使用bind模式时不能成功初始化数据。如果docker-compose.yml使用dockerfile的方式则能够初始化数据。



参考:

mysql官方docker说明 https://hub.docker.com/_/mysql/

Introduce relative entrypoints and start services after project clone and checkout 
https://gitlab.com/gitlab-org/gitlab-runner/issues/3210

MIGRATING TO GITLAB CI SERVICES 
https://www.mariocarrion.com/2017/10/16/gitlab-ci-services.html

gitlab ci: mysql build and restore db dump 
https://stackoverflow.com/questions/44009941/gitlab-ci-mysql-build-and-restore-db-dump
