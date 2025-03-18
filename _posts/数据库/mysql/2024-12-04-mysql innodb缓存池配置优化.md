---
title: mysql innodb缓存池配置优化
date: 2024-12-04 23:00:00
categories: [数据库, mysql]
tags: [数据库, 运维, mysql, 性能优化]
image:
  path: /assets/img/posts/common/mysql.jpg
---

# mysql innodb缓存池配置优化
基于MySQL Server 8.0版本

## 缓存池简介
缓存池Buffer Pool是主内存中的一个区域，InnoDB在访问表和索引数据时会在该区域进行缓存。缓存池允许直接从内存访问频繁使用的数据，加快处理速度，减少磁盘IO，最终提高sql执行速度。

## 配置获取
+ 从my.ini配置文件读取：win目录参考C:\ProgramData\MySQL\MySQL Server 8.0\my.ini
+ 从sql读取：show variables like 'innodb_buffer_pool%';

## 配置项说明
[配置参考官网](https://dev.mysql.com/doc/refman/8.0/en/innodb-buffer-pool-resize.html)
### innodb_buffer_pool_size
缓存池的大小（以byte字节为单位），即InnoDB缓存表和索引数据的内存区域。   
my.ini相关配置说明如下
```ini
# The size in bytes of the buffer pool, the memory area where InnoDB caches table 
# and index data. The default value is 134217728 bytes (128MB). The maximum value 
# depends on the CPU architecture; the maximum is 4294967295 (232-1) on 32-bit systems 
# and 18446744073709551615 (264-1) on 64-bit systems. On 32-bit systems, the CPU 
# architecture and operating system may impose a lower practical maximum size than the 
# stated maximum. When the size of the buffer pool is greater than 1GB, setting 
# innodb_buffer_pool_instances to a value greater than 1 can improve the scalability on 
# a busy server.
innodb_buffer_pool_size=128M
```
联动配置`innodb_buffer_pool_instances`，关联公式`innodb_buffer_pool_size=innodb_buffer_pool_chunk_size * innodb_buffer_pool_instances`

### innodb_buffer_pool_instances
my.ini相关配置说明如下
```ini
# The number of regions that the InnoDB buffer pool is divided into.
# For systems with buffer pools in the multi-gigabyte range, dividing the buffer pool into separate instances can improve concurrency,
# by reducing contention as different threads read and write to cached pages.
innodb_buffer_pool_instances=8
```

## 经验配置
手动修改配置文件my.ini并重启服务。文件注意格式编码另存为ANSI
+ innodb_buffer_pool_size，值一般设置为物理内存的1/3或1/2（非独占。独占单独部署可以为80%）
+ 联动innodb_buffer_pool_chunk_size块大小配置，一般为300M~800M
+ 联动innodb_buffer_pool_instances，一般为(innodb_buffer_pool_size / innodb_buffer_pool_chunk_size)   

部分参数支持sql动态修改，如`SET GLOBAL innodb_buffer_pool_size = xxx;`

## 效果评估
### 缓存池使用率
计算使用率，评估是否需要调整内存。使用率=`Innodb_buffer_pool_pages_data`/`Innodb_buffer_pool_pages_total`，超过`95%`可以增大`innodb_buffer_pool_size`
```sql
show global status like 'innodb_buffer_pool_pages%';
```
## 工具诊断
[MySQLTuner-perl性能诊断工具](https://github.com/major/MySQLTuner-perl)