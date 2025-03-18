---
title: ubuntu部署postgresql+timescaladb时序数据库
date: 2025-03-11 09:30:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, timescaladb, 时序数据库]
image:
  path: /assets/img/posts/common/pg-ts.jpg
---

# ubuntu部署postgresql+timescaladb时序数据库

## 中间件版本
+ postgresql-14=14.15-0ubuntu0.22.04.1
+ timescaledb-2-postgresql-14=2.17.2~ubuntu22.04

## pg数据库安装
```sh
sudo apt install -y postgresql-14=14.15-0ubuntu0.22.04.1
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql
```

## pg数据库配置
pg数据库配置文件一般位于`/etc/postgresql/14/main/postgresql.conf`，修改以下内容。其他按需修改。
```
## 默认timezone = 'Etc/UTC'
timezone = 'Asia/Shanghai'
```
配置允许远程连接
```sh
echo "host all all 0.0.0.0/0 md5" >> /etc/postgresql/14/main/pg_hba.conf
echo "listen_addresses = '*'" >> /etc/postgresql/14/main/postgresql.conf
```
修改后重启服务`systemctl restart postgresql`

## timescaledb扩展安装
[参考](https://docs.timescaledb.cn/self-hosted/latest/install/installation-linux/)，注意版本和pg数据库版本一致。
### 配置APT存储库
```sh
## 添加官方的APT存储库，到默认的Ubuntu存储库中。先导入存储库的GPG密钥
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
sudo apt update
sudo apt install -y timescaledb-2-postgresql-14=2.17.2~ubuntu22.04
sudo apt install -y timescaledb-2-loader-postgresql-14='2.17.2~ubuntu22.04'
```

### 配置扩展
修改`postgresql.conf`文件的`shared_preload_libraries`配置项，添加值`timescaledb`
```sh
## 注意如果原来有使用其他扩展，则在末尾追加，逗号分隔
echo "shared_preload_libraries = 'timescaledb'" >> /etc/postgresql/14/main/postgresql.conf
```
修改后，执行`systemctl restart postgresql`重启数据库。

### 扩展使用
```sql
-- 安装扩展。后续可以使用timescaledb特性
CREATE EXTENSION IF NOT EXISTS timescaledb;
```