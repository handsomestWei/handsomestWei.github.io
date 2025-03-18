---
title: 使用pglogical实现postgresql数据库双主同步
date: 2025-02-08 09:20:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, 数据同步]
image:
  path: /assets/img/posts/common/postgresql.jpg
---

# 使用pglogical实现postgresql数据库双主同步

## 方案优缺点
### 优点
pg数据库只支持单向数据复制，双机部署一般只能使用主（读写）备（只读）模式。而使用pglogical能实现pg数据库双机的双主模式，支持同时双写，省去主备切换流程，适用于负载均衡和热备等场景。

### 缺点
pglogical**只支持数据的逻辑复制**，对于必须使用流式复制的场景不适用（如pg timescaledb的超表数据同步）

### 附逻辑复制和流式复制区别
+ 流式复制：直接复制和传输数据库中的物理数据块，传输原始二进制数据‌。对应pg配置`wal_level = 'logical'`
+ 逻辑复制：在流式二进制数据基础上，增加数据解析，使得能识别到sql，方便进行表、库等粒度的数据过滤。对应pg配置`wal_level = 'replica'`

## pglogical简介
[git地址](https://github.com/2ndQuadrant/pglogical)，也称pglogical 2，是一个为PostgreSQL数据库提供逻辑流复制功能的插件。基于pg数据库原生的发布/订阅模型封装，实现数据的逻辑复制。[使用说明](https://github.com/2ndQuadrant/pglogical/tree/REL2_x_STABLE/docs)

## pglogical安装
```sh
## 注意安装包中的版本和pg数据库版本一致
sudo apt-get install postgresql-14-pglogical
```

## pg pglogical配置
修改pg配置文件`postgresql.conf`，添加扩展，和必要的复制配置。
```conf
wal_level = 'logical' # 写死
max_worker_processes = 10   # one per database needed on provider node
                            # one per node needed on subscriber node
max_replication_slots = 10  # one per node needed on provider node
max_wal_senders = 10        # one per node needed on provider node
shared_preload_libraries = 'pglogical'
```

## 发布和订阅配置
### 添加扩展
```sql
CREATE EXTENSION IF NOT EXISTS pglogical;
```

### 创建发布者
在本机和对端互相执行
```sql
-- 创建节点。如果订阅时要使用密码验证，在发布节点创建时要声明
-- https://github.com/2ndQuadrant/pglogical/issues/73
SELECT pglogical.create_node(
    node_name := 'provider1',
    dsn := 'host=192.168.0.144 port=5432 dbname=pglogical-test user=postgres password=postgres'
);

-- 将表添加到复制副本集
SELECT pglogical.replication_set_add_all_tables('default', ARRAY['public']);
```
### 创建订阅者
在本机和对端互相执行
```sql
-- 创建节点
SELECT pglogical.create_node(
    node_name := 'provider1',
    dsn := 'host=192.168.0.144 port=5432 dbname=pglogical-test user=postgres password=postgres'
);

-- 创建订阅
SELECT pglogical.create_subscription(
    subscription_name := 'subscription1',
    provider_dsn := 'host=192.168.0.144 port=5432 dbname=pglogical-test'
);

-- 等待同步完成
SELECT pglogical.wait_for_subscription_sync_complete('subscription1');

-- 查看所有订阅的状态
SELECT * FROM pglogical.show_subscription_status();
```

## pglogical运维
```sql
-- 查看所有发布
SELECT * FROM pglogical.publication;

-- 查看所有订阅
SELECT * FROM pglogical.subscription;

-- 停止并删除订阅
SELECT pglogical.drop_subscription('subscription1');

-- 停止并删除发布
SELECT pglogical.drop_node(node_name := 'provider1', ifexists := true);

-- 查看复制槽
SELECT * FROM pg_replication_slots;

-- 删除复制槽
SELECT pg_drop_replication_slot(replication_slot_name);
-- 如果提示replication slot "xx" is active for PID xx，先执行pid停止再删除
-- SELECT pg_terminate_backend(pid);
```