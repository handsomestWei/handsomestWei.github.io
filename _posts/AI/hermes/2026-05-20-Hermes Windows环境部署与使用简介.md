---
title: Hermes Windows环境部署与使用简介
date: 2026-05-20 10:00:00
categories: [AI, hermes]
tags: [AI, hermes, Agent, Windows]
image:
  path: /assets/img/posts/common/hermes.jpg
---

# Hermes Windows环境部署与使用简介

> 面向在 **Windows** 本机安装、配置与日常使用 **Nous Research Hermes Agent** 的实操说明。本文基于实际踩坑整理：安装路径、Python 环境污染、API Key 配置、CLI / Dashboard / Gateway 区别等。版本与 CLI 行为可能随发布变化，请以 [Hermes 官方文档](https://hermes-agent.nousresearch.com/docs) 与 `hermes --help` 为准。

---

## 1. Hermes Agent 是什么

**Hermes Agent** 是 Nous Research 开源的 **终端 AI Agent**：在本地通过 CLI 对话，可调用工具（终端、浏览器、文件、MCP 等），并可选接入 **Telegram / Discord / Slack** 等消息平台作为远程入口。

与「纯聊天网页」不同，Hermes 更偏向 **可执行任务的编码/运维助手**：

- 本地 **`hermes --tui`** 终端 TUI 直接对话；
- **`hermes dashboard`** 提供 Web 会话管理与可视化（默认 `http://127.0.0.1:9119`）；
- **`hermes gateway`** 在后台对接消息平台，不是浏览器里打开的「聊天链接」。

支持多模型与多厂商（OpenRouter、Nous Portal、小米 MiMo、Z.AI/GLM、Kimi、MiniMax 等），用 **`hermes model`** 切换，无需改代码。

---

## 2. 官方资源

| 资源 | 链接 |
|------|------|
| GitHub 仓库 | https://github.com/NousResearch/hermes-agent |
| 文档首页 | https://hermes-agent.nousresearch.com/docs |
| 提供商与 API Key | https://hermes-agent.nousresearch.com/docs/integrations/providers |
| 环境变量参考 | https://hermes-agent.nousresearch.com/docs/reference/environment-variables |
| CLI 命令参考 | https://hermes-agent.nousresearch.com/docs/reference/cli-commands |

---

## 3. 目录与配置文件（Windows）

安装完成后，典型路径如下（`%LOCALAPPDATA%` 一般为 `C:\Users\<用户名>\AppData\Local`）：

| 路径 | 说明 |
|------|------|
| `%LOCALAPPDATA%\hermes\hermes-agent\` | 源码与 **venv**（`uv sync` 安装的 Python 环境） |
| `%LOCALAPPDATA%\hermes\.env` | **API Key、Gateway Token** 等敏感配置（勿提交 Git） |
| `%LOCALAPPDATA%\hermes\config.yaml` | **默认模型、工具集、终端后端** 等非密钥配置 |
| `%LOCALAPPDATA%\hermes\` 下其他目录 | 会话、日志、技能缓存等运行时数据 |

环境变量 **`HERMES_HOME`** 可指向上述数据目录；未设置时安装脚本通常默认为 `%LOCALAPPDATA%\hermes`。

```text
┌─────────────────────────────────────────────────────────────┐
│                    Hermes 本地布局（Windows）                 │
├─────────────────────────────────────────────────────────────┤
│  hermes-agent/          ← 程序与 venv（可 git pull 升级）     │
│  .env                   ← API Key（从 .env.example 复制填写）  │
│  config.yaml            ← model.provider / model.default 等  │
│  sessions / logs / ...  ← 运行时数据                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Windows 安装

### 4.1 环境要求

- **Windows 10/11**，PowerShell 5.1 或 PowerShell 7+
- 网络可访问 GitHub（安装脚本会拉取仓库、Python、依赖）
- 磁盘空间建议 **数 GB 以上**（含 venv 与可选浏览器依赖）

### 4.2 一键安装（推荐）

在 **PowerShell** 中执行官方安装脚本（使用 **uv** 管理 Python 与依赖）：

```powershell
iex (irm https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.ps1)
```

脚本默认将仓库安装到 `%LOCALAPPDATA%\hermes\hermes-agent`，并执行 `uv sync`、可选 `hermes setup` 等步骤。

### 4.3 Git 克隆失败时的替代方式

若公司网络或 SSH/HTTPS 克隆 GitHub 失败，可：

1. 从 GitHub 下载 **ZIP** 解压到 `%LOCALAPPDATA%\hermes\hermes-agent`；
2. 进入该目录，安装 **uv** 后执行：

```powershell
cd $env:LOCALAPPDATA\hermes\hermes-agent
uv sync --extra all --locked
```

3. 将 `venv\Scripts` 加入 PATH，或每次先激活 venv（见下文 **activate-hermes.ps1**）。

安装结束时若出现 **baseline import 失败**，不一定表示完全不可用，可执行 **`hermes doctor`** 再确认。

### 4.4 安装 Web 仪表盘依赖

默认核心安装较精简；若 `hermes dashboard` 提示缺少 FastAPI/Uvicorn，在仓库目录执行：

```powershell
uv pip install -e ".[web]"
```

---

## 5. 启动前：隔离 Python 环境污染（重要）

### 5.1 现象

本机若曾设置全局 **`PYTHONPATH`**、**`PIP_TARGET`** 或自定义 site-packages（例如指向 `D:\work\python-site-packages`），即使使用 `venv\Scripts\python.exe`，`openai` / `pydantic` 仍可能从**错误路径**加载，导致：

- `hermes doctor` 报 OpenAI SDK 异常；
- `pydantic_core` 版本不匹配等。

### 5.2 推荐：activate-hermes.ps1（自编辅助，非官方）

下文 **`scripts/activate-hermes.ps1`** 为本文实践中的**自编辅助脚本**，**不是** Nous Research Hermes 官方仓库自带内容。用途是在每次启动前**隔离本机 Python 环境**：激活 Hermes 的 venv，并清除 `PYTHONPATH` 等全局变量，避免与系统或其它项目的 site-packages 冲突。

在 `hermes-agent\scripts\` 下自行创建该文件后，**每次开新 PowerShell 会话**先执行：

```powershell
cd $env:LOCALAPPDATA\hermes\hermes-agent
.\scripts\activate-hermes.ps1
```

将下列内容保存为 `%LOCALAPPDATA%\hermes\hermes-agent\scripts\activate-hermes.ps1`（仅对**当前 PowerShell 会话**生效，不修改系统 PATH）：

```powershell
# Usage (current PowerShell session only):
#   cd $env:LOCALAPPDATA\hermes\hermes-agent
#   .\scripts\activate-hermes.ps1
#
# activate venv, clear PYTHONPATH/PIP_TARGET, PYTHONNOUSERSITE=1.

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Activate = Join-Path $RepoRoot 'venv\Scripts\Activate.ps1'

if (-not (Test-Path $Activate)) {
    Write-Error "Activate.ps1 not found: $Activate. Run Hermes install.ps1 first."
}

. $Activate

Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
Remove-Item Env:PIP_TARGET -ErrorAction SilentlyContinue
Remove-Item Env:PYTHONHOME -ErrorAction SilentlyContinue
$env:PYTHONNOUSERSITE = '1'

$env:UV_PROJECT_ENVIRONMENT = Join-Path $RepoRoot 'venv'

if (-not $env:HERMES_HOME) {
    $env:HERMES_HOME = Join-Path $env:LOCALAPPDATA 'hermes'
}

Set-Location $RepoRoot

Write-Host '[hermes] venv active; PYTHONPATH/PIP_TARGET cleared; PYTHONNOUSERSITE=1' -ForegroundColor Cyan
Write-Host "[hermes] repo: $RepoRoot" -ForegroundColor DarkGray
Write-Host "[hermes] HERMES_HOME=$($env:HERMES_HOME)" -ForegroundColor DarkGray
Write-Host '[hermes] Next: hermes doctor | hermes setup | hermes' -ForegroundColor Cyan
```

脚本作用简述：激活 venv、清除 `PYTHONPATH` / `PIP_TARGET` / `PYTHONHOME`、设置 `PYTHONNOUSERSITE=1` 与 `UV_PROJECT_ENVIRONMENT`，未设置时默认 `HERMES_HOME=%LOCALAPPDATA%\hermes`。

---

## 6. 配置 API Key 与默认模型

### 6.1 创建 .env

```powershell
copy $env:LOCALAPPDATA\hermes\hermes-agent\.env.example $env:LOCALAPPDATA\hermes\.env
notepad $env:LOCALAPPDATA\hermes\.env
```

### 6.2 切换模型

```powershell
hermes model          # 交互选择 provider + model
hermes setup          # 向导式配置（含 Key 检测）
```

修改 `.env` 或 `config.yaml` 后，在 Hermes TUI 中可执行 **`/reload`**，或退出后重新运行 `hermes --tui`。

### 6.3 健康检查

```powershell
hermes doctor
```

用于检查 venv、SDK、部分 API 连通性等。通过后再执行 `hermes --tui` 进行对话测试。

---

## 7. 日常使用

### 7.1 终端 TUI

本地对话推荐 **现代 TUI**（多行输入、斜杠命令补全、流式工具输出等），需先执行 **`activate-hermes.ps1`**，再启动：

```powershell
hermes --tui
```

也可设置环境变量后直接用 `hermes` 进入 TUI：

```powershell
$env:HERMES_TUI = '1'
hermes
```

不带 `--tui` 时默认进入**经典 REPL**（`prompt_toolkit` 界面），功能相近但交互较简；若习惯新界面，建议固定使用 **`hermes --tui`**。

常用变体：

| 命令 | 说明 |
|------|------|
| `hermes --tui` | 启动现代终端 TUI（推荐） |
| `hermes --tui -c` | 继续最近一次 TUI 会话 |
| `hermes --tui --resume <会话ID或标题>` | 恢复指定会话 |
| `hermes chat --tui` | 与上表等价（显式 `chat` 子命令） |

在 TUI 中输入问题即可；状态栏会显示当前 **模型与 provider**。斜杠命令（如 `/model`、`/new`、`/reload`）在 TUI 与经典 REPL 中大多通用。

### 7.2 Web Dashboard

```powershell
hermes dashboard
```

浏览器访问 **`http://127.0.0.1:9119`**（端口以实际输出为准）。用于查看会话、部分分析功能；需**保持该 PowerShell 窗口前台运行**。

- 初次打开 **「暂无会话」** 属正常，需先在 CLI 产生对话或配合 TUI 使用；
- Windows 上网页内直接聊天有时需 **`hermes dashboard --tui`** 或 WSL2，以官方文档为准；
- 建议流程：终端 `hermes --tui` 聊几句 → 刷新 Dashboard 会话列表。

### 7.3 Gateway（消息平台）

Gateway 用于 **Telegram / Discord / Slack** 等后台对接，**不是**在浏览器里打开的聊天页面。典型配置写入 `.env`（如 `TELEGRAM_BOT_TOKEN`、`TELEGRAM_ALLOWED_USERS`；开发可临时设 `GATEWAY_ALLOW_ALL_USERS=true`）。未配置任何消息平台时，启动可能提示 **no messaging platform enabled**，对纯本地 TUI 使用通常无影响。

| 命令 | 作用 |
|------|------|
| `hermes gateway` / `hermes gateway run` | 前台启动网关（`gateway` 默认等价于 `run`） |
| `hermes gateway run --replace` | 启动前结束已有实例并清理 PID/锁，避免双实例 |
| `hermes gateway restart` | 重启网关（先停后启；改 `.env` 或 Bot 配置后常用） |
| `hermes gateway restart --all` | 停止所有 profile 的网关后再启动当前配置 |
| `hermes gateway stop` | 停止当前 profile 的网关进程 |
| `hermes gateway start` | 启动已安装的网关（计划任务或后台拉起） |
| `hermes gateway status` | 查看是否在运行、PID、计划任务/启动项状态 |
| `hermes gateway setup` | 交互式配置消息平台（Token、允许用户等） |
| `hermes gateway install` | 注册 Windows 登录自启动（计划任务，失败则回退启动文件夹） |
| `hermes gateway uninstall` | 移除自启动注册与相关包装脚本 |

---

## 8. 常见问题

| 现象 | 可能原因 | 处理建议 |
|------|----------|----------|
| `hermes doctor` OpenAI SDK 异常 | 全局 `PYTHONPATH` 污染 | 使用 **activate-hermes.ps1**；`uv pip install --reinstall openai pydantic pydantic-core` |
| 安装脚本 baseline import 失败 | 同上或安装未完成 | 进入 venv 手动 `uv sync`；再 `hermes doctor` |
| `hermes dashboard` 无法启动 | 未装 `[web]` 额外依赖 | `uv pip install -e ".[web]"` |
| Gateway 无平台 / 无 allowlist | 未配 Telegram 等或未设允许用户 | 按文档配置 Token 与 `TELEGRAM_ALLOWED_USERS` 或 `GATEWAY_ALLOW_ALL_USERS` |
| `Gateway already running` | 旧进程未退出 | `hermes gateway restart` 或 `hermes gateway run --replace` |
| 会话页为空 | 尚无历史对话 | 先用 `hermes --tui` 产生会话 |

---

## 9. 安全与运维建议

1. **`.env` 仅保留在本机**，不要提交到 Git 或发到聊天工具；泄露后应在厂商控制台**轮换密钥**。
2. 每次新开 PowerShell 运行 Hermes 前，先执行 **`activate-hermes.ps1`**，避免环境污染复发。
3. 升级：在 `hermes-agent` 目录 `git pull` 后执行 `uv sync --extra all --locked`，再 `hermes doctor`。
4. Dashboard 默认绑定 **127.0.0.1**，勿在未加固情况下暴露到公网。
