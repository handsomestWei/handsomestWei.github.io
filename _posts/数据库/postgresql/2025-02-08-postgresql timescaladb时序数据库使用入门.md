---
title: postgresql timescaladb时序数据库使用入门
date: 2025-02-08 10:00:00
categories: [数据库, postgresql]
tags: [数据库, postgresql, timescaladb, 时序数据库]
image:
  path: /assets/img/posts/common/pg-ts.jpg
---

# postgresql timescaladb时序数据库使用入门
[git地址](https://github.com/timescale/timescaledb)，[官方文档](https://docs.timescale.com/)，[官方文档-cn](https://docs.timescaledb.cn/getting-started/latest/)   
本文基于`timescaladb 2.17.2`版本，在低版本，相关函数和功能可能有差别。

## timescaladb优点
+ 建立在PostgreSQL之上，融入pg生态，可以使用pg的全部特性。
+ 压缩。针对海量时序数据，高压缩率节省空间。不需要特殊的存储格式，列存压缩，并提供查询加速。
+ 持续聚合。在按时间颗粒度统计场景，时序数据通常增长很快，传统方案定时统计时扫描全表会很慢。提供了自动累加方案替代，持续跟踪数据集，视图方式呈现。
+ 丰富的时间窗口函数。

## hypertable超表使用示例
```sql
-- 使用timescaledb扩展
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- 先创建普通表
CREATE TABLE tb_xx (
    log_id BIGINT NOT NULL GENERATED ALWAYS AS IDENTITY,
    identity VARCHAR(64) NOT NULL,
    create_time TIMESTAMP NOT NULL
);

-- 创建主键，必须带时间，且时间字段定义必须非空。时序表一般以时间为主键就足够了，若业务上定义有非时间主键，则使用复合主键关联时间序列
ALTER TABLE tb_xx ADD PRIMARY KEY(log_id, create_time);

-- 将普通表转换为超表，并设置区块划分策略。这里设置每6个小时分一个块
-- 原始表的实际数据，存储在_timescaledb_internal模式的表下，并按分块命名xxx_chunk。涉及数据同步时要注意
SELECT create_hypertable('tb_xx', by_range('create_time', INTERVAL '6 hours'));

-- 创建数据压缩分段列。建议按业务特性选择分段的列，如该列可能被常用在group by
ALTER TABLE tb_xx SET (
  timescaledb.compress,
  timescaledb.compress_segmentby = 'identity',
  timescaledb.compress_orderby='create_time DESC'
);

-- 创建数据压缩策略。这里设置每6小时执行一次压缩
SELECT add_compression_policy('tb_xx', INTERVAL '6 hours');

-- 创建数据保留策略。保留xx内的数据，超过xx的数据块会被删除。这里设置保留1年内的数据
SELECT add_retention_policy('tb_xx', INTERVAL '1 year');
```

## 使用时间桶加速聚合统计
[参考文档](https://docs.timescaledb.cn/use-timescale/latest/time-buckets/use-time-buckets/)   
在使用`group by`统计海量数据时，可以结合`time_bucket`函数对任意时间间隔执行聚合计算。
```sql
-- 示例：对create_time字段，按月聚合数据，替代to_char(create_time, 'YYYY-MM')时间格式化
SELECT
	time_bucket('1 MONTH', create_time) AS history_date,
	ROUND(AVG("numeric"(log_value)), 2) AS log_value 
FROM
	tb_xx
WHERE
	xxx = 'xx'
	AND create_time >= '2024-03-10 00:00:00' 
	AND create_time <= '2025-03-10 00:00:00' 
GROUP BY
	history_date 
ORDER BY
	history_date;
```

## 使用连续聚合替代定时扫描全表统计
[参考文档](https://docs.timescaledb.cn/use-timescale/latest/continuous-aggregates/about-continuous-aggregates/)   
连续聚合是一种超表，类似于物化视图，它会在后台随着新数据的添加或旧数据的修改而自动刷新。对数据集的更改会被跟踪，并且连续聚合背后的超表会在后台自动更新。