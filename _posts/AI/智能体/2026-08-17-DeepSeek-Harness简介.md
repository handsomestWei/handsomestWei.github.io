---
title: DeepSeek Harness简介
date: 2026-08-17 09:15:00
categories: [AI, 智能体]
tags: [AI, 智能体, DeepSeek, Harness]
image:
  path: /assets/img/posts/common/ai-agent.jpg
---

# DeepSeek Harness简介

> DeepSeek 开源的 **agent harness**（智能体运行框架）`dsh` 以「一切皆插件」为口号，把模型、工具、技能、会话、沙箱、循环和 UI 都做成可替换组件。本文说明它是什么、如何安装、官网与文档入口，以及 **Harness 插件** 与 **Skill、MCP、各家 IDE/Agent 产品插件** 的层次差异。项目处于 **开发者预览**，接口可能不兼容升级；安装命令与端口以仓库 README 为准。

**参考与延伸阅读**：

- 产品页（中文）：<https://deepseek.com/harness>
- 产品页（英文）：<https://deepseek.com/harness/en/>
- GitHub 仓库：<https://github.com/deepseek-ai/deepseek-harness>
- 开发者文档：<https://deepseek-harness.github.io/deepseek-harness/>
- npm 启动器：<https://www.npmjs.com/package/@deepseek-ai/dsh>

---

## 目录

- [一、定位与架构](#一定位与架构)
- [二、安装与首次使用](#二安装与首次使用)
- [三、官网与使用文档](#三官网与使用文档)
- [四、插件机制](#四插件机制)
- [五、插件开发流程与脚手架](#五插件开发流程与脚手架)
- [六、与 Skill、MCP、各家产品插件的区别](#六与-skillmcp各家产品插件的区别)
- [七、小结](#七小结)

---

## 一、定位与架构

**DeepSeek Harness**（命令行名 **`dsh`**）是 DeepSeek AI 开源的 **agent harness**：模型负责推理，Harness 负责让智能体理解环境、调用工具、在真实工作区里持续干活。官方公式是 **Agent = Model + Harness**。许可证为 **MIT**。

它不是新的基座模型权重，也不是「再做一个只能对话的网页」。定位更接近 **可组装的编码智能体运行时**：本地 Web UI、权限审批、会话轨迹、多模式预设。内核用 **[Cordis](https://github.com/cordiverse/cordis)** 管插件的加载、卸载和依赖；具体能力都在插件里。

```text
模型（灵魂）
    +
Harness（环境、工具、循环、沙箱、UI）
    =
可在仓库里读改文件、跑命令、规划与委派的 Agent
```

官方强调两件事：

| 设计点 | 含义 |
|--------|------|
| **一切皆插件** | 模型适配、工具、Skills、会话、沙箱、存储、Agent 循环、调度、UI 均可替换或重组，不必改 Harness 源码 |
| **运行有迹可循** | 系统提示、思维链、工具调用与结果、子 Agent 调度、上下文注入写入仅追加会话日志；可按来源查看，并做恢复、分叉、检索、回放 |

出厂常见运行模式（名称以当前 UI / 文档为准，中英文站用词可能略有差异）：

| 模式 | 作用 |
|------|------|
| **标准（Standard）** | 完整编码 Agent：文件编辑、Shell、检索、Skills、计划、目标、子代理、工作流 |
| **Code / PTC** | 标准能力之上，用 Code Mode SDK 让模型用一段 TypeScript 编排多步工具调用 |
| **极简（Minimal）** | 主要保留持久 bash 与文件编辑，便于做「最小工具集」基准 |
| **创造（Creator）** | 标准能力 + 运行时检查、内存中试验插件、编写自定义 preset |

社区讨论常把它和 DeepSeek V4 等模型一起提，但 **Harness 与模型是两层**：换模型适配插件即可接其他提供方或 OpenAI 兼容端点，不必绑定单一权重。

---

## 二、安装与首次使用

官方推荐两条路径：**npx 快速启动** 与 **源码构建**。当前预览阶段对 Node 版本较严，仓库 `engines` 常见要求为 **Node.js `^22.19.0` 或 `>=24`**；过旧的 Node 即使用得了 `npx`，也可能装不上 `@deepseek-ai/dsh`。

### 2.1 快速启动（npm）

```bash
# 先确认 Node 版本
node --version

npx @deepseek-ai/dsh web
```

默认 Web UI：`http://127.0.0.1:3080`。端口占用时可按 CLI 帮助换端口（社区示例常见 `--port 3081`）。终端需保持运行。

**升级**：CLI **没有** `dsh update` / `upgrade` / `self-update`（`dsh --help` 可核对）。`npx` 会缓存包，再次执行同一条命令不一定拉到新版。要跟 npm 最新 rc：

```bash
# 看当前启动器版本（-V 须写在子命令之前）
npx @deepseek-ai/dsh -V

# 强制用 registry 上的 latest 再启 Web UI
npx @deepseek-ai/dsh@latest web
```

若已 **全局安装**：

```bash
npm install -g @deepseek-ai/dsh@latest
dsh -V
dsh web
```

内置 bundle（如 `@deepseek-ai/dsh-base`、`dsh-web-app`）跟**当前这次安装的 dsh** 走，升启动器即升这些包。已经 `dsh plugin add` 进 profile 的**树外插件**要另升，例如：

```bash
dsh plugin --profile web update
```

（`dsh plugin` 把后续参数转给该 profile 目录里的 pnpm，`update` 与 pnpm 语义相同。）升级后停掉旧进程再启动；预览版可能不兼容，升完用 `-V` 和一次冒烟任务确认。

### 2.2 从源码运行

```bash
git clone https://github.com/deepseek-ai/deepseek-harness.git
cd deepseek-harness
pnpm install
pnpm run build
pnpm dsh web
```

依赖管理以仓库说明为准（官方源码路径用 **pnpm**）。跟上游时：

```bash
git pull
pnpm install
pnpm run build
pnpm dsh web
```

源码启动器**不检查**前端产物是否过期，只 `git pull` 不 `build` 可能仍跑旧的浏览器包。

### 2.3 打开 UI 之后

按仓库 [Web UI 指南](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/index.zh.md)：

1. **设置 → 模型**：填入 DeepSeek API Key 并保存（一般不必重启服务）。其他提供方与自定义兼容端点见同目录 `providers.md`。
2. **选择工作区**：指定项目目录。未选工作区时，会话输入框不可用。
3. 发一条有界任务做冒烟，例如：`Summarize this repository and identify its main packages.`
4. 写文件、跑 Shell 等操作会按当前**权限策略**弹出审批，先看再放行。

密钥走本地凭据存储，界面侧通常只展示脱敏描述。官方还提供 **Python SDK** 与无界面 CLI / headless 模式，见用户指南「继续使用」一节，本文不展开。

**注意**：预览版会破坏兼容性；社区里也有名称相近、但**未加 `@deepseek-ai` 作用域**的 npm 包，安装时认准 **`@deepseek-ai/dsh`**。

---

## 三、官网与使用文档

| 类型 | 链接 | 说明 |
|------|------|------|
| 产品页 | https://deepseek.com/harness | 中文介绍、一键命令、模式说明 |
| 产品页（EN） | https://deepseek.com/harness/en/ | 与中文站对应 |
| 源码 | https://github.com/deepseek-ai/deepseek-harness | README、架构、贡献指南 |
| 中文 README | https://github.com/deepseek-ai/deepseek-harness/blob/master/README.zh.md | 安装命令与预览声明 |
| 开发者文档 | https://deepseek-harness.github.io/deepseek-harness/ | 用户指南、插件教程、配置/工具目录 |
| 英文文档根 | https://deepseek-harness.github.io/deepseek-harness/en/ | 路径多一个 `/en/` |
| Web UI 指南 | https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/index.zh.md | 配模型、选工作区、跑任务 |
| 第一个插件 | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/ | `apply(ctx)` 最小插件 |
| 做成可安装包 | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/publish | bundle / profile、`dsh plugin add` |
| 编写工具 | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/tool | `defineTool` 示例 |
| Cordis 教程 | https://deepseek-harness.github.io/deepseek-harness/en/develop/cordis-tutorial/ | 内核练习，可不配 API Key |
| Cordis | https://github.com/cordiverse/cordis | 插件内核 |
| 讨论区 | https://github.com/deepseek-ai/deepseek-harness/discussions | 反馈与缺陷 |
| 插件发现 | https://github.com/topics/dsh-plugin | 官方指定的社区插件 Topic（非审核市场） |

文档站与 CLI 子命令仍在快迭代，**以 GitHub 当日 README 和 docs 为准**。

---

## 四、插件机制

在 DeepSeek Harness 里，**插件是 TypeScript 模块**：导出 `apply(ctx)`（也可对象 / 类形式），在加载时拿到 Cordis 的 **`Context`**，通过 `ctx` 注册能力。框架在所需服务就绪后才调用 `apply`；卸载时经 `ctx` 注册的监听器、工具、定时器会一并清掉。

```ts
import type { Context } from '@deepseek-ai/cordis'

export const name = 'hello-plugin'
export const inject = ['tools']

export function apply(ctx: Context) {
  ctx.tools.register(/* 工具定义 */)
}
```

本地试验可用 overlay：`pnpm dsh web --patch ./scratch-plugin/cordis.yml`，在 `cordis.yml` 里 `insert` 插件绝对路径。对外分发时，包可声明 `cordis.patch.yml`，再用 `dsh plugin --profile <name> add <包或 Git 路径>` 装到某个 **profile**（如 `web`）。社区插件仓库建议打上 `dsh-plugin` topic。

插件能挂的不只是「多一个工具」，而是整层运行时，例如：

| 能力 | 常见挂载点 |
|------|------------|
| 内置工具 | `ctx.tools.register()`（bash、fs、web、subagent 等） |
| 模型适配 | 注册 LLM adapter / provider |
| Skills | 技能注册表 + 面向模型的 `skill` 工具，调用时注入正文 |
| MCP | 每个 MCP 服务器对应一个 `@deepseek-ai/dsh-mcp-client` 插件实例，发现工具后再 `register` |
| 循环 / 钩子 | 监听 `agent/pre-step`、`tools/pre-execute` 等 |
| UI、存储、沙箱 | 同样以插件形式组合进 profile |

因此：**「dsh 插件」= 运行时组合单元**，不是给模型看的一篇 Markdown 说明书。从最小模块到可安装包的步骤见下一章。

---

## 五、插件开发流程与脚手架

官方把插件开发拆成一条递进教程：**先在源码仓库里用 `--patch` 冒烟，再打成 bundle 装进 profile**。截至本文撰写时（2026-08），**没有**官方的 `pnpm create dsh-plugin` / 官方模板仓库；社区有 RFC 在催，日常仍是对照文档手写，或抄官方示例包。

### 5.1 官方教程路径

```text
克隆 deepseek-harness 并 pnpm install && pnpm run build
  → 写 apply(ctx) 插件（可选 inject、Config schema）
  → cordis.yml + pnpm dsh web --patch … 在 Web UI 里验证
  → 需要给模型用的能力：defineTool 注册到 ctx.tools
  → 打成 npm 包：package.json 声明 dsh.bundle + cordis.patch.yml
  → dsh plugin --profile <名> add ./本地包 或 github:user/repo
  → 仓库打上 dsh-plugin topic，便于发现
```

**本地 overlay**

前提是已经按 README **从源码跑起来**（教程假设在仓库根目录操作）。新建目录、写 TypeScript 模块、再写一份 patch：

```yaml
# scratch-plugin/cordis.yml（插件 path 须为绝对路径）
- insert:
    - id: hello
      name: '/absolute/path/to/deepseek-harness/scratch-plugin/src/my-plugin.ts'
```

```bash
pnpm dsh web --patch ./scratch-plugin/cordis.yml
```

终端里能看到 `apply` 里的日志，即加载成功。依赖 `tools` / `llm` 等服务时导出 `inject`，Cordis 会等服务就绪再加载。改配置会热替换插件：旧实例卸载，经 `ctx` 注册的工具和监听会清掉。

**注册模型可调用的工具**

用 `@deepseek-ai/dsh-tools` 的 `defineTool`，在 `apply` 里 `ctx.tools.register(...)`。官方 [Build a tool](https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/tool) 用 `greet` 走通：重启带 `--patch` 的 Web UI，让模型调用该工具即可。更细的 schema、后台执行、UI 卡片见工具编写参考。

**打包为可安装 bundle**

`--patch` 只适合本机调试。要给别人装，需要一个 **bundle**（你发布的 npm 包）和一个 **profile**（用户机器上「装了哪些 bundle、按什么顺序组合」）。

| 概念 | 含义 | 清单关键字段 |
|------|------------|--------------|
| **bundle** | 可分发的配置层（npm 包） | `package.json` 里 `dsh.bundle.patch` 指向 `cordis.patch.yml` |
| **profile** | 本机一次启动所组合的 bundle 列表 | `$DSH_HOME/profiles/<名>/`；由 `dsh plugin` 维护 |

最小包结构（官方 publish 教程）：

```text
hello-plugin/
├── package.json        # name、type: module、dsh.bundle.patch
├── cordis.patch.yml    # insert 一行，name 用包名而非本地绝对路径
└── index.js            # 或构建后的 lib/
```

```json
{
  "name": "dsh-hello-plugin",
  "version": "0.1.0",
  "type": "module",
  "main": "index.js",
  "files": ["index.js", "cordis.patch.yml"],
  "dsh": { "bundle": { "patch": "./cordis.patch.yml" } }
}
```

没有 `dsh.bundle` 的包也能被 pnpm 装上，但 **不会激活配置层**（`dsh plugin` 会警告）。那种形态适合「给别的插件 import 的库」，不是用户要启用的插件。

安装与卸载：

```bash
dsh plugin --profile demo add ./hello-plugin
dsh --profile demo --dump-config    # 不启动，先看层是否出现
dsh --profile demo
dsh plugin --profile demo remove dsh-hello-plugin
```

`dsh plugin --profile …` 实际是在该 profile 目录里转发给 **pnpm**。首次 `add` 会初始化 profile，并默认带上 `@deepseek-ai/dsh-base`。

加载顺序（后者覆盖前者；同一 `id` 的 `config` **整段替换、不做深合并**）：

1. profile 里 `dsh.profile.bundles` 列出的各 bundle patch（`dsh-base` 通常最先）
2. 该 profile 自己的 `cordis.patch.yml`
3. 机器级 `$DSH_HOME/cordis.patch.yml`
4. 命令行 `--patch`（按参数顺序）

从 GitHub 安装时，pnpm 拿到的是源码不是构建产物。作者需提供自包含的 **`prepare` 构建脚本**；pnpm 10+ 还要求用户在 profile 的 `pnpm-workspace.yaml` 里 `allowBuilds` 放行。官方把 [turtle-ui](https://github.com/deepseek-harness/turtle-ui) 当作 `prepare` + tsdown 的可运行样例。不想让用户放行构建，就发 npm（带打好的 `lib/`）或 `pnpm pack` 的 tarball。Git 安装建议钉 commit：`github:you/hello-plugin#<sha>`。

### 5.2 脚手架与官方模板

| 项目 | 现状（以文档与讨论为准，预览期会变） |
|------|----------------------------------------|
| `pnpm create dsh-plugin` / 官方模板仓 | **尚未作为官方交付**。仓库 [Discussion #1629](https://github.com/deepseek-ai/deepseek-harness/discussions/1629) 在征集「模板仓 + create CLI + 检查清单」 |
| 官方替代做法 | 按 [Your first plugin](https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/) 手写；打包按 [Package and install](https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/publish/)；TypeScript 从 Git 安装可对照 **turtle-ui** |
| 仓库内 `adding-a-package` | 面向 **monorepo 第一方** `@deepseek-ai/dsh-*` 包的文件清单（`packages/<group>/<pkg>/`、改根 tsconfig），**不是**社区插件生成器 |
| 社区脚手架 | 存在第三方 `create-dsh-plugin` / 模板仓讨论，**不是** DeepSeek 官方；版本需自行对齐当前 `@deepseek-ai/dsh` 的 rc 列车 |

向官方仓库贡献第一方包时，走 cookbook「adding a workspace package」和 `CONTRIBUTING.md`；对外发布社区插件时，走 bundle + `dsh plugin add` + GitHub topic `dsh-plugin`。

### 5.3 插件发现入口

官方**没有**独立的插件市场（无审核上架、无应用商店式目录）。产品页「社区插件」与 README「Community and support」指向同一发现机制：GitHub Topic。

| 入口 | 链接 | 说明 |
|------|------|------|
| **官方发现 Topic** | https://github.com/topics/dsh-plugin | README 要求插件仓库打上该 topic，便于检索 |
| 官网「社区插件」 | https://deepseek.com/harness | 产品页按钮，与 Topic 同一生态入口 |
| 第一方示例仓 | https://github.com/deepseek-harness/turtle-ui | `deepseek-harness` 组织下的 TUI 示例，非市场首页 |
| npm 作用域 | `@deepseek-ai/dsh` 及 `@deepseek-ai/dsh-*` | 启动器与内置 bundle，不是第三方插件商店 |
| 第三方目录（非官方） | 如社区爬 Topic 做成的静态站 | 未替代官方 Topic；安装前仍需核源码与许可 |

Topic 无官方审核，标签可被无关仓库占用。安装社区插件等于在本机执行其源码（尤其 Git + `prepare`），应阅读仓库、钉 commit，并在隔离环境试用。

```bash
# 按作者 README 提供的 Git 规格安装，示例：
dsh plugin --profile web add github:owner/repo
```

### 5.4 开发文档

| 文档 | 链接 | 用途 |
|------|------|------|
| Your first plugin | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/ | 最小插件 + `--patch` |
| Plugin configuration | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/config | `Config` + Schemastery |
| Build a tool | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/tool | `defineTool` |
| Package and install | https://deepseek-harness.github.io/deepseek-harness/en/develop/basic/publish | bundle / profile / Git `prepare` |
| Cordis tutorial | https://deepseek-harness.github.io/deepseek-harness/en/develop/cordis-tutorial/ | 内核、生命周期、HMR |
| Tool authoring | https://deepseek-harness.github.io/deepseek-harness/en/reference/cookbook/adding-a-tool | 工具契约细节 |
| Extension cookbook | https://deepseek-harness.github.io/deepseek-harness/en/reference/cookbook/extension-cookbook | 工具 / MCP / Skill / 钩子形态 |
| Adding a workspace package | https://deepseek-harness.github.io/deepseek-harness/en/reference/cookbook/adding-a-package | 第一方 monorepo 包 |
| turtle-ui（示例而非脚手架） | https://github.com/deepseek-harness/turtle-ui | 社区/官方示例包的 `prepare` 写法 |
| 脚手架 RFC | https://github.com/deepseek-ai/deepseek-harness/discussions/1629 | 官方模板仓与 create CLI 提案 |

中文文档站同一路径去掉 `/en/` 即可（例如 [做成可安装包](https://deepseek-harness.github.io/deepseek-harness/develop/basic/publish)）。预览期页面结构可能调整，以文档站导航为准。

---

## 六、与 Skill、MCP、各家产品插件的区别

四者经常被放在一起聊，解决的问题不在同一层。日常说的「插件」至少要拆成两类：**编辑器/IDE 扩展**，以及 **Agent 运行时扩展**。前者改的是写代码的壳，后者改的是智能体怎么跑。

```text
IDE / 编辑器扩展      → 改宿主产品（高亮、主题、侧栏、语言服务、厂商自有 Agent 面板）
Skill（SKILL.md）     → 给模型看的流程/规范（指令包，跨产品可复用程度较高）
MCP 服务器            → 用开放协议对外提供工具/数据（多宿主可当客户端）
Harness / Cordis 插件 → 组装「Agent 怎么跑」（循环、审批、会话、UI、把 MCP/Skill 接进来）
```

常见宿主并不只有某一家：VS Code 及其衍生 IDE、JetBrains 系、Claude Code / Codex 一类 CLI Agent、以及各类「AI 编程助手」桌面或 Web 产品，都可能同时提供「扩展市场 + MCP + Skill」中的若干层。名字都叫插件，挂载点和权限边界并不相同。

### 6.1 对照表

| 维度 | DeepSeek Harness 插件 | Skill | MCP | 各家 IDE / Agent 产品插件 |
|------|----------------------|-------|-----|---------------------------|
| **本质** | Cordis 上的可加载 **运行时代码** | 多为 `SKILL.md` 的 **指令与清单** | **工具/资源协议**（stdio 或 HTTP） | 厂商扩展 API 上的 **宿主附加组件** |
| **给谁用** | Harness 内核：挂载服务、改循环 | 模型：按任务读完整说明书 | 任意 MCP 客户端：发现并调用工具 | 人 + 该产品：改编辑体验或产品内 Agent 面板 |
| **典型产物** | `apply(ctx)`、`cordis.yml` / patch | `name` + `description` + 步骤 | `tools/list`、`tools/call` | 扩展清单、`contributes`、厂商插件包 |
| **能否替换 Agent 循环** | 可以（循环本身也是插件） | 不能 | 不能 | 一般不能（内核仍属该产品） |
| **可移植性** | 主要在 dsh / Cordis 生态内 | 目录约定接近时，多宿主可复用 | 协议开放，换客户端仍可接同一服务器 | 绑定具体产品或编辑器内核 |
| **卸载行为** | 可逆：工具、监听、连接随插件卸掉 | 从技能目录/注册表消失 | 断开该服务器，工具从列表移除 | 禁用扩展，该产品里对应功能消失 |

### 6.2 Skill：说明书，不是运行时

Skill 告诉模型「这类任务按哪份清单做」：发现阶段往往只暴露名称与短描述，真正干活前再加载全文（渐进披露）。DeepSeek Harness **内置 Skills 能力**，格式上与业界 Agent Skills / Claude Code 一类 Markdown 约定接近，不少 Skill 目录可复用。在 dsh 里，文件系统技能提供方、注册表、面向模型的 `skill` 工具，**仍然是由插件提供的**。写一份 `SKILL.md` 不会让 Harness 多出新的沙箱或新的 Agent 循环。

### 6.3 MCP：外接工具总线，Harness 当客户端

[MCP（Model Context Protocol）](https://modelcontextprotocol.io/) 统一「怎么连外部工具和数据」。DeepSeek Harness 通过 **`@deepseek-ai/dsh-mcp-client`** 做客户端：每个服务器一条插件配置，发现到的工具再登记进 `ctx.tools`。stdio 服务可随插件生命周期起停；HTTP 类服务需事先可达。CLI 文档写明：默认**不**随便启用 MCP 服务器，因为每条启动命令都是沙箱外的受信任可执行代码。

关系可以记成：

| 层 | 负责 |
|----|------|
| MCP | 工具连接方式与 schema |
| Harness 插件 | 调用时机、审批、失败重试、会话写入、停止条件 |

MCP 服务器可以成为 dsh 的工具来源；**不能替代** Cordis 插件去组合模型、循环和 UI。同一套 MCP 也可以被 VS Code、JetBrains 插件、Claude Code、Codex 或其他 Agent 客户端使用——换的是**谁来当客户端**，不是协议本身。

### 6.4 各家产品插件：改的是宿主，不是 dsh 运行时

市场上叫「插件 / 扩展 / Extension」的东西，多数挂在**某一款产品**上，而不是挂在开放的 Agent 循环上。常见几类：

| 类型 | 例子（示意，非清单） | 实际改的是什么 |
|------|----------------------|----------------|
| 编辑器扩展 | VS Code 及其衍生 IDE 的扩展市场、JetBrains Plugin | 主题、语言服务、调试、侧栏、Git 视图 |
| 产品内 Agent 扩展 | 各 AI IDE、CLI Agent 自有的插件或 Hook | 该产品允许的面板、命令、有限工具入口 |
| 误叫成「插件」的 MCP / Skill | 各宿主里的 MCP 配置、`SKILL.md` 目录 | 仍是协议或指令包，只是安装入口在该产品里 |

它们和 dsh 插件的差别在于 **宿主边界**：

- **闭源或一体化产品**：对话、补全、Agent 循环通常绑在厂商内核里。你能装扩展、接 MCP、放 Skill，一般**不能**把循环、沙箱、会话存储、UI 整段换成自己的 Cordis 插件。
- **DeepSeek Harness**：开源运行时，**连循环和 UI 都按插件组装**；MCP 与 Skill 是其中两类可挂能力，而不是唯一扩展方式。

因此：在某家 IDE 里选用 DeepSeek 模型写代码，用的仍是**那家产品的宿主**。要体验「一切皆插件」的组装方式，需要单独跑 `dsh`，而不是只在编辑器市场里搜一个扩展。

不同产品对扩展的开放程度差很多：有的几乎只能改 UI，有的把 MCP/Skill 做得很完整，极少数会把 Agent 循环也做成可替换模块。选型时看的是**能替换到哪一层**，不要被「插件」三个字对齐。

### 6.5 选型依据

| 需求 | 更合适的层 |
|------------|------------|
| 固定团队编码规范、评审清单 | Skill（可随目录在多宿主间复用） |
| 接公司内部 API、数据库、浏览器 | MCP（由当前 IDE / CLI / dsh 当客户端） |
| 改当前编辑器的 UI、语言支持、调试体验 | 该编辑器的扩展 / 插件市场 |
| 换模型适配、改审批策略、自定义 Agent 循环或 Web UI | DeepSeek Harness 插件 |

---

## 七、小结

| 要点 | 结论 |
|------|------|
| 定位 | 开源 agent harness（`dsh`），不是新模型；Agent = 模型 + 运行时 |
| 架构 | Cordis「一切皆插件」；会话轨迹可回放 |
| 安装 | `npx @deepseek-ai/dsh web`，默认 `127.0.0.1:3080`；源码用 pnpm 构建 |
| 插件 | TypeScript `apply(ctx)`，组装工具/模型/循环/UI |
| 插件开发 | `--patch` 验证 → `dsh.bundle` 打包 → `dsh plugin add`；官方暂无 create 脚手架 |
| 插件发现 | 官方无独立市场；发现入口为 GitHub Topic [`dsh-plugin`](https://github.com/topics/dsh-plugin) |
| 与 Skill | Skill 是给模型的说明书；在 dsh 里由技能类插件加载 |
| 与 MCP | MCP 是外接工具协议；dsh 用 mcp-client 插件接入 |
| 与各家产品插件 | 编辑器扩展改宿主 UI；各产品内的 MCP/Skill 仍挂在该产品 Agent 上；dsh 插件改的是开源 Harness 本身 |
| 现状 | 开发者预览，以官方 README 与文档站为准 |

核心插件与 API 仍会变。试用时认准官方仓库与 `@deepseek-ai/dsh`，把密钥与工作区权限当作本地开发环境来管理。
