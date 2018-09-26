---
title: gitlab ci && docker-compose中mysql的添加权限
date: 2018-09-20 01:37:27
tags:
    - docker
    - gitlabci
---

目前网上添加msyql用户和权限时，很多都是使用INSERT, UPDATE, DELETE 直接操作权限表，并且总结得参差不齐。根据官方网站应该使用 CREATE USER 语句创建用户，使用 GRANT 语句添加权限。


* 在mysql:5.7.22中需要配合 /docker-entrypoint-initdb.d/ 目录初始化数据，这时可以在该目录的sql中可以添加权限的配置。

```sql
 -- 不应该在这里直接删除'root'@'%'，否则会影响原本root应有的权限。可以通过该命令查看该命令的影响，SHOW GRANTS FOR 'root'@'%';
 -- 如果不删用户root，会出现该权限 GRANT ALL PRIVILEGES ON *.* to 'root'@'%' WITH GRANT OPTION
 -- 如果删了用户root，会出现该权限 GRANT USAGE ON *.* to 'root'@'%'
 -- drop user 'root'@'%';

 -- 密码在启动mysql容器或者在docker-compose.yml文件中时就应该指定，如
 -- docker run -e MYSQL_ROOT_PASSWORD=test mysql:5.7.22
 -- 或
 -- environment:
 --     - MYSQL_ROOT_PASSWORD=test
 -- CREATE USER 'root'@'%' IDENTIFIED BY 'test';

GRANT ALL PRIVILEGES ON YOU_DATABASE.* TO 'root'@'%';
```

* 当然建库建表前应该用if判断，不判断也行，因为本来就是新实例。

```sql
DROP DATABASE IF EXISTS YOUR_DATABASE;
CREATE DATABASE YOUR_DATABASE;

USE YOUR_DATABASE;

CREATE TABLE `your_table` (

) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='必要的注释';
```

* 查看权限

```sql
SHOW GRANTS FOR 'root'@'%';
```

### docker-compose up命令

运行docker-compose up时，如果以前未创建相应的镜像，则默认会创建镜像并且根据该镜像启动container；如果以前创建过镜像，则判断当前是否有对应的container，如果有则直接启动，如果没有则创建对应的container；

* --build  Build images before starting containers.

    * --build，加了这个选项后，每次运行 docker-compose up 都会构建镜像。构建镜像有另外一个专门的命令docker-compose build，可以使用--build-arg key=val 传入编译时参数，如下则为 --build-arg X=3 --build-arg Y=4。传入到docker-compose后，再传到dockerfile的 ARG 声明的同名变量中，

```yml
# docker-compose.yml
version: '3'

services:
    app:
        build:
            context: .
            dockerfile: docker/dockerfile
            args:
                X: ${X:-1} #如果X不传，则X为1
                Y: ${Y:-2} #如果Y不传，则Y为2

# dockerfile
FROM some-image
# 包含编译时默认值
ARG X=1
ARG Y=gitlabci

# 编译时不包含默认值
#ARG X
#ARG Y

# 设置容器内部环境变量
ENV X=$X
ENV Y=$Y
```

* --force-recreate  Recreate containers even if their configuration and image haven't changed.
	* --force-recreate，加了这个选项后，docker-compose会重新创建container，即使与它对应的镜像没有变化
* -V, --renew-anon-volumes   Recreate anonymous volumes instead of retrievingdata from the previous containers.
    * 1.22.0版本有这个选项，某些低版本的不存在该选项
	* 仅在启动的容器已经被创建的情况下有意义
	* 从字面上来看，使用该选项运行docker-compose up 启动容器时，将会不使用复用上一个container的volume，而是重新创建对应的volume。如果不使用该选项，而是只加了--force-recreate也将仅仅会重新创建对应的容器，而不会重新mount根据对应目录而创建的volume。这个可以通过docker inpsect containter_name命令验证，两次运行docker-compose --build --force-recreate所创建的容器对应的volume的name依然相同。
	* 这个选项的存在的意义是，如果加了改选项，第一次启动容器的时候，mount对应的目录的文件有误，想stop掉当前的container，并且在对应的目录添加了对应的文件后，第二次启动容器时能够重新mount对应的文件夹，使容器读取正确对应的文件；如果不加改选项，则使用上一个container的volume，不能读取正确的文件
	* 当然，也可以不使用该命令，只要不是重启container的场景即可，什么意思呢，可以先 docker-compose rm -v contaner_name，下次docker-compose up的时候就是创建新容器了，当然也会重新挂载对应的volume。目前低版本的docker-comopose就是这么做的。
	* 之前在mysql:5.7.22 版本的docker容器在使用/docker-entrypoint-initdb.d/ 目录初始化数据时，遇到类似的问题，踩了很多坑。
* 总结，docker-compose up 与 docker start 命令更相似，因为它们都会复用之前的container（如果存在），而docker run是总会创建新的container。这要点需要牢记，才能避免踩坑。


参考:

Mysql官网 https://dev.mysql.com/doc/refman/5.7/en/adding-users.html