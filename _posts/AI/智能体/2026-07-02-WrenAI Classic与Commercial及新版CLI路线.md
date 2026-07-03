---
title: WrenAI Classic与Commercial及新版CLI路线
date: 2026-07-02 15:02:00
categories: [AI, 智能体]
tags: [AI, 智能体, WrenAI, GenBI, Text-to-SQL, Agent]
image:
  path: /assets/img/posts/common/ai-agent.jpg
---

# WrenAI Classic与Commercial及新版CLI路线

> 2026 年 5 月，Canner 完成 Wren 开源仓库整合：`main` 分支转向 **面向 AI Agent 的 Open Context Engine**，旧版 Docker 成套 Web 产品 **Wren GenBI Classic** 已 sunset。本文从产品线定位、Classic 与 Commercial 能力差异、新版 CLI 引擎策略、Web UI 分发形态、Commercial 闭源与私有化部署五个维度展开综述，并给出选型建议。信息以官方文档与 GitHub 公告为准，具体功能与定价以厂商当前页面为准。

**参考与延伸阅读**：

- Wren AI OSS 介绍：<https://docs.getwren.ai/oss/introduction>
- OSS vs Commercial 官方对比：<https://docs.getwren.ai/oss/concepts/oss_vs_commercial>
- 仓库整合公告（Discussion #2205）：<https://github.com/Canner/WrenAI/discussions/2205>
- Classic 安装文档：<https://docs.getwren.ai/oss/installation>
- Commercial 概览：<https://docs.getwren.ai/cp/overview>
- Commercial EULA：<https://www.getwren.ai/eula>

---

## 目录

- [一、三条产品线定位](#一三条产品线定位)
- [二、Classic 与 Commercial 功能比对](#二classic-与-commercial-功能比对)
- [三、新版 OSS 的 CLI 引擎路线](#三新版-oss-的-cli-引擎路线)
- [四、Web UI 的分发形态](#四web-ui-的分发形态)
- [五、Commercial 闭源与私有化部署](#五commercial-闭源与私有化部署)
- [六、选型建议](#六选型建议)
- [七、小结](#七小结)
- [八、参考与来源](#八参考与来源)

---

## 一、三条产品线定位

Wren 当前并存三条路径：**Classic**（旧版 Docker Web 问数）、**新版 OSS**（`main` 分支 CLI/SDK 引擎）、**Commercial**（商业团队平台）。选型前须先厘清三者边界，避免将 **旧版开源 Docker 产品** 与 **商业团队平台** 混为一谈。

| 名称 | 定位 | 维护状态 |
|------|------|----------|
| **Classic**（Wren GenBI Classic） | 旧版 Docker 成套 Web 问数产品（`wren-ui` + `wren-ai-service` + Launcher） | 已 sunset；代码在 `legacy/v1`，**停更、无安全修复** |
| **新版 OSS**（`main` 分支） | 开源 **Context Engine + CLI/SDK**，面向 LLM Agent / MCP 客户端 | **活跃开发**（Apache 2.0） |
| **Commercial** | 商业版团队平台：云托管或企业自建，含 Web UI 与治理能力 | **活跃维护**（EULA） |

官方在 OSS 介绍中明确：Classic 的「持续维护版体验」指向 **Commercial**，而非新版 OSS CLI。

> *For an actively maintained, hosted version of that classic experience, see Wren AI Commercial.*

举证：<https://docs.getwren.ai/oss/introduction>

Classic 代码与 Docker 编排保留在 [`legacy/v1`](https://github.com/Canner/WrenAI/tree/legacy/v1) 分支（tag `v1-final`），Launcher 最后发布版本为 [0.29.1](https://github.com/Canner/WrenAI/releases/tag/0.29.1)。

---

## 二、Classic 与 Commercial 功能比对

下表对比 **Classic（legacy/v1）** 与 **Commercial**，并在「举证」列给出可核对的官方链接。新版 OSS（`main`）与 Commercial 的官方对比见 [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial)，第三节末单独列出节选。

| 维度 | Classic（legacy/v1） | Commercial | 举证 |
|------|----------------------|------------|------|
| **产品定位** | Docker 聊天式 GenBI，浏览器自然语言问数 | 团队级 Agentic GenBI：人 + Agent 共用治理语义层 | [Commercial Overview](https://docs.getwren.ai/cp/overview)、[Classic README](https://github.com/Canner/WrenAI/blob/legacy/v1/README.md) |
| **Web UI** | ✅ 有（`wren-ui`） | ✅ 有，持续迭代 | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial)、[#2205 维护者回复](https://github.com/Canner/WrenAI/discussions/2205) |
| **部署方式** | 自建 Docker / Launcher | 云托管（Essential / Enterprise）或企业自建（Business / Enterprise Plus） | [Classic 安装](https://docs.getwren.ai/oss/installation)、[Commercial Overview](https://docs.getwren.ai/cp/overview) |
| **费用** | 免费（自建） | 付费商业计划 | [getwren.ai](https://getwren.ai)、[Commercial Overview](https://docs.getwren.ai/cp/overview) |
| **维护与安全更新** | ❌ 已 sunset，无新功能、**无安全修复** | ✅ 持续维护 + 厂商支持 | [OSS Introduction](https://docs.getwren.ai/oss/introduction)、[#2205](https://github.com/Canner/WrenAI/discussions/2205) |
| **开源协议** | 旧代码在 `legacy/v1`（历史多为 AGPL） | **EULA 商业许可**（非开源） | [EULA](https://www.getwren.ai/eula)、[CHANGELOG](https://github.com/Canner/WrenAI/blob/main/CHANGELOG.md) |
| **Text-to-SQL 对话** | ✅ | ✅ | [Classic README](https://github.com/Canner/WrenAI/blob/legacy/v1/README.md) |
| **MDL 语义层建模** | ✅ 浏览器可视化建模 | ✅ Git-native MDL + 平台管理 | [Classic 架构](https://github.com/Canner/WrenAI/blob/legacy/v1/README.md#-architecture)、[getwren.ai](https://getwren.ai) |
| **Knowledge 知识库** | ✅ UI 内管理业务词典与示例 | ✅ Agentic 项目 + 发布流程 | [Knowledge（Agentic）](https://docs.getwren.ai/cp/guide/agentic/knowledge) |
| **Agentic 多步推理** | ❌（经典对话模式为主） | ✅ Agentic Mode | [Asking Questions](https://docs.getwren.ai/cp/guide/agentic/querying/ask) |
| **GenBI Apps（交互仪表盘）** | Classic 版 Dashboards | ✅ Agentic 项目专属 GenBI Apps | [GenBI Apps](https://docs.getwren.ai/cp/guide/agentic/querying/genbi-apps) |
| **Slack / Microsoft Teams** | ❌ | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **多用户 / 账号 / 角色** | ❌（单机 Docker 栈） | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **SSO / LDAP / SCIM** | ❌ | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **按用户的 RLS/CLS、审计日志** | ❌（仅 MDL 级 RLAC/CLAC） | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **MCP Server / 托管 REST API** | ❌ | ✅（API 需 Essential / Business 及以上） | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial)、[API Access](https://docs.getwren.ai/cp/guide/api-access/overview) |
| **CLI / SDK 供自建 Agent** | 弱（以 UI 为主） | ✅ 同时支持 | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **Evaluation / AI Advisor / 反馈追踪** | ❌ | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **厂商技术支持** | ❌ | ✅ | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **BYO LLM（自带大模型）** | 可配 `config.yaml`（DIY） | ✅ 正式支持（Business 自建版） | [Custom LLM（Classic）](https://docs.getwren.ai/oss/ai_service/guide/custom_llm)、[BYO LLM](https://docs.getwren.ai/cp/guide/byo_llm/overview) |

**核心差异**：

- **Classic**：免费、自建、有 Web UI，适合短期 POC 或内网试用，但**已冻结**，不宜作为长期生产依赖。
- **Commercial**：在「浏览器问数」体验之上，补齐团队协作、身份权限、集成、API、审计与支持，且**持续维护**。

---

## 三、新版 OSS 的 CLI 引擎路线

2026 年 4–5 月，Canner 将 `wren-engine` 并入 `Canner/WrenAI`，`main` 分支完成战略 repositioning。维护者在 [Discussion #2205](https://github.com/Canner/WrenAI/discussions/2205) 阐明：新版仓库定位为 **Open Context Engine for AI Agents**，主用户是 **LLM Agent 或 MCP 客户端**，通过编程接口交互，而非依赖浏览器 UI。

> *The new Canner/WrenAI is being repositioned as an **Open Context Engine for AI Agents** — the primary user is an LLM agent or MCP client interacting programmatically, rather than a human clicking through a UI.*

据此，新版 OSS 以 **CLI + SDK** 为默认交付形态；**`wren-ui` 不迁入 `main` 的 `core/`**，旧 UI 保留在 `legacy/v1`，可用但不再开发新功能。

### 3.1 Classic UI 能力在新版 OSS 中的对应关系

| Classic UI 功能 | 新版 OSS（CLI）对应 |
|-----------------|---------------------|
| 浏览器里建 MDL 模型 | `wren context init` / `wren context build` + **YAML/MDL 文件**（可 Git 版本管理） |
| Knowledge / 业务词典 | `instructions.md`、`queries.yml` + `wren memory index` |
| 自然语言问数 | `wren query`，或 Agent 通过 `wren-langchain` / `wren-pydantic` 接入 |
| 仪表盘 | `wren skills get genbi` 生成可部署的 **GenBI App**（浏览器端 WASM，可部署到 Vercel / Cloudflare Pages） |

官方将建模与知识从「GUI 表单」转为「文件 + CLI + LanceDB 索引」，以支持 **Git 评审、与引擎查询路径一致、避免 UI 与引擎漂移**。Memory 文档：<https://docs.getwren.ai/oss/engine/guide/memory>；GenBI 指南：<https://docs.getwren.ai/oss/guides/genbi>。

### 3.2 新版 OSS 与 Commercial 官方能力对照（节选）

| 能力 | 新版 OSS | Commercial |
|------|----------|------------|
| 免费且可完全自建 | ✅ | ✅（含自建商业版） |
| 全托管云 | ❌ | ✅ |
| CLI 与 SDK | ✅ | ✅ |
| MCP Server / 托管 REST API | ❌ | ✅ |
| MDL 级访问控制（RLAC/CLAC） | ✅ | ✅ |
| GenBI 仪表盘 | ✅ | ✅ |
| 面向非技术用户的 Web UI | ❌ | ✅ |
| Slack / Teams | ❌ | ✅ |
| 账号、角色、多用户 | ❌ | ✅ |
| SSO / LDAP / SCIM | ❌ | ✅ |
| 按用户 RLS/CLS、审计日志 | ❌ | ✅ |
| Evaluation、AI Advisor、反馈追踪 | ❌ | ✅ |
| 厂商支持 | ❌ | ✅ |

完整表格：<https://docs.getwren.ai/oss/concepts/oss_vs_commercial>

---

## 四、Web UI 的分发形态

仓库整合后，Web UI 按产品线拆分为三种形态，如下表所示。

| 维度 | 说明 |
|------|------|
| **新版 OSS（`main`）** | **暂无**与 Classic 同级的官方 Web UI（`wren-ui` 未迁入 `core/`） |
| **Classic（`legacy/v1`）** | Web UI **开源**，代码在 [`legacy/v1/wren-ui`](https://github.com/Canner/WrenAI/tree/legacy/v1/wren-ui)，**已停更** |
| **Commercial** | Web UI **闭源**，属商业产品（EULA），不在 OSS `main` 仓库 |
| **新版 GenBI UI（roadmap）** | 官方计划基于 `core/` 重建 GenBI UI，设计进行中，**尚未发布预览** |
| **当前活跃 Web UI** | 由 **Commercial**（云或企业自建）提供 |

维护者在 #2205 中补充：欢迎社区在 Apache 2.0 引擎之上 **自建或赞助 UI**（*"Build or sponsor a UI on top of core"*）。MDL JSON Schema 位于 `core/wren-mdl/`，任何 UI 均可读写。

短期内若业务 **必须以浏览器问数** 且无法接受停更风险，官方路径为：

1. 继续使用 `legacy/v1` Docker 镜像（GHCR 至 `0.29.1` 仍可用）——须接受无安全更新；
2. 选用 **Commercial**——获得持续维护的 Web 体验与企业能力。

---

## 五、Commercial 闭源与私有化部署

选型时常见误解是把 **「Web UI 不开源」** 等同于 **「无法私有化部署」**。二者应分开理解：**Commercial 的 Web UI 属 EULA 闭源软件，不在 OSS 仓库发布源码；官方同时提供 Self-Hosted 商业版本，可在自有基础设施中部署完整产品（含 Web UI）**。

### 5.1 闭源与私有化是两个维度

| 维度 | Commercial 情况 | 举证 |
|------|-----------------|------|
| **是否开源** | **否**。适用 [EULA](https://www.getwren.ai/eula)，Web UI 不在 `Canner/WrenAI` OSS 仓库 | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial)（OSS 无 Web UI，Commercial 有） |
| **能否私有化部署** | **能**。提供 **Self-Hosted** 版本（Business / Enterprise Plus） | [Commercial Overview](https://docs.getwren.ai/cp/overview) |
| **部署形态** | 云托管（Essential / Enterprise）**或** 企业自建 | [OSS vs Commercial](https://docs.getwren.ai/oss/concepts/oss_vs_commercial) |
| **许可获取** | 向厂商购买计划；自建版需 **license 激活**（非自行编译开源代码） | [EULA](https://www.getwren.ai/eula)（Deployment Models / License Activation） |

官方对比表中，Commercial 在 **Free and fully self-hosted** 与 **Fully managed cloud** 两项均为 ✅，表明 **自建与托管并存**，并非只能 SaaS：

| 能力 | OSS | Commercial |
|------|-----|------------|
| Free and fully self-hosted | ✅ | ✅ |
| Fully managed cloud | ❌ | ✅ |

举证：<https://docs.getwren.ai/oss/concepts/oss_vs_commercial>

同页原文：

> *Wren AI Commercial … runs as a **hosted cloud service or as a self-hosted enterprise deployment**, and it adds a **web UI** …*

### 5.2 Self-Hosted 商业版本与部署边界

[Commercial Overview](https://docs.getwren.ai/cp/overview) 将商业计划分为：

| 类型 | 版本 | 说明 |
|------|------|------|
| Cloud | Essential / Enterprise | 厂商托管 |
| **Self-Hosted** | **Business** | *For secure, scalable GenBI in your **private infrastructure**.* |
| **Self-Hosted** | **Enterprise Plus** | 面向大型组织、复杂采购需求 |

页内架构图标注 **ON-PREM**（本地数据库与治理层），与云仓库并列，说明私有化是正式产品线而非旁路方案。

官网 GenBI 页进一步写明部署边界：

> *Cloud, **private cloud**, or **air-gapped on-prem**; same product, your governance boundary.*

举证：<https://www.getwren.ai/genbi>；首页同类表述见 <https://getwren.ai/>。

[资源页](https://www.getwren.ai/resources) 亦写明：Commercial 可 *deploy within your infrastructure*，支持语义建模、数据治理与多租户隔离。

自建版配套文档（如 [BYO LLM](https://docs.getwren.ai/cp/guide/byo_llm/overview)）明确：

> *This capability is available on the **Business Plan for the Wren AI Self-Hosted Version**.*

Azure OpenAI、AWS Bedrock 等快速配置文档均标注 *Self-hosted: Business, Enterprise Plus*，且流程含 Web 控制台 **onboarding / Settings**，表明私有化交付的是 **带 UI 的完整商业栈**，而非纯 CLI。

### 5.3 与 Classic 自建的区别

| 维度 | Classic（legacy/v1） | Commercial Self-Hosted |
|------|----------------------|-------------------------|
| 许可 | 旧版开源代码（历史多为 AGPL） | **EULA 商业许可** |
| 获取方式 | GitHub + Docker 自行拉取 | 购买 Business / Enterprise Plus，厂商提供安装包/镜像与 **license 激活** |
| Web UI | 开源 `wren-ui`，**已停更** | 闭源 Web UI，**持续维护** |
| 私有化成本 | 软件免费，须自担 sunset 风险 | **付费**，含厂商支持与安全更新 |
| 适用场景 | POC、短期内网试用 | 生产级 Web 问数 + 企业治理 |

[EULA](https://www.getwren.ai/eula) 对 Self-Hosted 的 **Deployment Models** 定义为：*installed and operated within your own infrastructure (on-premise, private cloud, or virtual private cloud)*。Evaluation 与 Production 的自建许可均须 **Canner 激活**，不能等同于从 GitHub 拉源码长期用于生产。

### 5.4 三条私有化路径对照

若目标是 **数据与系统留在自有环境**，可按需求选择：

| 路径 | Web UI | 许可 | 维护 | 典型场景 |
|------|--------|------|------|----------|
| Classic Docker | ✅ 开源 UI | 开源（AGPL 等） | ❌ 停更 | 短期 POC |
| **Commercial Self-Hosted** | ✅ 闭源 UI | EULA 付费 | ✅ 持续 | 生产 Web 问数 + SSO/审计 |
| 新版 OSS CLI | ❌ 无同级官方 UI | Apache 2.0 | ✅ 引擎活跃 | Agent 集成、Git 管 MDL |

**不能同时满足的组合**：「免费 + 开源 Web UI + 长期官方维护」——目前仅 **停更 Classic** 或 **付费 Commercial 自建** 二选一；若接受无 Web UI，则 **新版 OSS CLI** 为免费自建引擎路线。

---

## 六、选型建议

| 场景 | 建议 |
|------|------|
| 快速 POC、内网试用、单人体验 Web 问数 | Classic Docker（`legacy/v1`），明确接受**无安全修复** |
| 生产环境、多用户、权限审计、Slack/Teams | **Commercial** |
| 接入自研 Agent、MCP、以 Git 管理 MDL | **新版 OSS CLI**（`pip install wrenai`） |
| 既要 Web UI 又要长期维护 | **Commercial**，而非新版 OSS |
| 私有化部署 + 活跃 Web UI + 企业治理 | **Commercial Self-Hosted**（Business / Enterprise Plus） |
| 嵌入自有产品的 NL→SQL / 图表 API | **Commercial** Essential / Business 及以上 |

新版安装入口：<https://docs.getwren.ai/oss/installation>（CLI 路径）；Classic 仍见文档侧栏 **Wren GenBI Classic · Sunset** 章节。

---

## 七、小结

| 要点 | 结论 |
|------|------|
| Commercial 与 Classic 的关系 | **不同产品**。Classic 是已冻结的免费 Docker 旧版；Commercial 是付费、持续维护的团队平台。 |
| Classic 可用性与生产适用性 | `legacy/v1` 与 Docker 镜像仍可用，但**不适合长期生产**。 |
| 新版 OSS 以 CLI 为主的原因 | 战略转向 **Agent-first Context Engine**，主用户为 Agent 而非浏览器操作者。 |
| Web UI 开源与维护现状 | Classic UI 在 `legacy/v1` 开源但停更；**活跃 Web UI 在 Commercial（闭源）**；新版 OSS GenBI UI **尚未发布**。 |
| Commercial 闭源与私有化 | **闭源 ≠ 不能私有化**；Business / Enterprise Plus 支持自建，交付含 Web UI 的完整商业栈，须 EULA 许可与 license 激活。 |
| 长期生产选型 | 要 Web + 治理 → **Commercial**（云或自建）；要 Agent 集成 → **新版 OSS**；仅试用 → Classic（知情承担 sunset 风险）。 |

---

## 八、参考与来源

- Wren AI OSS Introduction：<https://docs.getwren.ai/oss/introduction>
- Open source vs Commercial：<https://docs.getwren.ai/oss/concepts/oss_vs_commercial>
- Wren AI Commercial Overview：<https://docs.getwren.ai/cp/overview>
- 仓库整合公告 Discussion #2205：<https://github.com/Canner/WrenAI/discussions/2205>
- Classic 分支 legacy/v1：<https://github.com/Canner/WrenAI/tree/legacy/v1>
- Classic Launcher 0.29.1：<https://github.com/Canner/WrenAI/releases/tag/0.29.1>
- Classic 安装文档：<https://docs.getwren.ai/oss/installation>
- Memory 指南：<https://docs.getwren.ai/oss/engine/guide/memory>
- GenBI 指南：<https://docs.getwren.ai/oss/guides/genbi>
- Commercial EULA：<https://www.getwren.ai/eula>
- Commercial API Access：<https://docs.getwren.ai/cp/guide/api-access/overview>
- Commercial BYO LLM：<https://docs.getwren.ai/cp/guide/byo_llm/overview>
- Wren AI GenBI 产品页（on-prem）：<https://www.getwren.ai/genbi>
- Wren AI 资源页（自建说明）：<https://www.getwren.ai/resources>
