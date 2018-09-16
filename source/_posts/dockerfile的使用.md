---
title: dockerfile的使用
date: 2018-09-16 23:01:21
tags:
    - docker
    - gitlabci
---

## dockerfile

### COPY VS. ADD

* ADD支持从本地tar文件复制解压，tar文件内的根目录应该包含dockerfile，并且context也限定为tar内部，通常配合docker build 使用，如 docker build - < archive.tar.gz
* ADD支持url获取，COPY不支持。当使用 docker build - < somefile 传入dockerfile时，没有context可用，只能使用ADD从一个URL获取context
* ADD的最佳用途是将本地tar文件自动提取到image中，如 ADD rootfs.tar.xz / 。
* 它们都是based context，不能复制context之外的东西
* 区别：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#add-or-copy

### CMD VS. ENTRYPOINT

#### CMD：

* The CMD instruction should be used to run the software contained by your image, along with any arguments. Indeed, this form of the instruction is recommended for any service-based image. like:
    * CMD [“executable”, “param1”, “param2”…]
	* CMD ["apache2","-DFOREGROUND"]
* CMD命令还用在交互式的shell中，如bash，python，perl。例如以下几个用法。 使用这种方式的好处是你能够执行如  docker run -it python 就能直接进入到一个有用的shell中。
	* CMD ["perl", "-de0"], CMD ["python"], or CMD [“php”, “-a”]
* CMD命令很少以 CMD [“param”, “param”] 的出现，这种用法是为了配合 ENTRYPOINT 使用的，所以不要轻易使用这种方式，除非你和你的目标用户清楚ENTRYPOINT是如何工作的

#### ENTRYPOINT:

* ENTRYPOINT的最佳实践是，设置一个主要命令，使得运行image就像运行一个命令一样
* 假如有一个image定义了s3cmd命令，ENRTRYPOINT和CMD如下
    * ENTRYPOINT ["s3cmd"]
	* CMD ["--help"]
	* 那么如果直接运行 docker run s3cmd 的话，将会显示 s3cmd 的帮助提示
	* 或者提供一个参数再执行命令，docker run s3cmd ls s3://mybucket，将会覆盖CMD的--help参数
* 当然ENTRYPOINT也可以是一个sh脚本，可以自定义解析docker run 的时候传入的命令参数
* 配置容器启动后执行的命令，并且不可被 docker run 提供的参数覆盖

<!--more-->

#### CMD和ENTRYPOINT联合使用：

* ENTRYPOINT提供默认运行的命令，也可以包含默认的参数
* CMD提供附加的参数，并且如果在docker run 的时候传入了对应的命令，则会覆盖CMD的参数，附加到ENTRYPOINT后面

### context:

* 在执行docker build PATH的时候，PATH即为context，并且PATH目录默认应该有dockerfile文件
* 当然也可以使用 -f 指定dockerfile，但是PATH依然是context的唯一依据

### EXPOSE:

* EXPOSE指令通知Docker容器在运行时侦听指定的网络端口



### 参考:
* dockfile最佳实践 
https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#cmd

* ci的默认变量 
https://docs.gitlab.com/ce/ci/variables/README.html