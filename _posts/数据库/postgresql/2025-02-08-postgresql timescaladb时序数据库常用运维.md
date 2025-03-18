---
title: postgresql timescaladb时序数据库常用运维
date: 2025-02-08 10:00:00
categories: [数据库, postgresql]
tags: [数据库, 运维, postgresql, timescaladb, 时序数据库]
image:
  path: /assets/img/posts/common/pg-ts.jpg
---

# postgresql timescaladb时序数据库常用运维

```sql
-- 查看各块和压缩情况
SELECT * FROM timescaledb_information.chunks;

-- 查看压缩效果
SELECT 
    pg_size_pretty(pg_database_size('db_name')) as db_size,
    pg_size_pretty(before_compression_total_bytes) as before,
    pg_size_pretty(after_compression_total_bytes) as after,
	now()
 FROM hypertable_compression_stats('your_hypertable_name');
 
 -- 查看数据库当前连接情况
 SELECT * FROM  pg_stat_activity where datname = 'db_name';

 -- 调整超表已经存在的区块策略
SELECT set_chunk_time_interval('your_hypertable_name', INTERVAL '6 hours');

-- 删除指定超表的数据保留策略
SELECT remove_retention_policy('your_hypertable_name');
 
-- 重启压缩。压缩任务停止时尝试使用
-- SELECT _timescaledb_functions.start_background_workers();
```