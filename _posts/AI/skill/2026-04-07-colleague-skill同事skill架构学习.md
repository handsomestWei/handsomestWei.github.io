---
title: colleague-skill同事skill架构学习
date: 2026-04-07 21:00:00
categories: [AI, skill]
tags: [AI, skill]
image:
  path: /assets/img/posts/common/skill.jpg
---

# colleague-skill同事skill架构学习

- **Git 仓库**：<https://github.com/titanwings/colleague-skill>
- **简介**：从飞书、钉钉、Slack、邮件、文件等多源材料中蒸馏同事的 **Work**（工作方式与规范）与 **Persona**（沟通与行为风格），生成 `colleagues/{slug}/` 下可独立调用的子 Skill，并支持列表、回滚与对话纠正等演进流程。

---

## 1. 总体定位

- **类型**：主入口 `SKILL.md` 编排流程，生成物为 `colleagues/{slug}/` 下的可独立调用子 Skill。
- **目标**：把多源原材料蒸馏为可执行的「工作能力 + 人物性格」双层能力，并支持持续进化。

---

## 2. 架构设计要点

### 2.1 入口与元数据（Frontmatter）

`SKILL.md` 使用 YAML 头，典型字段：

- `name`、`description`（中英双语摘要）、`argument-hint`、`version`
- `user-invocable: true`（可被用户主动唤起）
- `allowed-tools`（在 Claude Code 等环境中声明可用工具边界）

### 2.2 编排 vs 实现分离

| 层级 | 职责 |
|------|------|
| **SKILL.md** | 触发条件、分步流程、工具映射表、路径约定、中英文双份指令 |
| **prompts/*.md** | 对话脚本、分析维度、生成模板、merge/纠正逻辑（**不执行**，由 Agent 按路径 `Read` 后遵循） |
| **tools/*.py** | 数据采集、解析、版本管理、列表等**可重复执行的脚本** |
| **docs/PRD.md** | 产品级需求与数据结构约定，与运行时代码并列维护 |

复杂指令拆到 `prompts/`，主 SKILL 侧重「何时读哪份文件、执行哪条命令」，降低单文件体积，便于单独迭代 prompt。

### 2.3 双层内容模型（Work + Persona）

#### 2.3.1 两条内容轨：Work 与 Persona

工程上把「同事」拆成**两条并行流水线**（同一对话内由 Agent 按步骤执行，非多进程）：**专业能力**与**风格行为**分文件、分 prompt 维护，避免混写成单一「人设大杂烩」。

| 轨道 | 产物 | 分析 | 生成 | 侧重 |
|------|------|------|------|------|
| **Work** | `work.md` | `prompts/work_analyzer.md` | `prompts/work_builder.md` | 负责范围、技术栈、流程、文档与输出习惯、CR 关注点等**可执行专业内容**；强调有依据再写，不足则标注原材料不足 |
| **Persona** | `persona.md` | `prompts/persona_analyzer.md` | `prompts/persona_builder.md` | 表达风格、决策习惯、人际互动、雷区等；分析侧常见规则为**手动标签优先于纯文件推断**，冲突以手动为准并可在输出中注明 |

合并调用时，子 Skill 的 `SKILL.md` 常采用 **PART A：Work** + **PART B：Persona** 结构，便于一次加载完整行为。

#### 2.3.2 Persona 内部分层（Layer 0～5 与 Correction）

`persona_builder.md` 将 `persona.md` 固化为层级 Markdown，用于约定**冲突时优先级**与**可执行的描述方式**（避免停留在空洞形容词）：

| 层级 | 含义 |
|------|------|
| **Layer 0** | 核心性格：最高优先级；将标签/文化等译为「在什么情况下怎么做」的具体规则 |
| **Layer 1** | 身份：姓名、职级、MBTI、企业文化如何体现在行为上 |
| **Layer 2** | 表达风格：口头禅、句式、正式程度及典型场景下的原话级示例 |
| **Layer 3** | 决策与判断：优先级、推进/拖延触发、如何说「不」、如何回应质疑 |
| **Layer 4** | 人际行为：对上级/下级/平级及压力下的差异 |
| **Layer 5** | 边界与雷区：不喜欢、会拒绝、回避的话题 |
| **Correction 记录** | 初始可为空；用户纠正「他不会这样」时，由 `correction_handler.md` 流程追加条文，**显式覆盖**笼统描述 |

生成模板中的**行为总原则**要点：日常遵循 Layer 0 为底线，说话对齐 Layer 2、判断对齐 Layer 3、人际对齐 Layer 4；**存在 Correction 记录时优先遵守其中规则**（在不违背 Layer 0 核心约束的前提下）。Work 侧 `work.md` 亦可有对称的 **Correction 记录**；纠正归属由 `correction_handler.md` 判定（工作方法 → Work，沟通与人际 → Persona）。

#### 2.3.3 实现要点（与 2.4 衔接）

- **文件**：`colleagues/{slug}/work.md`、`persona.md` 分存；合并版 `SKILL.md` 供一体引用。  
- **Prompt**：analyzer 规定提取维度与输出形态，builder 规定最终 Markdown 骨架（含 Persona 各 Layer 与 Correction 占位）。  
- **演进**：`merger.md`、`correction_handler.md` 与 `tools/version_manager.py` 等配合版本与增量；`meta.json` 记录版本、标签、纠正次数等便于列表与回滚。

### 2.4 数据与产物目录

- 生成物：`colleagues/{slug}/work.md`、`persona.md`、`meta.json`、合并版 `SKILL.md`、`versions/`、`knowledge/`。
- **meta.json**：记录时间、版本、标签、原材料清单、纠正次数等，支撑列表与回滚。

---

## 3. 是否使用脚本、MCP、多 Agent？

### 3.1 脚本（Python CLI）

**大量使用**。`tools/` 下包括：

- 飞书：自动采集、浏览器登录态抓取、**MCP 客户端封装**、JSON 导出解析
- 钉钉、Slack、邮件解析
- `skill_writer.py`、`version_manager.py`

执行方式：在 SKILL 中写明 `Bash` + `python3 ${CLAUDE_SKILL_DIR}/tools/xxx.py ...`，并约定 `CLAUDE_SKILL_DIR` 环境变量。

**结论**：**是**——以脚本接 API/浏览器/文件解析，Agent 负责调度和解读输出文件。

### 3.2 MCP

**部分使用，需区分两种含义**：

1. **飞书 MCP 方案**：`feishu_mcp_client.py` 封装对 **Feishu MCP Server**（如 `feishu-mcp` npm 包）的调用，用 App Token 读文档/消息；与「Cursor 内置 MCP 列表」不是同一套配置，但概念一致：**标准化工具接口 + Token 鉴权**。
2. **浏览器方案**：Playwright 复用 Chrome 登录态，作为 MCP 的替代路径。

**结论**：**是**——官方/第三方 MCP 与脚本桥接并存，SKILL 内用表格让用户选「浏览器 vs MCP」。

### 3.3 多 Agent

**代码层面没有**多进程多 Agent 框架；**流程层面**是：

- 单 Agent 按 **Step 1→5** 顺序执行；
- **分析阶段**显式分为 **线路 A / 线路 B**（Work 与 Persona），类似「逻辑上的双流水线」，仍由同一对话中的模型完成。

**结论**：**否（无独立多 Agent 运行时）**；**是（有双轨分析与模块化 prompt）**。

---

## 4. 实现技巧摘录

1. **触发条件枚举**：斜杠命令 + 自然语言短语 + 进化模式（追加、纠正）+ 管理命令（list/rollback/delete）。
2. **工具映射表**：一行一类任务，降低模型漏用工具的概率。
3. **灵活性原则**：脚本失败时允许「直接写 Python 调 API」的说明，避免死磕单一入口。
4. **用户确认门闩**：生成摘要 → 用户确认 → 再 `Write` 全套文件。
5. **进化模式**：`merger.md` + `correction_handler.md` + `version_manager.py` 形成闭环。
6. **双语**：首段说明「按用户首条消息语言全程一致」，下面中英各一份完整流程（篇幅长但自包含）。