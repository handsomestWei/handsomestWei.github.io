---
title: 使用原生binlog复制实现mysql双主同步
date: 2025-02-05 10:10:00
categories: [数据库, mysql]
tags: [数据库, 运维, mysql, 数据同步]
image:
  path: /assets/img/posts/common/mysql.jpg
---

# 使用原生binlog复制实现mysql双主同步
基于mysql **8.0**版本，`docker`容器化部署，使用基础镜像`mysql:8.0`。适用于双机热备、负载均衡等场景。双机均为主模式，双机均可读写，在单端写入数据会自动同步到对端。

## 自定义mysql配置
新建`mycustom.cnf`自定义配置文件，运行时会自动合并配置。以下为binlog复制用配置。
```conf
# 以下为双主双向同步配置
# 每个服务器唯一。对端值设置为2
server-id=1

# 使用行格式记录二进制日志
binlog-format=row

# 二进制日志有效期，单位天。超时自动删除。也适用于中继日志。在8.0.1后提供了binlog_expire_logs_seconds参数秒级的更细粒度控制
expire_logs_days=7

# 单个二进制日志文件的最大大小。当max_relay_log_size参数未设置时也适用于中继日志
max_binlog_size=500M

# 指定本服务使用的中继日志文件名前缀。中继日志是从服务器接收主服务器二进制日志事件的记录，用于更新从服务器上的数据
relay-log=mysql-relay-bin

# 单个中继日志文件的最大大小
max_relay_log_size=500M

# 所有中继日志文件占用的总磁盘空间。超过阈值会自动清理超过expire_logs_days有效期的日志
relay_log_space_limit=4G

# 自动清除已经执行过的中继日志文件（当超过relay_log_space_limit设定阈值时）
relay_log_purge=ON

# 从库会将从主库接收到的所有更新操作记录到自己的二进制日志中。适用于主主复制或链式复制
log-slave-updates=1

# 自增步长。用于解决自增列冲突
auto-increment-increment=2

# 自增列起始值。用于解决自增列冲突。对端值设置为2
auto-increment-offset=1

# 启用GTID模式
gtid-mode=ON

# 强制GTID一致性
enforce-gtid-consistency=ON

# 复制任务跳过指定错误码，避免因为复制异常导致任务暂停。多个用逗号分隔，也可以直接设置为ALL跳过全部（慎用）。这里跳过1062主键冲突
slave_skip_errors=1062
```

## docker容器化配置
### 自定义mysql配置挂载
容器内的`/etc/my.cnf`，定义了自定义配置文件目录`!includedir /etc/mysql/conf.d/`，运行时会自动合并该目录下的所有`.cnf`文件的配置。   
挂载`mycustom.cnf`自定义文件到上述目录。注意文件权限`chmod 644`只读，否则配置不生效，启动时会出现日志提示`mysqld: [Warning] World-writable config file '/xxx/xx.cnf' is ignored`
> 注意：不同的mysql docker版本，自定义配置文件的`include`目录可能不同，`6.0`的可能在`/etc/mysql/mysql.conf.d`

### docker compose配置
```yml
mysql:
    image: mysql:8.0
    container_name: mysql
    restart: always
    ports:
      - 3306:3306
    privileged: true
    volumes:
      - /xxx/mysql/mysql:/var/lib/mysql
      - /xxx/mysql/mycustom.cnf:/etc/mysql/conf.d/mycustom.cnf
    environment:
      TZ: Asia/Shanghai
      MYSQL_DATABASE: your_database_name
      MYSQL_ROOT_PASSWORD: password
    command:
      [
        'mysqld',
        '--character-set-server=utf8',
        '--collation-server=utf8_unicode_ci',
        '--lower-case-table-names=1'
      ]
```
## 日志配置确认
mysql容器运行后，确认相关日志功能已启用。
### binlog日志配置确认
```sql
show VARIABLES like 'log_%';
```
常用参数项说明：
+ log_bin：ON表示已开启binlog日志。
+ log_bin_basename：binlog日志的存储位置。
+ log_bin_index：binlog日志索引文件的位置。

### 中继日志配置确认
```sql
SHOW VARIABLES LIKE 'relay_log%';
```
常用参数项说明：
+ relay_log_purge：ON表示自动清除已经执行过的中继日志文件。
+ relay_log_recovery：控制在发生崩溃后是否自动重新生成中继日志文件。默认OFF。
+ relay_log_space_limit：中继日志文件占用的最大磁盘空间（以字节为单位），超过阈值会自动清理。默认0，表示没有限制。


## 双向复制配置
### 本机状态确认
```sql
-- 查看主库状态
SHOW MASTER STATUS;
```
结果项说明：
+ File: 本机最新的binlog日志文件。
+ Position: 本机最新的binlog日志索引位。
+ Executed_Gtid_Set: 本机可用的GTID复制集合。

### 复制任务配置
分别在两个mysql服务器上执行
#### 方式一：基于binlog点位
初次启动时，需要指定复制的起始位置。在对端执行`SHOW MASTER STATUS`获取相关值。
```sql
CHANGE MASTER TO
  MASTER_HOST='192.168.1.2', -- 对端mysql服务ip
  MASTER_USER='root', -- 对端mysql服务连接账号。可额外创建复制账号
  MASTER_PASSWORD='password', -- 对端mysql服务连接密码
  MASTER_LOG_FILE='mysql-bin.000001', -- 对端的File值
  MASTER_LOG_POS=1234; -- 对端的Position值
START SLAVE;
```

#### 方式二：基于GTID全局事务标识符
[参考官网](https://dev.mysql.com/doc/refman/8.0/en/replication-gtids-howto.html)，不需要手动指定二进制日志文件名和位置，从而减少了人为错误的可能性，并提供了更好的灵活性和可靠性。
```sql
CHANGE MASTER TO
  MASTER_HOST='192.168.1.2', -- 对端mysql服务ip
  MASTER_USER='root', -- 对端mysql服务连接账号。可额外创建复制账号
  MASTER_PASSWORD='password', -- 对端mysql服务连接密码
  MASTER_AUTO_POSITION=1; -- 允许MySQL自动管理复制位置
START SLAVE;
```

### 查看复制任务状态
```sql
SHOW SLAVE STATUS;
```
确认`Slave_IO_Running`和`Slave_SQL_Running`均为Yes，`Last_Error`项是否有报错。

### 复制任务状态控制
常见操作如下。
```sql
-- 停止任务
STOP SLAVE；

-- 启动任务
START SLAVE;

-- 修改已有的复制任务，并从指定位置重新复制
-- 1、先停止复制任务
-- 2、重新执行CHANGE MASTER TO指令，指定文件和索引位
-- 3、启动复制任务

-- 重置复制任务。高危操作。需先停止复制任务
RESET SLAVE ALL;
-- RESET SLAVE;
```

## 复制任务异常处理
当复制任务出现错误，会导致任务暂停，等待用户介入处理。建议定期执行`SHOW SLAVE STATUS`巡检查看复制任务状态，从`Last_Errno`项获取最近一次错误码，从`Last_Error`项获取错误详情。   
可以根据错误类型，决定是否跳过该错误。
### 跳过错误
适用于binlog点位同步模式。
```sql
STOP SLAVE;
-- 跳过当前事务，自动执行下一条
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
SHOW SLAVE STATUS;
```

### 跳过错误事务
适用于GTID同步模式。直接跳过错误可能会导致更复杂的问题。从`SHOW SLAVE STATUS`获取错误关联的具体的GTID事务。
```sql
STOP SLAVE;
SET @@SESSION.GTID_NEXT= 'your_gtid';
BEGIN; COMMIT;
SET @@SESSION.GTID_NEXT= 'AUTOMATIC';
START SLAVE;
SHOW SLAVE STATUS;
```