---
title: keepalived docker部署
date: 2025-02-10 10:45:00
categories: [运维]
tags: [运维, keepalived, docker]
image:
  path: /assets/img/posts/common/keepalived.jpg
---

# keepalived docker部署
基于`osixia/keepalived` docker镜像。

## 容器化部署优缺点
+ 优点：融入云原生的生态。
+ 缺点：非常明显。在自定义健康检测和通知处理场景，如果涉及访问或修改其他外部中间件文件（也可能是容器化部署），由于该操作是在容器内发起，需要使用特权指令或全量挂载等特殊配置，且违背容器隔离原则。

## 镜像使用说明
[使用参考](https://github.com/osixia/docker-keepalived)，基于docker compose
```yml
keepalived:
    image: osixia/keepalived:2.0.20
    container_name: keepalived-master
    # 相当于--net=host，容器内部默认网卡ens0，使得能从容器内部识别到宿主机的物理网卡
    network_mode: "host"
    privileged: true
    # restart: always
    volumes:
      # 挂载自定义keepalived.conf配置文件。注意文件权限非可执行，建议chmod 644
      - /xx/keepalived-master.conf:/container/service/keepalived/assets/keepalived.conf
      # 非必须。需要自定义状态通知处理时挂载
      - /xxx/ctm-notify.sh:/container/service/keepalived/assets/notify.sh
    # 使用挂载时，该参数必须，参考https://github.com/osixia/docker-keepalived/issues/5
    command: [ '--copy-service' ]
```

## 镜像默认通知处理脚本
位于容器内的`/container/service/keepalived/assets/notify.sh`
```sh
#!/bin/bash

# for ANY state transition.
# "notify" script is called AFTER the
# notify_* script(s) and is executed
# with 3 arguments provided by keepalived
# (ie don't include parameters in the notify line).
# arguments
# $1 = "GROUP"|"INSTANCE"
# $2 = name of group or instance
# $3 = target state of transition
#     ("MASTER"|"BACKUP"|"FAULT")

TYPE=$1
NAME=$2
STATE=$3

case $STATE in
    "MASTER") echo "I'm the MASTER! Whup whup." > /proc/1/fd/1
		echo -e "\n$(date '+%Y-%m-%d %H:%M:%S')" >> ./notify.log
        exit 0
    ;;
    "BACKUP") echo "Ok, i'm just a backup, great." > /proc/1/fd/1
        exit 0
    ;;
    "FAULT")  echo "Fault, what ?" > /proc/1/fd/1
        exit 0
    ;;
    *)        echo "Unknown state" > /proc/1/fd/1
        exit 1
    ;;
esac
```