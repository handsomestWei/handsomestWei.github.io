---
title: SGLang在win的wsl部署使用
description: >-
  Windows 上不装原生 SGLang，改走 WSL2 Ubuntu：驱动复用宿主机，PyTorch 与 CUDA 运行库必须装 Linux 轮子。与 vLLM 共用 Hugging Face 缓存、另建虚拟环境。用 uv 安装后给 DeepEP 指定 CUDA_HOME，注意力与采样改走 Triton / PyTorch，避开 FlashInfer JIT，即可把 OpenAI 兼容对话跑通。
date: 2026-10-03 13:00:25
categories: [AI, LLM]
tags: [AI, LLM, SGLang, WSL]
image:
  path: /assets/img/posts/common/llm.jpg
---

# SGLang在win的wsl部署使用

> 在 **Windows 11 + WSL2 Ubuntu** 上部署 **SGLang**，用小参数 Instruct 模型走通「装环境 → 起服务 → chat completions」。原生 Windows 没有官方轮子；与已有的 vLLM 共用同一份权重缓存，**不要共用同一套虚拟环境**。下文是一条可复现的工程路径，不是吞吐评测。

**参考与延伸阅读**：

- SGLang 安装：<https://docs.sglang.io/docs/get-started/install>
- SGLang Quickstart：<https://docs.sglang.io/docs/get-started/quickstart>
- SGLang Attention Backend：<https://docs.sglang.io/docs/advanced_features/attention_backend>
- uv：<https://docs.astral.sh/uv/>
- Qwen2.5-0.5B-Instruct：<https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct>
- Hugging Face 镜像：<https://hf-mirror.com/>
- FlashInfer：<https://github.com/flashinfer-ai/flashinfer>
- SGLang Native API：<https://docs.sglang.io/basic_usage/native_api.html>
- SGLang Production Metrics：<https://docs.sglang.io/docs/references/production_metrics>

---

## 目录

- [1. 结论与边界](#1-结论与边界)
- [2. 驱动复用与独立环境](#2-驱动复用与独立环境)
- [3. 安装 uv 与 Python 环境](#3-安装-uv-与-python-环境)
- [4. 国内源与 403](#4-国内源与-403)
- [5. 安装 SGLang](#5-安装-sglang)
- [6. CUDA_HOME 与 DeepEP](#6-cuda_home-与-deepep)
- [7. FlashInfer 改走 Triton](#7-flashinfer-改走-triton)
- [8. 启动 0.5B 并验证对话](#8-启动-05b-并验证对话)
- [9. 模型缓存路径与查看](#9-模型缓存路径与查看)
- [10. 服务就绪的日志标志](#10-服务就绪的日志标志)
- [11. 运行监测](#11-运行监测)
- [12. 常见问题](#12-常见问题)
- [13. 小结](#13-小结)

---

## 1. 结论与边界

**可以在本地走通部署和推理。** 不要走 Windows 原生 pip，走 **WSL2 Ubuntu + NVIDIA GPU**。消费级笔记本显存有限时，先用 **0.5B / 1.5B Instruct**，上下文锁在 2K 左右；全精度 7B 通常进不去。同一块卡不要同时跑 vLLM 和 SGLang。

| 项 | 本次选择 |
|----|----------|
| 系统 | Windows 11，WSL2 Ubuntu |
| GPU | 宿主机 NVIDIA 独显，WSL 里 `nvidia-smi` 可见 |
| 安装方式 | `uv pip install --prerelease=allow sglang --torch-backend=auto` |
| 虚拟环境 | `~/sglang-lab/.venv`（与 vLLM 分开） |
| 模型 | `Qwen/Qwen2.5-0.5B-Instruct`（可换成 1.5B） |
| 服务 | `sglang serve`，默认端口 **30000**，OpenAI 兼容 `/v1/chat/completions` |

0.5B 能聊天，容量小、回答容易短或跑偏，用来把接口跑通足够。笔记本降频发热时速度变慢，多半是功耗墙，不是框架损坏。

---

## 2. 驱动复用与独立环境

宿主机上的 NVIDIA 驱动可以给 WSL 用；Windows 版 PyTorch **不能**拿到 Ubuntu 里用。

| 层 | 位置 | 处理 |
|----|------|------|
| NVIDIA 驱动 | 只装在 Windows | 不必在 Ubuntu 再装驱动。`nvidia-smi` 能看到同一块卡即已复用 |
| PyTorch / CUDA Runtime / SGLang 的 `.so` | 绑定 Linux Python | **必须再装 Linux 轮子** |
| 模型权重 | Hugging Face 缓存 | 与 vLLM **共用** `HF_HOME` |
| Python 虚拟环境 | 各自一份 | **不要**把 SGLang 装进 vLLM 的 `.venv`，CUDA 扩展和依赖会互相覆盖 |

WSL2 是独立 Linux：自己的文件系统、自己的解释器。Windows 的 `win_amd64` wheel 无法被 Ubuntu 的 Python 加载。SGLang 的 CUDA 扩展按 Linux ABI 编译。

进发行版后先确认 GPU：

```bash
nvidia-smi
```

能列出 NVIDIA 设备再继续。权重和虚拟环境写在 Linux 家目录，不要放到 `/mnt/c`。若 vLLM 正在占用 GPU，先在其启动窗口 **Ctrl+C** 停掉。

---

## 3. 安装 uv 与 Python 环境

在 WSL 的 Ubuntu 终端执行。已装过 uv 时直接 `uv --version` 即可，不必重装。新版安装脚本不一定生成 `~/.local/bin/env`：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv --version
```

另建项目目录，用 uv 拉 CPython 3.12：

```bash
mkdir -p ~/sglang-lab
cd ~/sglang-lab
uv venv --python 3.12 --seed
source .venv/bin/activate
```

提示符出现虚拟环境前缀后再装框架。最小化 Ubuntu 往往没有 `gcc`。SGLang / Triton / FlashInfer 都可能 JIT，缺编译器时先装：

```bash
sudo apt update
sudo apt install -y build-essential
```

资源管理器可用 UNC 浏览，不要去挂载 WSL 的 `ext4.vhdx`：

```text
\\wsl.localhost\<发行版名>\home\<用户名>\sglang-lab
```

---

## 4. 国内源与 403

`uv` 拉 wheel 时，部分 PyPI 镜像会对 `/packages/` 返回 **403**。清华源曾拒过 `pip` 一类 whl。改用阿里云或官方源后重建环境：

```bash
deactivate 2>/dev/null
cd ~/sglang-lab
rm -rf .venv

export UV_DEFAULT_INDEX="https://mirrors.aliyun.com/pypi/simple/"
export UV_TORCH_BACKEND=auto

uv venv --python 3.12 --seed
source .venv/bin/activate
```

阿里云同样 403 时：

```bash
export UV_DEFAULT_INDEX="https://pypi.org/simple"
```

`UV_DEFAULT_INDEX` 只加速普通依赖。`--torch-backend=auto` 仍按本机驱动选择 **CUDA 版** PyTorch，不要单独从国内源装 `torch`，以免落到 CPU 轮子。拉官方 Python 构建若走 GitHub 超时，再考虑 `UV_PYTHON_INSTALL_MIRROR`。

模型下载与 PyPI 不是同一条线，启动前再设：

```bash
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME="$HOME/.cache/huggingface"
```

---

## 5. 安装 SGLang

官方推荐 uv，并允许预发布轮子：

```bash
uv pip install --prerelease=allow sglang --torch-backend=auto
```

终端刷出一长串 `+ 包名==版本` 并回到提示符，即安装成功。体积几个 GB，落在 WSL 家目录所在的虚拟盘。

`sglang` 命令来自该虚拟环境。未激活时要用 `~/sglang-lab/.venv/bin/sglang`。

---

## 6. CUDA_HOME 与 DeepEP

SGLang 在 import 阶段会拉 **DeepEP**。`deep_ep` 用 `CUDA_HOME` / `CUDA_PATH` / `which nvcc` 找工具链，找不到 `/usr/local/cuda` 时直接 `AssertionError`。WSL 通常只复用宿主机驱动，**没有**系统级 CUDA Toolkit。

PyTorch / NVIDIA 轮子会自带 `nvcc`，指向虚拟环境即可，不必再装一份 `/usr/local/cuda`：

```bash
export CUDA_HOME="$VIRTUAL_ENV/lib/python3.12/site-packages/nvidia/cu13"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$CUDA_HOME/lib:${LIBRARY_PATH:-}"

ln -sfn lib "$CUDA_HOME/lib64"
ln -sfn libcudart.so.13 "$CUDA_HOME/lib/libcudart.so"

nvcc --version
ls -l "$CUDA_HOME/lib64/libcudart.so"
```

pip 轮子把运行库放在 `cu13/lib`，且只有带版本号的 `libcudart.so.13`。SGLang 的 RoPE JIT 却按 Toolkit 惯例去链 `lib64` 下的 `-lcudart`，缺符号链接时会报 `cannot find -lcudart`。上面两条 `ln` 做一次即可，不必装系统级 Toolkit。

能打印 CUDA 编译器版本、并且 `lib64/libcudart.so` 能列出来即可。`VIRTUAL_ENV` 在 `source .venv/bin/activate` 之后才有；找不到时用：

```bash
find "$VIRTUAL_ENV" -name nvcc | head
```

把找到的 `.../cu13` 赋给 `CUDA_HOME`。0.5B 稠密模型并不真正走专家并行，但当前版本仍会在 import 时初始化 DeepEP，所以这一步不能省。

NCCL 版本对不上时再加：

```bash
export EP_SUPPRESS_NCCL_CHECK=1
```

---

## 7. FlashInfer 改走 Triton

权重加载成功之后，默认注意力后端是 **FlashInfer**，采样后端也是 FlashInfer。Ada 架构上若没有匹配的预编译核，warmup 会现场 JIT。`nvcc` 来自 pip 轮子、头文件来自 FlashInfer 自带 CCCL 时，常见报错：

```text
CUDA compiler and CUDA toolkit headers are incompatible, please check your include paths
```

随后 scheduler `SIGQUIT`，进程被杀掉。这和「对话接口要不要采样」不是一回事：FlashInfer 是 CUDA 核库，默认用来做注意力和 top-k / top-p。官方文档对 FlashInfer 出问题的卡，建议改 Triton 注意力 + PyTorch 采样：

```bash
--attention-backend triton \
--sampling-backend pytorch
```

| 维度 | 默认 FlashInfer | Triton + PyTorch |
|------|-----------------|------------------|
| 作用 | 注意力与采样走 FlashInfer CUDA 核 | 注意力走 Triton，采样走 PyTorch |
| 生成质量 | 同一套采样公式，不换模型 | 不换模型 |
| 启动依赖 | 需要可编译的 `nvcc` 与匹配头文件 | WSL 体验部署够用 |
| 吞吐 | 匹配预编译核时通常更好 | 单路小模型差别往往不明显 |

笔记本上先关 FlashInfer 路径，只为把服务拉起来。不要为此在 WSL 里再装完整 Toolkit，除非要对比 FlashInfer 吞吐。`--disable-cuda-graph` 已弃用，改用：

```text
--cuda-graph-backend-decode=disabled
--cuda-graph-backend-prefill=disabled
```

CUDA Graph 关掉后笔记本更不容易在捕获阶段 OOM。

---

## 8. 启动 0.5B 并验证对话

把第 4、6 节的环境变量留在当前窗口，再启动。端口用 **30000**，避开 vLLM 常用的 8000。

```bash
sglang serve Qwen/Qwen2.5-0.5B-Instruct \
  --host 0.0.0.0 \
  --port 30000 \
  --context-length 2048 \
  --mem-fraction-static 0.7 \
  --cuda-graph-backend-decode=disabled \
  --cuda-graph-backend-prefill=disabled \
  --attention-backend triton \
  --sampling-backend pytorch \
  --enable-metrics
```

`--mem-fraction-static` 类似 vLLM 的 `--gpu-memory-utilization`。`--enable-metrics` 打开 Prometheus 的 `/metrics`，默认关闭。该窗口会一直占用。另开一个 WSL 会话：

```bash
curl -s http://127.0.0.1:30000/v1/models

curl http://127.0.0.1:30000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "用一句话介绍 SGLang"}],
    "max_tokens": 128
  }'
```

请求体里的 `model` 必须与启动名一致。Windows 浏览器可打开 `http://127.0.0.1:30000/docs`（FastAPI Swagger）。显存仍宽裕可换成 `Qwen/Qwen2.5-1.5B-Instruct`。

---

## 9. 模型缓存路径与查看

未改环境变量时，Hugging Face / SGLang 默认把权重放在 Linux 家目录：

```text
~/.cache/huggingface/hub/models--<组织>--<仓库名>
```

本次 0.5B 对应：

```text
~/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct
```

设置了 `HF_HOME` 时，把上面的 `~/.cache/huggingface` 换成 `$HF_HOME`，默认值与之一致。物理文件在 WSL 文件系统里，不要写到 `/mnt/c`。

资源管理器：

```text
\\wsl.localhost\<发行版名>\home\<用户名>\.cache\huggingface\hub
```

查看体积和目录：

```bash
du -sh ~/.cache/huggingface
ls ~/.cache/huggingface/hub
du -sh ~/.cache/huggingface/hub/models--Qwen--Qwen2.5-0.5B-Instruct
```

同一模型名若已由 vLLM 拉过，日志会出现 `Found local HF snapshot ... skipping download`，**不会整包重下**。换模型名才会再下一份。

---

## 10. 服务就绪的日志标志

出现 `Load weight begin`、`Found local HF snapshot`、`Load weight end`、`KV Cache is allocated` **还不算出就绪**，只是在读权重并划 KV。Uvicorn 已经监听也不够：默认 FlashInfer 会在随后的 warmup（例如 `GET /model_info`）里 JIT，失败则 `Scheduler hit an exception` 后整树退出。

等到类似下面几行，并且进程还在、没有立刻 `SIGQUIT` / `Killed`，服务才真正可请求：

```text
The server is fired up and ready to roll!
Application startup complete
Uvicorn running on http://0.0.0.0:30000
```

下列提示可忽略：未设置 `HF_TOKEN`、`Attention backend not specified`（已显式指定 Triton 后不应再出现 FlashInfer 默认）、`--disable-cuda-graph` 弃用警告（改用第 7 节新参数即可）。

---

## 11. 运行监测

SGLang 没有类似昇腾 `npu-smi info` 的独立命令。HTTP 层是 **FastAPI + Uvicorn**，和 vLLM 一样带 OpenAPI 页面；GPU 占用看 NVIDIA 工具；队列和 KV 看原生接口与 `/metrics`。在 **另一个 WSL 窗口**里执行，不要停掉 `sglang serve`。

**FastAPI 文档页**

默认提供 Swagger 与 OpenAPI：

```text
http://127.0.0.1:30000/docs
http://127.0.0.1:30000/redoc
http://127.0.0.1:30000/openapi.json
```

设了环境变量 `DISABLE_OPENAPI_DOC=1` 时这三个会关掉。页面上能点 `/v1/chat/completions`、`/health`、`/server_info` 等路径，和 curl 是同一套接口。

**GPU（对应 `npu-smi`）**

```bash
nvidia-smi
watch -n 1 nvidia-smi
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv
nvidia-smi pmon -s um
```

服务起来后这里应出现 Python / SGLang 进程。显存大约是权重加上 KV Cache（0.5B、`--mem-fraction-static 0.7` 时日志里 K/V 会再各占一块）。

**进程是否就绪、配置与内部状态**

SGLang **没有** vLLM 那种 `/load`。对应关系：

| 用途 | SGLang |
|------|--------|
| 进程活着 | `GET /health` → `200` |
| 可以接新请求 | `GET /ready` → `200`；启动中为 `503` |
| 探活并真正跑一步生成 | `GET /health_generate` |
| 已加载模型 | `GET /model_info`、`GET /v1/models` |
| 启动参数 + scheduler 内部状态 | `GET /server_info` |

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:30000/health
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:30000/ready
curl -s http://127.0.0.1:30000/model_info
curl -s http://127.0.0.1:30000/v1/models
curl -s http://127.0.0.1:30000/server_info | python -m json.tool | head
```

`/health` 在默认配置下只回状态码、不打 GPU。`/health_generate` 会生成 1 个 token，确认调度器和解码路径还活着。`/server_info` 体积较大，含启动参数和 `internal_states`。

**Prometheus 指标（吞吐、排队、cache）**

必须在启动命令里加 `--enable-metrics`（见第 8 节），否则没有 `/metrics`。

```bash
curl -s http://127.0.0.1:30000/metrics | grep -E "sglang:num_running_reqs|sglang:num_queue_reqs|sglang:token_usage|sglang:cache_hit_rate|sglang:gen_throughput|sglang:prompt_tokens_total|sglang:generation_tokens_total"
```

| 指标 | 含义 |
|------|------|
| `sglang:num_running_reqs` | 正在跑的请求数 |
| `sglang:num_queue_reqs` | 等待队列长度 |
| `sglang:token_usage` | token / KV 使用比例 |
| `sglang:cache_hit_rate` | Radix Cache 命中率 |
| `sglang:gen_throughput` | 生成吞吐（token/s） |

指标名随小版本可能增减，以 `/metrics` 实际输出为准。官方说明见 [Production Metrics](https://docs.sglang.io/docs/references/production_metrics)。笔记本体验部署不必再起 Prometheus / Grafana。

启动窗口里 scheduler 还会按 `decode_log_interval`（默认约 40 步）打 decode 日志，适合盯着 serve 终端看。

| 观测项 | 昇腾习惯 | 本次环境 |
|--------|----------|----------|
| 卡是否在、温度功耗 | `npu-smi info` | `nvidia-smi` |
| 显存 | 同上 | `nvidia-smi` 的 Memory-Usage |
| 推理队列、KV 比例 | 各框架接口 | `/server_info`、`/metrics`、serve 日志 |

---

## 12. 常见问题

| 现象 | 处理 |
|------|------|
| `~/.local/bin/env` 不存在 | 新版 uv 安装脚本可能不再生成该文件；`uv --version` 能跑即可 |
| 清华源 403 | 换阿里云或 `pypi.org`，删掉半成品 `.venv` 再建 |
| DeepEP `assert cuda_home is not None` | 见第 6 节，把 `CUDA_HOME` 指到 venv 里的 `nvidia/cu13` |
| `cannot find -lcudart` / RoPE JIT ninja 失败 | 见第 6 节，补 `lib64` 与 `libcudart.so` 符号链接 |
| NCCL 版本对不上 | `export EP_SUPPRESS_NCCL_CHECK=1` |
| `/docs` 打不开 | 未设 `DISABLE_OPENAPI_DOC`；浏览器访问 `http://127.0.0.1:30000/docs` |
| `/metrics` 404 或无数据 | 启动时加 `--enable-metrics` 后重启；先打几条 chat 再 curl |
| FlashInfer ninja 失败 / 头文件 incompatible | 见第 7 节，改 `--attention-backend triton --sampling-backend pytorch` |
| `Uvicorn running` 后立刻 `SIGQUIT` | warmup JIT 失败，不是权重没下完；换 Triton 后再启 |
| CUDA OOM | 降 `--mem-fraction-static` 到 0.6，或继续用 0.5B、缩短 `--context-length` |
| 与 vLLM 抢显存 / 抢 8000 端口 | 先停掉另一套服务；SGLang 用 30000 |
| 权重落到 `/mnt/c` | 确认 `HF_HOME` 在 `$HOME/.cache/huggingface` |
| 再次 serve 与本地缓存 | 同一仓库已在 `hub/models--*` 下则走缓存；用第 9 节命令确认目录 |

下次进 WSL 后：

```bash
cd ~/sglang-lab
source .venv/bin/activate
export CUDA_HOME="$VIRTUAL_ENV/lib/python3.12/site-packages/nvidia/cu13"
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib:${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$CUDA_HOME/lib:${LIBRARY_PATH:-}"
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME="$HOME/.cache/huggingface"
```

再执行第 8 节的 `sglang serve`。

---

## 13. 小结

| 要点 | 结论 |
|------|------|
| 安装面 | Windows 原生不作为目标；WSL2 + Linux 轮子 |
| 环境 | 与 vLLM 共用权重缓存，分开虚拟环境 |
| 驱动 | 只维护宿主机 NVIDIA 驱动；WSL 复用，不在 Ubuntu 里装 nvidia-driver |
| 磁盘 | 权重和虚拟环境放 Linux 家目录，不要写到 `/mnt/c` |
| 镜像 | uv 拉 whl 遇 403 换源；模型走 `HF_ENDPOINT` |
| 工具链 | DeepEP 需要 `CUDA_HOME`；用 venv 自带 `nvcc`，不必装系统 Toolkit |
| 核路径 | 体验部署用 Triton 注意力 + PyTorch 采样，避开 FlashInfer JIT |
| 验证 | 0.5B Instruct + `/v1/chat/completions` 即可确认部署链路 |
| 监测 | 卡况用 `nvidia-smi`；接口页用 `/docs`；队列和 KV 用 `/ready`、`/server_info`、`--enable-metrics` 后的 `/metrics` |

先把「能起服务、能返回一段 chat」稳住，再换 1.5B，或对照 CUDA Graph 与吞吐。
