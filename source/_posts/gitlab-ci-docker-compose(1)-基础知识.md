---
title: gitlab ci && docker-compose(1)-基础知识
date: 2018-09-27 00:44:36
tags:
    - docker
    - gitlabci
---

工作中需要使用到gitlab ci和docker-compose，而docker是这两者的前提。网上docker学习资料有很多，但是有一大部分是过时的，官网也有详细的文档，但是快速阅读起来比较慢，毕竟不是母语。之前学习的时候走了很多弯路，现把最近搜集到比较好的资料分享出来，希望对大家有帮助

## docker学习资料

Docker — 从入门到实践（一个不错的docker入门教程，极力推荐）:
* https://github.com/yeasy/docker_practice
* https://docker_practice.gitee.io/

Docker 问答录（100 问）：https://blog.lab99.org/post/docker-2016-07-14-faq.html

dockerfile中：https://docs.docker.com/engine/reference/builder/

dockerfile的最佳实践：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

docker之Dockerfile实践（以nginx为例，一步一步构建镜像）：http://www.cnblogs.com/jsonhc/p/7767669.html


## docker-compose学习资料

docker-compose中的environment：https://docs.docker.com/compose/compose-file/#environment

docker-compose中的变量：https://docs.docker.com/compose/compose-file/#variable-substitution

docker-comppose中的变量的优先顺序：https://docs.docker.com/compose/environment-variables/

Declare default environment variables in file：https://docs.docker.com/compose/env-file/

ENTRYPOINT的shell模式的副作用：https://docs.docker.com/engine/reference/builder/#entrypoint

vishnubob/wait-for-it https://github.com/vishnubob/wait-for-it

dockfile最佳实践：https://docs.docker.com/develop/develop-images/dockerfile_best-practices/

## gitlab-ci学习资料

这部分学习大部分都是官网，不做过多的分享，只留一个默认变量的链接

ci的默认变量：https://docs.gitlab.com/ce/ci/variables/README.html