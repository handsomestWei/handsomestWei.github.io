---
title: revfactory-harness使用简介
date: 2026-04-29 22:00:00
categories: [AI, AI编程]
tags: [AI, AI编程, claude-code, harness, Agent-Team]
image:
  path: /assets/img/posts/common/AI.jpg
---

# revfactory-harness使用简介

[revfactory/harness](https://github.com/revfactory/harness) 是面向 **Claude Code** 的插件：根据自然语言描述的领域目标，自动生成 **多智能体（`.claude/agents/`）**、**配套 Skill（`.claude/skills/`）**，并按 **六种预定义团队架构**（流水线、扇入扇出、专家池、生产者-审查者、监督者、层级委派等）组织协作。本文整理 **环境要求、插件安装（在线与离线）、基本用法**，并结合一次 harness 构建过程的要点做说明（不涉及具体业务代码实现细节）。

## 前置条件

- 已安装并能正常使用 **Claude Code**；安装方式可参考官方文档：<https://code.claude.com/docs/zh-CN/overview>
- 启用 **Agent Teams（实验能力）**：环境变量 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`（Windows 在系统或用户环境变量中新增后，**新开终端**再执行 `claude`）

## 插件安装

### 方式一：在 Claude Code 内在线安装（推荐）

在 Claude Code 对话中执行（以当前仓库 README 为准，若命令有变更以对端提示为准）：

```text
/plugin marketplace add revfactory/harness
/plugin install harness@harness
```

安装完成后，可在项目根目录用 README 中的英文提示触发生成（见下文「基本使用」）。

### 方式二：离线安装（网络受限时）

若无法直连 GitHub marketplace，可手动拉取仓库产物并注册本地市场：

1. 从 GitHub 下载 [revfactory/harness](https://github.com/revfactory/harness) 的源码包（zip）并解压到本地目录
2. 将解压目录拷贝到 Claude Code 插件市场目录，例如：
   - 类 Unix：`~/.claude/plugins/marketplaces/harness-marketplace`（目录名以你本机约定为准）
   - Windows：对应用户目录下 `.claude\plugins\marketplaces\` 下同名结构；可用 Git Bash 或资源管理器复制
3. 在 Claude Code 的 `known_marketplaces.json`（或当前版本等价配置）中 **注册该 marketplace**，使 UI/命令能识别本地源
4. 再执行本地的 `install harness@harness` 或随版本文档指定的安装步骤

具体操作路径以本机 `~/.claude/` 下实际文件名为准；不一致时以 [revfactory/harness](https://github.com/revfactory/harness) 最新说明优先。

## 基本使用

### 第一步：在项目根目录打开 Claude Code

进入要落地的仓库根目录，启动 `claude`，确保已加载上述插件与环境变量。

### 第二步：用一句话触发「搭 harness」

建议用 **英文** 写清业务边界与技术栈（角色、是否登录、API 形态等），风格和官方 README 一致，便于插件解析。

**两条通用模板（中文说明 + 可复制英文）**

- **模板 A（全栈）**：让插件为「从需求到上线」搭一支队——覆盖大致的设计、前端、后端与测试，并按流水线协作；适合你已确定前后端技术栈、要写完整 Web 产品的场景。  
- **模板 B（代码审查）**：让插件为多角色 **并行** 检查（架构、安全、性能、风格等）搭编队，最后合并成 **一份** 报告；适合先验证 harness 是否生成 `.claude/agents` 与 `.claude/skills`、或长期做 PR 体检。

```text
Build a harness for full-stack website development. The team should handle
design, frontend (React/Next.js), backend (REST API), and QA testing in a
coordinated pipeline from requirements to deployment.
```

```text
Build a harness for comprehensive code review. I want parallel agents checking
architecture, security vulnerabilities, performance bottlenecks, and code style —
then merging all findings into a single report.
```

**具体需求示例**

**示例 1 — 内部请假审批（全栈）**  
中文：员工提单、主管审批、人事看汇总；需登录与 employee/manager/hr 三角色；Next.js + FastAPI + PostgreSQL；希望从 API 草图一路覆盖到部署说明类文档。下面英文把上述约束写死，复制后可根据实际项目替换栈或角色名。

```text
Build a harness for full-stack development of an internal leave-request app.
Users: employees submit requests, managers approve/reject, HR views reports.
Stack: Next.js (App Router) + TypeScript frontend, FastAPI + PostgreSQL backend,
session-based auth with three roles (employee, manager, hr). Include API design,
migrations, UI forms, and QA for happy-path plus permission edge cases.
Coordinate as a pipeline from OpenAPI sketch to deploy notes.
```

**示例 2 — 限定目录的代码审查**  
中文：只关心当前分支相对 `main` 在支付与认证目录下的改动；重点放在幂等、密钥/日志脱敏、注入与 XSS；输出要分级、带文件与行号线索。路径请改成你仓库真实目录。

```text
Build a harness for comprehensive code review. Scope: only changes under
src/payments/ and src/auth/ compared to main. Run parallel agents for
architecture fit, payment idempotency and PCI-style secrets handling,
injection/XSS, performance hot paths, and style; merge into one Markdown report
with severities and file-level pointers.
```

提示里 **越具体**，生成的 Agent 与 Skill **越贴你的真实分工**；不必堆很多场景，只要把一条写透即可。

#### 生成后的目录结构示例

插件执行成功后，**仓库根目录**下会出现 **`.claude/`**（若已存在则往里追加/更新）。其中 **`agents/`** 里是每个角色的说明（`.md`），**`skills/`** 下多为 **一层子目录 + `SKILL.md`**，有时还带 **`references/`** 放补充规范或示例；复杂场景下还可能有 **编排器** 专用 Skill。**具体文件名、子目录名会随你的英文需求与插件版本变化**，下面仅供对照形态：

```text
your-repo/
└── .claude/
    ├── agents/
    │   ├── architect.md       # 架构 / 领域：拆需求、定边界、API·数据模型草图、技术约束
    │   ├── engineer.md        # 工程实现：后端/核心业务、存储、集成与关键算法落地
    │   ├── designer.md        # 前端与体验：页面结构、组件、交互与可访问性等
    │   └── qa.md              # 质量保障：测试计划、用例、边界与回归，对接验收标准
    └── skills/
        ├── app-orchestrator/          # 编排：多阶段顺序/并行门禁、任务分发与结果汇总
        │   └── SKILL.md               #   说明何时进入哪一阶段、与其它 Skill 的衔接方式
        ├── app-architecture/          # 技能：领域建模、契约设计、非功能需求（安全/性能）条目化
        │   ├── SKILL.md
        │   └── references/            #   可选：ADR 模板、OpenAPI 片段示例、检查清单
        ├── app-implementation/       # 技能：按栈实现后端/服务层、迁移、与外部 API 对接
        │   ├── SKILL.md
        │   └── references/
        ├── app-frontend/            # 前端与 UI：组件规范、状态管理、路由与样式约定
        │   ├── SKILL.md
        │   └── references/
        ├── app-quality/             # 技能：单测/集成/E2E 策略、覆盖率与 CI 门禁说明
        │   ├── SKILL.md
        │   └── references/
        └── ...                      # 实际目录名随需求命名（如 leave-*、review-*）；审查场景常见 security、performance 等专项 Skill
```

与官方文档对照可参见 [revfactory/harness README「Output」](https://github.com/revfactory/harness#output) 中的说明。

### 第三步：查看生成结果

成功时通常在项目下出现：

- `.claude/agents/*.md`：各角色 Agent 定义
- `.claude/skills/**/SKILL.md`：技能与可参考子文档

若目录仍为空，可检查是否开启 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`、是否处于仓库根目录、以及插件是否已正确安装。

### 以 QA 智能体为例：做什么、何时触发、文件里大致有什么

**职责（相对「开发」角色的边界）**  
Harness 里常见的 **QA / `qa.md` 角色**，主要负责把 **验收标准** 变成 **可执行的验证**：测试分层策略（单测 / 集成 / 契约 / E2E 或冒烟）、用例与等价类/边界、**失败时如何报 bug**（复现步骤、期望/实际）、与权限/安全相关的负面用例、以及 **测试报告** 或 CI 门禁说明。通常 **不以写业务功能为主**，而是 **对照派工里的 Acceptance** 逐项核对，并推动缺的自动化测例补全。

**大致何时会「轮到」QA**  
- **编排器 / 团队流程**：流水线里约定「开发/前后端告一段落 → 集成与验证阶段」时，由主导会话把任务分派给 QA 角色，或由你口头要求「按 harness 里的 qa 执行验证」。  
- **你的派工里明确写了测试交付物**：例如前文示例要求 `pytest`、冒烟说明、审查报告等，模型会倾向 **加载 `qa` 对应的 Agent 定义与 `app-quality`（或生成物中的同类）Skill** 来对齐执行。  
- **Fan-in 收口**：并行开发结束后，需要 **一份汇总性的质量结论**（通过/不通过、缺口列表）时，常由 QA 视角收口。

以下说明 **Agent 文件** 与 **Skill 文件** 各管什么；二者都是 **Markdown 规范与指引**，真正的 `tests/test_*.py` 一般在项目目录里 **由后续对话按 Skill 约定生成或补全**，而不是 harness 一次性替你塞满整个测试仓库。

**`.claude/agents/qa.md`（Agent 定义）里常见块**  

| 块 | 作用 |
|----|------|
| 角色与使命 | QA 是谁、对产品/风险负责到哪一层 |
| 工作原则 | 如：先对齐验收再写用例、可疑即报、不替业务擅自改需求 |
| 输入 / 输出协议 | 从上游接过什么（接口列表、构建产物、环境说明）；产出什么（用例表、脚本路径、报告链接） |
| 协作方式 | 如何与 architect/engineer/designer 沟通、何时阻塞发布 |
| 错误与边界 | 缺环境、缺测试数据、flaky 测试时怎么处理 |

**`.claude/skills/.../app-quality/`（或生成时命名的 `*-qa/`）里常见内容**  

| 位置 | 常见内容 |
|------|-----------|
| `SKILL.md` | 本项目的 **测试金字塔约定**、目录布局（如 `tests/`、`conftest`）、**推荐命令**（`pytest -q`、`npm test`）、**报告放哪**（如 `docs/test-reports/` 或 CI 工件）、覆盖率或门禁阈值 |
| `references/` | **示例用例表**、**示例 `pytest` / API 测试片段**、Mock 与夹具注意点、与产品验收条目的 **追溯表**（可选） |

**和「测试脚本、报告」的关系（避免误解）**  
- **Skill** 里可以出现 **示例代码块**，用来教会模型「在本仓库应如何写测例」；**最终成规模的 `test_*.py`** 通常落在 **`tests/`**（或你项目约定路径），在一次次的 **「第四步派工」** 里由智能体写入或迭代。  
- **测试报告** 可能是会话里生成的 **Markdown**（或导出日志），Skill 会规定 **结构**（摘要、通过/失败列表、未覆盖风险）；是否每次都在仓库落盘，取决于你在派工里是否写清路径。  
- 若你希望 **强制** 产出文件，在派工里写明即可，例如：`Write pytest under tests/api/ and a short report under docs/qa-report.md`。

### 第四步（可选）：在生成 harness 后继续派工

**中文说明**：第三步只是在仓库里 **生成**「班组与技能」；要真正写代码或出审查报告，需要 **再发一段指令**，用英文写清 **交付物** 与 **验收条件**（顺序一般是：接口/数据模型 → 后端 → 前端 → 测试，或审查输出路径与格式）。与第二步若用了「示例 1」，第四步就应对着同一业务写实现任务；若用了「示例 2」，第四步就应要求生成 `docs/reviews/` 下报告等。

**与示例 1 配套的派工（全栈实现）**

```text
Use the harness we generated. Implement the leave-request app end-to-end.
Deliverables: (1) OpenAPI or README for auth, requests, approval, HR report APIs;
(2) FastAPI + PostgreSQL migrations; (3) Next.js UI for three roles; (4) pytest
for API plus brief UI smoke notes. Acceptance: manager cannot self-approve;
HR can list all but cannot change others' pending state without role.
```

**中文对照**：用上一步生成的 harness，**从头到尾实现请假应用**。交付物包括：(1) 用 OpenAPI 或 README 写清认证、请假单、审批、人事报表相关接口；(2) FastAPI + PostgreSQL 及迁移；(3) 三角色对应的 Next 界面；(4) API 的 pytest 与简要 UI 冒烟说明。**验收**：主管**不能审批自己的单**；人事可列表查看，但**不能越权**改掉他人「待审批」状态。

**与示例 2 配套的派工（要审查报告）**

```text
Use the harness we generated. Review current branch vs main under src/payments/
and src/auth/ only. Write one Markdown under docs/reviews/ with severity buckets,
file:line references, and retest suggestions; skip refactors outside scope unless
blocking.
```

**中文对照**：用已生成的 harness，**只比较当前分支与 `main`**，范围仅限 `src/payments/` 与 `src/auth/`。在 `docs/reviews/` 下输出 **一篇 Markdown**：按严重程度分桶、给出 **文件:行号**、附复测建议；**除非阻塞性问题**，不要对范围外的代码提大范围重构。

**自拟业务时的骨架（中文：把括号里换成你的目标、验收、不做范围）**

```text
Use the harness we generated. Implement: [one-paragraph product goal]. Order:
OpenAPI/data model → backend → frontend → tests. Acceptance: [bullets].
Non-goals: [out of scope].
```

## harness 构建过程在工具侧大致经历什么

结合一次完整「搭 harness」的体验，工具端逻辑可对应为多阶段（与插件内 SKILL 流程一致，表述可能随版本微调）：

1. **现状审计**：检查 `.claude/agents/`、`.claude/skills/` 是否已有内容，判断是增量还是全新构建  
2. **领域分析**：从描述中抽取数据层、业务层、展示层等，并映射到若干专业角色（如架构/开发/设计/QA）  
3. **团队架构设计**：在 Pipeline、Fan-out/Fan-in 等模式中选择或组合（例如先分析，再并行开发与可视化，最后测试收口）  
4. **Agent 定义生成**：为每个角色写出职责、协作协议、错误处理等  
5. **Skill 生成**：为各角色写可渐进加载的 SKILL，并可含编排器 Skill 统一多阶段与后续扩展  
6. **集成与验证**：Dry-run、触发检查等（以仓库 README 为准）

## 小结与注意点

- **定位**：revfactory/harness 是 **Claude Code 专用** 的团队架构工厂；与 CI/CD 产品 Harness 开源仓库 **同名不同义**。  
- **实践建议**：启动前尽量写清需求与技术约束；生成后通过「再发任务」驱动实际开发或评审。

## 参考链接

- revfactory/harness：<https://github.com/revfactory/harness>  
- Claude Code 文档：<https://code.claude.com/docs/zh-CN/overview>  
- Agent 设计模式（仓库内引用）：<https://github.com/revfactory/harness/blob/main/skills/harness/references/agent-design-patterns.md>
