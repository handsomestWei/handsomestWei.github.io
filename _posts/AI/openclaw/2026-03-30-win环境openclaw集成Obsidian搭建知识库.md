---
title: win环境openclaw集成Obsidian搭建知识库
date: 2026-03-30 10:50:00
categories: [AI, openclaw]
tags: [AI, openclaw, Obsidian]
image:
  path: /assets/img/posts/common/openclaw.jpg
---

# win环境openclaw集成Obsidian搭建知识库

> 本文简要说明在 **Windows** 下用 **OpenClaw** 集成 **Obsidian** 搭建本地知识库的做法：大模型使用 **小米 MiMo**，消息渠道接入 **飞书**，Obsidian 侧通过 **Skill** 等能力参与整理与写入。  
> OpenClaw 版本与 CLI 可能随发布变化，请以官网与 `openclaw --help` 为准。

---

## 一、整体架构

- **OpenClaw**：本地运行的 **Gateway（网关）**，负责会话、工具调用、频道接入等；通过 **WebSocket** 提供能力，浏览器 **Dashboard** 做配置与健康查看。  
- **小米 MiMo**：作为 **模型提供方**，通过 OpenAI 兼容接口为智能体提供推理能力。  
- **飞书**：作为 **入站/出站渠道**，用户在企业内与机器人对话即驱动智能体。  
- **Obsidian**：作为 **知识载体**（本地 Markdown 库）。通过 OpenClaw **Skill** 接入后，可由 **Obsidian 官方 CLI** 或第三方 **`obsidian-cli`** 等工具，向大模型暴露 **写入、检索、搜索** 等能力（以所装 skill 与本地配置为准），供智能体在对话中 **调用**；用户侧 **收发消息** 则仍经 **OpenClaw 已配置的渠道**（如飞书）完成，形成「渠道对话 → 模型推理 → CLI/库操作」的闭环。

官方总入口：[OpenClaw 文档](https://docs.openclaw.ai/) · [ClawHub（技能市场）](https://clawhub.ai/)

---

## 二、环境准备（Windows）

1. 安装 **Node.js**（LTS 即可），并确认终端里可用：
   - `node -v`
   - `npm -v`
2. 建议同时使用 **Git Bash** 或 **PowerShell**，与文档中的命令一致即可。

---

## 三、安装 OpenClaw（npm 全局）

```bash
npm i -g openclaw@latest
openclaw --version
```

- **全局配置目录**（默认）：`%USERPROFILE%\.openclaw\`，主配置文件为 **`openclaw.json`**（JSON5）。  
- 查看当前生效的配置文件路径：

```bash
openclaw config file
```

更多说明：[Gateway 配置概览](https://docs.openclaw.ai/gateway/configuration) · [CLI 总览](https://docs.openclaw.ai/cli)

**升级提示**：在 Windows 上若 **`npm i -g` 报 `EBUSY`（文件被占用）**，请先 **停止正在运行的 `openclaw gateway`**（前台 `Ctrl+C`，或服务方式 `openclaw gateway stop`），再执行升级。也可用 **`openclaw update`**（见 [Updating](https://docs.openclaw.ai/install/updating)、[`openclaw update`](https://docs.openclaw.ai/cli/update)）。

---

## 四、首次配置：网关模式与 Token

OpenClaw 要求在本机跑网关时，配置中显式声明 **`gateway.mode: "local"`**（仅有 `gateway.auth` 不够）。示例（节选，需与你的 JSON 合并）：

```json5
{
  "gateway": {
    "mode": "local",
    "auth": {
      "mode": "token",
      "token": "你的网关令牌或 SecretRef"
    }
  }
}
```

- 首次可使用向导生成令牌与基础结构：`openclaw onboard` 或 `openclaw configure`。  
- 校验配置：`openclaw config validate` · 排障：`openclaw doctor`

网关 CLI：[Gateway CLI](https://docs.openclaw.ai/cli/gateway)

---

## 五、接入小米 MiMo 大模型

### 5.1 在小米侧准备密钥

- 开放平台与文档：[小米 MiMo API 开放平台](https://platform.xiaomimimo.com/#/docs/welcome)  
- 创建 API Key：[控制台 API Keys](https://platform.xiaomimimo.com/#/console/api-keys)  
- OpenClaw 与 MiMo 的集成说明（OpenAI 兼容）：[Xiaomi MiMo（OpenClaw Providers）](https://docs.openclaw.ai/providers/xiaomi)

### 5.2 用 CLI 快速写入

```bash
openclaw onboard --auth-choice xiaomi-api-key
# 或非交互时可配合官方文档中的参数传入密钥
```

### 5.3 配置要点

- **Base URL**：`https://api.xiaomimimo.com/v1`  
- **API 类型**：`openai-completions`  
- **模型引用**：`xiaomi/mimo-v2-flash`、`xiaomi/mimo-v2-pro`、`xiaomi/mimo-v2-omni` 等  

若调用返回 **402 / 余额不足**，属于 **小米账号侧计费/额度** 问题，需到控制台检查余额与套餐，而非 OpenClaw 配置语法错误。

---

## 六、接入飞书渠道

### 6.1 官方文档

- OpenClaw 飞书频道：[Feishu 频道文档](https://docs.openclaw.ai/channels/feishu)  
- 飞书开放平台：在开放平台创建企业应用、机器人和 **事件订阅**（如 `im.message.receive_v1`），按文档配置权限与连接方式。

### 6.2 在 OpenClaw 中添加频道

按官方文档使用 `openclaw channels add` 等流程填入 **App ID / App Secret**，并确认 **Gateway 已启动** 后，在飞书内发消息测试。

### 6.3 务必知晓：一个机器人 ≈ 一条长连接

飞书侧通过 **WebSocket** 收事件时，**同一机器人同一时间通常只能连一个实例**。若旧机器上 **Gateway 仍在运行**，新环境会 **收不到消息**。处理思路：

1. 停掉所有旧实例上的 **`openclaw gateway`**（或对应服务）。  
2. 只在当前环境启动 Gateway，再测飞书。  
3. 若仍异常，可在飞书开放平台 **事件与回调 → 事件配置** 中对 `im.message.receive_v1` 等事件 **删除后重新添加**，强制断开旧连接后再连新实例。

### 6.4 首次对话与配对

首次私聊机器人可能出现 **配对码**，在终端执行（具体子命令以 `openclaw pairing --help` 为准）：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <配对码>
```

---

## 七、接入 Obsidian：用 Skill 做「知识库整理」

### 7.0 简单了解 Obsidian

**Obsidian** 是一款以 **本地 Markdown** 为主的笔记与知识管理工具：每个 **库（Vault）** 对应电脑上的一个文件夹，支持双向链接、标签、社区插件与主题；笔记文件在本地，适合作为个人知识库的 **存放与阅读端**。

- **Windows 下载（官方）**：<https://obsidian.md/download>（在页面中选择 Windows 安装包）。  
- **使用说明与帮助**：<https://help.obsidian.md/Home> · 中文可参考 <https://obsidian.md/zh/help/Home>。  
- **官方 CLI**（在应用内开启后，可在终端操作同一库）：<https://obsidian.md/help/cli>。

OpenClaw **不内置**唯一的 Obsidian 入口；常见做法是在本机已安装 Obsidian 与（按需）CLI 的前提下，从 **ClawHub** 安装 **Obsidian 相关 Skill**，让智能体在允许的工具策略下操作 vault（搜索、建笔记、改链接等，以具体 skill 的 `SKILL.md` 为准）。

### 7.1 发现与安装技能

- ClawHub 说明：[ClawHub（OpenClaw 文档）](https://docs.openclaw.ai/tools/clawhub)  
- 站点：[clawhub.ai](https://clawhub.ai/)  

```bash
openclaw skills search "obsidian"
openclaw skills install <slug>
openclaw skills info <slug>
```

示例索引（以站点当前列表为准）：[Obsidian（ClawHub）](https://clawhub.ai/skills/obsidian) · [Obsidian Official CLI（ClawHub）](https://clawhub.ai/skills/obsidian-official-cli)

### 7.2 「已安装 Obsidian」≠ 终端里已有 `obsidian-cli`

- **Obsidian 桌面版** 与 **命令行工具** 是两条线；装应用不会自动在 PATH 里出现第三方 **`obsidian-cli`**。  
- **官方 CLI**：在较新版本 Obsidian 中通过 **设置** 启用，命令名可能是 **`obs`** 等，请参阅 [Obsidian CLI 官方帮助](https://obsidian.md/help/cli)（含 Windows 说明）。  
- 若某 skill 要求 **`obsidian-cli`**：请 **按该 skill 文档单独安装**，并在 Git Bash / PowerShell 中确认命令可执行。

### 7.3 多智能体时的技能目录

技能可装在 **当前工作区** 的 `skills/`，也可使用共享目录；多智能体场景下每个 agent 有独立工作区时，注意 **在哪个工作区安装 skill**。参见：[Skills](https://docs.openclaw.ai/tools/skills) · [多智能体路由](https://docs.openclaw.ai/concepts/multi-agent)

### 7.4 「自动知识库整理」设计

在模型与飞书都打通后，可由你在 **系统提示 / AGENTS.md / SOUL.md** 中约定：例如「飞书确认的任务 → 在 Obsidian 指定路径下创建/更新笔记、打标签、维护 MOC」。是否真能执行取决于 **skill 能力 + 是否允许 exec/写文件 + vault 路径是否对 agent 可见**。生产环境建议配合 **沙箱与工具白名单**（见官方沙箱与工具文档）。

---

## 八、日常运行：Gateway 与 Dashboard

1. 启动网关（一个终端前台占用时，另开终端做别的事）：

```bash
openclaw gateway
```

2. 打开控制台（另一终端）：

```bash
openclaw dashboard
```

说明：[dashboard CLI](https://docs.openclaw.ai/cli/dashboard) · 多智能体与绑定：[Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent) · [`openclaw agents`](https://docs.openclaw.ai/cli/agents)

---

## 九、推荐阅读与链接汇总

| 主题 | 链接 |
|------|------|
| OpenClaw 首页/文档 | <https://docs.openclaw.ai/> |
| 安装与升级 | <https://docs.openclaw.ai/install/updating> |
| 网关配置 | <https://docs.openclaw.ai/gateway/configuration> |
| 小米 MiMo（OpenClaw） | <https://docs.openclaw.ai/providers/xiaomi> |
| 小米 MiMo 平台 | <https://platform.xiaomimimo.com/#/docs/welcome> |
| 飞书频道（OpenClaw） | <https://docs.openclaw.ai/channels/feishu> |
| ClawHub | <https://clawhub.ai/> |
| Obsidian CLI（官方） | <https://obsidian.md/help/cli> |