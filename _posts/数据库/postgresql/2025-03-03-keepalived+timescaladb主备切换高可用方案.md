---
title: keepalived+timescaladb主备切换高可用方案
date:  2025-03-03 11:24:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, timescaladb, 时序数据库]
image:
  path: /assets/img/posts/common/pg-ts.jpg
---

# keepalived+timescaladb主备切换高可用方案

## 环境和组件依赖
ubuntu 22.04，docker引擎
+ keepalived v2.2.4
+ timescaledb docker镜像`wjy2020/timescaledb-repmgr:pg14.15-ts2.17.2`，[镜像使用参考](https://hub.docker.com/r/wjy2020/timescaledb-repmgr)

## 方案思路
在双机分别部署这两个组件，`keepalived`定时检测`timescaladb`数据库的主备状态，当数据库状态发生变化，`keepalived`状态随之调整，使得虚拟ip能正确的绑定到主数据库（可读写）所在ip。

## keepalived配置
执行`sudo apt install keepalived -y`安装后，`keepalived.conf`配置文件位于`/etc/keepalived`目录，文件和目录没有则手动创建。   
使用非抢占模式，双机的状态配置都是`state BACKUP`，先启动的是master节点。
```conf
! Configuration File for keepalived
# 配置参考https://keepalived.org/manpage.html
# 注意：如果使用了osixia/keepalived docker镜像并配置了相关环境量，会覆盖本配置文件对应的参数值

# 选配。声明模块名称为check_haproxy，使用自定义检测脚本来监控服务的状态，并根据脚本的返回结果决定是否触发故障转移
# 如果健康检测脚本返回非零退出状态码，Keepalived 会将自身降级为Backup状态；如果所有健康检测都通过，且当前没有其他节点是Master，它将尝试升为主
# 需要在vrrp_instance之前提前声明
vrrp_script check_postgres {
	# 注意脚本执行权限。docker需要配置挂载映射。注意脚本可能有入参传递
	script "/etc/keepalived/check_postgres.sh pg0"
	# 每隔5秒检查一次
	interval 5
}

global_defs {
	# 路由id，当前安装keepalived的节点主机标识符，保证全局唯一。
	router_id MASTER
	# WARNING - default user 'keepalived_script' for script execution does not exist - please create.
	script_user root
}
 
vrrp_instance VI_1 {
    # 虚拟ip绑定的物理机网卡名称
    interface ens33
    # 节点定义，MASTER/BACKUP
    # state MASTER
	state BACKUP
	# 非抢占模式，同时master节点的state也要改为BACKUP，先启动的是master节点
	# 当MASTER故障后，BACKUP会成为新的MASTER，而当老的MASTER恢复后，又会抢占成为新的 MASTER，接管VIP的流量，会产生一次不必要的主备切换。也避免虚拟ip在节点间来回漂移引起网络抖动
	nopreempt
    # 虚拟路由id，主从集群之间必须一致，同一组集群vid唯一。基于规范性要求，一般设置为虚拟iP最后一位
    virtual_router_id 51
    # 优先级，值高的为master，主从尽量相差50
    priority 100
	
	# 多播/单播配置
	# mcast_src_ip 192.168.89.131 # 发送多播包源地址，默认为设置的网卡绑定的ip
	# 本节点ip
	unicast_src_ip 192.168.89.131
	# 其他节点ip
	unicast_peer {
		192.168.89.133
	}
	
	# 定义虚拟ip，需要定义一个同一子网下未被分配的ip
    virtual_ipaddress {
		192.168.89.134/24
    }
	
	# 定义认证类型和密码，主从集群之间的认证必须一致
    authentication {
        auth_type PASS
        auth_pass d0cker  
    }

    # 选配。执行自定义检测脚本，常用于检测到本机的某个中间件nginx、mysql等进程挂掉就自杀kill掉自身keepalived进程做切换
    track_script {
	    # 调用配置文件头部声明的脚本模块名称check_postgres
        check_postgres
    }
	
    # 选配
	# 定义通知脚本，当前节点成为主节点时触发的脚本
    #notify_master "/etc/keepalived/notify.sh MASTER"
    # 定义通知脚本，当前节点转为备节点时触发的脚本
    #notify_backup "/etc/keepalived/notify.sh BACKUP"
    # 定义通知脚本，当前节点转为“失败”状态时触发的脚本
    #notify_fault "/etc/keepalived/notify.sh FAULT"
}
```
配置完成后，`启动/重启`keepalived服务
```sh
sudo systemctl start keepalived
sudo systemctl enable keepalived
```

## 数据库健康检测脚本
`keepalived.conf`中声明调用的`check_postgres.sh`脚本内容
```sh
#!/bin/bash

# 从入参获取容器名称
CONTAINER_NAME=$1

# 执行命令并捕获输出
output=$(docker exec $CONTAINER_NAME psql -U postgres -c "SELECT pg_is_in_recovery();" | awk 'NR==3 {print $1}')

# 检查命令是否成功
if [ $? -ne 0 ]; then
    echo "Failed to execute command in container."
    exit 1
fi

# 确认当前pg实例是否处于备库模式.t-备库，f-主库
if [ $output = "t" ]; then
	# 当前是备库，降为Backup状态
    echo "PostgreSQL is in recovery mode."
	exit 1
elif [ $output = "f" ]; then
    # 当前是主库，升为Master抢占vip
    echo "PostgreSQL is not in recovery mode."
	exit 0
else
    echo "Unexpected output: $output"
    exit 1
fi
```

## keepalived状态说明
使用`systemctl status keepalived`查看状态。由于数据库存在`主/备`两种状态，和普通的中间件`运行/挂掉`状态不同。因此在`keepalived`中`状态和服务器角色`对应关系：
+ MASTER 主。
+ FAULT 备。
+ BACKUP 不存在这个状态。只作为中间状态用于升降级转换。

## 常见问题和解决方案
### 数据库双主脑裂
两个数据库的主备状态都是主。
#### 问题场景
过程如下   
1）主服务器网卡down掉（在虚拟机中可以直接关掉网卡来模拟该故障场景），主备服务器网络不通。内部的pg docker容器仍然是正常运行，仍然是主数据库。   
2）在备服务器端，由于备库的repmgr已经感知不到对端主库的状态，触发自动升主。   
3） 主服务器网络恢复后，出现双主。   
#### 解决方案
参考[pg数据库repmgr主备双节点见证者方案](https://handsomestwei.github.io/posts/pg%E6%95%B0%E6%8D%AE%E5%BA%93repmgr%E4%B8%BB%E5%A4%87%E5%8F%8C%E8%8A%82%E7%82%B9%E8%A7%81%E8%AF%81%E8%80%85%E6%96%B9%E6%A1%88/)   
重启非期望状态的容器。执行`sql`语句`SELECT pg_is_in_recovery()`查看数据库主备状态，在期望是备库但实际结果是主的服务器上，重启pg docker容器，使之恢复正常备状态。