---
title: Superpowers 技能使用简介
date: 2026-05-02 23:00:00
categories: [AI, AI编程]
tags: [AI, AI编程, Superpowers, Agent, Skills]
image:
  path: /assets/img/posts/common/AI.jpg
---

# Superpowers 技能使用简介

本文介绍开源项目 **[obra/superpowers](https://github.com/obra/superpowers)**：面向「编程智能体」的 **可组合 Skills（技能）库** 与配套 **工作流程**。内容结合仓库中的目录与 `SKILL.md` 写法整理，便于在 Cursor、Claude Code、Codex 等环境中理解「装上之后智能体为何会换一套行事方式」。

---

## 〇、技能（Superpowers）是什么

Superpowers **不是某个单一模型**，而是一套挂载在宿主（插件 / Harness）里的 **行为规范与流程模板**：

- 每个主题对应 `skills/<技能名>/` 目录，核心入口为 **`SKILL.md`**（带 YAML front matter：`name`、`description`，供宿主做触发与检索）。
- 官方强调：**执行任务前会先检查是否有适用技能；若适用则应加载并遵照执行**（强制性流程而非泛泛建议）。
- **`using-superpowers`** 充当「元技能」，约定 **何时必须用 Skill 工具**、与用户指令优先级、以及各宿主上如何挂载技能。
- Cursor 场景下，`/.cursor-plugin/plugin.json` 声明 `skills`、`agents`、`commands`、`hooks` 的根路径，`sessionStart` 钩子会拉起引导逻辑，保证会话一开始进入「会按 Superpowers 规则找技能」的状态。

一句话：**Skills = 把 TDD、调试、结对设计、拆解计划、代码评审等实践，落成智能体可读、可复用的操作规程。**

---

## 一、作用与适用场景

| 维度 | 说明 |
|------|------|
| **你要解决什么** | 减少「一上来就写码」的冲动；在长任务里对齐 **澄清需求 → 设计 → 拆解 → 实现 → 验证 → 收尾** 的顺序。 |
| **适合谁** | 已在使用 **Cursor Agent**、**Claude Code**、**Codex** 等、希望 **流程稳定、可复盘** 的开发者或小团队。 |
| **不太适合** | 只想问一两个语法问题、不需要过程约束的短对话；或坚持使用完全自定义提示、不想被技能抢占流程时（可通过项目内 `AGENTS.md` / 各宿主的用户规则做覆盖，见 `using-superpowers` 中的优先级说明）。 |
| **典型收益** | 设计文档与实现计划有**默认落盘位置**（如 `docs/superpowers/specs/`、`docs/superpowers/plans/`）；**TDD、评审、分支收尾** 有清单可依；多子任务时可用 **子智能体驱动开发** 等模式控节奏。 |

---

## 二、仓库组成：目录、文件与作用

下表按**角色**归纳。

### 2.1 插件入口与宿主配置

| 路径 | 作用 |
|------|------|
| `.cursor-plugin/plugin.json` | Cursor 插件清单：名称、版本、`skills` / `agents` / `commands` 根路径、Cursor 用 `hooks/hooks-cursor.json`。 |
| `.claude-plugin/` | Claude Code 等平台的插件打包元数据（与 Cursor 目录并列，多宿主发布）。 |
| `.codex-plugin/` | OpenAI Codex 侧插件相关配置。 |
| `gemini-extension.json` | Gemini CLI 扩展声明。 |
| `package.json` | 仓库级 Node 元数据（若涉及前端测试子项目等）。 |

### 2.2 钩子与会话启动

| 路径 | 作用 |
|------|------|
| `hooks/hooks-cursor.json` | 声明 Cursor 的 `sessionStart` 钩子，指向 `./hooks/session-start`。 |
| `hooks/hooks.json` | 其他宿主共用的钩子配置入口。 |
| `hooks/session-start` | **会话开始**时执行的脚本：负责引导/bootstrap，使智能体加载 `using-superpowers` 所描述的「必须先考虑技能」行为（官方将「未正确挂载 bootstrap」视为未集成）。 |
| `hooks/run-hook.cmd` | Windows 等平台下调度钩子的辅助脚本（与多端 hook 兼容有关）。 |

### 2.3 命令、智能体与技能本体

| 路径 | 作用 |
|------|------|
| `commands/brainstorm.md` | 旧版命令说明；仓库内标明 **Deprecated**，建议使用 **`brainstorming` 技能** 替代。 |
| `commands/write-plan.md` | 同上，_deprecated_，导向 **`writing-plans`**。 |
| `commands/execute-plan.md` | 同上，_deprecated_，导向 **`executing-plans`** 等流程。 |
| `agents/code-reviewer.md` | 代码评审向的 **Agent 人设/说明**，供宿主在委派子 Agent 时使用。 |

### 2.4 技能库 `skills/*/SKILL.md`（核心）

每项为独立目录，`SKILL.md` 为正文；部分技能还带 `references/`、`*.md` 补充材料（例如 TDD 反模式）。以下为当前仓库中出现的技能路径与简述：

| 路径 | 作用（摘要） |
|------|----------------|
| `skills/using-superpowers/SKILL.md` | 元技能：**何时必须调用 Skill**、与用户指令优先级、多平台工具名对照说明。 |
| `skills/brainstorming/SKILL.md` | **动工前**：澄清意图、对比方案、分段呈现设计、落盘设计文档；含 **HARD-GATE**：未获用户认可设计前不得实现。 |
| `skills/writing-plans/SKILL.md` | **有规格后**：写可执行的实现计划（小步任务、文件边界、测试方式）；默认保存到 `docs/superpowers/plans/`。 |
| `skills/executing-plans/SKILL.md` | **按计划批量执行**，带人类检查点。 |
| `skills/subagent-driven-development/SKILL.md` | **子智能体驱动开发**：按任务派发子 Agent，含两阶段审查（对齐规格、代码质量）。 |
| `skills/dispatching-parallel-agents/SKILL.md` | **并行子智能体**工作流编排。 |
| `skills/using-git-worktrees/SKILL.md` | 设计批准后 **Git worktree / 分支隔离**、基线环境与干净测试校验。 |
| `skills/test-driven-development/SKILL.md` | **红—绿—重构**、先测后实现等行为约束。 |
| `skills/systematic-debugging/SKILL.md` | **系统化调试**（根因分层、佐证再下结论）。 |
| `skills/verification-before-completion/SKILL.md` | 宣称「修好」之前的 **核验** 清单。 |
| `skills/requesting-code-review/SKILL.md` | 发起评审：对照计划分严重度列出问题；严重问题阻断推进。 |
| `skills/receiving-code-review/SKILL.md` | 接收评审反馈后的处理节奏。 |
| `skills/finishing-a-development-branch/SKILL.md` | 收尾：验证测试、Merge/PR/保留/丢弃等选项与 worktree 清理。 |
| `skills/writing-skills/SKILL.md` | **编写新技能** 的规范与自检（面向维护者）。 |
| `skills/test-driven-development/testing-anti-patterns.md` | TDD 技能附属材料：**测试反模式** 参照。 |

### 2.5 文档、脚本与测试（维护与扩展）

| 路径 | 作用 |
|------|------|
| `README.md` | 项目总览、**标准工作流七步**、安装方式（含 Cursor `/add-plugin superpowers`）、哲学与社区链接。 |
| `docs/README.opencode.md`、`docs/README.codex.md` 等 | 各宿主专用说明。 |
| `docs/testing.md` | 测试相关说明。 |
| `docs/superpowers/specs/`、`docs/superpowers/plans/` | 设计/计划样例与历史文档（技能里约定的默认落盘区也会指向类似路径）。 |
| `scripts/bump-version.sh`、`scripts/sync-to-codex-plugin.sh` | 发版、同步 Codex 插件等维护脚本。 |
| `tests/` | 技能触发、子 Agent 开发、OpenCode、brainstorm-server 等 **集成/回归脚本与样例工程**（如 `tests/skill-triggering/`、`tests/subagent-driven-dev/`）。 |
| `CLAUDE.md` | 面向**向本仓库贡献**的代理/人类说明（PR 规范、不接受项等）；**日常使用者**以 `README` 与各宿主安装为准。 |
| `AGENTS.md` | 部分宿主会从工程根读取的 Agent 说明；官方仓库根该文件可为空或由你在业务仓库中自建内容。 |
| `GEMINI.md` | Gemini 侧加载与工具映射说明。 |

---

## 三、具体场景：技能如何串起来

### 3.1 场景 A：从一句话需求到可合并分支（功能开发）

**例子**：用户对 Agent 说：「我们做一个小型待办列表（React），支持新增、勾选完成。」

在未挂载 Superpowers 时，模型容易直接建项目、写组件；挂载后，`brainstorming` 会优先介入：**先对齐成功标准与技术取舍，再写入设计文档**，然后才进入拆任务与编码。

```
用户提出功能想法
       │
       ▼
brainstorming ─────────────────────────► 澄清 / 方案对比 / 分段设计 / 写入 docs/superpowers/specs/…
       │
       │（用户认可设计）
       ▼
using-git-worktrees（可选） ─────────────► 新建 worktree · 分支 · 验证基线测试绿
       │
       ▼
writing-plans ───────────────────────────► 输出 docs/superpowers/plans/…（原子任务 · 路径 · 如何测）
       │
       ▼
subagent-driven-development 或 executing-plans
       │
       ├──► test-driven-development（测试先行 · 红绿重构）
       ├──► requesting-code-review（按计划评审 · 重大问题阻断）
       └──► systematic-debugging / verification-before-completion（遇 Bug 或收尾前核验）
       │
       ▼
finishing-a-development-branch ─────────► PR / Merge / 清理 worktree
```

**技能发挥的实质作用**：在「需求讨论 / 设计 / 开发 / 评审 / 收尾」各段插入 **门禁**（例如未批准设计不写代码、未完成验证不宣称完成），减少返工。

### 3.2 场景 B：线上问题 / 缺陷排查（不修功能规格）

```
现象报告（报错、 flaky、回归）
       │
       ▼
systematic-debugging ───────► 复现 ► 假设 ► 最小实验 ► 根因分层
       │
       ▼
（若需改代码）
       │
       ├──► test-driven-development（先加失败用例再起修复）
       └──► verification-before-completion（修复是否真的消除问题）
```

此路径强调 **证据优先**，与「抢着改一行试试」相反；与仓库自述中的 **Evidence over claims** 一致。

### 3.3 场景 C：显式并行（多人格 / 多子 Agent）

若任务可纵向切分且无强顺序依赖，`dispatching-parallel-agents` 适合在 **已定计划** 的前提下，并行委派子 Agent，再在汇总点做集成与评审（仍常与 `executing-plans`、`requesting-code-review` 搭配）。

---
