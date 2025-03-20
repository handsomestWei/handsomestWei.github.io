---
title: 使用arthas监控诊断java应用
date: 2025-01-17 17:40:00
categories: [后端, java]
tags: [后端, java, arthas]
image:
  path: /assets/img/posts/common/java.jpg
---

# 使用arthas监控诊断java应用

## arthas简介
[arthas](https://arthas.aliyun.com/doc/)是阿里的一款线上监控诊断产品，通过全局视角实时查看应用 load、内存、gc、线程的状态信息，并能在不修改应用代码的情况下，对业务问题进行诊断，包括查看方法调用的出入参、异常，监测方法执行耗时，类加载信息等，大大提升线上问题排查效率。

## arthas安装使用
[参考](https://arthas.aliyun.com/doc/download.html#%E4%BB%8E-maven-%E4%BB%93%E5%BA%93%E4%B8%8B%E8%BD%BD)

## arthas常用命令 
### 使用dashboard查看当前应用整体信息
[dashboard命令详解](https://arthas.aliyun.com/doc/dashboard.html)   
包含有jvm信息，查看各代内存占用，查看gc次数和平均时间判断是否频繁gc（容易引起cpu升高）
```sh
dashboard
```
### 使用thread观测应用所有线程
[thread命令详解](https://arthas.aliyun.com/doc/thread.html)
```
## 查看当前线程情况
thread

## 查看线程cpu占用 top 5
thread -n 5
```
### 使用watch查看方法调用入出参数的实时值
[watch命令详解](https://arthas.aliyun.com/doc/watch.html)
```sh
watch <类全名> <方法名>
```
### 使用trace追踪方法调用栈和耗时
[trace命令详解](https://arthas.aliyun.com/doc/trace.html)   
可以在没有源码的情况下根据方法调用栈逐层追踪   
```
trace <类全名> <方法名>
```
默认不会追踪JDK自带的方法，如果需要追踪方法内部的`new Thread`等线程调用，需要带参数`--skipJDKMethod false`

### 查看对象内部属性
[ognl命令详解](https://arthas.aliyun.com/doc/ognl.html)
```sh
## 格式例：ognl '@类全名@内部属性.<属性方法>'
ognl '@com.xxx.XXXQueue@queue.size()
```
## 更多arthas使用案例
[参考](https://github.com/alibaba/arthas/issues?q=label%3Auser-case)
