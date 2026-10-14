---
title: PyTorch与TensorFlow简介
description: >-
  两个深度学习框架都在 GPU 上做张量、自动求导和搭网络。表格上的逻辑回归、梯度提升通常走 scikit-learn；图像、语音和大模型才主要用它们。
date: 2026-09-07 16:19:04
categories: [AI, AI基础]
tags: [AI, AI基础, PyTorch, TensorFlow]
image:
  path: /assets/img/posts/common/AI.jpg
---

# PyTorch与TensorFlow简介

> **PyTorch** 与 **TensorFlow** 是目前最常用的两个深度学习框架，用来在 GPU / TPU 上做张量计算、自动求导、训练神经网络。本文面向初学者，说明它们是什么、从哪来、能干什么，以及选型时差在哪。表格数据上的逻辑回归、XGBoost 通常走 **scikit-learn**；图像、语音、大模型这类深度网络才主要用这两个框架。

**参考与延伸阅读**：

- PyTorch 官网：<https://pytorch.org/>
- TensorFlow 官网：<https://www.tensorflow.org/>
- Keras：<https://keras.io/>

---

## 目录

- [1. 框架定位](#1-框架定位)
- [2. PyTorch 提供什么](#2-pytorch-提供什么)
- [3. 发展历史](#3-发展历史)
- [4. 典型用途](#4-典型用途)
- [5. 核心能力](#5-核心能力)
- [6. 两个框架的区别](#6-两个框架的区别)
- [7. 初学者选型](#7-初学者选型)
- [8. 小结](#8-小结)

---

## 1. 框架定位

两者都不是「一个算法」，而是 **搭积木的工作台**：

- 用 **张量（tensor）** 表示数据（比 NumPy 多了 GPU 和自动求导）
- 用层（卷积、全连接、注意力）拼成网络
- 用损失和优化器训练
- 把训练好的模型保存、推理、部署

---

## 2. PyTorch 提供什么

可以把它看成两层工具箱叠在一起，正是初学者常说的「数学函数包 + 神经网络积木」。

| 层 | 包 | 干什么 |
|----|----|--------|
| **数学与张量** | `torch` | 加减乘除、矩阵乘、卷积底层算子、广播、到 GPU；用法接近 NumPy |
| **自动求导** | `torch.autograd` | 前向算完后，`loss.backward()` 自动给参数求梯度 |
| **神经网络积木** | `torch.nn` | 现成层：`Linear`、`Conv2d`、`ReLU`、`LSTM`、`Transformer`、Dropout、BatchNorm 等 |
| **拼装与训练** | `nn.Sequential` / `nn.Module`、`torch.optim` | 把层串成多层网络；Adam / SGD 更新权重 |
| **数据** | `torch.utils.data` | Dataset、DataLoader：按 batch 喂数据 |

对**深度神经网络**，PyTorch 能做的就是这条闭环：

```text
数据（张量）
  → 用层搭积木组成网络（前向：x 进、y 出）
  → 用数学函数算损失
  → 自动反向传播得到梯度
  → 优化器改权重
  → 重复；最后保存模型做推理
```

「搭积木」在代码里就是把函数（层）叠起来。下面用**同一套结构**对照：输入 784 维 → 256 → ReLU → 64 → ReLU → 10 类。示意代码，不是完整可跑工程。

**PyTorch** 对应 `nn.Sequential`；**Keras** 对应 `keras.Sequential`（TensorFlow 2 里常用 `tf.keras`，Keras 3 也可 `import keras`）。

| PyTorch | Keras |
|---------|-------|
| `nn.Sequential(...)` | `keras.Sequential([...])` |
| `nn.Linear(in, out)` | `layers.Dense(out)`（首层要声明输入维） |
| `nn.ReLU()` | `layers.ReLU()`，或写进 `Dense(..., activation="relu")` |

```python
import torch.nn as nn

model = nn.Sequential(
    nn.Linear(784, 256),  # 积木 1：全连接
    nn.ReLU(),            # 积木 2：非线性
    nn.Linear(256, 64),   # 积木 3
    nn.ReLU(),
    nn.Linear(64, 10),    # 积木 4：10 类
)
```

```python
import keras
from keras import layers

model = keras.Sequential([
    layers.Input(shape=(784,)),
    layers.Dense(256),   # 对应 Linear(784, 256)
    layers.ReLU(),
    layers.Dense(64),    # 对应 Linear(256, 64)
    layers.ReLU(),
    layers.Dense(10),    # 对应 Linear(64, 10)
])
```

Keras 更常见的写法是把激活叠进全连接，层数看起来更少，数学上等价：

```python
model = keras.Sequential([
    layers.Input(shape=(784,)),
    layers.Dense(256, activation="relu"),
    layers.Dense(64, activation="relu"),
    layers.Dense(10),
])
```

每一块都是一次**数学变换**（矩阵乘 + 偏置、ReLU 截断负值等）。层数变多、换成卷积 / 注意力，只是换积木，训练闭环不变。

它**不负责**：替你选业务指标、做表格特征工程（那是 pandas / sklearn）、也不等于部署好的网站。框架只提供「算」和「训」的积木。

---

## 3. 发展历史

| 时间 | TensorFlow（Google） | PyTorch（Meta / 原 Facebook） |
|------|----------------------|-------------------------------|
| 更早 | 内部系统 DistBelief | Lua 版 **Torch** |
| 2015 | 开源 TensorFlow 1.x：先建**静态计算图**，再 `Session` 跑 | — |
| 2016 | — | 开源 PyTorch：默认 **即时执行（eager）**，写法像普通 Python |
| 2017–2019 | Keras 成为 TF 官方高层 API；1.x 图模式对新手不友好 | 科研论文、课程大量转向 PyTorch |
| 2019 | **TF 2.x**：默认 eager，Keras 成主入口 | 生态成型：torchvision、Hugging Face 等 |
| 2022– | Keras 3 可挂 TF / JAX / PyTorch 后端 | **PyTorch 2.x**：`torch.compile` 把动态图编译加速 |
| 现在 | 生产、移动端、浏览器、TPU 工具链仍完整 | 研究、开源模型、大模型微调的默认栈 |

一句话：**TF 先占领工业部署；PyTorch 后发，靠「像写 Python」拿走了研究和教学。** 后来两边互相靠拢：TF 也 eager 了，PyTorch 也能编译成图加速。

---

## 4. 典型用途

两边都能做同一类事：

- **计算机视觉**：分类、检测、分割
- **自然语言 / 大模型**：分类、生成、微调 Transformer
- **语音、推荐、强化学习、时序**
- **科研原型**：改网络结构、复现论文
- **工程落地**：训练 → 导出 → 服务端 / 手机推理

差别主要在 **默认生态和部署路径**，不是「这个能干、那个不能干」。

---

## 5. 核心能力

**两边都有的能力**

| 能力 | 通俗理解 |
|------|----------|
| 张量 + GPU/TPU | 大批矩阵运算放到加速器上 |
| 自动求导（autograd） | 不用手推公式，反向传播自动算梯度 |
| 网络模块 | 卷积、RNN、Transformer 等现成层 |
| 训练循环 | 损失、优化器、学习率、checkpoint |
| 数据管线 | 读图、读文本、批处理、增强 |
| 分布式训练 | 多卡、多机 |
| 可视化 | TensorBoard；PyTorch 也可接 |
| 模型导出 | 保存权重；或转 ONNX 等中间格式 |

**TensorFlow 更成体系的周边**

- **Keras**：高层 API，几行就能训一个标准模型
- **TensorFlow Lite / LiteRT**：手机、嵌入式
- **TensorFlow.js**：浏览器
- **TF Serving、TFX**：服务端推理与生产流水线
- **TPU**：Google 云上的原生支持更顺

**PyTorch 更成体系的周边**

- **像 NumPy 的 API**：`print`、断点、逐步调试都自然
- **Hugging Face Transformers**：开源大模型默认先出 PyTorch 权重
- **Lightning 等**：少写样板训练代码
- **torch.compile**：加速训练 / 推理
- **TorchServe、ExecuTorch**：服务端与端侧在补齐，成熟度整体仍不如 TF 那套老工具链

---

## 6. 两个框架的区别

| 维度 | PyTorch | TensorFlow |
|------|---------|------------|
| 默认执行 | 动态图 / eager，边写边跑 | TF 2 也默认 eager；`tf.function` 可编译成图 |
| 学习曲线 | 更像普通 Python，调试直观 | Keras 入门很快；深入图、部署概念更多 |
| 研究与开源模型 | 论文、复现、HF 生态占优 | 仍有大量存量代码和教程 |
| 生产部署 | 能部署，路径更散（ONNX、TorchServe、ExecuTorch） | 移动端、浏览器、Serving 更完整 |
| 代码风格 | 训练循环往往自己写清楚 | Keras `fit()` 更省事 |
| 典型选型 | 学习、科研、微调开源模型 | 已有 TF 栈、要上手机 / 网页、Google 云 / TPU |

对初学者，差别可以压成三句：

1. **学概念、跟论文、玩开源大模型**：先学 **PyTorch**。
2. **团队已经在用 TF，或明确要 TFLite / TF.js**：学 **TensorFlow + Keras**。
3. **算法能力接近**；真正拉开差距的是 **文档、社区和部署工具**，不是「谁更能算卷积」。

---

## 7. 初学者选型

**TensorFlow 没有停更。** 官方仍在发 2.x 版本，Keras 3 继续作为高层 API，并可挂 TensorFlow / JAX / PyTorch 后端。推 PyTorch 当入门第一框架，不是因为 TF 死了，而是因为**初学者接触到的材料分布变了**。

- **只学一个**：优先 **PyTorch**。原因是：论文与开源模型默认权重多为 PyTorch；Hugging Face、多数新教程和课程按它写；eager 写法接近普通 Python，断点调试更直观。TensorFlow 在移动端（Lite / LiteRT）、浏览器（TF.js）、Serving 和 Google 云 / TPU 上仍然完整，只是「从零自学跟社区」这条路上材料更少、旧版 1.x 图模式教程还容易踩坑。
- **想最快看到结果**：Keras 写得更短；它现在也可以不绑死 TensorFlow。
- **以后换框架**：核心概念可迁移——张量、层、损失、反向传播、GPU。换的是 API 名字，不是另一套数学。
- **Google 内部研究**不少已转向 **JAX**，这会让人感觉 TF 热度下降，但 JAX 是另一条栈，不等于 TensorFlow 仓库停更。

---

## 8. 小结

| 要点 | 结论 |
|------|------|
| 是什么 | 数学张量包 + 神经网络积木，不是单个算法 |
| 历史 | TF 先工业、后 eager；PyTorch 先研究、后编译加速 |
| 用途 | 视觉、NLP、语音、强化学习、大模型微调与部署 |
| 能力差 | 核心训练能力接近；差在生态与部署路径 |
| 入门建议 | 无存量约束时先学 PyTorch（材料多、调试顺）；TF 仍在更新，适合已有栈或要上手机 / 网页 |
