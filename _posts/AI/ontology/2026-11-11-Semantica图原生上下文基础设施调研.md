---
title: Semantica图原生上下文基础设施调研
description: >-
  Semantica 是 MIT 许可的图原生语义层：把来源收成可遍历的上下文图，在图上做 OWL/SHACL 治理、规则推理、PROV-O 溯源和决策节点。它补的是结构和「为什么」，不是对象写回，也不是问数口径。
date: 2026-11-11 18:00:00
categories: [AI, ontology]
tags: [AI, ontology, Semantica]
image:
  path: /assets/img/posts/common/ontology.jpg
---

# Semantica图原生上下文基础设施调研

> **Semantica** 面向 Agent 与高风险决策场景，把企业数据建成可查询的上下文图和知识图谱，并在图上做本体治理、规则推理和决策溯源。仓库 [semantica-agi/semantica](https://github.com/semantica-agi/semantica)（调研时约 14,529 star、1,713 fork，MIT），主页 [getsemantica.ai](https://getsemantica.ai/)，PyPI 包 [`semantica`](https://pypi.org/project/semantica/)。截至调研时最新 tagged 版本为 [v0.7.0](https://github.com/semantica-agi/semantica/releases/tag/v0.7.0)（2026-09-22）。下文按 README、ARCHITECTURE.md 与官方文档整理。

**参考与延伸阅读**：

- 仓库：<https://github.com/semantica-agi/semantica>
- 架构说明：<https://github.com/semantica-agi/semantica/blob/main/ARCHITECTURE.md>
- 文档站：<https://docs.getsemantica.ai/>
- 主页：<https://getsemantica.ai/>
- PyPI：<https://pypi.org/project/semantica/>
- v0.7.0：<https://github.com/semantica-agi/semantica/releases/tag/v0.7.0>
- 封面图 BFO 2.0：<https://commons.wikimedia.org/wiki/File:BFO_ontology.jpg>（AH-LOD，CC BY-SA 4.0）

---

## 目录

- [1. 定位](#1-定位)
- [2. 能力范围](#2-能力范围)
- [3. 产品快照](#3-产品快照)
- [4. 流水线](#4-流水线)
- [5. 四块核心能力](#5-四块核心能力)
- [6. 使用面](#6-使用面)
- [7. 和相邻产品的位置](#7-和相邻产品的位置)
- [8. 成熟度](#8-成熟度)
- [9. 小结](#9-小结)

---

## 1. 定位

Semantica 是一套 Python 知识基础设施，口号是 *Graph-Native Infrastructure for Context and Accountable AI Systems*。官方把自己写成「昂贵企业平台的开发者向替代品」：自托管、MIT 许可、存储可替换，不把数据交给第三方 SaaS。

仓库创建于 2025-06-25，作者 Mohammad Kaif（`@KaifAhmad1`）。产品形态是可独立导入的模块库，外加 CLI、REST、MCP Server 和浏览器工作台 Knowledge Explorer。核心安装不捆绑重型 NLP；NER、可视化、文档解析、图数据库客户端以 extras 按需安装。当前 README 要求 **Python 3.11–3.13**。

**结论性定义：** Semantica 放在 LLM、向量库和 Agent 框架之下。它把分散来源收成带类型的实体、关系和决策节点，使「是什么、和谁有关、依据哪条规则、这次为什么这样判」成为可遍历、可导出的图结构。图构建、规则推理和溯源可以不调用大模型；大模型只用于抽取或问答，且经 `semantica.llms` 可换厂商。

它解释的是系统外围：送进模型的上下文、产出的决策、出处、关系和策略轨迹。它不声称能打开基础模型内部推理。

---

## 2. 能力范围

| 对照 | 本文所指 |
| --- | --- |
| 文档检索 / RAG | 主记忆是图遍历；向量检索只是下游配件。原文页面管理仍由知识库产品承担 |
| 对象—动作运行时 | 补的是结构、规则与决策溯源。写回源系统、按对象实例下发写权限，不在本产品范围内 |
| 行业参考本体 | OWL/SHACL 多半从已抽出的实体关系归纳，需人审定；金融、制造等现成词汇表需另行引入 |
| 问数口径 | 湖仓连接器把表变成图节点；指标口径和受控 SQL 仍由问数语义层负责 |
| 业务系统改造 | 连接器覆盖已能访问的库、文件和 SaaS；订单、库存接口不会自动发布成工具 |

一句话：它是 Agent 下面的图操作系统，用来组织上下文、规则和「为什么」。

---

## 3. 产品快照

| 项 | 值（2026-11-11） |
| --- | --- |
| 仓库 | [semantica-agi/semantica](https://github.com/semantica-agi/semantica) |
| 星标 / Fork / 开放议题 | 14,529 / 1,713 / 约 125 |
| 许可 | MIT |
| 语言 | Python |
| 安装 | `pip install semantica`；完整能力用 extras 或 `pip install "semantica[all]"` |
| 最新 GitHub Release | v0.7.0（2026-09-22）；主分支此后持续合入修复与文档 |
| 企业版 | 官网宣称提供私有化、SLA 与受监管行业专业服务，细节不在开源仓库 |

受众按 README：要给 Agent 结构化上下文的平台团队；要把湖仓表变成带血缘知识图谱的数据团队；需要回答「AI 为什么这样做」的合规与审计；不能把数据交给外部 SaaS 的金融、医疗、法律、政务和国防机构。

---

## 4. 流水线

Semantica 按端到端流水线组织，各阶段可单独 import：

```text
来源 → 摄入 → 解析 → 归一化 → 切块 → 抽取
     → 冲突检测 → 去重 → 知识图谱
     → 本体 · 推理 · 溯源 · 决策
     → 向量库 + RDF / LPG 图存储
     → 导出 / 可视化 / REST · MCP · CLI
```

1. **摄入。** 文件（PDF、DOCX、HTML、表格等）、网页、关系库、湖仓（Databricks、Snowflake）、SAP OData、Git、邮件、消息流，以及 MCP 资源。较新版本还增加 BigQuery、Redshift、Power BI、Airflow、JSONL 等连接器。
2. **解析与切块。** 文本、实体、日期归一化；面向 GraphRAG 的实体感知、关系感知、本体感知切块，避免把一个实体从中间切断。
3. **抽取。** NER、关系、事件、三元组。可选按领域 schema 校验抽取结果，也可从抽取结果引导出草稿本体。
4. **冲突与去重。** 多源对同一实体给出不同职务或金额时先标记再合并，而不是静默覆盖。去重支持 blocking 与语义相似度。
5. **建图。** `GraphBuilder` 生成节点与边，可开双时态事实。之上跑中心性、社区发现、链路预测、最短路。
6. **智能层。** OWL/SHACL/SKOS 治理，Rete / Datalog / SPARQL 推理，W3C PROV-O 血缘，决策节点与因果链。
7. **存储与出口。** RDF（Oxigraph、Blazegraph、Jena、RDF4J 等）与 LPG（Neo4j、FalkorDB、AGE、Neptune）可换；向量库可选 FAISS、Qdrant、Weaviate、Milvus、Pinecone、PgVector。导出 Turtle、JSON-LD、OWL、Parquet、Cypher 等。

---

## 5. 四块核心能力

### 5.1 上下文图（Context Graph）

相对扁平 embedding，「相似」之外再回答「连着谁、为什么、怎么连」。实体、关系、事实、决策都是一等节点，可按 hop 遍历，可按历史日期取快照（`state_at`）。边可带 `valid_from` / `valid_until`，事实可同时记录「世界上何时为真」和「系统何时写入」。

`AgentContext` 把向量库与知识图谱绑在一起，供 Agent 写入对话记忆并按问题取回。多个 Agent 可共用同一张图，而不是各持一份窗口记忆。

### 5.2 决策智能（Decision Intelligence）

一次 Agent 选择不是日志行，而是图上的节点，带类别、场景、理由、结果、置信度和元数据。因果边限定为 `CAUSED`、`INFLUENCED`、`PRECEDENT_FOR`。

| API | 作用 |
| --- | --- |
| `record_decision` | 写入结构化决策 |
| `add_causal_relationship` | 挂上游原因或下游影响 |
| `trace_decision_chain` | 回溯祖先链 |
| `find_similar_decisions` | 按语义找先例 |
| `analyze_decision_impact` | 看该决策影响了什么 |
| `check_decision_rules` | 对照策略规则做合规门 |

导出格式包括 W3C PROV-O、JSON、CSV，面向审计提交。这是相对普通 GraphRAG 仓库最明显的增量。

### 5.3 本体：从数据归纳，用 SHACL 约束

`OntologyGenerator` 从实体/关系字典推断类和属性，生成 OWL；`OntologyValidator` 做一致性与 SHACL 形状检查。另有 SKOS 词表、跨本体对齐、Ontology Hub 可视化编辑。v0.7.0 增加 `bootstrap_schema`：先从抽取结果长出草稿，再由人批准。

这与 Palantir ObjectType「人事先声明对象、属性、链接、动作」方向相反：先有实例与边，再反推类型。归纳结果是草稿，不能当作已发布的企业契约。

### 5.4 推理、溯源与事实可信度

- **推理：** 前向链、Rete、Datalog、SPARQL，并生成可逐步展开的解释。README 写明当前 Rete 的条件匹配仍然简单，接入生产合规闸门前要对照真实规则集验收。
- **溯源：** `ProvenanceManager` 按 W3C PROV-O 记录实体和关系来自哪份文件、哪次抽取。
- **冲突：** 值、类型、关系、时间、逻辑五类冲突，可用来源可信度加权、最近写入或投票等方式消解。
- **信任分层：** 较新版本按旁证把图事实标为隔离 / bronze / silver / gold，并可按「仍被支持的事实」过滤检索。

---

## 6. 使用面

能力可以从 Python API 调用，也可以不写代码：

| 入口 | 说明 |
| --- | --- |
| Python 包 | `semantica.context`、`ingest`、`kg`、`ontology`、`reasoning` 等模块可单独使用 |
| CLI | `semantica doctor` 做健康检查；分组命令覆盖摄入、抽取、建图、推理、决策、本体、导出、可视化、MCP |
| REST | `python -m semantica.server`，默认 8000 端口；覆盖抽取、图、决策、推理、溯源、本体、检索、流水线 |
| MCP | `python -m semantica.mcp_server` 或 `semantica-mcp`，默认 stdio，面向 Claude Desktop 等客户端 |
| Explorer | `pip install "semantica[explorer]"` 后本地打开图谱、时间轴、决策链、实体消歧、Ontology Hub、血缘视图 |

MCP 工具（文档列出的集合，随版本增减）大致分四类：抽取实体与关系；增删改查图节点与边、导出与统计；记录/查询决策、先例与因果链；执行规则与语义检索（`store_document` / `retrieve_context` 等）。

编辑器插件覆盖 Claude Code、Cursor、Codex、Windsurf、Cline、Continue、VS Code 等。Agent 框架侧对 Agno、CrewAI、LangChain 有一等集成；LangGraph、LlamaIndex、AutoGen 等走 REST 或 MCP。LLM 经 LiteLLM 对接 OpenAI、Anthropic、Gemini、Ollama、DeepSeek 等。

生产部署文档指向 Docker / Kubernetes，以及 AWS、GCP、Azure、Fly.io 等模板，并建议为 API 配置 `SEMANTICA_API_KEY`、为图和向量选用持久后端。v0.6.5 起 Explorer 默认校验 API Key，未设置则拒绝匿名访问。

---

## 7. 和相邻产品的位置

| | 向量库 + RAG | Palantir Ontology / Ontexus | EvoOntology | **Semantica** |
| --- | --- | --- | --- | --- |
| 主问题 | 这段文本像不像 | 业务对象是什么、能怎么改 | 这个词对应哪张表、哪条约束 | 实体如何相连、这次决策从哪来 |
| 本体来源 | 无 | 人事先建模 Object / Link / Action | 任务轨迹上版本化术语与映射 | 从抽取结果生成 OWL/SHACL 草稿 |
| 写操作 | 无 | Action 是唯一写闸 | 不执行业务写入 | 图节点与决策记录；不回写源系统 |
| 记忆形态 | 切片与相似度 | 物化对象视图 | 小型语义图文件 | Context Graph + 可选向量 |
| 审计 | 弱 | Action History | 证据与对照评估 | PROV-O + 决策因果链 |
| 形态 | 检索组件 | 企业平台或自托管运行时 | 编码 Agent 插件 | Python SDK + 可选常驻服务 |

相对向量 RAG：补上结构、冲突、时间旅行和「为什么」。  
相对 Palantir 路线：更接近知识工程与 GraphRAG 流水线，缺对象物化和受管写回。  
相对 EvoOntology：Semantica 自己建图、推理、可视化；EvoOntology 只保存语义记录，查数仍走宿主原有工具。

仓库把自己写成「补在现有 LLM / 向量库 / Agent 之上，而不是替换它们」。这个说法与代码结构一致：没有 LLM 也能建图和跑规则；有 LLM 时抽取质量会上去，但规则引擎并不依赖它。

---

## 8. 成熟度

星标在约十七个月内过万，叙事（GraphRAG、可问责 AI、本体、合规导出）与 2025–2026 年热点重合。高星不等于可直接作为生产语义平台。

仓库与发行说明里已经写明、或仍在修复的缺口包括：

- Rete 条件匹配刻意保持简单，生产合规闸门前必须用真实规则验收。
- SPARQL 执行直到较近版本才真正打到 triple store；此前存在空操作路径。
- 开放修复中仍可见：部分导出丢失嵌套置信度或零值偏移、个别 Agent 集成把关系键写错导致边被丢弃、Rete 结论未代入绑定、Explorer 再导入只追加不删除旧节点等。
- v0.6.x 连续发布过安全补丁（Explorer 缺鉴权、Cypher/SPARQL 注入、SSRF、pickle 反序列化等）。私有化部署应跟发行说明升级，并关闭匿名模式。
- README 中的性能数字来自约 11.8 万节点的一次测量，不是持续基准；去重加速数字写在 changelog 而非自动化断言里。

适合作为：已有湖仓或文档、需要给 Agent 加可遍历上下文和决策留痕、并能接受自运一套 Python 图栈时的开源选项。  
不适合直接当作：企业主数据标准、对象—动作运行时，或传统业务系统的智能化改造工具。

---

## 9. 小结

| 要点 | 结论 |
| --- | --- |
| 主问题 | Agent 只靠 embedding 时没有结构、没有关系、也说不清依据 |
| 给出的答案 | 带出处的上下文图：实体和决策都是节点，SHACL 约束形状，PROV-O 回答事实从哪来 |
| 本体角色 | 治理与导出格式（OWL、SHACL、SKOS），不是事先发布的业务契约，也不是写回闸门 |
| 不宜类比 | 开源 Palantir；缺对象物化和受管写回 |

把它当作图原生的语义 / 上下文层来理解，比把它当作「开源 Palantir」更准确。
