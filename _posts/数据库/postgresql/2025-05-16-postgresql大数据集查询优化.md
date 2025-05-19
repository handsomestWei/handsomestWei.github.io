---
title: postgresql大数据集查询优化
date: 2025-05-16 09:00:00
categories: [数据库, postgresql]
tags: [数据库, postgresql, 优化]
image:
  path: /assets/img/posts/common/postgresql.jpg
---

# postgresql大数据集查询优化
期望能减少数据处理量，特别是在处理大规模数据集例如时序数据时效果明显。

## 采样
数据采样通过减少数据量，使得处理大规模数据集变得更加高效。采样后的数据集大小显著减小，从而加快了数据处理速度，降低了计算和存储资源的消耗‌。

### 随机方式
随机采样，使用`tablesample`函数和`system`方式。
```sql
-- 获取大约10%的数据作为样本。结合order by随机的方式打散数据
select * from tb_xxx tablesample system(10) order by random();
```

### 统计学方式
`SYSTEM`方式更快但可能不保证完全随机，而使用`BERNOULLI`方式按统计学的伯努力离散分布，较查询慢但提供更均匀的随机样本。
```sql
-- 行数约按总条数*0.1，但不严格
select * from tb_xxx tablesample bernoulli(0.1);
```

## 时间桶
时间桶查询可以将数据按照一定的时间间隔（例如每小时、每天等）进行分组，从而简化数据分析和报表的生成。时间桶的实现方式有多种。
### 使用date_trunc函数截取时间
sql例：
```sql
SELECT
    date_trunc('hour', timestamp) AS hour,
    COUNT(*) AS event_count
FROM
    events
GROUP BY
    date_trunc('hour', timestamp)
ORDER BY
    hour;
```

### 使用EXTRACT函数按时间范围抽取数据
sql例：
```sql
-- 自定义时间桶，每隔3小时
SELECT 
    EXTRACT(EPOCH FROM create_time)::BIGINT / (3 * 3600) AS bucket_id,
    TO_TIMESTAMP(
        (EXTRACT(EPOCH FROM create_time)::BIGINT / (3 * 3600)) * (3 * 3600)
    ) AS custom_hour_bucket
FROM iot_device_log;
```

### 使用generate_series结合窗口函数生成时间序列
sql例：
```sql
SELECT 
    hour AS time,
    COUNT(e.event_time) AS event_count
FROM 
    generate_series(
        now() - interval '24 hours',
        now(),
        interval '1 hour'
    ) AS hour
LEFT JOIN events e
    ON e.event_time >= hour
   AND e.event_time < hour + interval '1 hour'
   AND e.event_type = 'click' -- 可选条件
GROUP BY hour
ORDER BY hour;
```

## 统计表
### 业务层
使用定时任务维护统计表（基于等月、年等粒度）压缩数据。

### 数据库层
使用物化视图和聚合视图等能力，在数据库层面自动实现数据统计。