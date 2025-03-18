---
title: postgresql数据库参数优化
date: 2024-12-16 22:00:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, 性能优化]
image:
  path: /assets/img/posts/common/postgresql.jpg
---

# postgresql数据库参数优化

## pgtune参数配置工具使用
可以使用pgtune工具，会根据硬件配置提供pg参数设置建议。   
[git地址](https://github.com/le0pard/pgtune)   
[在线网站](https://pgtune.leopard.in.ua/)

## 数据库参数确认
修改后，使用sql查看配置是否生效。
```sql
SELECT name, setting, unit, boot_val, reset_val, source, pending_restart
FROM pg_settings
WHERE name IN (
    'max_connections',
    'shared_buffers',
    'effective_cache_size',
    'maintenance_work_mem',
    'checkpoint_completion_target',
    'wal_buffers',
    'default_statistics_target',
    'random_page_cost',
    'effective_io_concurrency',
    'work_mem',
    'huge_pages',
    'min_wal_size',
    'max_wal_size',
    'max_worker_processes',
    'max_parallel_workers_per_gather',
    'max_parallel_workers',
    'max_parallel_maintenance_workers'
);
```

## 效果评估
### 使用pg扩展监控
`pg_stat_statements`是PostgreSQL的一个扩展，它提供了关于数据库中执行的所有SQL语句的统计信息，对于监控和分析数据库性能非常有用。
#### 使用准备
修改`postgresql.conf`文件，在`shared_preload_libraries`项追加扩展（多个用逗号分隔），并重启服务。
```conf
shared_preload_libraries = 'pg_stat_statements'
```
```sql
-- 安装扩展
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;
```
注意：开启扩展监控会有额外的性能损耗，后续可以使用`
SELECT pg_disable_extension('pg_stat_statements');`禁用扩展或修改配置文件剔除。

#### 使用示例
```sql
SELECT 
    query as "执行的SQL语句", 
    calls as "语句被调用的次数", 
    total_exec_time as "语句总的执行时间（毫秒）", 
    (total_exec_time / calls) as "平均每次执行的时间（毫秒）",
    rows as "返回或处理的行数", 
    100.0 * shared_blks_hit / nullif(shared_blks_hit + shared_blks_read, 0) as "缓存命中率（共享缓冲区命中次数除以总访问次数）"
FROM 
    pg_stat_statements 
ORDER BY 
    total_exec_time DESC 
LIMIT 10;
```

### 使用pgAdmin工具监控
`pgAdmin`是一个PostgreSQL的管理工具，提供了实时监控数据库活动的功能。   
[官网下载链接](https://www.pgadmin.org/download/)   
可以通过提供的`Dashboard`和`Statistics`等图表查看。