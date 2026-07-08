---
title: scikit-learn数据预处理模块
date: 2026-04-02 18:00:00
categories: [AI, ML]
tags: [AI, ML, sklearn, 数据预处理, 特征工程, 缩放, StandardScaler]
image:
  path: /assets/img/posts/common/ml.jpg
---

# scikit-learn数据预处理模块

> `sklearn.preprocessing` 提供将**原始特征向量**转换为更适合下游估计器表示的常用工具。下文按官方用户指南 **[7.3 Preprocessing data](https://scikit-learn.org/stable/modules/preprocessing.html)** 归纳；**§1** 结合数值特征缩放专题，对 **StandardScaler、RobustScaler、PowerTransformer、MinMaxScaler** 四种方法的原理、适用场景与局限性做展开（内容归纳参考社区文章与官方示例，见文末来源）。

---

## 目录

- [引言](#引言)
- [1. 数值特征缩放：四种常用方法](#1-数值特征缩放四种常用方法)
- [2. 非线性变换](#2-非线性变换)
- [3. 归一化（Normalization）](#3-归一化normalization)
- [4. 类别特征编码](#4-类别特征编码)
- [5. 离散化（Discretization）](#5-离散化discretization)
- [6. 缺失值填充](#6-缺失值填充)
- [7. 多项式与样条特征](#7-多项式与样条特征)
- [8. 自定义变换](#8-自定义变换)
- [9. 与 Pipeline 的配合](#9-与-pipeline-的配合)
- [参考](#参考)

---

## 引言

`sklearn.preprocessing` 提供将**原始特征向量**转换为更适合下游估计器的表示的常用工具与 `Transformer` 类。许多算法（尤其线性模型、基于距离的模型）对**特征尺度、分布形态**敏感；类别特征需先**编码**；连续特征有时需**分箱**或**非线性变换**以增强表达力。版本叙述以当前稳定文档为准，细节以官方页为准。

---

## 1. 数值特征缩放：四种常用方法

数值特征缩放是机器学习预处理中**几乎不可跳过**的环节，主要应对两类问题：

| 问题 | 典型表现 | 不处理的后果 |
|------|----------|--------------|
| **量级差异** | 年龄（0～100）与薪资（0～数十万）同表 | 基于距离、梯度的模型易被**大数值列主导** |
| **偏斜与异常值** | 收入、房价等右偏长尾；少数极端样本 | 均值/方差被拉偏，线性模型拟合被「跷跷板」拽偏 |

常用四种线性/非线性缩放思路如下（与 scikit-learn 类一一对应）：

| 方法 | sklearn 类 | 核心统计量 | 主要目标 |
|------|------------|------------|----------|
| **标准化** | `StandardScaler` | 均值、标准差 | 零均值、单位方差 |
| **Robust 缩放** | `RobustScaler` | 中位数、IQR | 抗极端离群点 |
| **幂变换** | `PowerTransformer` | 幂变换参数（MLE） | 压长尾、近似高斯 |
| **归一化（Min-Max）** | `MinMaxScaler` | 最小值、最大值 | 映射到固定区间（常 \([0,1]\)） |

演示时常用 **California Housing** 等数据集中量级差异明显的列（如 MedInc、Population）对比变换前后散点图；官方示例见 [plot_all_scaling](https://scikit-learn.org/stable/auto_examples/preprocessing/plot_all_scaling.html)。

### 1.1 标准化（Standardization）— StandardScaler

**原理**：按列做 Z-score 变换：

```text
z = (x - mean) / std
```

变换后特征近似 **均值 0、方差 1**，不同列落到可比较的数值尺度。

**适用场景**：

- 线性回归、逻辑回归、SVM（尤其 RBF 核）、PCA 等**隐含或偏好正态/可比尺度**的算法
- 特征量级差异大、但**离群点不极端**时

**局限性**：

- **对异常值极其敏感**：极端值抬高均值、放大方差，主体数据易被挤压到狭窄区间（如大部分点落在 \([-1, 4]\)）
- **只改尺度、不改形状**：原本右偏的分布，标准化后**仍然偏斜**

```python
from sklearn.preprocessing import StandardScaler

scaler = StandardScaler()
X_std = scaler.fit_transform(X_train)  # 仅在训练集 fit
```

可通过 `with_mean=False` / `with_std=False` 关闭居中或缩放；稀疏矩阵见 §1.7。

### 1.2 Robust 缩放 — RobustScaler

**原理**：用 **中位数** 居中、用 **四分位距 IQR**（默认第 25～75 百分位）作尺度，替代均值与标准差：

```text
x' = (x - median) / IQR
```

**适用场景**：

- 存在**明显极端离群点**，但仍希望保留离群样本信息（不直接删除）
- 需要在「拉平尺度」的同时，降低少数异常点对统计量的污染

**局限性**：

- 异常值**不会被移除**，变换后极端点仍可存在
- 与 StandardScaler 一样，**难以消除分布偏斜**——只是把主体数据放到更合理区间
- **不能在稀疏矩阵上 `fit`**（可对稀疏 `transform`）

```python
from sklearn.preprocessing import RobustScaler

robust = RobustScaler(quantile_range=(25.0, 75.0))
X_robust = robust.fit_transform(X_train)
```

默认 `quantile_range=(25, 75)` 即两端各弱化约 25% 极端值的影响，这也是「Robust」名称的来源。

### 1.3 幂变换 — PowerTransformer

**原理**：对每个特征施加**非线性**幂变换（Yeo-Johnson 或 Box-Cox），通过最大似然等方法估计参数，把**右偏长尾**压向主体，使分布更接近钟形；默认输出可再做零均值、单位方差。

**适用场景**：

- **重度偏斜**特征（收入、房价、Population 等）
- 线性模型被少数极大值「拽偏」拟合线；神经网络中单步**梯度冲击**过大
- 希望**保留异常值信息**，但降低其数值上对模型的扭曲

**局限性**：

- **计算成本**高于线性缩放
- **Box-Cox** 要求严格为正；含负值时宜用 **Yeo-Johnson**
- 变换后特征**可解释性**下降，汇报业务时需说明已非原始单位

```python
from sklearn.preprocessing import PowerTransformer

pt = PowerTransformer(method="yeo-johnson")
X_pt = pt.fit_transform(X_train)
```

与 StandardScaler 对比：标准化只改变数值跨度，长尾仍在；幂变换会**改变分布形状**，箱线图常呈现更对称的箱体。类似思路还可选用 **QuantileTransformer**（见 §2）。

### 1.4 归一化（Min-Max）— MinMaxScaler

**原理**：线性映射到给定区间（默认 \([0, 1]\)）：

```text
x_norm = (x - x_min) / (x_max - x_min)
```

**适用场景**：

- **KNN** 等基于距离的算法（对绝对数值敏感）
- **神经网络**输入：将特征压到激活函数敏感区，缓解饱和区梯度消失
- 特征边界**已知且固定**（如图像像素 0～255）

**局限性**：

- **对极端异常值致命**：一个极大值成为 `x_max` 后，其余样本全被压到接近 0 的窄区间，**分辨力丧失**（如 Population 最大值 35k 映射为 1.0，主体 1000～2000 仅占约 1/35 宽度）
- 新数据若超出训练集 min/max，变换结果可能**越界**

```python
from sklearn.preprocessing import MinMaxScaler

mm = MinMaxScaler()
X_mm = mm.fit_transform(X_train)
```

### 1.5 四种方法选型对照

| 面临的问题 | 优先工具 | 原因 |
|------------|----------|------|
| 不同特征**量级**差异大 | **StandardScaler** | 拉到可比尺度，实现简单 |
| **重度偏斜**、长尾 | **PowerTransformer** / QuantileTransformer | 改变分布形状，压长尾 |
| **极端离群点**多 | **RobustScaler** | 中位数 + IQR，不受边际异常值牵动 |
| 神经网络 / 固定有界输入 | **MinMaxScaler** | 映射到 \([0,1]\) 等区间 |
| 稀疏矩阵、需保留零结构 | **MaxAbsScaler**（§1.6） | 不按列减均值 |

树模型（随机森林、XGBoost 等）基于排序分裂，**不强制**缩放；但与线性模型混用、或做聚类/距离度量时，仍须统一尺度。

### 1.6 其他缩放器：MaxAbsScaler

按各列**最大绝对值**缩放，使训练数据落在 \([-1, 1]\) 附近，适合已近似中心化或**稀疏数据**（**保留零结构**）。见官方 [MaxAbsScaler](https://scikit-learn.org/stable/modules/generated/sklearn.preprocessing.MaxAbsScaler.html)。

### 1.7 稀疏矩阵注意事项

对稀疏输入**一般不要居中**（会破坏稀疏结构）。推荐 **MaxAbsScaler**；**StandardScaler** 在 `with_mean=False` 时可接受 `scipy.sparse`。

### 1.8 fit 与 transform：防数据泄露

| 方法 | 规则 |
|------|------|
| **`fit`** | **仅在训练集**上估计均值、标准差、分位数等统计量 |
| **`transform`** | 用训练集学到的参数变换训练/验证/测试/线上数据 |
| **禁止** | 在测试集上 `fit`（等于提前「看到」测试分布） |

部署时须将 **Scaler 与模型一并序列化**（放入同一 `Pipeline`），保证线上一致。见 §9。

### 1.9 核矩阵中心化

**KernelCenterer**：对核 Gram 矩阵在特征空间做中心化，用于核方法流水线（文档给出 \(\tilde{K}\) 与测试核矩阵的居中公式）。

---

## 2. 非线性变换

> **PowerTransformer** 的详细原理、适用场景与局限性见 **§1.3**；本节补充其他非线性工具。

**QuantileTransformer**：基于分位数的单调变换，可把特征映射到指定分布（如均匀 \([0,1]\) 或近似正态）。对异常值相对不敏感，但会**扭曲特征间相关性与距离**。

**PowerTransformer**：Yeo-Johnson / Box-Cox 等，把数据推向近似高斯；Box-Cox 要求严格为正。默认可对输出再做零均值单位方差。

---

## 3. 归一化（Normalization）

> 注意：此处 **Normalizer** 为 **按样本（行）** 将特征向量缩放到单位范数，与 **§1.4 MinMaxScaler（按列缩放到区间）** 目的不同；中文语境下「归一化」有时混指 Min-Max，选型时需区分。

**normalize** / **Normalizer**：按**样本**将特征向量缩放到单位范数（`l1`、`l2` 或 `max`），常用于点积、核相似度、文本向量空间模型等。**按样本操作**，`fit` 几乎无状态。

---

## 4. 类别特征编码

### 4.1 OrdinalEncoder

每列类别映射为整数 \(0 \ldots n-1\)。**不能直接当作有序数值用于所有估计器**——许多模型会误读顺序。默认可透传 `np.nan`；可用 `encoded_missing_value` 等为缺失指定整数码。

### 4.2 OneHotEncoder

每列 \(k\) 个类别展开为 \(k\) 个二元列（或 `drop` 后为 \(k-1\) 列以避免共线）。可指定 `categories`、`handle_unknown`（如 `ignore`、`infrequent_if_exist`）、`drop='first'` / `drop='if_binary'`。缺失可视为**单独类别**；`np.nan` 与 `None` 可被区分为不同类别。

### 4.3 低频类别聚合

**OneHotEncoder** 与 **OrdinalEncoder** 支持 **`min_frequency`**、**`max_categories`**：将出现次数过少的类别合并为「低频」桶，缓解高基数与稀疏。

### 4.4 TargetEncoder（目标编码）

用**给定类别下目标的条件均值**（经收缩）编码无序类别，适合**高基数**场景（如邮编、地区），避免 One-hot 维度过大。二分类、多分类、连续目标在文档中均有闭式说明：编码为类内统计与**全局目标统计**的凸组合，收缩系数 \(\lambda_i\) 与样本量及 `smooth` 有关；`smooth="auto"` 时为经验 Bayes 估计。

**关键**：训练数据应使用 **`fit_transform(X_train, y_train)`**——内部用 **k 折交叉拟合**，每折用其余折学编码，减轻标签泄露与下游过拟合；**`fit`+`transform` 与 `fit_transform` 在训练集上不等价**。`fit` 在全训练集上学习易泄露，**不推荐**单独用于训练侧编码。`transform(X_test)` 使用 `fit_transform` 阶段在**全训练数据**上最终学到的 `encodings_`。缺失为单独类别；未见类别用 **`target_mean_`**。

---

## 5. 离散化（Discretization）

**KBinsDiscretizer**：将连续特征分入 `k` 个箱；策略可为 `uniform`（等宽）、`quantile`（等量）、`kmeans`。输出可再接 One-hot 等，为线性模型引入**非线性**。

**Binarizer**：按阈值将数值二值化；与 `KBinsDiscretizer` 在 \(k=2\) 时概念相关。

也可用 **FunctionTransformer** 包装 `pandas.cut` 等自定义分箱。

---

## 6. 缺失值填充

具体工具在独立章节 **Imputation of missing values**（如 `SimpleImputer`、`IterativeImputer`）；预处理章仅作索引。

---

## 7. 多项式与样条特征

**PolynomialFeatures**：生成指定次数的多项式与交叉项；`interaction_only=True` 仅交互项。

**SplineTransformer**：B 样条基，按次数与结点为每列单独构造基函数（不产生特征间交互）；低次数 + 结点控制可避免高次多项式的边界振荡等问题。

---

## 8. 自定义变换

**FunctionTransformer**：将任意可调用函数包装成 `Transformer`，便于在 **Pipeline** 中复用（如对数、`pandas.cut` 等）。可配置 `inverse_func`、`check_inverse` 等。

---

## 9. 与 Pipeline 的配合

缩放、编码、分箱等应 **`fit` 在训练子集**，**`transform` 验证/测试**，并写入同一 **Pipeline**，保证复现与防泄露。官方示例常用 `make_pipeline(StandardScaler(), LogisticRegression())` 等形式。

---

## 参考

- 官方用户指南：[7.3 Preprocessing data](https://scikit-learn.org/stable/modules/preprocessing.html)
- 官方示例：[比较不同缩放器对含异常值数据的影响](https://scikit-learn.org/stable/auto_examples/preprocessing/plot_all_scaling.html)
- API 入口：`sklearn.preprocessing` 包内各类与函数说明
- 社区文章归纳（四种缩放方法原理与对比）：[知乎专栏](https://zhuanlan.zhihu.com/p/2019156782434530017)