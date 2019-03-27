---
title: go系列-中间件
date: 2018-09-29 01:02:32
tags:
    - go
---

## go中间件

最近看代码看到go中间件的代码，遂搜相关代码以及类似的框架进行学习 

### 什么是中间件

* 了解中间件前需要了解 ServeMux、DefaultServeMux、http.Handler、http.HandlerFunc、mux.HandleFunc、ServeHTTP 等相关知识和它们之间的关系[推荐]
https://www.alexedwards.net/blog/a-recap-of-request-handling

* context能做什么
https://blog.questionable.services/article/map-string-interface/

### gorilla系列 & Negroni

* Go实战--Golang中http中间件(goji/httpauth、urfave/negroni、gorilla/handlers、justinas/alice)
https://blog.csdn.net/wangshubo1989/article/details/79227443

* Go实战--Gorilla web toolkit使用之gorilla/handlers
https://blog.csdn.net/wangshubo1989/article/details/78970282

* Go实战--Gorilla web toolkit使用之gorilla/context
https://blog.csdn.net/wangshubo1989/article/details/78910935

* gorilla/mux https://github.com/gorilla/mux (需要着重看一下 文中的Graceful Shutdown和 https://github.com/gorilla/mux#graceful-shutdown）

* Negroni https://github.com/urfave/negroni

[代码学习](https://github.com/salmon7/go-learning/tree/master/middle

### justinas/alice

// TO-DO