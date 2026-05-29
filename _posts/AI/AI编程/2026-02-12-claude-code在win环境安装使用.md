---
title: claude-code在win环境安装使用
date: 2026-02-12 22:00:00
categories: [AI, AI编程]
tags: [AI, AI编程, claude-code]
image:
  path: /assets/img/posts/common/AI.jpg
---

# claude-code在win环境安装使用

> 在 Windows 原生环境安装、配置与升级 **Claude Code** CLI，并结合 **CC-Switch** 切换 API 渠道。官方文档：[概述](https://code.claude.com/docs/zh-CN/overview)、[高级安装](https://code.claude.com/docs/zh-CN/setup)。

---

## 目录

- [1. 环境要求](#1-环境要求)
- [2. 安装 Claude Code](#2-安装-claude-code)
- [3. 升级 Claude Code](#3-升级-claude-code)
- [4. CC-Switch 配置渠道](#4-cc-switch-配置渠道)
- [5. 启动与使用](#5-启动与使用)
- [6. 常见问题](#6-常见问题)

---

## 1. 环境要求

| 项目 | 说明 |
|------|------|
| 系统 | **Windows 10 1809+** 或 Windows Server 2019+ |
| 终端 | **PowerShell** 或 **CMD**（安装脚本不同，勿混用） |
| 网络 | 需能访问 Anthropic 或你所用 API 中转 |
| Git for Windows | **推荐但非必须**；未安装时 Claude Code 用 **PowerShell** 执行 shell；安装后可用 **Bash 工具**（更接近 Linux 开发体验） |

---

## 2. 安装 Claude Code

### 2.1 原生安装（官方推荐）

**PowerShell**（提示符为 `PS C:\...`）：

```powershell
irm https://claude.ai/install.ps1 | iex
```

**CMD**（提示符为 `C:\...`，无 `PS` 前缀）：

```batch
curl -fsSL https://claude.ai/install.cmd -o install.cmd && install.cmd && del install.cmd
```

- 安装完成后**关闭并重新打开**终端，再执行 `claude --version`。
- 原生安装会**后台自动更新**，一般无需手动跟版本。

### 2.2 WinGet 安装

```powershell
winget install Anthropic.ClaudeCode
```

WinGet 安装**不会自动更新**，需定期执行：

```powershell
winget upgrade Anthropic.ClaudeCode
```

### 2.3 npm 安装（可选）

仍可用 npm 一次性安装/升级 Claude Code 及同类 CLI（适合已习惯 Node 环境的用户）：

```sh
npm install -g @anthropic-ai/claude-code@latest @openai/codex@latest @google/gemini-cli@latest
claude --version && codex --version && gemini --version
```

- 仓库：https://github.com/anthropics/claude-code  
- npm 安装**无**原生安装的后台自动更新，升级见 [§3](#3-升级-claude-code)。

### 2.4 安装 Git for Windows（推荐）

若需 Bash 工具或安装/运行时报缺少 git-bash：

1. 下载：https://git-scm.com/downloads/win  
2. 默认安装后 `bash.exe` 多在：`C:\Program Files\Git\bin\bash.exe`  
3. 若仍找不到，见 [§6.1](#61-启动报错-git-bash-缺失)。

---

## 3. 升级 Claude Code

按你的安装方式选择：

| 安装方式 | 升级方法 |
|----------|----------|
| **原生安装（install.ps1）** | 一般**自动后台更新**；也可重新执行安装脚本覆盖 |
| **WinGet** | `winget upgrade Anthropic.ClaudeCode` |
| **npm** | `npm install -g @anthropic-ai/claude-code@latest` |
| **CC-Switch 切换渠道后** | 改配置后需**重启** Claude Code / 终端 |

升级后建议验证：

```powershell
claude --version
claude doctor
```

`claude doctor` 可检查 Git Bash、网络、配置等常见问题。

---

## 4. CC-Switch 配置渠道

使用国内或第三方 API 时，可用 **CC-Switch** 管理 Claude Code / Codex / Gemini 等连接与 Skill、MCP。

| 项 | 链接 |
|----|------|
| 仓库 | https://github.com/farion1231/cc-switch |
| 安装包 | https://github.com/farion1231/cc-switch/releases（展开 Assets，选 Windows 安装包） |

功能：快速切换 Claude Code **中转商/渠道**；切换后需**重启** Claude Code；自带 Skill、提示词、MCP 配置入口。

**初次使用注意**：窗体无滚动条，需用滚轮下拉才能看到 API Key、模型名称等项。

---

## 5. 启动与使用

建议先在 CC-Switch 中配置好大模型连接，再在项目目录启动：

```sh
cd your-project
claude
```

首次运行会提示登录；使用中转时按 CC-Switch 文档配置 API Key 与 Base URL。启动后终端会打印当前使用的模型 id。

---

## 6. 常见问题

### 6.1 启动报错：git-bash 缺失

日志示例：

```log
Claude Code on Windows requires git-bash ...
If installed but not in PATH, set environment variable ...
CLAUDE_CODE_GIT_BASH_PATH=C:\Program Files\Git\bin\bash.exe
```

**方案一（推荐）**：安装 [Git for Windows](https://git-scm.com/downloads/win)，并确保 `bash.exe` 在 PATH 中。

**方案二**：指定 Bash 路径（二选一即可）：

- **系统环境变量**：`CLAUDE_CODE_GIT_BASH_PATH` = `C:\Program Files\Git\bin\bash.exe` 全路径  
- **项目/用户配置**：在 `C:\Users\<用户名>\.claude\settings.json` 中写入：

```json
{
  "env": {
    "CLAUDE_CODE_GIT_BASH_PATH": "C:\\Program Files\\Git\\bin\\bash.exe"
  }
}
```

> 未安装 Git 时，新版本也可仅用 PowerShell 作为 shell；若仍报错，以 `claude doctor` 输出为准。

### 6.2 启动报错：ERR_BAD_REQUEST

日志示例：

```log
Unable to connect to Anthropic services
Failed to connect to api.anthropic.com: ERR_BAD_REQUEST
```

常见于直连官方 API 失败或使用中转未配好时：

- **方案一**：在 CC-Switch 中开启「跳过 claude code 初次安装确认」  
- **方案二**：编辑 `C:\Users\<用户名>\.claude.json`，末尾增加：`"hasCompletedOnboarding": true`  
- **方案三**：在 CC-Switch 中确认 API Key、Base URL、模型 id 与渠道文档一致后重启

### 6.3 PowerShell 与 CMD 装混

| 现象 | 原因 |
|------|------|
| `'irm' is not recognized` | 在 CMD 里执行了 PowerShell 命令 → 改用 CMD 安装命令或换 PowerShell |
| `'&&' is not a valid statement separator` | 在 PowerShell 里执行了 CMD 的 `&&` 链 → 改用 PowerShell 的 `irm ... \| iex` |

---

## 参考链接

- Claude Code 概述：https://code.claude.com/docs/zh-CN/overview  
- 高级安装与故障排除：https://code.claude.com/docs/zh-CN/setup  
- GitHub：https://github.com/anthropics/claude-code  
