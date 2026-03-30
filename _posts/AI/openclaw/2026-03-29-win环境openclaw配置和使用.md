---
title: win环境OpenClaw配置和使用
date: 2026-03-29 15:15:00
categories: [AI, openclaw]
tags: [AI, openclaw, feishu]
image:
  path: /assets/img/posts/common/openclaw.jpg
---

# win环境OpenClaw配置和使用

本文按 **安装 → 配置 → 使用** 的顺序整理 OpenClaw 在本地的常用操作，并收录 **飞书联调要点** 与 **常见问题**。关键处附有官方文档链接，便于对照与排障。OpenClaw 版本与 CLI 行为可能随发布变化，请以当时官网与 `openclaw --help` 为准。

---

## 一、安装与升级

### 1.1 通过 npm 安装

```bash
npm i -g openclaw@latest
openclaw --version
```

需本机已安装 **Node.js**（建议 LTS）。其他安装方式见官方文档。

### 1.2 升级方式

**推荐**（可识别 npm / git 等安装类型，并执行 `openclaw doctor`，默认成功后可能重启网关）：

```bash
openclaw update
openclaw update status
openclaw update --dry-run
openclaw update wizard
openclaw --update
```

**备选**：直接重装全局包：

```bash
npm i -g openclaw@latest
# 或 pnpm add -g openclaw@latest
```

升级后建议：`openclaw doctor`、`openclaw gateway restart`（若以服务运行）、`openclaw health`。查看线上版本：`npm view openclaw version`；固定版本：`npm i -g openclaw@<版本号>`。

官方说明：[Updating](https://docs.openclaw.ai/install/updating) · [`openclaw update`](https://docs.openclaw.ai/cli/update)

### 1.3 升级前停止网关（强烈建议）

**升级前请先停止正在运行的 `openclaw gateway`**，再执行 `openclaw update` 或 `npm i -g`。

- **前台**：在运行网关的终端 **Ctrl+C**。  
- **服务 / 计划任务**：`openclaw gateway stop`，或在任务管理器中结束相关 **Node.js** 进程。  

在 **Windows** 上，若网关未停，`npm` 覆盖全局 `node_modules\openclaw` 时可能报 **`EBUSY: resource busy or locked`**（原生 `.node` 被占用）。升级完成后再启动网关。

### 1.4 可选：自动更新

可在 `openclaw.json` 中配置 `update.auto.enabled` 等（见 [Updating](https://docs.openclaw.ai/install/updating)）。网关启动时也可能提示新版本（可通过 `update.checkOnStart` 等关闭，以文档为准）。

---

## 二、配置文件与用户目录

### 2.1 配置文件路径

| 项 | 说明 |
| --- | --- |
| 主配置 | 可选 JSON5 文件 **`~/.openclaw/openclaw.json`**；缺失时使用内置默认。 |
| Windows 常见路径 | `C:\Users\<用户名>\.openclaw\openclaw.json`（Git Bash 中 `~` 常对应 `/c/Users/<用户名>`）。 |
| 查看当前生效路径 | `openclaw config file` |

### 2.2 路径何时变化

- **`openclaw --dev`**：状态与配置隔离在 **`~/.openclaw-dev`**。  
- **`openclaw --profile <name>`**：隔离在 **`~/.openclaw-<name>`**；环境变量 **`OPENCLAW_STATE_DIR`**、**`OPENCLAW_CONFIG_PATH`** 随 profile 变化。  

以当前终端下 **`openclaw config file`** 输出为准。

### 2.3 格式、热加载与环境变量

- 配置文件为 **JSON5**。  
- 可直接编辑 `openclaw.json`；网关通常会监视文件并 **热加载**（以官方文档为准）。  
- 部分环境变量可放在 **`~/.openclaw/.env`**。  

详见：[Configuration](https://docs.openclaw.ai/gateway/configuration)

### 2.4 常用 `config` 命令

```bash
openclaw config file
openclaw config validate
openclaw config get agents.defaults.workspace
openclaw doctor
```

### 2.5 配置相关官方链接

- 配置总览：<https://docs.openclaw.ai/gateway/configuration>  
- CLI：<https://docs.openclaw.ai/cli>  
- 配置项完整参考：<https://docs.openclaw.ai/gateway/configuration-reference>  

---

## 三、网关、Token 与 Dashboard

本节对应：[Gateway CLI](https://docs.openclaw.ai/cli/gateway)、[dashboard](https://docs.openclaw.ai/cli/dashboard)、[onboard](https://docs.openclaw.ai/cli/onboard)。

### 3.1 本地网关须设置 `gateway.mode`

仅有 **`gateway.auth`**（如 token）**不够**：须显式声明在本机运行网关，否则可能提示：

`Gateway start blocked: set gateway.mode=local (current: unset) or pass --allow-unconfigured.`

在 **`gateway`** 段增加 **`"mode": "local"`**（与 `auth` 并列）。临时可用 **`openclaw gateway --allow-unconfigured`**；长期使用建议写配置。

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

### 3.2 启动网关

前台（二选一）：

```bash
openclaw gateway
openclaw gateway run
```

常用参数：

| 参数 | 作用 |
| --- | --- |
| `--port <端口>` | WebSocket 端口（常见 `18789`） |
| `--token <令牌>` | 覆盖本次进程 Token，相当于设置 `OPENCLAW_GATEWAY_TOKEN` |
| `--allow-unconfigured` | 未配置 `gateway.mode=local` 时仍允许启动（临时/开发） |
| `--dev` | 开发配置与隔离状态（见 `openclaw --help`） |
| `--force` | 端口被占用时先释放再启动 |

**说明**：没有 `press --allow` 类子命令；对应的是 **`--allow-unconfigured`**。

作为系统服务：

```bash
openclaw gateway install
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw gateway status
```

### 3.3 网关 Token 的来源与查看

1. **`openclaw onboard`** 的 quickstart 等流程可生成并写入配置。  
2. **`openclaw.json`** 中 `gateway.auth.token`（或 SecretRef）。  
3. 环境变量 **`OPENCLAW_GATEWAY_TOKEN`**。  
4. **`openclaw gateway install`** 可传 `--token`（以文档为准）。  

```bash
openclaw config get gateway.auth.token
```

SecretRef 场景请按 `openclaw secrets` 文档解析，勿向不可信环境粘贴 Token。

### 3.4 Dashboard（控制台 UI）

本机能连上网关且 CLI 能解析鉴权时：

```bash
openclaw dashboard
openclaw dashboard --no-open
```

SecretRef 管理 Token 时，可能打印 **不含明文 Token** 的 URL（安全行为）。远程探测示例：

```bash
openclaw gateway health --url ws://127.0.0.1:18789
# 按文档显式传入 --token 或 --password
```

### 3.5 建议操作顺序（新手）

1. `openclaw onboard` 或 `openclaw configure`。  
2. 确认 **`gateway.mode: "local"`** 后执行 **`openclaw gateway`**（或临时 `--allow-unconfigured`）。  
3. **`openclaw dashboard`**（网关以前台运行时，通常需 **另开终端** 执行本命令）。  
4. 排障：`openclaw doctor`、`openclaw gateway status`、`openclaw gateway probe`。

---

## 四、接入小米 MiMo 大模型

### 4.1 文档与密钥来源

- 小米开放平台集成页：<https://platform.xiaomimimo.com/#/docs/integration/open-claw>（浏览器打开；前端站点不宜整页抓取）。  
- OpenClaw 官方 Xiaomi 说明：[Xiaomi MiMo](https://docs.openclaw.ai/providers/xiaomi)。  
- 创建 API Key：<https://platform.xiaomimimo.com/#/console/api-keys>  

### 4.2 接口概要

| 项 | 说明 |
| --- | --- |
| Base URL | `https://api.xiaomimimo.com/v1` |
| API 类型 | `openai-completions` |
| 鉴权 | `Authorization: Bearer <API Key>`，环境变量常用 **`XIAOMI_API_KEY`** |

### 4.3 模型引用（`xiaomi/<模型 id>`）

| 模型 id | 说明 |
| --- | --- |
| `mimo-v2-flash` | 默认文本，上下文约 262144 tokens |
| `mimo-v2-pro` | 推理文本，上下文约 1048576 tokens |
| `mimo-v2-omni` | 多模态（文本+图），上下文约 262144 tokens |

默认主模型示例：`xiaomi/mimo-v2-flash`。

### 4.4 CLI 快速接入

```bash
openclaw onboard --auth-choice xiaomi-api-key
openclaw onboard --auth-choice xiaomi-api-key --xiaomi-api-key "$XIAOMI_API_KEY"
```

已设置 `XIAOMI_API_KEY` 或对应 auth 时，可能自动注入 `xiaomi` 提供方：[Model providers](https://docs.openclaw.ai/concepts/model-providers)。

### 4.5 手动编辑 `openclaw.json` 示例（JSON5）

可与现有 `agents`、`channels` 等合并。

```json5
{
  env: { XIAOMI_API_KEY: "你的API密钥" },
  agents: { defaults: { model: { primary: "xiaomi/mimo-v2-flash" } } },
  models: {
    mode: "merge",
    providers: {
      xiaomi: {
        baseUrl: "https://api.xiaomimimo.com/v1",
        api: "openai-completions",
        apiKey: "XIAOMI_API_KEY",
        models: [
          {
            id: "mimo-v2-flash",
            name: "Xiaomi MiMo V2 Flash",
            reasoning: false,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 262144,
            maxTokens: 8192,
          },
          {
            id: "mimo-v2-pro",
            name: "Xiaomi MiMo V2 Pro",
            reasoning: true,
            input: ["text"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 1048576,
            maxTokens: 32000,
          },
          {
            id: "mimo-v2-omni",
            name: "Xiaomi MiMo V2 Omni",
            reasoning: true,
            input: ["text", "image"],
            cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0 },
            contextWindow: 262144,
            maxTokens: 32000,
          },
        ],
      },
    },
  },
}
```

**安全**：勿将真实 Key 提交到 Git；可用 `openclaw secrets configure`、SecretRef 或 **`~/.openclaw/.env`**（见第二节）。

### 4.6 配置后检查

```bash
openclaw config validate
openclaw models list
```

---

## 五、多智能体与频道路由

官方文档：[Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)、[`openclaw agents`](https://docs.openclaw.ai/cli/agents)。

### 5.1 单个智能体包含什么

每个 **`agentId`** 大致包含：**独立工作区**、**独立 `agentDir`**（勿多智能体共用）、**独立会话存储**。同一 Gateway 上，入站消息由 **`bindings`** 路由到对应 `agentId`。

### 5.2 用 CLI 添加智能体

```bash
openclaw agents add work --workspace ~/.openclaw/workspace-work
openclaw agents add coding --workspace ~/.openclaw/workspace-coding
openclaw agents list
openclaw agents set-identity --agent work --name "工作助手" --emoji "💼"
openclaw agents delete work
```

### 5.3 路由绑定（CLI）

```bash
openclaw agents bindings
openclaw agents bindings --json
openclaw agents bind --agent work --bind telegram:ops
openclaw agents unbind --agent work --bind telegram:ops
openclaw agents unbind --agent work --all
```

省略 `accountId` 时通常只匹配频道默认账号；更具体匹配优先；同 agent 的频道级绑定可被账号级绑定**升级**而非重复堆积（细节以官方文档为准）。

### 5.4 在 `openclaw.json` 中手写

维护 **`agents.list`** 与根级 **`bindings`**，示例见 [Multi-Agent Routing](https://docs.openclaw.ai/concepts/multi-agent)。

### 5.5 默认智能体与按智能体指定模型

- **`default: true`** 指定默认智能体；否则多回落到 `main` 或列表首项。  
- 在 **`agents.list[]`** 中设置 **`model`**（如 `xiaomi/mimo-v2-pro`）可与全局 `agents.defaults.model` 组合使用。

### 5.6 修改后检查

```bash
openclaw config validate
openclaw agents list --bindings
openclaw channels status --probe
```

### 5.7 相关链接

- <https://docs.openclaw.ai/concepts/multi-agent>  
- <https://docs.openclaw.ai/cli/agents>  
- <https://docs.openclaw.ai/gateway/configuration-reference#multi-agent-routing>  

---

## 六、飞书渠道要点

> 以下为飞书与 OpenClaw 联调备忘；菜单名称以飞书开放平台当前界面为准。OpenClaw 飞书频道文档：<https://docs.openclaw.ai/channels/feishu>

### 6.1 长连接与实例数量

飞书机器人通过 **WebSocket 长连接** 收事件，**同一时刻通常只能有一个连接实例**。若旧环境 **`openclaw gateway` 仍在运行**，新环境常 **收不到消息**。

### 6.2 收不到消息时的排查

1. 停止所有旧实例上的网关（或服务）。  
2. 仅在当前环境启动 **Gateway**，再于飞书发消息验证。  
3. 不确定旧实例所在机器时：排查各机 **gateway 进程/服务**，或采用 **6.3** 在开放平台重置事件订阅。

### 6.3 开放平台重置事件订阅

在飞书开放平台对应应用：**事件与回调** → **事件配置** → 搜索 **`im.message.receive_v1`**（或实际订阅的 IM 事件）→ **删除后重新添加**，以强制断开旧连接；再确保本机 **Gateway 已启动** 后复测。

### 6.4 首次私聊与配对码

首次对话可能返回配对码，在终端执行（以 `openclaw pairing --help` 为准）：

```bash
openclaw pairing list feishu
openclaw pairing approve feishu <配对码>
```

---

## 七、常见问题与排障

### 7.1 npm 全局升级后，配置还在吗

**还在。** `npm i -g openclaw@latest` 只更新全局包目录下的 CLI，**不会**按惯例删除 **`~/.openclaw/`**（含 `openclaw.json`、工作区、credentials 等）。大版本升级后请运行 **`openclaw doctor`**。**`openclaw uninstall`** 类命令才可能清理用户数据，与单纯 `npm i -g` 不同。

### 7.2 模型报错 402 或余额不足

日志中出现 **`402 Insufficient account balance`** 等时，表示请求已到小米侧，但 **账号余额/额度不足**（或套餐问题）。需在 [小米开放平台](https://platform.xiaomimimo.com/) 检查计费与 Key，而非仅改 OpenClaw 语法。

### 7.3 Dashboard 与网关终端

**`openclaw gateway` 在前台运行时会占用当前终端**，一般需在 **另一个终端** 中执行 **`openclaw dashboard`**；或将网关安装为服务后在后台运行。

### 7.4 通用排障命令

```bash
openclaw doctor
openclaw config validate
openclaw gateway status
openclaw gateway probe
openclaw health
```

---

## 附录：官方文档索引

| 主题 | 链接 |
| --- | --- |
| OpenClaw 文档首页 | <https://docs.openclaw.ai/> |
| 安装与升级 | <https://docs.openclaw.ai/install/updating> |
| 网关配置 | <https://docs.openclaw.ai/gateway/configuration> |
| CLI | <https://docs.openclaw.ai/cli> |
| Gateway CLI | <https://docs.openclaw.ai/cli/gateway> |
| dashboard | <https://docs.openclaw.ai/cli/dashboard> |
| onboard | <https://docs.openclaw.ai/cli/onboard> |
| 小米 MiMo（OpenClaw） | <https://docs.openclaw.ai/providers/xiaomi> |
| 飞书频道 | <https://docs.openclaw.ai/channels/feishu> |
| 多智能体 | <https://docs.openclaw.ai/concepts/multi-agent> |

---

*文档整理：2026-03-29；小米 MiMo 配置依据 OpenClaw 官方 Xiaomi 文档，小米集成页请以浏览器打开为准。2026-03-30 调整章节目录与命名。*
