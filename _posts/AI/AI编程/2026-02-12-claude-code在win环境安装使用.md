---
title: claude-code在win环境安装使用
date: 2026-02-12 22:00:00
categories: [AI, AI编程]
tags: [AI, AI编程, claude-code]
image:
  path: /assets/img/posts/common/AI.jpg
---

# claude-code在win环境安装使用

## cc-switch安装
- git地址 https://github.com/farion1231/cc-switch
- 下载链接 https://github.com/farion1231/cc-switch/releases 点击展开show all找到win安装包

快速切换Claude code中转商/渠道，切换完需要重启，自带Skill、提示词、MCP快速配置。

## claude code安装
- git地址 https://github.com/anthropics/claude-code
- 使用文档 https://code.claude.com/docs/zh-CN/overview
建议使用npm方式，一次性安装/升级Claude code、Codex、Gemini
```sh
npm install -g @anthropic-ai/claude-code@latest @openai/codex@latest @google/gemini-cli@latest
claude --version && codex --version && gemini --version
```

## 使用cc-switch配置大模型连接
- 初次使用注意： 窗体没有滚动条，都需要滚轮滚动才能看到更多内容。
添加自定义模型供应商，API KEY和模型名称选择等配置，需要下拉滚动窗体，才能看到相关配置项并填写。

## claude code使用
建议先在cc-switch配置大模型连接。
```sh
claude
```
启动后，终端会打印当前使用的大模型id。

### 常见问题
#### 启动报错git-bash缺失
claude-code相关日志
```log
Claude Code on Windows requires git-bash (https://git-scm.com/downloads/win). If installed but not in PATH, set environment variable pointing to your bash.exe, similar to: CLAUDE_CODE_GIT_BASH_PATH=C:\Program Files\Git\bin\bash.exe
```
找到本地git的bash.exe路径，按日志提示，在系统环境变量添加CLAUDE_CODE_GIT_BASH_PATH变量和值为bash.exe全路径。

#### 启动报错ERR_BAD_REQUEST
claude-code相关日志
```log
Unable to connect to Anthropic servicesFailed to connect to api.anthropic.com: ERR_BAD_REQUEST
```
- 方案一： 在CC-Switch配置，开启“跳过claude code初次安装确认”
- 方案二： 修改claude code配置文件，通常位于`C:\Users\<用户名>\.claude.json`，末尾增加一项`"hasCompletedOnboarding": true`
