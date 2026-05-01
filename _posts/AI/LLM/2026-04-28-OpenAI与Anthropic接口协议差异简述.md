---
title: OpenAI 与 Anthropic 接口协议差异简述
date: 2026-04-28 14:00:00
categories: [AI, LLM]
tags: [AI, LLM, OpenAI, Anthropic, API, 网关]
image:
  path: /assets/img/posts/common/llm.jpg
---

# OpenAI 与 Anthropic 接口协议差异简述

> 多数模型聚合网关会同时提供 **OpenAI 兼容**（如 `…/v1`）与 **Anthropic 兼容**（如 `…/anthropic`）两类入口。两套协议在路径、请求体、鉴权与流式响应上并不相同；分开展示是为了对齐各自官方 SDK 与既有工具链，降低迁移成本，而非单纯的技术能力不足。

---

## 目录

- [1. 两套协议的主要差异](#1-两套协议的主要差异)
  - [1.1 URL 与资源模型](#11-url-与资源模型)
  - [1.2 请求体结构](#12-请求体结构)
  - [1.3 鉴权与版本头](#13-鉴权与版本头)
  - [1.4 响应与流式输出](#14-响应与流式输出)
- [2. 分设两套入口的常见原因](#2-分设两套入口的常见原因)
- [3. 生态分流：不仅是时间先后](#3-生态分流不仅是时间先后)
- [4. 两家模型产品线概览](#4-两家模型产品线概览)
- [5. 小结](#5-小结)

---

## 1. 两套协议的主要差异

### 1.1 URL 与资源模型

- **OpenAI 兼容**：习惯与官方 OpenAI 一致，常见基路径带 `v1`，核心能力集中在 `chat/completions`、`embeddings` 等资源路径上。
- **Anthropic 兼容**：与 Anthropic **Messages API** 的路径与命名习惯一致（具体子路径以实现方文档为准），与 OpenAI 的 URL 体系不混用同一套资源树。

同一聚合域名下常见做法是：`…/v1` 服务 OpenAI 形态客户端，`…/anthropic`（或等价前缀）服务 Anthropic 形态客户端，由网关分别做路由与校验。

### 1.2 请求体结构

- **OpenAI**：`messages` 中广泛使用 `role: system | user | assistant`；`model`、`temperature` 等字段名与工具调用（`tools` / `tool_choice` 等）遵循 OpenAI 文档约定。
- **Anthropic**：同样使用 `messages`，但 **`system` 常以独立字段**出现，与 `messages` 分离；`max_tokens` 等必选语义、工具（tool use）的 JSON 结构与 OpenAI **不是一一对应**，不能仅靠替换 URL 完成互通。

因此，在网关侧往往需要两条「完整形状」的兼容层，而不是单一 JSON 模板。

### 1.3 鉴权与版本头

- **OpenAI**：通行做法是 `Authorization: Bearer <token>`。
- **Anthropic**：常见为 **`x-api-key`**，并常配合 **`anthropic-version`**（或兼容层要求的等价头字段）。

客户端若只改 base URL 而不改头信息，网关或上游会直接拒绝请求。

### 1.4 响应与流式输出

- **OpenAI**：流式多为 SSE，`data: {…}` 片段中常见 `choices[].delta` 等结构。
- **Anthropic**：流式事件类型、正文块（content block）、`stop_reason`、用量字段等与 OpenAI **字段名与层级不同**，解析代码需按协议分别编写。

结论：**二者都是「对话式补全」，但 HTTP 层面的契约不同**；大量代码库是按其中一种契约写死的。

---

## 2. 分设两套入口的常见原因

- **对齐既有客户端**：OpenAI 与 Anthropic 官方及各语言 SDK、Agent 框架默认假设的 URL、头、JSON 不同；网关分别暴露兼容端点，用户通常只需替换 **base URL** 与密钥，即可复用原有代码。
- **避免语义强扭**：System 提示、工具调用、多模态、流式增量等能力，两家演进路径不完全一致；若强行统一为一种 JSON，要么丢失信息，要么在网关内部维护复杂映射，且排错时难以对照官方文档。
- **运维与产品语义清晰**：`/v1` 表示「按 OpenAI 客户端预期工作」，`/anthropic` 表示「按 Anthropic 客户端预期工作」，限流、错误码对齐、日志归类都可以分轨处理。

---

## 3. 生态分流：不仅是时间先后

生态上大量库、脚本默认其中一种接口形态，其成因包括：

- **先发与示范效应**：OpenAI 将「HTTP + JSON 的 Chat Completions」用法推广得早，教程与示例默认多是 OpenAI 形状。
- **路径依赖**：后续出现的网关、监控、计费脚本若已假设某种请求结构，更换为另一厂家的 schema 即需要适配层或重写。
- **Anthropic 的独立设计**：Claude 侧 Messages API 自有一套约定，并非 OpenAI 的子集或简单变体，客观上会形成「OpenAI 系」与「Anthropic 系」两套工具链。

因此，**双协议并存是历史路径、网络效应与接口设计分叉共同作用的结果**；不能简化为「仅因某家模型更早推出」。

---

## 4. 两家模型产品线概览

具体 **模型 ID** 与在售型号以各平台控制台及官方文档为准，下文按**产品线**归纳，便于与接口选型对照。

### 4.1 OpenAI

- **GPT 系列**：从 GPT‑3 / GPT‑3.5 到 GPT‑4 及后续多模态、长上下文等变体；常见各类 Turbo、带日期的 snapshot SKU。
- **推理向 o 系列**：强调复杂推理任务的型号（如 o1、o3 一类），命名与定位随产品迭代更新。
- **其它能力**：嵌入（embedding）、文生图（如 DALL·E 线）、语音等相关接口，在产品与计费上常与「对话模型」并列管理。

### 4.2 Anthropic

- **Claude 系列**：Claude 2 → Claude 3 家族（常见档位 **Opus / Sonnet / Haiku**）→ Claude 3.5（如 Sonnet）及后续世代（如 Claude 4 等，以官方当前列表为准）。
- **档位含义**（同代内大致区分）：**Opus** 偏能力与质量上限，**Sonnet** 偏均衡，**Haiku** 偏速度与成本；具体字符串仍以控制台为准。

需要精确到「当前每一个 model 名」时，应以 [OpenAI Models 文档](https://platform.openai.com/docs/models) 与 [Anthropic Claude 模型文档](https://docs.anthropic.com/en/docs/about-claude/models) 的实时列表为准。

---

## 5. 小结

- OpenAI 兼容与 Anthropic 兼容在 **路径、请求 JSON、鉴权头、流式格式**上均存在系统性差异。
- 网关分设两套入口，主要为 **复用现有 SDK 与脚本**、**减少错误映射**，并保持与 **各自官方文档** 的可对照性。
- 生态上的「两派客户端」来自 **时间线上的示范效应、既有代码投资，以及 Anthropic 独立 API 设计**，不宜仅用「谁更早」单因素解释。
- 选型时依据实际依赖：**OpenAI SDK / 大量 OpenAI 形态配置** 走 `…/v1` 一类入口；**Anthropic SDK / 需 Messages API 行为** 走 `…/anthropic` 一类入口，并核对实现方提供的完整路径与头要求。
