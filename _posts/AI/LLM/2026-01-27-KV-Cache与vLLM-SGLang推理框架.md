---
title: KV Cache与vLLM、SGLang推理框架
date: 2026-01-27 14:00:00
categories: [AI, LLM]
tags: [AI, LLM, vLLM, SGLang]
image:
  path: /assets/img/posts/common/llm.jpg
---

# KV Cache与vLLM、SGLang推理框架

> 本文介绍 KV Cache 在大模型推理中的地位与资源估算、vLLM 与 SGLang 的异同、二者对 KV Cache 的利用方式、使用策略与首字延迟的关系，以及基于两者部署小模型并进行对话验证的步骤。

---

## 目录

- [0. KV Cache 在大模型技术中的地位与资源估算](#0-kv-cache-在大模型技术中的地位与资源估算)
  - [0.1 地位与作用](#01-地位与作用)
  - [0.2 根据参数量估算 KV Cache 资源占用](#02-根据参数量估算-kv-cache-资源占用)
  - [0.3 在哪里配置](#03-在哪里配置)
- [1. vLLM 与 SGLang 简介与对比](#1-vllm-与-sglang-简介与对比)
  - [1.1 vLLM 简介](#11-vllm-简介)
  - [1.2 SGLang 简介](#12-sglang-简介)
  - [1.3 相同点与不同点](#13-相同点与不同点)
  - [1.4 其他类似推理框架及区别](#14-其他类似推理框架及区别)
- [1.5 vLLM 与 Ollama 的部署形态对比](#15-vllm-与-ollama-的部署形态对比)
- [2. vLLM 与 SGLang 如何利用 KV Cache](#2-vllm-与-sglang-如何利用-kv-cache)
- [3. KV Cache 的使用策略](#3-kv-cache-的使用策略)
- [4. KV Cache 与首字延迟的关系](#4-kv-cache-与首字延迟的关系)
- [5. 使用 vLLM 与 SGLang 部署小模型与对话验证](#5-使用-vllm-与-sglang-部署小模型与对话验证)
  - [5.1 vLLM 部署与验证](#51-vllm-部署与验证)
  - [5.2 SGLang 部署与验证](#52-sglang-部署与验证)

---

## 0. KV Cache 在大模型技术中的地位与资源估算

### 0.1 地位与作用

**KV Cache（Key-Value Cache）** 是 Transformer 自回归推理中的核心优化手段之一。

- **作用**：在自回归生成时，每个新 token 都依赖此前所有 token 的 Key、Value。若每次都重算整段历史，计算量会随序列长度线性增长。KV Cache 把已算过的 K、V 存起来重复使用，避免对历史 token 的重复计算，从而显著加速解码。
- **地位**：推理阶段显存主要由「模型参数 + KV Cache + 少量激活」构成。长序列、大 batch 时，KV Cache 常是除模型权重外的最大显存来源，也是吞吐与延迟调优的主要对象。

### 0.2 根据参数量估算 KV Cache 资源占用（速算）

用 **float16** 存 KV 时，可按下面经验公式速算：

**速算公式**：

```
KV Cache (GB) ≈ 参数量(十亿) × 序列长(千 token) × batch ÷ 14
```

**公式里各量指什么**：

1. **序列长**：是**单次请求**里「输入 token + 输出 token」的**总长度上限**，也就是你为这一条请求分配的最大上下文长度（通常对应配置里的 `max_model_len` / `context_length`）。不是「你一句话说了几个 token」，而是整次请求在推理过程中会用到的总 token 数；多轮对话时，一般会把历史 + 当前输入 + 预留输出一起算进这段长度。

2. **参数量为什么出现在公式里**：模型参数和 KV cache 都在 GPU 显存里，但占的是**不同的区域**——权重一块、KV 一块，互不重叠。公式里的「参数量」**不是**说“参数量占用了 KV 的显存”，而是用参数量当作**模型规模的代表量**，用来推算「每个 token 的 KV 要占多少显存」。因为每个 token 的 KV 体积由层数、hidden_size 等决定，这些量和参数量同向变化，所以用 7B/70B 这种大家熟悉的数代替“查 config 算 L×hidden_size”，纯属为了**估算 KV 本身占多少显存**——参数量只是公式的输入，真正占用 KV 那块显存的只有 KV cache 自己。

**记法**：7B 模型、1K 序列、batch=1 约 **0.5 GB**；参数量或序列长翻倍，KV 显存大致翻倍。

**详细计算与换算说明**：

1. **代入速算公式**（参数量用十亿、序列长用千 token）：
   ```
   KV (GB) = 7 × 1 × 1 ÷ 14 = 0.5  ⇒  7B、1K、batch=1 约 0.5 GB
   ```

2. **除数「14」从哪来**：在 fp16、常见 LLaMA 类结构下，由「7B、10K token、batch=1 ≈ 5 GB」反推得到：
   ```
   参数量(十亿)×序列长(千)×batch ÷ KV(GB) = 7×10×1 ÷ 5 ≈ 14
   ```
   因此速算统一写成分母 14；GQA 等结构会有偏差，量级可继续沿用。

3. **与精确形式的对应**（便于查 config 自算）：单 token 的 KV 显存（bytes）为
   ```
   2 × 2 × L × hidden_size = 4 × L × hidden_size
   ```
   （前一个 2 表示 K、V 两套，后一个 2 表示 fp16 占 2 字节）。总 KV（GB）= 上述单 token × 序列长 × batch ÷ 10^9。用「参数量(十亿)×序列长(千)×batch÷14」是上式在典型结构下的近似。

**示例**：

| 模型   | 序列长   | batch | KV Cache 约 |
|--------|----------|-------|-------------|
| 7B     | 4K token | 1     | ≈ 2 GB      |
| 7B     | 8K       | 4     | ≈ 16 GB     |
| 70B    | 4K       | 1     | ≈ 20 GB     |

根据「最大序列长 × 最大并发」估出 KV 显存后，再结合模型权重显存定单卡/多卡或量化方案。

### 0.3 在哪里配置

KV Cache 的「容量与使用方式」通常由推理引擎和部署参数共同决定，而不是在模型权重里单独存一份「KV 配置」。常见配置入口包括：

| 层级         | 配置含义与典型位置 |
|--------------|--------------------|
| **推理引擎** | 在 vLLM、SGLang、TensorRT-LLM 等启动参数或配置文件中，设置 **max_model_len / max_num_seqs**、**gpu-memory-utilization** 等，间接决定可用于 KV Cache 的显存和最大序列数。 |
| **vLLM**     | `--max-model-len`、`--gpu-memory-utilization`、`--max-num-seqs` 等；引擎按块（block）分配 KV，块大小多由实现固定或通过少量环境变量/内部选项调节。 |
| **SGLang**   | `--mem-fraction-static`、`--context-length`、`--max-total-tokens` 等，以及 RadixAttention 相关参数，影响 KV 内存布局与复用。 |
| **应用/编排** | 若使用 Kubernetes、Docker 或云托管，在资源配置（GPU 显存、实例数）与推理服务参数中，限制「单实例最大序列长度 / 并发数」，从而约束 KV 使用上界。 |

因此：「根据参数量估算出 KV 需要多少显存」后，是在 **推理引擎的启动参数或部署配置** 里，通过「最大序列长度、最大 batch、显存占用比例」等来做分配与限流，而不是在模型文件里写死。

---

## 1. vLLM 与 SGLang 简介与对比

### 1.1 vLLM 简介

**vLLM** 是面向高吞吐、低延迟的大模型推理引擎，核心思想包括：

- **PagedAttention**：把 KV Cache 按「块（block）」管理，类似操作系统分页，减少显存碎片，提高利用率。
- **Continuous Batching**：请求以「连续批」的方式调度，新请求随时加入、完成请求随时释放，提高 GPU 利用率。
- 接口上兼容 **OpenAI API**，便于替换现有调用方式。

适合高并发、序列长度不一、以「标准文本生成」为主的线上推理场景。

### 1.2 SGLang 简介

**SGLang** 在保证高吞吐的同时，更强调 **结构化输出与复杂控制流**：

- **RadixAttention**：用 Radix Tree 管理 KV Cache，对「公共前缀」（如系统提示、多轮对话的历史）做复用，减少重复计算与显存。
- **前端语言**：提供一套类似「指令式」的接口，方便描述分支、循环、工具调用、约束输出格式等，适合 Agent、多轮对话、复杂推理。
- 在多轮对话、共享前缀多的场景下，吞吐和首字延迟常有明显优势。

适合多轮对话、RAG、Agent、需要 JSON/工具调用等结构化输出的场景。

### 1.3 相同点与不同点

| 维度       | vLLM                          | SGLang                                |
|------------|-------------------------------|----------------------------------------|
| 设计目标   | 高吞吐、高并发、内存利用率    | 高吞吐 + 灵活控制流与结构化输出       |
| KV 管理    | PagedAttention（分块、碎片少）| RadixAttention（前缀复用、共享多）    |
| 批处理     | Continuous Batching          | 类似连续批 + 与前端控制流结合         |
| 典型场景   | 高并发、变长、标准生成        | 多轮对话、工具调用、结构化输出        |
| 首字/吞吐  | 基准                          | 多轮与长前缀场景下常更优（如首字更低、吞吐更高）|
| API        | OpenAI 兼容                   | OpenAI 兼容 + 自有前端 API            |

两者都依赖「高效 KV Cache 管理」提升推理效率，只是实现路径不同：vLLM 偏「内存与调度」，SGLang 偏「前缀复用与控制流」。

### 1.4 其他类似推理框架及区别

除 vLLM、SGLang 外，常见推理框架还有：

| 框架             | 特点简述 | 与 vLLM/SGLang 的差异 |
|------------------|----------|------------------------|
| **TensorRT-LLM** | NVIDIA 官方，针对自家 GPU 深度优化；支持 KV Cache 早期复用、量化等。 | 偏「单机极致性能」和生态绑定，灵活性和生态广度一般不如 vLLM。 |
| **TGI (Text Generation Inference)** | Hugging Face 出品，内置连续批、量化等。 | 更贴近 HF 生态，易与 HF 模型和 Hub 集成；性能调优维度通常不如 vLLM 丰富。 |
| **LMDeploy**     | 支持多种后端（如 TurboMind），强调端侧与多卡部署。 | 更适合需要「多后端、多形态部署」的团队，和国内模型/工具有较好结合。 |
| **llama.cpp**    | CPU/部分 GPU、量化优先，单文件部署简单。 | 面向轻量、边缘或本地调试，不强调高并发与 KV 的「服务化」管理。 |

共同点多是：都在「减少重复计算、提高显存利用率、提升吞吐/首字」上做文章；差异主要体现在「谁更偏通用服务、谁更偏厂商生态、谁更偏控制流与结构化」等。

### 1.5 vLLM 与 Ollama 的部署形态对比

常有人问：**vLLM 能否像 Ollama 那样服务化部署和管理多个模型，而不只是在 py 依赖里拉起？**

**结论**：可以做到类似效果，但 vLLM 本身不是「单进程多模型管理」，需要借助路由或编排层。

| 维度       | Ollama                    | vLLM 原生                         |
|------------|----------------------------|-----------------------------------|
| 运行方式   | 常驻服务，`ollama serve`    | 每个模型一个进程，`vllm serve <model>` |
| 多模型     | 单进程管理多个模型，`ollama run xxx` 切换 | 单进程只加载一个模型               |
| 模型管理   | `ollama pull/list/rm` 统一管理 | 无内置模型管理，需自行拉模型、起进程 |
| 部署形态   | 装好即用，类似「模型服务器」 | 更像「推理引擎」，多模型需自行编排 |

**vLLM 实现多模型服务化的常见做法**：

1. **多实例 + 路由**：每个模型起一个 vLLM 进程（不同端口），前面加 Nginx 或自写 Gateway，按请求里的 `model` 字段转发到对应实例。
2. **Ray Serve**：用 Ray Serve 的 `LLMRouter` + `LLMServer`，可部署多模型并自动路由、扩缩容，需引入 Ray 环境。
3. **K8s + Helm（vLLM 生产堆栈）**：官方 Helm Chart 支持多模型、模型感知路由，适合生产。
4. **Docker Compose**：每个模型一个容器，用 Compose 编排，再配合简单路由。

**关于「是否只能在 py 依赖里拉起」**：不是。vLLM 可用 `vllm serve` 命令行、Docker 镜像、K8s 等方式部署，不一定要在 Python 代码里启动。

---

## 2. vLLM 与 SGLang 如何利用 KV Cache

- **vLLM**  
  - 用 **PagedAttention** 把 KV 切成固定大小块，按块分配与回收，类似虚拟内存。  
  - 好处：显存碎片少、利用率高，便于做 **Continuous Batching**，在不同长度、不同进度的请求之间复用显存。  
  - 对「前缀相同」的请求，vLLM 也能做前缀缓存（如通过块级复用），但前缀复用并非其首要设计重点。

- **SGLang**  
  - 用 **RadixAttention** 以 **Radix Tree** 组织 KV：相同前缀只存一份，多请求或多轮对话共享。  
  - 适合系统提示相同、多轮历史相同或高度重叠的场景，能明显减少 prefill 计算和 KV 占用，从而提升首字延迟和吞吐。  
  - 在「共享前缀多」的负载下，相比「每请求独立 KV」的 baseline，SGLang 对 KV 的利用更「集约」。

因此：**vLLM 主要通过「块式管理 + 连续批」提升 KV 的显存利用与调度效率；SGLang 在此基础上，通过「前缀级共享」进一步减少 KV 的重复计算与占用。**

---

## 3. KV Cache 的使用策略

可以根据「算力与访存」的主瓶颈，粗分为几类思路（实际引擎会组合使用）：

| 策略类型       | 思路简述 | 典型技术 |
|----------------|----------|----------|
| **计算密集优化** | 减少「大算力」阶段的 token 数或计算量。 | **投机采样（Speculative Decoding）**：小模型先草稿若干 token，大模型再并行验证，可明显降低「大模型自回归步数」。 |
| **访问/显存密集** | 提高 KV 的复用率、减少重复计算与冗余存储。 | **Prefix / Radix 等前缀缓存**：多请求或多轮共享相同前缀的 KV；**KV 量化（INT4/INT8 等）**：在可控精度损失下减小显存。 |
| **调度与系统**   | 让 prefill 与 decode 更好重叠，或按负载调节 KV 容量。 | **Chunked Prefill**：把长 prompt 切成块，使 prefill 与 decode 并行；**滑动窗口 + 混合 KV 管理**：控制长序列下的缓存增长。 |

实践中需要根据「请求长度、并发、是否多轮、是否共享前缀」等特征，在「批大小、最大序列长度、是否开前缀复用、是否开投机采样」之间做权衡；这些都会落到「能给 KV 多少显存、怎么用」上。

---

## 4. KV Cache 与首字延迟的关系

**首字延迟（TTFT，Time To First Token）** 主要对应 **prefill 阶段**：把整段 prompt 算完并产出第一个 token 的时间。

- **直接关系**：  
  - Prefill 要为整段 prompt 计算并写入 KV Cache；**KV 的容量与分配策略**会影响 prefill 能否顺畅完成（例如是否会因显存不足而等待或失败）。  
  - 若采用 **前缀缓存 / RadixAttention**，相同前缀可直接复用已有 KV，**跳过这部分 prefill**，从而缩短首字延迟。

- **间接关系**：  
  - 若把更多显存留给 KV（或提高块利用率），同一时刻能接受的 prefill 请求更多，排队更少，TTFT 更稳定。  
  - 有些系统会做「KV 早期复用」：例如共享系统提示的请求复用同一份 KV，使首 token 延迟显著下降（文献与实践中常有数倍提升）。

因此：**KV Cache 的容量、管理方式（尤其是前缀复用、共享策略）会明显影响首字延迟**；「更多 KV」不一定直接加快首字，但「更好的复用与调度」通常会。

---

## 5. 使用 vLLM 与 SGLang 部署小模型与对话验证

以下以 **7B 级小模型** 为例，给出两种方式的部署命令与最小对话验证步骤。环境需已安装对应 Python 包、CUDA 与足够显存（7B fp16 建议 ≥16GB）。

### 5.1 vLLM 部署与验证

**安装：**

```bash
pip install vllm
```

**启动服务（示例：Qwen2-7B，按需替换模型名或本地路径）：**

```bash
python -m vllm.entrypoints.openai.api_server \
  --model Qwen/Qwen2-7B-Instruct \
  --served-model-name Qwen2-7B-Instruct \
  --host 0.0.0.0 \
  --port 8000
```

如需限制长度与显存占用，可加：

- `--max-model-len 4096`
- `--gpu-memory-utilization 0.9`

**对话验证：**

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen2-7B-Instruct",
    "messages": [{"role": "user", "content": "你好，请用一句话介绍你自己。"}],
    "max_tokens": 128
  }'
```

**对话验证步骤（简要）**：

1. 确认服务已启动且日志中有 `Uvicorn running on http://0.0.0.0:8000` 等提示。
2. 使用上述 `curl` 或 OpenAI 兼容客户端（`base_url=http://localhost:8000/v1`）发送一条 `/v1/chat/completions` 请求。
3. 检查返回 JSON 中的 `choices[0].message.content` 是否有正常文本；若有，则说明部署与对话链路正常。

### 5.2 SGLang 部署与验证

**安装：**

```bash
pip install "sglang[all]"
```

**启动服务：**

```bash
python -m sglang.launch_server \
  --model-path Qwen/Qwen2-7B-Instruct \
  --host 0.0.0.0 \
  --port 30000
```

可按需增加：`--context-length 4096`、`--mem-fraction-static 0.9` 等。

**对话验证：**

SGLang 也提供 OpenAI 兼容接口，例如：

```bash
curl http://localhost:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2-7B-Instruct",
    "messages": [{"role": "user", "content": "你好，请用一句话介绍你自己。"}],
    "max_tokens": 128
  }'
```

**对话验证步骤（简要）**：

1. 确认服务已启动；若未指定 `--port`，注意控制台输出的实际端口（如 34325）。
2. 向 `http://localhost:30000/v1/chat/completions`（或实际端口）发送请求，body 中 `model` 可填 `Qwen/Qwen2-7B-Instruct` 或与 `--model-path` 一致。
3. 检查返回中的 `choices[0].message.content` 是否有正常回复；若有，则部署与对话验证通过。

若使用 Python，可统一用 `openai` 库，仅修改 `base_url` 和 `model` 在 8000（vLLM）与 30000（SGLang）之间切换，对比同一 prompt 的首字延迟与输出。

---

## 小结

- **KV Cache** 是自回归推理里「省算力、占显存」的核心手段；其容量可由层数、头数、头维、序列长与 batch 估算，并在 **推理引擎的启动/部署参数** 中配置。
- **vLLM** 以 PagedAttention + Continuous Batching 见长，适合高并发、标准生成；**SGLang** 以 RadixAttention 与结构化控制见长，在多轮与共享前缀场景下对 KV 利用更充分。
- 两者都深度依赖 KV Cache 的合理分配与复用；前缀复用、投机采样等策略可进一步降低首字延迟与显存压力。按序列与并发需求选好引擎与参数后，用上述命令即可快速完成小模型部署与对话验证。
