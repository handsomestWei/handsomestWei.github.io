---
title: JeecgBoot低代码平台AI工作流技术解构
date: 2025-09-22 14:00:00
categories: [AI, AI编程]
tags: [AI, AI编程, 低代码]
image:
  path: /assets/img/posts/common/AI.jpg
---

# JeecgBoot低代码平台AI工作流技术解构
[github仓库：jeecgboot/JeecgBoot](https://github.com/jeecgboot/JeecgBoot)，基于3.8.2版本sprongboot3分支。

## 概述

JeecgBoot是一个基于Spring Boot 3的开源低代码平台，集成了AI工作流功能，支持通过可视化界面构建和运行AI应用。

## 核心框架
- **LiteFlow**: 开源的规则引擎。在项目用于工作流编排和执行，而不是LangChain原生方式。
- **LangChain4j**: 开源的智能体框架。在项目中结合pgvector等向量数据库，用于RAG知识库构建和查找。
- **Jeecg-AiFlow**: JeecgBoot自研的AI工作流核心jar包，包装了一些基于LiteFlow的节点增强实现。没有开源，还做了代码混淆。
- **各种LLM SDK**：作为客户端调用大模型api实现对话。
- **LogicFlow**: 开源的前端工作流画布，低代码可视化拖拽。

AI工作流的核心模块位于`jeecg-boot-module\jeecg-boot-module-airag`，对话入口主要在`AIChatHandler.java`

## 数据存储

### 工作流存储
参考`jeecg-aiflow` jar包的`config/application.yml`文件，包含有LiteFlow框架配置，指定脚本存储的表名。

**表名**: `airag_flow`

**核心字段**:
- `chain`: LiteFlow表达式，定义工作流执行逻辑
- `design`: JSON格式的可视化设计数据。保存脚本代码和llm调用配置如提示词等。通过LiteFlow的脚本引擎动态编译执行，支持多种脚本语言。具体细节可以参考初始化的sql脚本查看该表数据。
- `status`: 状态（enable=启用、disable=禁用、release=发布）

**chain**表达式字段示例片段
```java
THEN(
    start.tag('start-node'),
    llm.tag('e9f3470a-f129-4baf-880a-294d7b3bff93'),
    end.tag('9eb6f5c7-94a6-421f-aa39-7cfd7cec44f1')
).tag("start-node")
```

**design**脚本字段示例片段
包含页面的回显展示样式配置，如果是llm大模型调用节点，则包含有调用参数等。
```json
{
		"id": "160311787014434816",
		"type": "llm",
		"x": 1018.1304347826085,
		"y": -414.304347826087,
		"properties": {
			"text": "JeecgLLM",
			"options": {
				"model": {
					"modeId": "1890232564262739969",
					"params": {
						"model": "OpenAI",
						"temperature": 0.7
					}
				},
				"history": 3,
				"messages": [{
					"role": "system",
					"content": ""
				},
				{
					"role": "user",
					"content": "{{question}}"
				}]
			},
			"inputParams": [{
				"field": "content",
				"name": "question",
				"nodeId": "start-node"
			},
			{
				"field": "data",
				"name": "doc",
				"nodeId": "160311730106118144"
			}],
			"outputParams": [{
				"field": "text",
				"name": "回复内容",
				"type": "string"
			}],
			"height": 114,
			"width": 332
		}
	},
```

### AI应用存储
工作流是业务的基础，在此之上，进一步包装成AI应用，类似coze扣子。

**表名**: `airag_app`

**核心字段**:
- `flowId`: 关联的工作流ID。如果只是简单的对话智能体，不会包含流程。
- `modelId`: 使用的LLM模型ID
- `knowledgeIds`: 知识库ID列表
- `prompt`: 应用提示词。通过提示词限定智能体的使用领域和场景。

## 对话历史管理
使用Redis缓存，而非数据库表。用于对话查询和上下文填充。

## 当前版本技术限制
- **缺少mcp调用**：类似于coze的插件库
- **状态持久化**: 当前实现不支持工作流执行状态的持久化
- **断点续传**: 不支持工作流中断后的断点续传和事务回滚
- **Redis依赖**: 对话历史完全依赖Redis，存在数据丢失风险
