---
title: NumPy与pandas简介
description: >-
  NumPy 管同质数值数组上的向量运算，pandas 管带行列名的表格读写和分组。二者是叠层关系，不是二选一；表里的数值列取出后往往就是数组。
date: 2026-09-07 16:51:52
categories: [AI, AI基础]
tags: [AI, AI基础, NumPy, pandas]
image:
  path: /assets/img/posts/common/AI.jpg
---

# NumPy与pandas简介

> **NumPy** 和 **pandas** 都是 Python 数据科学的底座，但管的不是同一层东西：NumPy 管 **同质数值数组上的数学运算**；pandas 管 **带行列名的表格**（读 CSV、筛选、分组、缺失值）。pandas 底层大量用 NumPy，二者是叠层关系，不是二选一的替代品。本文面向初学者，用同一组数字说明差在哪、何时用哪个。

**参考与延伸阅读**：

- NumPy 官网：<https://numpy.org/>
- pandas 官网：<https://pandas.pydata.org/>
- 用户指南（10 minutes to pandas）：<https://pandas.pydata.org/docs/user_guide/10min.html>

---

## 目录

- [1. 各自定位](#1-各自定位)
- [2. 核心数据结构](#2-核心数据结构)
- [3. 同一例子对照](#3-同一例子对照)
- [4. 能力对照](#4-能力对照)
- [5. 和深度学习框架的关系](#5-和深度学习框架的关系)
- [6. 怎么选](#6-怎么选)
- [7. 小结](#7-小结)

---

## 1. 各自定位

| 库 | 一句话 | 典型对象 |
|----|--------|----------|
| **NumPy** | 多维数组 + 向量化数学 | 图像像素矩阵、特征矩阵 \(X\)、科学计算 |
| **pandas** | 带标签的表 | Excel / CSV、业务明细、时间序列 |

可以把 NumPy 想成 **「能批量算的格子」**，pandas 想成 **「带表头的电子表格」**。表里的某一列数值，取出来往往就是一个 NumPy 数组。

---

## 2. 核心数据结构

| | NumPy | pandas |
|--|-------|--------|
| 一维 | `ndarray`，如形状 `(n,)` | `Series`：值 + **索引名** |
| 二维 | `ndarray`，形状 `(行, 列)`，一般**同一类型**（全是 float 或全是 int） | `DataFrame`：多列，**每列可以不同类型**（数字、字符串、日期） |
| 标签 | 主要靠整数下标 `a[0, 1]` | 行索引、列名：`df.loc["甲", "时长"]` |
| 缺失值 | 常用 `nan`，处理偏底层 | `NA` / `NaN`，有 `dropna`、`fillna` 等现成方法 |

pandas 的 `DataFrame.values` / `.to_numpy()` 可以把表吐成 NumPy，交给 sklearn、PyTorch 训练。

---

## 3. 同一例子对照

同一批学员数据：学习时长、刷题套数。NumPy 只存数字；pandas 还记得「谁、哪一列」。

**NumPy：纯矩阵运算**

```python
import numpy as np

# 行=学员，列=特征；没有列名
X = np.array([
    [2.0, 1.9],
    [1.6, 1.5],
    [-0.8, -0.7],
], dtype=float)

X.mean(axis=0)          # 每列均值
X @ np.array([1.1, 0.9])  # 矩阵乘，得到线性打分
```

**pandas：带表头的表**

```python
import pandas as pd

df = pd.DataFrame(
    {"时长": [2.0, 1.6, -0.8], "刷题": [1.9, 1.5, -0.7]},
    index=["甲", "乙", "丙"],
)

df["时长"]                 # 按列名取
df.loc["甲"]               # 按行名取
df.mean(numeric_only=True) # 按列统计
df[df["时长"] > 0]         # 按条件筛行
```

同一套数：要用 **公式批量算** 走 NumPy；要用 **列名、筛人、和 CSV 打交道** 走 pandas。训练模型前常见流程是：pandas 洗表 → `.to_numpy()` → sklearn / PyTorch。

---

## 4. 能力对照

| 维度 | NumPy | pandas |
|------|-------|--------|
| 擅长 | 加减乘、广播、线性代数、随机数、傅里叶变换等 | 读存 CSV/Excel、对齐索引、合并表、`groupby`、时间序列、缺失值 |
| 速度 | 同质数组、底层 C，数值循环远快于纯 Python | 表操作方便；纯数值大矩阵循环仍常落到 NumPy |
| 类型 | 一张数组一种 dtype 最省事 | 每列一个 dtype，混用字符串和数字很自然 |
| 内存 | 紧凑 | 索引、列名有额外开销 |
| 不擅长 | 没有「列名」「主键连接」这套表语义 | 不是通用多维张量库；三维以上图像/批次数据仍用 NumPy 或框架张量 |

二者常见组合：

```text
CSV / 数据库
  → pandas 读入、清洗、分组聚合
  → to_numpy()
  → NumPy 标准化、矩阵运算
  → sklearn 拟合 或 转成 torch.Tensor / tf.Tensor
```

---

## 5. 和深度学习框架的关系

| 库 | 角色 |
|----|------|
| pandas | 表格样本的清洗与特征列管理 |
| NumPy | CPU 上的数值数组；sklearn 的输入格式 |
| PyTorch / TensorFlow | GPU 张量、自动求导、神经网络积木 |

`torch.from_numpy(x)`、`tf.convert_to_tensor(x)` 都是从 NumPy 接过去。不要用 pandas 的 `DataFrame` 直接当卷积输入；先变成数值数组再转张量。

---

## 6. 怎么选

- **只有数字、要矩阵乘 / 广播 / 科学计算**：NumPy。
- **有列名、要筛选分组、要对齐两张表、要读写表格文件**：pandas。
- **机器学习入门**：先 pandas 把表洗干净，再交给 NumPy / sklearn；上深度网络时再转张量。
- **不必二选一**：pandas 依赖 NumPy；学顺序一般是 **先 NumPy 数组概念，再 pandas 表操作**。

---

## 7. 小结

| 要点 | 结论 |
|------|------|
| 关系 | pandas 建在 NumPy 上，表里的数值列本质是数组 |
| NumPy | 同质多维数组 + 向量化数学 |
| pandas | 带行列标签的表 + 清洗、连接、分组 |
| 训练前 | 表用 pandas，矩阵用 NumPy，网络用框架张量 |
