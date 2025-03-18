---
title: 使用bucardo实现postgresql数据库双主同步
date: 2025-02-07 09:30:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, 数据同步]
image:
  path: /assets/img/posts/common/postgresql.jpg
---

# 使用bucardo实现postgresql数据库双主同步

## 方案优缺点
### 优点
pg数据库只支持单向数据复制，双机部署一般只能使用主（读写）备（只读）模式。而使用bucardo能实现pg数据库双机的双主模式，支持同时双写，省去主备切换流程，适用于负载均衡和热备等场景。

### 缺点
bucardo基于perl脚本，数据复制管理依赖额外的中间库，脚本维护和同步问题排查难度较大。

## bucardo简介
bucardo是一个用于PostgreSQL数据库的高性能、异步、多对多数据复制解决方案。使用perl脚本实现，利用触发器方式，并引入中间数据库做元数据管理。   
[git地址](https://github.com/bucardo/bucardo)   
[官网](https://bucardo.org/)   
[使用文档](https://bucardo.org/Bucardo/)   

## bucardo安装
```sh
sudo apt-get install bucardo=5.6.0-4

# 安装后执行初始化命令，有命令行交互，会创建中间数据库做元数据管理
# 建议使用postgres账号，中间库名称使用默认bucardo
# 初始化完成后，会在/etc/bucardorc文件写入记录
bucardo install

sudo systemctl start bucardo
sudo systemctl status bucardo
sudo systemctl enable bucardo
```

## bucardo同步配置
分别在本机和对端配置。
```sh
## 1、设置同步数据库的连接信息。其中p1、p2为bucardo起的别名，用于后续使用
bucardo add database p1 dbname=bucardo-test port=5432 host=192.168.0.144 user=postgres pass=postgres
bucardo add database p2 dbname=bucardo-test port=5432 host=192.168.0.194 user=postgres pass=postgres

## 2、设置数据源组。绑定数据源，指定同步的方向。这里的组名称设置为gp1
bucardo add dbgroup gp1 p1:source p2:target

## 3、添加要同步的表，和序列（必须）
bucardo add all tables db=p1 --verbose
bucardo add all sequences db=p1 --verbose

## 4、添加复制集。指定表名，多个用空格分隔在末尾追加。这里的复制集名称设置为relgrp01
bucardo add relgroup relgrp01 table1 table2

## 5、添加同步任务。需要指定dbgroup和relgroup，并使用conflict_strategy参数指定冲突解决策略。这里的同步任务名称设置为sync01
bucardo add sync sync01 relgroup=relgrp01 dbgroup=gp1 conflict_strategy=bucardo_latest
```

## bucardo运维
[指令列表](https://bucardo.org/Bucardo/cli/)，常用指令如下。
```sh
## 查看同步状态
bucardo status

## 停止同步
bucardo stop

## 暂停/恢复某一个同步任务
bucardo pause/resume sync01
```