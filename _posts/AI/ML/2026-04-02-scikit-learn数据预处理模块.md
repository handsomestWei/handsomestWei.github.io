---
title: scikit-learn数据预处理模块
date: 2026-04-02 18:00:00
categories: [AI, ML]
tags: [AI, ML, sklearn, 数据预处理, 特征工程]
image:
  path: /assets/img/posts/common/ml.jpg
---

# scikit-learn数据预处理模块


---

## 引言

`sklearn.preprocessing` 提供将**原始特征向量**转换为更适合下游估计器的表示的常用工具与 `Transformer` 类。许多算法（尤其线性模型、基于距离的模型）对**特征尺度、分布形态**敏感；类别特征需先**编码**；连续特征有时需**分箱**或**非线性变换**以增强表达力。下文按官方用户指南 **[7.3 Preprocessing data](https://scikit-learn.org/stable/modules/preprocessing.html)** 的结构做归纳，版本叙述以当前稳定文档（如 1.8）为准，细节以官方页为准。

---

## 1. 标准化与缩放（Standardization / Scaling）

### 1.1 标准化（去均值、单位方差）

**StandardScaler**：各列减训练集均值、除以标准差，使数据近似零均值、单位方差。SVM 的 RBF 核、线性模型的 L1/L2 等常隐含「特征量级可比」的假设；若某列方差远大于其他列，可能主导目标函数。可通过 `with_mean=False` / `with_std=False` 关闭居中或缩放。

**Pipeline 要点**：在训练集上 `fit`，对测试集仅 `transform`，避免把测试信息泄露进缩放参数。

### 1.2 缩放到区间

- **MinMaxScaler**：线性缩放到给定区间（常用 \([0,1]\)），公式为先按列 min-max 标准化再映射到 `feature_range`。
- **MaxAbsScaler**：按各列最大绝对值缩放，使训练数据落在 \([-1,1]\) 附近，适合已近似中心化或**稀疏数据**（保留零结构）。

### 1.3 稀疏矩阵

对稀疏输入**一般不要居中**（会破坏稀疏结构）。缩放稀疏数据推荐 **MaxAbsScaler**；**StandardScaler** 在 `with_mean=False` 时可接受 `scipy.sparse`。**RobustScaler** 不能在稀疏矩阵上 `fit**（但可对稀疏 `transform`）。

### 1.4 含离群点时的缩放

离群点多时，基于均值/方差的缩放不稳定，可用 **RobustScaler** 用更稳健的中心与尺度估计替代。

### 1.5 核矩阵中心化

**KernelCenterer**：对核 Gram 矩阵在特征空间做中心化（文档给出 \(\tilde{K}\) 与测试核矩阵的居中公式），用于核方法流水线。

---

## 2. 非线性变换

**QuantileTransformer**：基于分位数的单调变换，可把特征映射到指定分布（如均匀 \([0,1]\) 或近似正态）。对异常值相对不敏感，但会**扭曲特征间相关性与距离**。

**PowerTransformer**：Yeo-Johnson / Box-Cox 等，把数据推向近似高斯；Box-Cox 要求严格为正。默认可对输出再做零均值单位方差。

---

## 3. 归一化（Normalization）

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
- API 入口：`sklearn.preprocessing` 包内各类与函数说明