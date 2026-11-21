---
title: NVIDIA Auto Ontology结构化数据语义层简介
description: >-
  NVIDIA Auto Ontology 架在关系库和问数 Agent 之间：从库表元数据生成术语、join 和 SQL 口径，人认证后再把自然语言编译成可执行 SQL。它是结构化数据上的语义目录加 Text-to-SQL，不是文档图谱，也不是对象—动作运行时。
date: 2026-11-12 18:00:00
categories: [AI, ontology]
tags: [AI, ontology, NVIDIA]
image:
  path: /assets/img/posts/common/ontology.jpg
---

# NVIDIA Auto Ontology结构化数据语义层简介

> **NVIDIA Auto Ontology** 是架在关系数据之上的语义目录与问数层。它从库表元数据生成术语、表关系和已审 SQL 口径，经人认证后，把自然语言问题编译成可执行的 SQL，并返回答案、语句和步骤。仓库 [NVIDIA/auto-ontology](https://github.com/NVIDIA/auto-ontology)（调研时约 12,013 star、986 fork，Apache-2.0），创建于 2026-04-27，主分支仍在更新，**暂不接受外部 PR**。下文按 README、`docs/mcp.md` 与配套评测仓整理。

**参考与延伸阅读**：

- 仓库：<https://github.com/NVIDIA/auto-ontology>
- MCP 说明：<https://github.com/NVIDIA/auto-ontology/blob/main/docs/mcp.md>
- 评测仓：<https://github.com/NVIDIA/auto-ontology-eval>
- SQL 评测：<https://github.com/NVIDIA/ontology-sql-eval>
- 封面图 BFO 2.0：<https://commons.wikimedia.org/wiki/File:BFO_ontology.jpg>（AH-LOD，CC BY-SA 4.0）

---

## 目录

- [1. 定位](#1-定位)
- [2. 它首先不是什么](#2-它首先不是什么)
- [3. 产品快照](#3-产品快照)
- [4. 三类定义](#4-三类定义)
- [5. 生命周期](#5-生命周期)
- [6. 必须配置数据源](#6-必须配置数据源)
- [7. 组件与使用面](#7-组件与使用面)
- [8. 和问数产品的关系](#8-和问数产品的关系)
- [9. 使用边界](#9-使用边界)
- [10. 小结](#10-小结)

---

## 1. 定位

Agent 已经能检索文档、连接数据库，但分析是否可信卡在口径：同一个「营收」在不同系统里算法不同，答得快不等于答得对。官方把缺口写成：Agent 需要知道数据在哪、是什么意思、能不能用、怎么用、从哪来、什么与它相近。Auto Ontology 从企业元数据构建这一层，调和跨系统定义，再通过 MCP、CLI 和 API 交给任意 Agent 运行时。它声明自己补充客户已有的语义模型，而不是替换它们。

产品形态是一套可 Docker Compose / Helm 部署的服务，不是单文件插件。默认推理走 NVIDIA NIM（也可改为自托管 NIM 或 OpenAI 兼容端点）。配套有网页 Chat、数据目录、RBAC，以及只读 MCP。

**结论性定义：** Auto Ontology 放在「关系库」和「问数 Agent」之间。它保存三类定义：业务术语（Term）、挂在术语下的 SQL 属性、表之间的关系。问数时先解析到这些定义，再生成并校验 SQL，最后在已连接的库上执行。没有数据源连接，就没有可执行的语义层。

四件事：Discover（从元数据生成本体、接入已有语义模型）、Ground（给指标和实体以可信含义）、Validate（对照已认证定义和血缘检查查询）、Expose / Learn（对外服务，并把认证过的修正折回本体）。

---

## 2. 它首先不是什么

| 不是 | 原因 |
| --- | --- |
| 文档知识库 / RAG | 不索引 PDF、Wiki、切片。原文检索不在产品范围内 |
| 无源语义文件 | 不像只存映射、自己不跑 SQL 的插件。它既编译语义，也执行查询 |
| Palantir 式对象—动作运行时 | 没有托管写回、没有对象实例上的写权限闸门。MCP 工具全是只读 |
| 免连库的「自动本体」 | 必须配置数据源。编译读的是 schema、列画像和样例值，数字来自 `SELECT` |
| 无人值守的口径发布 | 自动生成的是草稿。名称、描述和 SQL 属性要人认证后才当作可信口径 |

一句话：它是结构化数据上的语义目录加 Text-to-SQL，不是文档图谱，也不是业务系统本身。

---

## 3. 产品快照

| 项 | 值（2026-11-12） |
| --- | --- |
| 仓库 | [NVIDIA/auto-ontology](https://github.com/NVIDIA/auto-ontology) |
| 星标 / Fork / 开放议题 | 约 12,013 / 986 / 118 |
| 许可 | Apache-2.0 |
| 语言 | Python 3.12+（后端 FastAPI）；前端 Next.js 16 |
| 默认模型 | NIM：`nvidia/nemotron-3.5-lightning-30b-a3b`（推理）、嵌入与重排另有专用模型 |
| 对外端口 | Web 3000；MCP `http://…:3003/mcp`；FastAPI 3001/3002 应放内网 |
| 贡献政策 | 维护组不接受外部 pull request；集成需求和缺陷可开 issue |

默认 LLM / 嵌入 / 重排走 `integrate.api.nvidia.com`，需要 `nvapi-` 密钥。每个角色用一组 `*_ENDPOINT` / `*_API_KEY` / `*_MODEL`，未填的字段回落到 `DEFAULT_MODELS_*`。自托管 NIM 或任意 OpenAI 兼容端点可以按角色覆盖。嵌入模型在摄入和查询两侧必须一致。模型需支持结构化输出。

---

## 4. 三类定义

本体里只放定义，业务行仍在源库。

| 种类 | 含义 |
| --- | --- |
| Term | 业务概念，如 Customer、Invoice Line。含描述、同义词，映射到持有它的列 |
| SQL attribute | 审过的 SQL 表达式，挂在某个 Term 下，如毛利、滚动合计。Agent 复用同一条，保证同指标同算法 |
| Relationship | 表如何 join，含桥表。从键和数据推断 |

语义模型可用 Apache Ossie YAML 导入导出（Settings → Import / Export，或 `POST /api/model/import`、`/export`）。这是和已有语义资产对接的口，不是 OWL/SHACL 行业参考本体。

---

## 5. 生命周期

```text
连接数据源 → 摄入与语义编译（草稿）
         → 人在 UI / API 中修订并认证
         → Agent 按已认证定义写 SQL、校验、执行
```

**Generate。** 摄入服务从源库出第一稿：读 schema、给列做画像、采样值写入目录；按表抽出术语并映射到列；推断 join 和桥表；若有查询历史，可建议 SQL 属性；写入 Postgres，嵌入进 pgvector。结果是可在 UI 里点开的语义图。示例库 Wide World Importers 的一次编译约得到 31 个术语。

**Certify。** 用 Chat 或 MCP 的 `check_answerable` / `ask_question` 拿真实问题试；在界面或 API 里改术语、描述和 SQL 属性；确认无误后认证名称、描述和表达式。未认证的草稿不应当作生产口径。

**Answer。** 对每个问题：分类意图并抽出实体 → 用嵌入检索候选术语、列和 SQL 属性 → 据此写 SQL → 对照库检查过滤值，失败则修复 → 执行并返回答案、SQL 和步骤。候选撑不起查询时，明确说当前数据答不了。预测类问题在配置了 KumoRFM 时可旁路到该托管服务（会上传所连表，默认可关，启用前需做数据审查）。

Chat 里每条答案展示 SQL，可看行、下 CSV 或出图。官方 Quickstart 用「某商品在宾夕法尼亚 2015 年 6 月营收」演示：先解析到 Invoice Line、Stock Item、State Province 等术语，再沿关系 join。同一库没有广告花费时，问 ROAS 会得到覆盖不足的说明，而不是编一个数。

---

## 6. 必须配置数据源

用法与常见智能问数产品相同：**先挂业务库，再谈语义层。** 没有连接，编译没有输入，问数没有执行面。

在 **Settings → Connections** 添加，或在 `CONNECTION_STRINGS` 里列出。当前文档列出十种引擎：

PostgreSQL、MySQL、Databricks、Snowflake、ClickHouse、Trino、Apache Kyuubi、HeavyDB、DuckDB、SQLite。

DuckDB 与 SQLite 仅支持连接串。凭证可进可选的 HashiCorp Vault。连接、库范围和凭据说明见 `docs/connections.md`。

「自动」指的是连接之后的 Generate，不是免去连库。文档、Wiki、聊天记录不能替代一张可 `SELECT` 的表。

---

## 7. 组件与使用面

| 组件 | 技术 | 角色 | 端口 |
| --- | --- | --- | --- |
| Frontend | Next.js、Better Auth、Prisma | 网页、登录、对外 API 网关 | 3000 |
| Backend | FastAPI、LangChain | Text-to-SQL、目录、本体 API | 3001 |
| Ingestion | FastAPI | 摄入与语义编译 | 3002 |
| MCP | FastMCP | 只读工具，转发到公开 API | 3003 |
| Postgres + pgvector | PostgreSQL 17 | 应用元数据、目录、本体、向量 | 5432 |
| Vault | 可选 | 连接凭据 | — |

3001 / 3002 应留在私网。FastAPI 信任前端转发的 `x-auto-ontology-user-id`；摄入接口（ingest / delete / reset / compile）自身无鉴权。浏览器和外部客户端走 3000。

**本地 Quickstart（官方）：** Docker Compose v2、`uv`、NVIDIA API key。克隆仓库并填写 `.env`，拉起 Postgres，用 auto-ontology-eval 灌入 Microsoft Wide World Importers，再 `docker compose up -d --build`。打开 `http://localhost:3000` 登录，在 Settings → Semantic Compilation 打开编译，就绪后在 Chat 提问。生产用 Helm，见 `DEPLOYMENT.md`。

**REST：** `POST /api/chat/completions`（网页同源），用用户菜单里签发的 API Token。响应为 SSE：`result` 事件带答案和 SQL，`data: [DONE]` 结束。

**MCP：** 进程本身不持有库账号和模型配置，只把调用转到 3000 上的公开 API，权限等于登录用户。本地示例：

```text
AUTO_ONTOLOGY_API_URL=http://localhost:3000
uvx --from "git+https://github.com/NVIDIA/auto-ontology.git#subdirectory=mcp" auto-ontology-mcp
```

客户端指向 `http://localhost:3003/mcp`。协议要求用户在 Auto Ontology 上登录（OAuth）；文档写明没有「给 MCP 进程贴一张永久密钥、让所有调用者冒充其主人」的配置。部署需提供 `/.well-known/oauth-authorization-server`。

| 工具 | 作用 |
| --- | --- |
| `check_readiness` | 语义层是否已编译、库是否还能执行 SQL。二者缺一都会让后续提问又慢又含糊 |
| `search_terms` / `get_term` / `get_term_columns` / `get_term_sql_attributes` / `get_sql_attribute` | 读术语和口径 |
| `describe_table` | 某表参与了哪些术语和 SQL 属性 |
| `check_answerable` | 这题本体盖不盖得住，应作为廉价预检 |
| `ask_question` | 主工具：答案、SQL、行（最多 100 行）。内部多次调模型，常要数十秒 |

故意没有「浏览原始 schema / 裸列」的工具，避免 Agent 绕过语义层猜表。`ask_question` 走与网页 Chat 相同的完整 Text-to-SQL Agent，不应作为默认的第一跳；握手时的 instructions 也按「先可答性、再提问」编排。

另有三个编码 Agent 技能：`nvidia-ontology-setup`、`nvidia-ontology-management`、`nvidia-ontology-query`，入口见仓库 `AGENTS.md`。

---

## 8. 和问数产品的关系

二者同属「连上业务库 → 语义层 → 自然语言问数」。差别主要在语义层怎么出现，不在要不要配数据源。

| | 术语库 + 示例 SQL | Auto Ontology |
| --- | --- | --- |
| 数据源 | 必须配置 | 必须配置 |
| 语义层怎么来 | 人维护术语，并提供示例 SQL | 从元数据自动出草稿，人再认证 |
| 问数 | 自然语言 → SQL | 自然语言 → SQL，答案附带语句和步骤 |
| 覆盖不到时 | 靠示例和提示约束 | 可先 `check_answerable` |
| 口径一致性 | 示例写对了就稳 | 认证后的 SQL 属性强制同指标同表达式 |
| 对 Agent | MCP | MCP（只读工具集） |
| 额外能力 | 相对轻，上手快 | Ossie 导入导出、多引擎、可答性、编译出 join |

可以把 Auto Ontology 理解成 **同一赛道上更自动的语义层构建**：表多、口径散、join 复杂时，少手写一批示例 SQL；问法固定、表就几张、术语已经写清时，术语库加示例 SQL 已经覆盖主要用途，自动编译的增量有限。

「更自动」只覆盖 Generate：读表、起术语名、猜关系、从查询历史建议 SQL 属性。  
「更强」主要指：认证口径的复用、可答性预检、答案可核对 SQL、跨引擎连接和语义模型交换。

不是无人发布。草稿仍要人改描述、改表达式、点认证。不认证就拿去问生产指标，和问数产品没有示例 SQL 就开放查询一样不稳。

术语库一类产品执行查询；EvoOntology 一类插件只存映射，查数仍走宿主原有工具。Auto Ontology 把「存口径」和「跑 SQL」放在同一套服务里，因此更接近前者，并多了一段从元数据到草稿的编译。

---

## 9. 使用边界

- 连接必须先有。没有可执行的关系源，MCP 和 Chat 都没有数字。
- 编译质量依赖推理和嵌入模型。默认按 30B 级 NIM 设计；换成更小的兼容端点可以跑通，术语命名和 SQL 修复会变差。
- `ask_question` 耗时长、调用链深，适合作为「这题已经判定可答」之后的执行步，不适合当作所有问题的默认工具。
- MCP 登录绑定具体用户权限，不便做成「服务账号一劳永逸」。需要固定密钥时，应走网页同源的 API Token 调 Conversation API，而不是指望 MCP 进程自带身份。
- 预测路径（KumoRFM）会把表送到外部托管服务，默认不要开。
- 高星标、NVIDIA 署名、且不接受外部 PR：适合作为可部署的问数语义层选项，不适合当成可以随意改内核的框架。

---

## 10. 小结

| 要点 | 结论 |
| --- | --- |
| 位置 | 关系库与问数 Agent 之间的已认证语义目录 |
| 产物 | 带 SQL 的数字；前提是源库已连接、术语和表达式已经过人 |
| 不是 | 文档库、对象—动作运行时、免连库的自动本体 |
| 和术语库问数 | 连库与问数同构；多出来的是元数据草稿、可答性检查和认证后的口径复用 |

把它当作结构化数据上的语义目录加受管 Text-to-SQL 来理解，比把它当作通用企业本体平台更准确。
