---
title: EvoOntology数据Agent自进化本体层简介
description: >-
  人大数据实验室的 EvoOntology 是 Claude Code / Codex 插件：在数据和 Agent 之间保存术语、映射、关系、约束与证据，按任务轨迹对照评估后再发布下一版。它不执行业务查询，也不自动改当前本体。
date: 2026-10-20 18:00:00
categories: [AI, ontology]
tags: [AI, ontology, EvoOntology]
image:
  path: /assets/img/posts/common/ontology.jpg
---

# EvoOntology数据Agent自进化本体层简介

> **EvoOntology** 是中国人民大学数据实验室给数据 Agent 用的版本化语义层。它记录业务词如何对应到表、字段和文件，并按任务轨迹决定是否发布下一版。仓库 [ruc-datalab/EvoOntology](https://github.com/ruc-datalab/EvoOntology)（调研时约 992 star，MIT），论文 Chong 等，*EvoOntology: A Self-Evolving Ontology Layer for Data Agents*（[arXiv:2609.15779](https://arxiv.org/abs/2609.15779)）。下文按中文 README、USAGE 与 Codex 插件说明整理。

**参考与延伸阅读**：

- 仓库：<https://github.com/ruc-datalab/EvoOntology>
- 中文说明：<https://github.com/ruc-datalab/EvoOntology/blob/master/README.zh-CN.md>
- 使用指南：<https://github.com/ruc-datalab/EvoOntology/blob/master/USAGE.zh-CN.md>
- Codex 插件：<https://github.com/ruc-datalab/EvoOntology/blob/master/plugins/evoontology-codex/README.md>
- 论文：<https://arxiv.org/abs/2609.15779>
- 封面图 BFO 2.0：<https://commons.wikimedia.org/wiki/File:BFO_ontology.jpg>（AH-LOD，CC BY-SA 4.0）

---

## 目录

- [1. 定位](#1-定位)
- [2. 能力范围](#2-能力范围)
- [3. 内容、模式与工具](#3-内容模式与工具)
- [4. 生命周期](#4-生命周期)
- [5. 数据源](#5-数据源)
- [6. 可视化与运行边界](#6-可视化与运行边界)
- [7. 和问数术语库的关系](#7-和问数术语库的关系)
- [8. 小结](#8-小结)

---

## 1. 定位

EvoOntology 是 Claude Code 与 Codex 的插件。产品形态是一个确定性核心包，加上三个技能：`build-ontology`、`evolve-ontology`、`explore-ontology`。没有独立命令行。默认工作区是项目下的 `.evoontology/`。

**结论性定义：** Ontology Layer 放在原始数据和数据 Agent 之间。它不保存业务数据，也不执行业务查询。它保存五类记录：术语、映射、关系、约束、证据。Agent 通过 MCP 按当前问题取其中几条，再使用自己原有的查数工具。

本体层被当成可替换的 Agent 状态，不是模型权重。候选版本只有在对照评估中好于当前版本，才会成为下一正式版。

---

## 2. 能力范围

| 对照 | 本文所指 |
| --- | --- |
| 问数 | 本体层保存术语与映射，供 Agent 按当前问题取用；业务答案仍由宿主已有的 SQL 或文件工具给出。SQLite 可由插件只读执行并记录结果 |
| 主数据治理 | 只记录「这个词在这份数据里指什么」，不制定集团主数据，也不在系统之间同步数据 |
| 进化节奏 | 下一版由人触发、对照评估后发布；默认在新增不少于 30 个任务或间隔不少于 7 天时提醒 |
| 运维形态 | 一期可视化是一份本地 HTML，不做 Web UI、多租户和常驻服务 |

一句话：它是数据语义的版本库。问数仍然由原有的 SQL 或文件工具完成。

---

## 3. 内容、模式与工具

### 3.1 内容层（Content）

一张有类型的语义图，节点分四类：

| 节点 | 含义 |
| --- | --- |
| Term | 业务概念，如负责人、尾款 |
| Mapping | 概念对应的表、字段或文件 |
| Constraint | 查询时必须遵守的规则，如金额只从合同表取 |
| Evidence | 构建时实际看到的列、样例或查询结果 |

语义关系连接术语。结构引用把术语连到映射，并把约束或证据挂到它们约束或支撑的对象上。使用指南里的版本目录写成五类文件：Term、Mapping、Relation、Constraint、Evidence。Relation 就是上述连接。

### 3.2 模式层（Schema）

规定这几条节点有哪些字段、允许哪些语义关系、结构引用可以怎么连。模式层划定本体能表达什么，避免每轮随意发明新的关系类型。

### 3.3 工具层（Tool）

通过 MCP 暴露给 Agent：

| 工具 | 作用 |
| --- | --- |
| `browse_semantics` | 按查询发现相关概念 |
| `resolve_semantics` | 把提到的词解析成映射、关系、约束和证据 |
| `evo-semantic://session-manifest` | 会话开始时读取的简短说明 |

会话只注入这份说明。具体记录在需要时再取，不把整本本体写入提示词。构建和进化还会用到 `validate_semantics`、`visualize_ontology`、`evolution_status`。

---

## 4. 生命周期

```text
Build → Use → Evolve → Evaluate → Publish 或 Reject
```

1. **Build。** 从当前需求、同一项目的历史和抽查到的数据提出问题，抽出候选概念，到原始数据里核对，发布 `ontology_v0`。
2. **Use。** Agent 按需查询本体，任务结束时追加一条轨迹：用了哪些工具、看到什么结果、任务是否完成。
3. **Evolve。** 从重复出错里归因。一次候选只验证一个主要假设，改动落在内容、工具或模式三者之一，并可退回当前版。
4. **Evaluate。** 候选版与当前版使用相同数据、相同 Agent、相同解码设置和相同交互预算。有标准答案则打分；没有则由模型做匿名对照。
5. **Publish 或 Reject。** 通过则发布为 `ontology_vN+1`，并更新 `active.json`。未通过则当前版继续生效，候选和本轮记录留下可查。

版本名：正式版 `ontology_v0`、`ontology_v1`……候选 `v0-c1` 表示从 v0 出发的第一个候选。接受时映射为下一个正式版，不覆盖已有正式版。

插件不自动读取账号里的全部聊天。没有历史时，它查看元数据和抽样，再提出有数据依据的问题。普通对话本身不足以形成一条完整轨迹。

---

## 5. 数据源

| 来源 | 插件如何使用 |
| --- | --- |
| SQLite | 内置只读查询 `execute_ontology_query`，并自动记录真实结果 |
| 其他表、文件、数据库 | 没有官方连接器。由 Claude Code 或 Codex 已能使用的工具去查，再用 `record_ontology_task_event` 记下观察到的结果 |

仓库自带三个评测环境，用来说明它面向的数据形态：

| 环境 | 数据形态 | 论文中的变化（四模型子集） |
| --- | --- | --- |
| BIRD | 真实数据库上的 text-to-SQL | 执行准确率 63.6 → 初始本体 68.7 → 进化后 72.4 |
| DDR-10K | 异构金融文件上的开放研究 | 69.5 → 81.8 → 89.5 |
| InsightBench | 业务分析表上的洞察生成 | 53.2 → 54.0 → 54.2 |

初始语义层贡献了 BIRD 上的大部分增益。洞察生成几乎没有提升。评测数字以论文设定为准。

---

## 6. 可视化与运行边界

`visualize_ontology` 在 `.evoontology/visualizations/ontology-layer-explorer.html` 生成一份离线页面，默认用浏览器打开一次。Codex 桌面版可以把该页嵌在右侧预览中，只在本机回环地址提供。

使用指南把 Web UI、SaaS、多租户、消息队列、常驻 worker 和无人值守的自动循环列在一期之外。检测阈值后的动作是提醒人去运行进化，不是后台自动发布。

`validate_semantics` 在发布前自动执行。它检查 JSON 能否加载、引用是否完整。它不检查字段是否仍存在于数据库，也不检查某条映射是否一定能查出数。这些核对发生在构建和探索阶段。

---

## 7. 和问数术语库的关系

问数系统已经用术语库和示例 SQL 表达「这个词对应哪张表、以前哪条 SQL 是对的」。EvoOntology 的映射和约束解决的是同一类问题，并额外保存证据、版本和对照评估。

在字段清楚的单一业务库上，术语库加示例 SQL 已经覆盖主要用途。表、文件和多个库混在同一次分析里，或同一错误反复出现、需要证明新规则确实更好时，版本化的本体层才多出一块可回滚的记录。

它不替代问数引擎，也不接入外部文档知识库。若要把某条已接受的映射或约束写回问数产品的术语库，需要人另行维护。

---

## 8. 小结

| 要点 | 结论 |
| --- | --- |
| 位置 | 原始数据与数据 Agent 之间的版本化语义层 |
| 保存内容 | 术语、映射、关系、约束、证据；不保存业务行，也不跑最终查询 |
| 进化 | 人触发；候选须对照评估优于当前版才发布 |
| 适用 | 多源混查、反复出错、需要可回滚语义记录时；字段清楚的单库问数不必上这一层 |
