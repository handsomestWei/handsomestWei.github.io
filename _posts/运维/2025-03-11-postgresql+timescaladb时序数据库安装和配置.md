---
title: postgresql+timescaladb时序数据库安装和配置
date: 2025-03-11 09:30:00
categories: [运维, 数据库, postgresql]
tags: [运维, 数据库, postgresql, timescaladb, 时序数据库]
image:
  path: /assets/img/posts/common/postgresql.jpg
---

# postgresql+timescaladb时序数据库安装和配置

## 版本
+ postgresql-14=14.15-0ubuntu0.22.04.1
+ timescaledb-2-postgresql-14=2.17.2~ubuntu22.04

## docker compose方式
### 安装
docker compose yml文件配置示例。
```yml
# https://hub.docker.com/r/timescale/timescaledb-ha/tags
  postgres:
    image: timescale/timescaledb-ha:pg14.15-ts2.17.2
    container_name: postgres
    restart: always
    # 可选，固定ip
    networks:
      your-network:
        ipv4_address: 177.7.0.11
    ports:
      - 5432:5432
    privileged: true
    volumes:
      # 保证目录下为空
      - ${DATA_PATH}/postgres/pg-data:/home/postgres/pgdata/data
      # 可选，外部sql挂载
      - ${DATA_PATH}/postgres/sql:/var/pg-sql
    user: root
    environment:
      TZ: ${TZ}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

### 使用
#### 执行sql文件
利用挂载目录放置sql文件，参数`-f`指定映射的容器内部目录。
```sh
docker exec -i $CONTAINER_NAME psql -U postgres -d $DATABASE_NAME -f /var/pg-sql/xxx.sql
```

## 原生方式
### 安装
```sh
sudo apt install -y postgresql-14=14.15-0ubuntu0.22.04.1
sudo systemctl start postgresql
sudo systemctl enable postgresql
sudo systemctl status postgresql
```

### 配置
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

### timescaledb扩展安装
[参考](https://docs.timescaledb.cn/self-hosted/latest/install/installation-linux/)，注意版本和pg数据库版本一致。   
```sh
## 添加官方的APT存储库，到默认的Ubuntu存储库中。先导入存储库的GPG密钥
wget --quiet -O - https://packagecloud.io/timescale/timescaledb/gpgkey | sudo apt-key add -
echo "deb https://packagecloud.io/timescale/timescaledb/ubuntu/ $(lsb_release -c -s) main" | sudo tee /etc/apt/sources.list.d/timescaledb.list
sudo apt update
sudo apt install -y timescaledb-2-postgresql-14=2.17.2~ubuntu22.04
sudo apt install -y timescaledb-2-loader-postgresql-14='2.17.2~ubuntu22.04'
```
配置扩展，修改`postgresql.conf`文件的`shared_preload_libraries`配置项，添加值`timescaledb`
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