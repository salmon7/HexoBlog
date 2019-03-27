---
title: gitlab ci && docker-compose(2)-dockerfile的使用
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

* ENTRYPOINT为exec模式时，才能够指定CMD参数和docker run时的参数；
* ENTRYPOINT为shell模式时，CMD参数和docker run的参数都将失效。
* ENTRYPOINT提供默认运行的命令，也可以包含默认的参数
* dockerfile中的CMD提供的默认参数，并且如果在docker run 的时候传入了对应的命令（这时命令应该被理解为参数），则会覆盖CMD的默认参数，添加到ENTRYPOINT后面	

#### 小结

CMD
* 一般使用exec模式
* 使用shell模式时，将会默认在命令亲前面加上 /bin/sh -c，如 /bin/bash -c "echo $HOME"
* 如果要解析主机的环境变量，则要在docker run的时候替换dockerfile中默认的命令
* 如果要解析container的环境变量，则要在dockerfile中使用CMD的shell模式，如executable param1 param2，或者在正常exec模式加上"sh","-c"，然后具体命令参数只添加到list中的一个参数中，如["sh", "-c", "executable param1 param2"]，


ENTRYPOINTV
* 一般使用exec模式
	* 只有exec模式才能与CMD联合使用
	* shell模式将会忽略dockerfile中的CMD和docker run时指定的参数
* 如果要使用shell模式，请使用exec来启动命令，如果不加exec将会默认在命令亲前面加上 /bin/sh -c。要确保docker stop能给任何长时间运行的ENTRYPOINT可执行文件正确发出信号，需要记住用 *exec* 启动它，如 ENTRYPOINT exec executable param1 param2。
* 如果使用--entrypoint覆盖默认的ENTRYPOINT，则--entrypoint也必须为exec模式（将不会在命令前添加sh -c），需要注意的是entrypoint只能为一个命令或者shell脚本，不能包含任何参数，参数应该为docker run指定的参数。使用--entrypoint覆盖默认ENTRYPOINT的同时，dockerfile中的CMD也失效，CMD不再作为默认的参数



### context:

* 在执行docker build PATH的时候，PATH即为context，并且PATH目录默认应该有dockerfile文件
* 当然也可以使用 -f 指定dockerfile，但是PATH依然是context的唯一依据

### EXPOSE:

* EXPOSE指令通知Docker容器在运行时侦听指定的网络端口



### 参考:
dockfile最佳实践：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/#cmd

ci的默认变量：https://docs.gitlab.com/ce/ci/variables/README.html

dockerfile引用参考：https://docs.docker.com/engine/reference/builder/

ENTRYPOINT和CMD的联合使用：https://docs.docker.com/engine/reference/builder/#understand-how-cmd-and-entrypoint-interact

sudo or gosu：https://segmentfault.com/a/1190000004527476

What does set -e and exec “$@” do for docker entrypoint scripts?：https://stackoverflow.com/questions/39082768/what-does-set-e-and-exec-do-for-docker-entrypoint-scripts

bash 内置命令exec （重要！！）：https://www.cnblogs.com/gandefeng/p/7106742.html

docker run --entrypoint如何添加参数：https://docs.docker.com/engine/reference/run/#entrypoint-default-command-to-execute-at-runtime
