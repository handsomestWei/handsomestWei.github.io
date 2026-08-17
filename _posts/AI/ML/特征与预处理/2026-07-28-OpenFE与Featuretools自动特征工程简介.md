--
title: OpenFE与Featuretools自动特征工程简介
date: 2026-07-28 11:00:00
categories: [AI, ML]
tags: [AI, ML, 特征与预处理, OpenFE]
image:
  path: /assets/img/posts/common/ml.jpg
---

# OpenFE与Featuretools自动特征工程简介

> **OpenFE** 与 **Featuretools** 都属于「自动特征工程」工具，但面向的数据形态与方法论不同：前者专注**单表 tabular**，用算子组合 + 以模型效果为导向的筛选造特征（ICML 2023，Kaggle IEEE-CIS 等赛题有公开验证）；后者专注**多表关系数据**，用**深度特征合成（DFS）**沿实体关系做聚合与变换。本文概括二者定位、核心流程、OpenFE 方法细节与实验、差异对比与选型建议。

**参考与延伸阅读**：

- OpenFE 仓库：<https://github.com/IIIS-Li-Group/OpenFE>
- OpenFE 论文（ICML 2023）：<https://arxiv.org/abs/2211.12507>
- OpenFE 文档：<https://openfe-document.readthedocs.io/en/latest/>
- Featuretools 仓库：<https://github.com/alteryx/featuretools>
- Featuretools 文档：<https://featuretools.alteryx.com/>

---

## 目录

- [1. 自动特征工程在流水线中的位置](#1-自动特征工程在流水线中的位置)
- [2. OpenFE 简介](#2-openfe-简介)
  - [2.3 实验验证与竞赛成绩](#23-实验验证与竞赛成绩)
  - [2.5.1 原生输出字段与示例](#251-原生输出字段与示例)
  - [2.5.2 fit() 特征组合与筛选参数](#252-fit-特征组合与筛选参数)
  - [2.7 局限与常见问题](#27-局限与常见问题)
- [3. Featuretools 简介](#3-featuretools-简介)
- [4. OpenFE 与 Featuretools 对比](#4-openfe-与-featuretools-对比)
- [5. 选型建议](#5-选型建议)
- [6. 小结](#6-小结)
- [7. 参考与来源](#7-参考与来源)

---

## 1. 自动特征工程在流水线中的位置

表格机器学习常见流程：

```text
原始数据 → 清洗 / 编码 / 缩放 → 【自动特征生成】→ 模型训练 → 评估
```

**自动特征工程**试图减少人工「拍脑袋造特征」的工作量，但两类工具解决的问题并不相同：

| 痛点 | 典型工具方向 |
|------|--------------|
| 单表宽特征上，不知道 `A/B`、`log(A)`、交叉项哪些有用 | **OpenFE** 等：组合 + 按预测效果筛选 |
| 多张业务表（用户、订单、商品），跨表聚合特征难手工铺全 | **Featuretools** 等：关系型 DFS |

二者**不是互斥替代**，也可串联：先用 Featuretools 多表合成宽表，再用 OpenFE 在宽表上试组合与筛选。

---

## 2. OpenFE 简介

### 2.1 是什么

**OpenFE**（[IIIS-Li-Group/OpenFE](https://github.com/IIIS-Li-Group/OpenFE)）是面向**表格数据（tabular）**的自动特征生成框架，对应 ICML 2023 论文 *OpenFE: Automated Feature Generation with Expert-level Performance*（[arXiv:2211.12507](https://arxiv.org/abs/2211.12507)）。

目标：从现有列出发，**自动构造候选特征**，并挑出能**提升下游模型**（GBDT、神经网络等）效果的新列，减轻人工特征工程负担。

**背景与动机**：表格类（tabular）数据是机器学习与 Kaggle 等竞赛中最常见的形态之一。特征生成（组合、变换原始列）往往决定模型上限，但「造什么特征、哪些有效」高度依赖领域经验与反复试错，实践中常占建模总时间的**一半甚至更多**。现有 AutoML 工具大多聚焦模型与超参搜索，**很少把自动化特征生成纳入流程**；高效、准确的开源特征生成包也相对稀缺。OpenFE 针对这一缺口：用 **Expand-and-Reduce** 在大候选空间中快速找到能提升 **LightGBM / XGBoost** 以及 **FT-Transformer、AutoInt、TabNet** 等表格神经网络效果的新特征。

典型业务类比：股票领域的 **P/E ratio = 股价 / 每股收益**，由两张财报列组合而成，比单看原价或利润更能反映估值；OpenFE 试图在缺乏领域公式时，自动发现类似「比值、交叉、分组统计」的有效组合。

### 2.2 核心流程：Expand-and-Reduce

```text
原始特征列
    ↓ Expand（扩展）
用算子组合生成大量候选特征（如 A/B、log(A+1)、A×B、分箱交叉等）
    ↓ Reduce（缩减）
Feature Boosting 评估增量收益 + 两阶段剪枝 → 保留有效特征
    ↓
输出特征列表，用于增广训练/测试集
```

| 组件 | 作用 |
|------|------|
| **扩展（Expand）** | 内置约 **23 种算子**，对数值/类别列做一元、二元组合 |
| **Feature Boosting** | 快速评估「加入该候选特征后模型性能提升多少」，避免对每个候选全量重训 |
| **两阶段剪枝** | Stage1 粗筛候选 → Stage2 用 **LightGBM** 重要性（gain 或 permutation）排序，保留 Top-K |

#### 两大挑战与对应解法

| 挑战 | 问题 | OpenFE 解法 |
|------|------|-------------|
| **评估慢** | 需衡量候选特征相对已有特征的**增量贡献**；每个候选都「全量重训 + 看验证集」不可接受 | **Feature Boosting**：在 GBDT 基线预测（`init_score`）上增量训练，用 `metric₂ − metric₁` 近似增量收益（见下表） |
| **候选爆炸** | 组合后候选数量巨大，全量计算与评估内存、耗时都过高 | **两阶段剪枝**：Stage1 用 **successive halving** 粗筛；Stage2 在剩余候选上考虑**特征交互**并做重要性精排 |

#### Feature Boosting（增量评估）

思路类似 **Gradient Boosting**：不从头重训，而是在已有模型预测基础上衡量「多加这一列」带来的提升。

| 步骤 | 做法 |
|------|------|
| 1 | 用已有特征集 𝒯 训练 GBDT，得到预测 ŷ₁ 与验证指标 metric₁ |
| 2 | 将 ŷ₁ 作为新 GBDT 的 **init_score**（初始预测） |
| 3 | 仅用**候选特征**（或候选子集）继续训练，得到 ŷ₂ 与 metric₂ |
| 4 | 把 **metric₂ − metric₁** 当作该候选相对 𝒯 的**增量效果** |

实现上默认用 LightGBM 的 `init_score` 参数（见 [§2.6](#26-运行时依赖与-lightgbm-角色)）。论文指出该近似**速度快、且接近全量重训**的评估结果；思想也可推广到神经网络场景。`fit(feature_boosting=True)` 会在原始特征上先拟合基线 GBDT 生成 init_score（见 [§2.5.2](#252-fit-特征组合与筛选参数)）。

#### 两阶段剪枝（successive halving + 重要性精排）

有效新特征通常**稀疏**，OpenFE 用「先粗后细」降低计算量：

```text
全部候选特征
    ↓ Stage 1（粗筛，successive halving）
数据切成 n_data_blocks 块 → 先用 1 块评估所有候选 → 淘汰后一半 → 数据块翻倍 → 重复
（仅评估单特征自身增量，不考虑特征间交互）
    ↓ Stage 2（精筛）
剩余候选 + 原始特征拼成宽表 → 再训 LightGBM → 按 gain / permutation 重要性排序
（此时考虑特征交互对 loss 的贡献）
    ↓
输出按重要性排序的特征列表
```

Stage1 对应 `stage1_select` + `n_data_blocks` / `min_candidate_features`；Stage2 对应 `stage2_select` + `stage2_metric`（详见 [§2.5.2](#252-fit-特征组合与筛选参数)）。

> **说明**：Feature Boosting 与两阶段筛选在实现上依赖 **LightGBM**（见 [§2.6](#26-运行时依赖与-lightgbm-角色)），与论文中「生成特征可提升 GBDT / 神经网络」的**下游训练模型**不是同一层概念。

### 2.3 实验验证与竞赛成绩

论文与作者在多个公开数据集、两场 Kaggle 竞赛上验证了 OpenFE。核心结论可概括为：

| 结论 | 说明 |
|------|------|
| **相对 baseline 方法** | 在速度与效果上优于既有自动特征生成 baseline；无论下游用 GBDT 还是 Transformer，加入 OpenFE 特征均有收益 |
| **相对 SOTA 表格神经网络** | 专为表格设计的网络（如 FT-Transformer、AutoInt）虽能学特征交互，实验表明 **OpenFE 生成特征仍能显著提升**其效果；论文亦给出特征生成在常见设定下有效的理论分析 |
| **相对人工特征工程** | 在 **IEEE-CIS Fraud Detection** 上，简单 XGBoost + OpenFE 特征可超过 **99.3%** 参赛队伍（42/6351）；在同基线 XGBoost 下，OpenFE 自动特征带来的提升**大于该赛第一名队伍公开的特征方案** |
| **另一场竞赛** | **BNP Paribas Cardif Claims Management** 上，相较第一、七名队伍公开特征，OpenFE 自动特征同样带来更大模型提升 |

**竞赛解读（IEEE-CIS）**：第一名队伍公开材料主要是**特征 + 简单 XGBoost**；冲榜第一通常还需 **LightGBM、CatBoost、多种神经网络** 等模型集成。OpenFE 的价值在于：在特征工程这一环，用自动化方案达到或超过顶尖队伍手工特征的水平（详见 [论文](https://arxiv.org/abs/2211.12507) 与仓库 [Examples](https://github.com/IIIS-Li-Group/OpenFE/tree/master/examples)）。

### 2.4 主要特点

| 特点 | 说明 |
|------|------|
| 任务类型 | 二分类、多分类、回归 |
| 数据预处理 | 可自动处理缺失值、类别特征 |
| 并行 | 支持 `n_jobs` 并行 |
| 下游模型 | 论文验证对 **GBDT**（LightGBM、XGBoost）与 **表格神经网络**（Transformer、AutoInt、TabNet、FT-Transformer 等）均有收益 |
| 竞赛表现 | Kaggle **IEEE-CIS**、**BNP Paribas** 等赛题上验证有效（见 [§2.3](#23-实验验证与竞赛成绩)） |
| 易用性 | 典型用法约四行代码（`fit` + `transform`） |

### 2.5 快速上手

```python
from openfe import OpenFE, transform, tree_to_formula

ofe = OpenFE()
features = ofe.fit(data=train_x, label=train_y, n_jobs=8)
train_x, test_x = transform(train_x, test_x, features, n_jobs=8)
```

`fit` 返回的是**特征表达式树**（`Node` / `FNode` 对象列表），不是直接可用的数值列；需再调用 `transform` 把公式算成 DataFrame 新列。公式可读性可通过 `tree_to_formula` 查看（见 [§2.5.1](#251-原生输出字段与示例)）。

### 2.5.1 原生输出字段与示例

OpenFE **没有**单独的 JSON / Parquet 结构化导出格式；原生输出分三层：**`fit` 返回的特征树**、**实例上附带的重要性分数**、**`transform` 增广后的 DataFrame 列**。以下字段与示例均来自官方 [`openfe.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L259-L308)、[`FeatureGenerator.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/FeatureGenerator.py)、[`utils.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/utils.py) 及 [california_housing 示例](https://github.com/IIIS-Li-Group/OpenFE/blob/master/examples/california_housing.py)。

#### 输出层次总览

| 输出层次 | API / 属性 | 类型 | 作用 |
|----------|------------|------|------|
| **`fit` 返回值** | `features = ofe.fit(...)` | `list[Node]` | 筛选后的特征表达式树，**按 Stage2 重要性从高到低排序**；供 `transform` 或 `tree_to_formula` 使用 |
| **实例属性（同返回值）** | `ofe.new_features_list` | `list[Node]` | 与 `fit` 返回值相同，示例中常写 `ofe.new_features_list[:10]` 只取 Top-10 |
| **实例属性（含分数）** | `ofe.new_features_scores_list` | `list[[Node, float]]` | 每项为 `[特征树, 重要性分数]`；分数来自 Stage2 的 **gain**（默认）或 **permutation**，**不**在 `fit` 返回值里，需读此属性 |
| **可读公式** | `tree_to_formula(node)` | `str` | 将 `Node` 转为可审计的公式字符串，便于日志、落盘与人工复核 |
| **`transform` 返回值** | `train_x, test_x = transform(...)` | `(DataFrame, DataFrame)` | 在**保留全部原始列**基础上，**追加** OpenFE 新列 |
| **持久化（可选）** | `openfe.utils.file_to_node(path)` | `list[[Node, float]]` | 读入「公式 + 分数」文本行（见下表）；属 utils 辅助函数，需 `from openfe.utils import file_to_node` |

#### `fit` 返回的 `Node` / `FNode` 对象字段

特征在内部表示为**表达式树**：叶子 `FNode` 对应原始列名，内部 `Node` 对应算子及其子节点（[`FeatureGenerator.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/FeatureGenerator.py)）。

| 字段 / 属性 | 所在类型 | 类型 | 示例值 | 作用 |
|-------------|----------|------|--------|------|
| `name` | `Node` | `str` | `"/"`、`"log"`、`"GroupByThenMean"` | 算子名；决定如何对 `children` 做变换 |
| `name` | `FNode` | `str` | `"MedInc"`、`"product_id"` | 叶子节点：引用输入 DataFrame 的**原始列名** |
| `children` | `Node` | `list[Node\|FNode]` | `[FNode("MedInc"), FNode("AveRooms")]` | 子表达式；一元算子 1 个子节点，二元算子 2 个 |
| `data` | `Node` / `FNode` | `pd.Series` 或 `None` | `0.52, 1.17, …`（fit 结束后多为 `None`） | 运行时缓存该特征在样本上的计算结果；`fit` 结束会 `delete()` 释放，**结构（name/children）仍保留**供 `transform` 重算 |
| `get_fnode()` | `Node` | `list[str]` | `["MedInc", "AveRooms"]` | 该特征依赖的**底层原始列**去重列表，用于列裁剪与泄漏检查 |
| 重要性（第二元） | `new_features_scores_list[i][1]` | `float` | `156.32` | Stage2 排序依据：默认 **LightGBM gain**；`stage2_metric='permutation'` 时为置换重要性均值 |

#### `tree_to_formula` 公式字符串示例

公式格式由 [`tree_to_formula`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/utils.py#L8-L25) 生成：四则运算为**中缀括号**，其余算子为**函数式** `算子(子表达式,…)`。以下以 sklearn `california_housing` 列名为例（`MedInc`、`AveRooms`、`HouseAge` 等）：

| 公式字符串（示例） | 含义 | 产出 dtype |
|--------------------|------|------------|
| `log(MedInc)` | 收入取对数（内部 `log(abs(x))`，0 当缺失处理） | `float64` |
| `(MedInc/AveRooms)` | 收入 ÷ 平均房间数 | `float64` |
| `*(MedInc,HouseAge)` | 收入 × 房龄 | `float64` |
| `GroupByThenMean(AveRooms,HouseAge)` | 按 `HouseAge` 分组，取组内 `AveRooms` 均值再映射回各行 | `float64` |
| `Combine(product_id,city)` | 两列类别拼接后 factorize（高基数类别组合） | `category` |
| `freq(card_brand)` | 类别取值在样本中的出现频次 | `float64` |

官方示例打印 Top 特征的方式（[`california_housing.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/examples/california_housing.py#L40-L42)）：

```python
for feature in ofe.new_features_list[:10]:
    print(tree_to_formula(feature))
# 可能输出类似：
# GroupByThenMean(AveRooms,HouseAge)
# (MedInc/AveRooms)
# log(MedInc)
```

若需同时保留分数，可遍历 `ofe.new_features_scores_list`：

```python
for node, score in ofe.new_features_scores_list[:10]:
    print(tree_to_formula(node), score)
# GroupByThenMean(AveRooms,HouseAge)  156.32
```

也可用 [`file_to_node`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/utils.py#L52-L60)（`from openfe.utils import file_to_node`）读入每行「公式 + 分数」的文本：`(MedInc/AveRooms) 156.32`（首列为 `tree_to_formula` 同格式字符串）。

#### `transform` 增广后的 DataFrame 列

[`transform`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/utils.py#L86-L134)（或 `OpenFE.transform`）在原始 `X_train` / `X_test` 右侧**追加**新列，列名与 `features` 列表下标一一对应：

| 列名模式 | 示例 | 类型 | 作用 |
|----------|------|------|------|
| 原始列 | `MedInc`、`HouseAge`、… | 与输入一致 | 原样保留 |
| 新列 `autoFE_f_{i}` | `autoFE_f_0`、`autoFE_f_1`、… | 多数为 `float64`；`Combine` 等为 `category` | 第 `i` 个特征（与 `features[i]` / `new_features_list[i]` 对应，`i` 从 0 起） |
| 可选后缀 | `autoFE_f_0_val` | 同上 | `transform(..., name="_val")` 时在列名后追加 `name` 参数，避免多份 transform 列名冲突 |

| 列名 | 对应公式（示例） | 示例取值（示意） |
|------|------------------|------------------|
| `autoFE_f_0` | `GroupByThenMean(AveRooms,HouseAge)` | `5.12` |
| `autoFE_f_1` | `(MedInc/AveRooms)` | `0.83` |
| `autoFE_f_2` | `log(MedInc)` | `1.52` |

> **命名注意**：`fit` 阶段 Stage2 内部临时矩阵列名为 `autoFE-0`（**连字符**），仅用于 LightGBM 精排；**对外 `transform` 输出**为 `autoFE_f_0`（**下划线**），二者不要混用。

`transform` 会把 `inf` 置为 `NaN`；含 `GroupByThen*` 等**全局统计**算子时，训练集与测试集需**一起**传入 `transform`，与官方文档一致。

### 2.5.2 fit() 特征组合与筛选参数

OpenFE 的特征「组合」与「筛选」分两阶段：**Expand** 决定候选空间（算子 + 组合深度 + 列角色），**Reduce** 用 successive feature-wise halving（Stage 1）+ LightGBM 重要性（Stage 2）砍掉无效候选。完整参数说明见官方 [`OpenFE.fit` 文档字符串](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L138-L261)；调参指南见 [Parameters Tuning](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html)；高阶组合见 [FAQ：high-order features](https://openfe-document.readthedocs.io/en/latest/FAQ.html#how-to-generate-high-order-features)。

#### 候选特征空间（Expand）

控制「生成哪些组合、组合多深」。

| 参数 / API | 默认值 | 作用 | 官方说明 |
|------------|--------|------|----------|
| **`candidate_features_list`** | `None` | `None` 时自动枚举候选；传入自定义 `list[Node]` 可**完全接管**候选空间（最强控制，适合注入领域先验） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L181-L184) |
| **`get_candidate_features(...)`** | — | 独立 API，生成可传入 `fit` 的候选列表；非 `fit` 形参，但与组合深度强相关 | [`get_candidate_features`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L63-L118) |
| ↳ `numerical_features` | `[]` | 参与组合的**纯数值列** | 同上 |
| ↳ `categorical_features` | `[]` | 参与组合的**类别列**（可走 `Combine`、`GroupByThen*` 等） | 同上 |
| ↳ `ordinal_features` | `[]` | **有序离散数值**（如年龄档位）；同时按数值与类别两条路径参与组合 | 同上 |
| ↳ **`order`** | `1` | 候选特征的**最大阶数**：1 阶 = 对原始列套一层算子；`order=2` 会在 1 阶结果上再组合，候选量**指数级暴涨** | 同上；[FAQ 高阶特征](https://openfe-document.readthedocs.io/en/latest/FAQ.html#what-is-a-high-order-feature) |
| **`categorical_features`**（`fit`） | `None` | 指定哪些列当类别；`None` 时用 `select_dtypes(exclude=np.number)` 自动推断 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L190-L192) |
| **自动枚举规则**（`candidate_features_list=None`） | — | 非类别且 `nunique() <= 100` 的数值列视为 **ordinal**；其余数值列进 `numerical_features`；默认 **`order=1`** | [`get_candidate_features` 调用处](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L340-L356) |
| **内置算子** | 23 种 | 一元（`log`、`freq`…）、数值二元（`+`、`*`、`/`…）、类别聚合（`GroupByThenMean`、`Combine`…） | [`FeatureGenerator.py`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/FeatureGenerator.py#L5-L14) |

自定义候选 + 控制组合深度示例：

```python
from openfe import OpenFE, get_candidate_features

# order=1：仅对原始列做一层变换（推荐起点）
candidates = get_candidate_features(
    numerical_features=["amount", "hour"],
    categorical_features=["city", "card_brand"],
    ordinal_features=["age"],          # 同时走数值/类别两条组合路径
    order=1,
)
# order=2：在一阶特征上再组合，候选量极大，慎用
# candidates = get_candidate_features(..., order=2)

ofe = OpenFE()
ofe.fit(
    data=train_x, label=train_y,
    candidate_features_list=candidates,
    categorical_features=["city", "card_brand", "age"],
    n_jobs=8,
)
```

> **实践建议**：官方 FAQ 指出，多数数据集上 **高阶（≥2）特征收益有限**；更稳妥做法是先 `order=1` 筛出有效特征，再把它们并入基特征后手动升阶（见 [How to generate high-order features?](https://openfe-document.readthedocs.io/en/latest/FAQ.html#how-to-generate-high-order-features)）。

#### Stage 1：粗筛候选（successive feature-wise halving）

控制一阶段「砍候选」的**速度 vs 召回**。

| 参数 | 默认值 | 作用 | 官方说明 |
|------|--------|------|----------|
| **`is_stage1`** | `True` | `True`：启用 successive feature-wise halving 逐轮淘汰；`False`：**跳过** Stage 1，全部候选直接进入 Stage 2（慢、占内存，仅候选很少时考虑） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L237-L240) |
| **`n_data_blocks`** | `8` | 数据分块数，须为 **2 的幂**（1, 2, 4, 8, 16…）；**越大越快**，但易在早轮丢掉有用候选 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L204-L208)；[调参：加速](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#increase-n-data-blocks) |
| **`min_candidate_features`** | `2000` | halving 的**早停下限**：剩余候选 ≤ 此值时停止继续砍；**增大**可保留更多候选进 Stage 2（偏效果） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L210-L214)；[调参：效果](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#decrease-n-data-blocks-or-increase-min-candidate-features) |
| **`stage1_metric`** | `'predictive'` | Stage 1 单特征评分方式：`predictive`（论文方法，LightGBM + init_score 看指标增量）、`corr`（与标签 Pearson 相关）、`mi`（互信息） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L220-L225) |

| `stage1_metric` 取值 | 评估逻辑 | 适用场景 |
|----------------------|----------|----------|
| `predictive`（默认） | 单特征 + LightGBM，看验证集指标相对 `init_score` 的**增量** | 与论文一致，一般首选 |
| `corr` | 特征与标签的 Pearson 相关系数 | 快速粗筛、回归类探索 |
| `mi` | 特征与标签的互信息 | 非线性关系探索，仍比 `predictive` 粗糙 |

#### Feature Boosting 与基线分数

为 Stage 1 的 `predictive` 评估提供 GBDT 基线（`init_score`）。

| 参数 | 默认值 | 作用 | 官方说明 |
|------|--------|------|----------|
| **`feature_boosting`** | `False` | `True`：在原始特征上训 LightGBM，生成 **init_score** 供增量评估；多数数据集上效果更好，但并非总是更优 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L216-L218)；[调参：feature_boosting](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#set-feature-boosting-to-true-or-false-and-see-which-provides-better-results) |
| **`init_scores`** | `None` | 自定义 init_score；`None` 且 `feature_boosting=True` 时由 LightGBM 在原始特征上拟合得到 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L186-L188) |
| **`metric`** | `None` | LightGBM 评估指标：`binary_logloss` / `multi_logloss` / `auc` / `rmse`；`None` 时按任务自动选择 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L194-L198) |

#### Stage 2：精排与 Top-K

在剩余候选上训练 LightGBM，按重要性输出最终排序列表。

| 参数 | 默认值 | 作用 | 官方说明 |
|------|--------|------|----------|
| **`stage2_metric`** | `'gain_importance'` | 最终排序依据：`gain_importance`（LightGBM **gain**，快）或 `permutation`（置换重要性，慢但有时更准） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L227-L232) |
| **`stage2_params`** | `None` | 覆盖 Stage 2 LightGBM 超参；`None` 时默认 `n_estimators=1000, importance_type="gain", num_leaves=16` 等 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L234-L235) |
| **`n_repeats`** | `1` | 仅当 `stage2_metric='permutation'` 时生效：置换重要性重复次数 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L242-L243) |
| **`drop_columns`** | `None` | Stage 2 建 LightGBM 时**丢弃**的列（仍可用于生成候选）；用于去掉 ID 等泄漏列 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L200-L202) |

> OpenFE **不**提供 `top_k` 形参：`fit` 返回**全部**通过 Stage 2 的候选（按重要性排序）。实际使用时取 `ofe.new_features_list[:K]` 或再做前向选择（官方 [california_housing 示例](https://github.com/IIIS-Li-Group/OpenFE/blob/master/examples/california_housing.py#L36-L37) 取 Top-10；亦可接 `ForwardFeatureSelector`，见 [调参：生成后特征选择](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#perform-feature-selection-on-generated-features)）。

#### 数据划分与其他

| 参数 | 默认值 | 作用 | 官方说明 |
|------|--------|------|----------|
| **`train_index` / `val_index`** | `None` | 自定义训练/验证索引；`None` 时 8:2 随机划分（分类分层）。时序数据**建议显式传入** | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L173-L179) |
| **`task`** | `None` | `'classification'` / `'regression'`；`None` 时标签唯一值 &lt; 20 视为分类 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L169-L171) |
| **`n_jobs`** | `1` | 特征计算与评估的并行进程数，建议设为物理核数 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L248-L249)；[调参：n_jobs](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#add-more-computational-resources) |
| **`seed`** | `1` | 随机种子（划分、halving 子采样等） | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L251-L252) |
| **`verbose`** | `True` | 是否打印阶段进度与候选数量 | [`fit` 参数说明](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L254-L255) |

#### 调参速查（组合选择相关）

| 目标 | 建议调整 |
|------|----------|
| **更强控制候选空间** | 自定义 `candidate_features_list` 或 `get_candidate_features(..., order=1)` 收窄列与阶数 |
| **加速** | 增大 `n_data_blocks`（如 16/32）、增大 `n_jobs`；或 fit 前减少输入列（可能伤效果，见[官方说明](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html#perform-feature-selection-before-feature-generation)） |
| **提高召回 / 效果** | 减小 `n_data_blocks`、增大 `min_candidate_features`；尝试 `feature_boosting=True` |
| **Stage 1 更贴预测目标** | 保持 `stage1_metric='predictive'`（默认） |
| **Stage 2 更稳的重要性** | 试 `stage2_metric='permutation'`（显著更慢） |
| **类别列识别不准** | 显式传 `categorical_features=[...]` |
| **高阶交叉** | `order=2` 或迭代式升阶；注意候选爆炸与 FAQ 中的收益有限结论 |

### 2.6 运行时依赖与 LightGBM 角色

OpenFE **内部特征发现与筛选**依赖 **LightGBM**，这是 `pip install openfe` 时的**硬依赖**（官方 [`setup.py` 的 `install_requires`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/setup.py#L20-L27) 含 `lightgbm>=3.3.2`；`xgboost` 为注释项，并非默认必装）。

```text
pip install openfe    # 会一并安装 lightgbm>=3.3.2
```

**容易误解的一点**：OpenFE 用 LightGBM 做「造特征阶段的评估与排序」，**不要求**你最终业务模型也必须用 LightGBM。论文与示例中，OpenFE 生成的新列同样可交给 **XGBoost、神经网络** 等训练；LightGBM 是 OpenFE 自己的**运行时引擎**，不是对你下游算法的绑定。

| 环节 | LightGBM 在 OpenFE 内的作用 | 官方源码 |
|------|----------------------------|----------|
| **Feature Boosting**（`feature_boosting=True`） | 在原始特征上训练 `LGBMClassifier` / `LGBMRegressor`，得到 **init_score**（GBDT 基线分数），供后续增量评估 | [`openfe.py` `get_init_score`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L400-L409) |
| **Stage 1 粗筛** | 对每个候选特征，用 LightGBM + `init_score` 快速算**预测指标增量**（`stage1_metric='predictive'`），筛掉明显无效候选 | [`openfe.py` `_evaluate`（Stage 1）](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L598-L615) |
| **Stage 2 精排** | 在剩余候选上再训 LightGBM，按 **`feature_importances_`（gain）** 或 **`permutation_importance`** 排序，输出 Top-K 特征列表（默认 `stage2_metric='gain_importance'`） | [`openfe.py` `stage2_select`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L533-L557) |

对应源码中的典型参数（Stage 2 默认）：[`importance_type="gain"`](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L534-L535)，即与 LightGBM 的 **gain 重要性**一致。`stage1_metric` / `stage2_metric` 的默认值与说明见 [`OpenFE.fit` 文档字符串](https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py#L220-L230)。

项目若**单独锁定依赖版本**（例如与自有 GBDT 栈对齐），可显式声明：

```text
# openfe 内部特征发现依赖 LightGBM 做 Feature Boosting 与 Top-K 重要性排序
openfe>=0.0.12
lightgbm>=3.3.2
```

即使业务侧**不使用 OpenFE 做特征发现**（bypass OpenFE），只要环境中安装了 `openfe`，仍须满足其对 `lightgbm` 的版本要求；这与「最终模型用 XGBoost 还是 LightGBM」无关。

### 2.7 局限与常见问题

| 局限 | 说明 |
|------|------|
| **时序约束** | 不擅长「只能用过去数据算未来」类时序特征；新特征须满足时间因果时需另做约束 |
| **数据规模** | 虽已做效率优化，样本/特征极大或算力紧张时，可先对基础列做筛选再生成 |
| **关系型多表** | 设计重心在**单表**，不替代 Featuretools 的多表 DFS |
| **特征数量** | 高阶组合可能仍产生较多特征，需结合业务与后续特征选择 |
| **运行耗时** | 候选空间大时 Stage1/Stage2 仍可能较慢；可通过 `n_data_blocks`、`n_jobs`、缩小 `candidate_features_list` 加速（见 [§2.5.2](#252-fit-特征组合与筛选参数) 与官方 [Parameters Tuning](https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html)） |

#### 常见问题

| 问题 | 说明 |
|------|------|
| **和 gplearn 等遗传编程比？** | OpenFE 作者反馈：速度**快得多**，效果更好，且搜出的公式**更简单可读**；gplearn 适合符号回归探索，OpenFE 面向表格预测场景的 Expand-and-Reduce |
| **如何打印特征构成？** | `tree_to_formula(feature)` 输出公式字符串；见 [§2.5.1](#251-原生输出字段与示例) 与 [california_housing 示例](https://github.com/IIIS-Li-Group/OpenFE/blob/master/examples/california_housing.py) |
| **`transform` 为何要 train+test 一起传？会泄露吗？** | 含 `GroupByThen*`、`freq` 等**全局统计**算子时，需在同一数据快照上计算以保证训练/推理一致；**特征筛选**应在 `fit` 阶段仅用训练集完成，`transform` 只是对已选公式做数值变换。验证集/测试集应在 `fit` 之外，或只用 `train_index`/`val_index` 控制 |
| **SOTA 表格神经网络还需要 OpenFE 吗？** | 实验表明 FT-Transformer、AutoInt 等仍可被 OpenFE 特征进一步抬升；网络自动交互 ≠ 替代领域型组合特征（见 [§2.3](#23-实验验证与竞赛成绩)） |
| **正确 import 方式？** | `from openfe import OpenFE, transform`（类名为 **`OpenFE`**，非 `openfe()` 函数） |

更完整的局限讨论见论文与 [OpenFE FAQ](https://openfe-document.readthedocs.io/en/latest/FAQ.html)。

---

## 3. Featuretools 简介

### 3.1 是什么

**Featuretools**（[alteryx/featuretools](https://github.com/alteryx/featuretools)）是开源 Python 自动特征工程库，核心是 **Deep Feature Synthesis（DFS，深度特征合成）**：在**多张有关联的表**上，按实体关系自动做聚合与变换，生成预测用宽特征。

典型场景：用户表 + 订单表 + 商品表 → 自动得到「用户过去 30 天订单数」「最近一笔金额」「历史最大单笔」等跨表特征。

### 3.2 核心概念

| 概念 | 说明 |
|------|------|
| **EntitySet** | 多表及其主外键关系的结构化描述 |
| **Primitive** | 特征原语：聚合（`COUNT`、`SUM`、`MAX`…）或变换（`year`、`percentile`…） |
| **DFS** | 沿关系图递归应用 primitive，从子表聚合到父实体，并可叠加多层变换 |

```text
EntitySet（用户 ← 订单 ← 订单明细）
    ↓ DFS
对每个实体生成大量候选特征（COUNT、SUM、TIME_SINCE_LAST 等）
    ↓
输出特征矩阵（常需后续筛选降维）
```

### 3.3 主要特点

| 特点 | 说明 |
|------|------|
| 数据形态 | **多表关系型**为主 |
| 特征语义 | 特征名可追溯到「哪张表、什么聚合」，利于业务解释 |
| 扩展性 | 支持自定义 primitive；可接 **Dask** 做大规模计算 |
| 生态 | 文档与案例成熟，Alteryx 系产品链集成多 |
| 输出规模 | 易生成**海量特征**，通常需配合特征选择或模型内置正则 |

### 3.4 与 OpenFE 的方法差异（本质）

Featuretools **不以「试到能涨分的组合」为唯一目标**，而是按**实体关系 + primitive 规则机械展开**特征空间；是否有利于模型，需靠后续训练或筛选判断。OpenFE 则在生成过程中就用 **Feature Boosting** 等指标**导向式**保留有效特征。

---

## 4. OpenFE 与 Featuretools 对比

| 维度 | **OpenFE** | **Featuretools** |
|------|------------|------------------|
| **数据形态** | **单表** tabular 为主 | **多表**关系型（EntitySet） |
| **核心方法** | 算子组合 + **模型效果导向**筛选（Feature Boosting + 剪枝） | **DFS**：沿表关系做聚合/变换 primitive |
| **特征来源** | 对现有列做数学/逻辑组合（`A/B`、`log(A+1)`、`A×B` 等） | 跨表 `COUNT`、`SUM`、`MAX`、`TIME_SINCE` 等 |
| **选型逻辑** | 看新特征对**目标预测**的增量贡献 | 按 schema **展开**关系特征，数量可能很大 |
| **典型场景** | Kaggle 单表竞赛、GBDT 提分、宽表组合挖掘 | 金融/电商多表宽表化、实体特征库 |
| **可解释性** | 显式公式，相对直观 | 特征名含表与聚合语义，但量大时仍难读 |
| **生态成熟度** | 较新，偏研究与竞赛验证 | 更久，工业案例与文档更丰富 |
| **时序/关系** | 弱（单表组合；时序因果需自约束） | 强（多表 + 时间 primitive，需正确建 EntitySet） |

一句话区分：

- **Featuretools**：有多张关联表，要把「用户—订单—行为」这类**关系型特征**系统化铺出来 → 用 DFS。  
- **OpenFE**：只有一张宽表，想在现有列上**自动试组合**并挑出**真能涨分**的新列 → 用 OpenFE。

---

## 5. 选型建议

```text
数据是单表还是多表？
        │
        ├─ 多表（用户/订单/明细…）──→ 优先 Featuretools（DFS 建 EntitySet）
        │                              可选：宽表后再接 OpenFE 做组合筛选
        │
        └─ 单表宽特征 ──────────────→ 优先 OpenFE
                                       或人工特征 + 领域算子
```

| 场景 | 建议 |
|------|------|
| 竞赛单表、冲 GBDT/XGB 指标 | **OpenFE** |
| 企业数仓多表、要实体级特征库 | **Featuretools** |
| 已有 Featuretools 宽表，还想挖交叉项 | **Featuretools → OpenFE** 串联 |
| 强时序因果（只能用历史预测未来） | 两者都需额外约束；OpenFE 论文明确不自动处理时序约束 |
| 特征可解释性要求高 | Featuretools 聚合语义清晰；OpenFE 公式也可读，但高阶组合需人工复核 |

**落地注意**：

- 自动生成的特征可能**维度暴涨**，生产环境需版本管理、泄漏检查（训练/推理一致）与定期重训。  
- OpenFE 的 `fit` 应只在**训练集**上执行，`transform` 再应用到验证/测试集，避免标签泄露。  
- 安装 OpenFE 会拉取 **LightGBM** 作为其内部筛选引擎；与下游是否选用 XGBoost/LightGBM 训练最终模型无关（见 [§2.6](#26-运行时依赖与-lightgbm-角色)）。  
- Featuretools 的 DFS 要正确声明**时间索引**与**训练截止点**，防止用未来信息聚合。

---

## 6. 小结

| 要点 | 结论 |
|------|------|
| OpenFE 是什么 | 单表 tabular 自动特征生成；Expand-and-Reduce + Feature Boosting 筛选 |
| OpenFE 竞赛验证 | IEEE-CIS 简单 XGBoost 超 99.3% 队伍；自动特征优于多名次公开手工特征 |
| OpenFE 原生输出 | `fit` → `list[Node]`（按重要性排序）；`transform` → 原表 + `autoFE_f_{i}` 新列；公式用 `tree_to_formula` 查看 |
| OpenFE 组合筛选参数 | `candidate_features_list` / `get_candidate_features(order)` 控空间；`n_data_blocks` / `min_candidate_features` 控 Stage1；`stage1_metric` / `stage2_metric` 控评估 |
| OpenFE 与 LightGBM | **运行时硬依赖**：内部用 LGBM 做 Boosting 基线、候选评估与 gain/permutation  Top-K 排序；**不等于**下游必须用 LightGBM |
| Featuretools 是什么 | 多表关系数据自动特征工程；深度特征合成 DFS |
| 核心差异 | **单表 vs 多表**；**效果导向组合** vs **关系展开聚合** |
| 是否互斥 | 否，可串联使用 |
| 选型口诀 | 多表用 Featuretools，单表冲分用 OpenFE |

---

## 7. 参考与来源

| 资源 | 链接 |
|------|------|
| OpenFE GitHub | https://github.com/IIIS-Li-Group/OpenFE |
| OpenFE `setup.py`（`lightgbm>=3.3.2` 硬依赖） | https://github.com/IIIS-Li-Group/OpenFE/blob/master/setup.py#L20-L27 |
| OpenFE `openfe.py`（Feature Boosting / Stage1 / Stage2） | https://github.com/IIIS-Li-Group/OpenFE/blob/master/openfe/openfe.py |
| OpenFE 论文 | https://arxiv.org/abs/2211.12507 |
| OpenFE 文档 | https://openfe-document.readthedocs.io/en/latest/ |
| OpenFE Parameters Tuning | https://openfe-document.readthedocs.io/en/latest/parameter_tuning.html |
| OpenFE FAQ（高阶特征等） | https://openfe-document.readthedocs.io/en/latest/FAQ.html |
| Featuretools GitHub | https://github.com/alteryx/featuretools |
| Featuretools 文档 | https://featuretools.alteryx.com/ |
