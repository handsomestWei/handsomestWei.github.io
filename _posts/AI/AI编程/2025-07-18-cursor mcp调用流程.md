---
title: cursor mcp调用流程
date: 2025-07-18 14:10:00
categories: [AI, AI编程, cursor]
tags: [AI, AI编程, cursor]
image:
  path: /assets/img/posts/common/AI.jpg
---

# cursor mcp调用流程

## 概述

MCP（Model Context Protocol）是一个开放协议，用于标准化AI模型与外部工具和数据源的交互。在Cursor中，AI模型通过MCP协议安全地调用本地工具，如数据库查询、文件操作等。

## 核心概念

### MCP技术的作用
- **标准化接口**：为AI模型提供统一的工具调用接口
- **扩展能力**：让AI模型能够访问外部数据源、执行特定任务
- **安全隔离**：在本地环境中安全地执行AI模型请求的操作

### MCP架构组件
1. **MCP Hosts**：如Cursor、Claude Desktop等应用程序
2. **MCP Clients**：协议客户端，维护与服务器的1:1连接
3. **MCP Servers**：轻量级程序，通过标准化协议暴露特定功能
4. **Local Data Sources**：本地文件、数据库和服务
5. **Remote Services**：通过API可用的外部系统

## 完整调用流程
以`mcp-mysql-server`的使用为例分析。

### 1. 用户发起请求
```
用户 → Cursor → 服务端AI模型
```

### 2. AI模型分析请求
- AI模型分析用户的查询（如"查询数据库中的用户表"）
- 识别需要使用MySQL工具
- 生成MCP协议格式的调用指令

### 3. MCP客户端发现和选择

#### 3.1 配置驱动发现
AI模型通过配置文件了解可用的MCP客户端：

```json
{
  "mcpServers": {
    "mcp-mysql-example": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@example/mcp-mysql-server",
        "mysql://username:password@localhost:3306/database"
      ]
    }
  }
}
```

#### 3.2 工具发现过程
1. **读取配置文件**：了解可用的MCP服务器
2. **启动MCP客户端**：根据配置启动相应的MCP客户端进程
3. **获取工具列表**：向每个MCP客户端发送`tools/list`请求

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/list"
}
```

#### 3.3 工具注册
MCP客户端返回可用工具列表：

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "tools": [
      {
        "name": "query",
        "description": "Execute SQL query on MySQL database",
        "inputSchema": {
          "type": "object",
          "properties": {
            "sql": {
              "type": "string",
              "description": "SQL query to execute"
            }
          },
          "required": ["sql"]
        }
      }
    ]
  }
}
```

#### 3.4 AI模型决策逻辑
AI模型基于以下因素选择使用哪个MCP客户端：
- **工具名称匹配**：根据用户请求匹配相应的工具
- **工具描述理解**：通过工具描述理解其功能
- **参数模式匹配**：根据用户输入匹配工具参数
- **上下文相关性**：基于对话上下文选择最相关的工具

### 4. MCP工具调用
```
服务端AI → 本地MCP客户端 → 本地MCP-MySQL服务
```

#### 4.1 AI模型生成工具调用
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "query",
    "arguments": {
      "sql": "SELECT * FROM users LIMIT 10"
    }
  }
}
```

#### 4.2 MCP客户端路由
AI模型知道这个请求应该发送给`mcp-mysql-example`客户端，因为：
- 该客户端提供了`query`工具
- 工具描述表明它用于执行SQL查询
- 参数模式匹配用户需求

### 5. 执行和返回
```
MCP-MySQL服务 → 执行SQL查询 → 返回结果 → MCP客户端 → 服务端AI → Cursor → 用户
```

#### 5.1 MCP服务端处理并返回
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "content": [
      {
        "type": "text",
        "text": "Query executed successfully. Found 5 records."
      }
    ],
    "isError": false
  }
}
```

## MCP协议标准

### 协议基础架构
MCP协议基于**JSON-RPC 2.0**标准，定义了三种基本消息类型：

#### 请求（Request）
```json
{
  "jsonrpc": "2.0",
  "id": number | string,
  "method": string,
  "params": object
}
```

#### 响应（Response）
```json
{
  "jsonrpc": "2.0",
  "id": number | string,
  "result": object
}
```

#### 通知（Notification）
```json
{
  "jsonrpc": "2.0",
  "method": string,
  "params": object
}
```

### 传输层标准

#### stdio传输（本地）
- 通过标准输入输出进行通信
- 适用于本地集成和命令行工具

#### Streamable HTTP传输（网络）
- 使用HTTP POST请求进行客户端到服务器通信
- 支持Server-Sent Events (SSE)进行服务器到客户端通信
- 支持会话管理和断线重连

### 错误处理标准
MCP定义了标准的错误码：
- `-32700`: 解析错误
- `-32600`: 无效请求
- `-32601`: 方法未找到
- `-32602`: 无效参数
- `-32603`: 内部错误

### 工具定义标准
每个MCP工具都有标准的结构定义：

```json
{
  "name": "tool_name",
  "description": "Human-readable description",
  "inputSchema": {
    "type": "object",
    "properties": {
      "param1": {
        "type": "string",
        "description": "Parameter description"
      }
    },
    "required": ["param1"]
  },
  "annotations": {
    "title": "Display Title",
    "readOnlyHint": false,
    "destructiveHint": true,
    "idempotentHint": false,
    "openWorldHint": true
  }
}
```

## 安全考虑

### 1. 本地执行
- MCP工具在用户的本地环境执行
- 数据不会发送到AI服务商

### 2. 权限控制
- 只有用户明确配置的工具才能被调用
- 支持认证和授权机制

### 3. 网络隔离
- 数据库连接保持在用户的内网环境中
- 支持TLS加密传输

### 4. 输入验证
- 所有参数都经过JSON Schema验证
- 防止命令注入和恶意输入

## 实际应用示例

### MySQL数据库查询示例

#### 用户请求
```
用户: "查询数据库中的用户表"
```

#### AI模型决策过程
1. 分析用户意图 → 需要数据库查询功能
2. 查看可用工具 → 发现 "query" 和 "list_tables" 工具
3. 匹配工具描述 → "Execute SQL query" 符合需求
4. 选择MCP客户端 → 使用 mcp-mysql-example
5. 生成工具调用 → 调用 query 工具

#### 完整调用链路
```
用户 → Cursor → 服务端AI模型
                ↓
服务端AI → 本地MCP客户端 → 本地MCP-MySQL服务
                ↓
MCP-MySQL服务 → 执行SQL查询 → 返回结果 → MCP客户端 → 服务端AI → Cursor → 用户
```

## 多客户端场景

当有多个MCP客户端提供相似功能时，AI模型会：

1. **优先级排序**：基于工具描述的清晰度
2. **参数匹配度**：选择参数最匹配的工具
3. **历史使用**：优先选择之前成功使用的工具
4. **错误处理**：如果某个客户端失败，尝试其他客户端

## 动态工具发现

MCP协议支持动态工具发现：

```json
{
  "jsonrpc": "2.0",
  "method": "notifications/tools/list_changed"
}
```

当MCP客户端添加或移除工具时，会通知AI模型更新可用工具列表。

## 总结

MCP技术为AI模型提供了安全、标准化的工具调用能力。整个流程确保了：

- **标准化**：基于JSON-RPC 2.0的统一协议
- **安全性**：本地执行，数据不泄露
- **可扩展性**：支持多种工具和数据源
- **互操作性**：不同厂商的实现可以无缝协作

MCP就像AI应用的"USB-C接口"，为AI模型提供了标准化的工具连接能力，让AI能够安全、可控地访问用户的本地资源。
