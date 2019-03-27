---
title: gitlab ci && docker-compose(5)-容器启动环境变量传递
date: 2018-09-25 00:39:50
tags:
    - docker
    - gitlabci
---


## docker run和docker-compose启动容器环境变量传递

### dockrfile中的ENV和CMD的关系（不考虑ENTRYPOINT）

* docker run使用默认命令 && dockerfile中 ENV VERSION=100, CMD ["echo","$VERSION"]：输出空

* docker run使用默认命令 && dockrfile中 ENV VERSION=100，CMD ["sh","-c","echo","$VERSION"]：输出空

* docker run使用默认命令 && dockrfile中 ENV VERSION=100，CMD ["sh","-c","echo $VERSION"]：输出100

* docker run使用默认命令 && dockrfile中 ENV VERSION=100，CMD echo $VERSION：输出100

小结：docker run使用默认命令中要读取容器内部的环境变量的话，一定要使用后两种方式。并且需要记住的是，使用默认命令的情况下主机的环境变量不会影响container的变量，比如在root的shell下执行export VERSION=101，对以上四个结果都不会有影响

### docke run使用指定命令执行与shell环境变零的关系

docke run使用指定命令，docker run image_name echo $VERSION：则输出本地shell的VERSION变量，这个VERSION变量跟container一点关系都没有，完全取决于当前shell的环境变量。需要注意的是，由于docker run时一般是在root权限下，所以执行`export VERSION=xxx` 时，请先执行`su -`，避免因为使用sudo改变了实际的shell导致不能输出。

<!--more-->

### docker-compose中的environment和dockerfile中CMD的关系（dockerfile不考虑ENTRYPOINT，docke-compose不指定command和entrypoint）

由前面可知，要在CMD使用环境变量，必须是 `["sh","-c","echo $VERSION"]` 或 `echo $VERSION` 模式，其他几个不再解释。

* docker-compose.yml不指定enviroment && dockerfile中 ENV VERSION=100, CMD ["sh","-c","echo $VERSION"]: 输出100

* docker-compose.yml指定enviroment: ${VERSION:-200} && dockerfile中 ENV VERSION=100, CMD ["sh","-c","echo $VERSION"]: 输出200

* docker-compose.yml指定enviroment: ${VERSION:-200} && dockerfile中 ENV VERSION=100, CMD ["sh","-c","echo $VERSION"] && su - 下执行 export VERSION=300: 输出300

小结：在docker-compose模式下，shell环境变量优先于默认变量（此例中默认变量为200），docker-compose.yml中的environment变量优先于dockerfile中的ENV。其实docker-compose.yml中enviroment中的变量，会在docker-compose up的时候会创建或覆盖容器对应的环境变量，所以导致容器启动时它的优先级高于dockerfile中的ENV。


对于docker-compose指定command的情况与 'docke run使用指定命令执行与shell环境变零的关系'一致，不再举例。

善用 docker-compose config 查看解析后的yml是怎样的。

更多参考：

dockerfile中的cmd：https://docs.docker.com/engine/reference/builder/#cmd

dockerfile的最佳实践：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

docker build传入多个编译时变量：https://stackoverflow.com/questions/42297387/docker-build-with-build-arg-with-multiple-arguments

docker-compose中的environment：https://docs.docker.com/compose/compose-file/#environment

docker-compose中的变量：https://docs.docker.com/compose/compose-file/#variable-substitution

docker-comppose中的变量的优先顺序：https://docs.docker.com/compose/environment-variables/

Declare default environment variables in file：https://docs.docker.com/compose/env-file/

ENTRYPOINT的shell模式的副作用：https://docs.docker.com/engine/reference/builder/#entrypoint