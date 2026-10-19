---
title: vLLM在win的wsl部署使用
description: >-
  Windows 上不装原生 vLLM，改走 WSL2 Ubuntu：驱动复用宿主机，PyTorch 与 CUDA 运行库必须装 Linux 轮子。用 uv 建环境，国内镜像遇 403 换源，小参数 Instruct 起 OpenAI 兼容接口；缺 gcc 或 nvcc 时装系统编译器并关闭 FlashInfer 采样，即可把对话跑通。
date: 2026-10-03 12:30:28
categories: [AI, LLM]
tags: [AI, LLM, vLLM, WSL]
image:
  path: /assets/img/posts/common/llm.jpg
---

# vLLM在win的wsl部署使用

> 在 **Windows 11 + WSL2 Ubuntu** 上部署 **vLLM**，用小参数 Instruct 模型走通「装环境 → 起服务 → chat completions」。原生 Windows 没有官方轮子；Docker Desktop 未接入该发行版时，用官方推荐的 **uv** 安装。下文是一条可复现的工程路径，不是吞吐评测。

**参考与延伸阅读**：

- vLLM GPU 安装：<https://docs.vllm.ai/en/latest/getting_started/installation/gpu/>
- vLLM Quickstart：<https://docs.vllm.ai/en/stable/getting_started/quickstart/>
- uv：<https://docs.astral.sh/uv/>
- Qwen2.5-0.5B-Instruct：<https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct>
- Hugging Face 镜像：<https://hf-mirror.com/>
- FlashInfer：<https://github.com/flashinfer-ai/flashinfer>
- vLLM Metrics：<https://docs.vllm.ai/en/latest/serving/metrics.html>

---

## 目录

- [1. 结论与边界](#1-结论与边界)
- [2. 驱动复用与用户态必须重装](#2-驱动复用与用户态必须重装)
- [3. 安装 uv 与 Python 环境](#3-安装-uv-与-python-环境)
- [4. 国内源与 403](#4-国内源与-403)
- [5. 安装 vLLM](#5-安装-vllm)
- [6. 启动 0.5B 并验证对话](#6-启动-05b-并验证对话)
- [7. FlashInfer 采样开关](#7-flashinfer-采样开关)
- [8. 模型缓存路径与查看](#8-模型缓存路径与查看)
- [9. 服务就绪的日志标志](#9-服务就绪的日志标志)
- [10. 运行监测](#10-运行监测)
- [11. 常见问题](#11-常见问题)
- [12. 小结](#12-小结)

---

## 1. 结论与边界

**可以在本地走通部署和推理。** 不要走 Windows 原生 pip，走 **WSL2 Ubuntu + NVIDIA GPU**。消费级笔记本显存有限时，先用 **0.5B / 1.5B Instruct**，上下文锁在 2K 左右；全精度 7B 通常进不去。

| 项 | 本次选择 |
|----|----------|
| 系统 | Windows 11，WSL2 Ubuntu |
| GPU | 宿主机 NVIDIA 独显，WSL 里 `nvidia-smi` 可见 |
| 安装方式 | `uv pip install vllm --torch-backend=auto` |
| 模型 | `Qwen/Qwen2.5-0.5B-Instruct`（可换成 1.5B） |
| 服务 | `vllm serve`，OpenAI 兼容 `/v1/chat/completions` |

0.5B 能聊天，容量小、回答容易短或跑偏，用来把接口跑通足够。笔记本降频发热时速度变慢，多半是功耗墙，不是框架损坏。

---

## 2. 驱动复用与用户态必须重装

宿主机上的 NVIDIA 驱动可以给 WSL 用；Windows 版 PyTorch **不能**拿到 Ubuntu 里用。

| 层 | 位置 | 处理 |
|----|------|------|
| NVIDIA 驱动 | 只装在 Windows | 不必在 Ubuntu 再装驱动。`nvidia-smi` 能看到同一块卡即已复用 |
| PyTorch / CUDA Runtime / vLLM 的 `.so` | 绑定 Linux Python | **必须再装 Linux 轮子** |

WSL2 是独立 Linux：自己的文件系统、自己的解释器。Windows 的 `win_amd64` wheel 无法被 Ubuntu 的 Python 加载。vLLM 的 CUDA 扩展按 Linux ABI 编译。

进发行版后先确认 GPU：

```bash
nvidia-smi
```

能列出 NVIDIA 设备再继续。权重和虚拟环境写在 Linux 家目录，不要放到 `/mnt/c`。

---

## 3. 安装 uv 与 Python 环境

在 WSL 的 Ubuntu 终端执行。新版安装脚本不一定生成 `~/.local/bin/env`，`uv --version` 能跑即可：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"
uv --version
```

在家目录建项目，用 uv 拉 CPython 3.12：

```bash
mkdir -p ~/vllm-lab
cd ~/vllm-lab
uv venv --python 3.12 --seed
source .venv/bin/activate
```

提示符出现虚拟环境前缀后再装框架。最小化 Ubuntu 往往没有 `gcc`。vLLM 启动探测 KV 时会走 Triton 编译采样核，缺编译器会在权重已经加载完之后报 `Failed to find C compiler`：

```bash
sudo apt update
sudo apt install -y build-essential
```

资源管理器可用 UNC 浏览，不要去挂载 WSL 的 `ext4.vhdx`：

```text
\\wsl.localhost\<发行版名>\home\<用户名>\vllm-lab
```

---

## 4. 国内源与 403

`uv` 拉 wheel 时，部分 PyPI 镜像会对 `/packages/` 返回 **403**。清华源曾拒过 `pip` 与 `vllm` 的 whl。改用阿里云或官方源后重建环境：

```bash
deactivate 2>/dev/null
cd ~/vllm-lab
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

## 5. 安装 vLLM

```bash
uv pip install vllm --torch-backend=auto
```

`auto` 会按驱动选择对应 CUDA 轮子。终端刷出一长串 `+ 包名==版本` 并回到提示符，即安装成功。体积几个 GB，落在 WSL 家目录所在的虚拟盘。

WSL 里建议同时设置（只对当前窗口有效，可写入 `~/.bashrc`）：

```bash
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_USE_FLASHINFER_SAMPLER=0
```

---

## 6. 启动 0.5B 并验证对话

把流程跑通时用 0.5B Instruct；显存仍宽裕可换成 `Qwen/Qwen2.5-1.5B-Instruct`，请求体里的 `model` 必须与启动名一致。

```bash
vllm serve Qwen/Qwen2.5-0.5B-Instruct \
  --host 0.0.0.0 \
  --port 8000 \
  --max-model-len 2048 \
  --gpu-memory-utilization 0.75 \
  --enforce-eager
```

`--enforce-eager` 关掉 CUDA Graph，笔记本更不容易 OOM。该窗口会一直占用。另开一个 WSL 会话：

```bash
curl http://127.0.0.1:8000/v1/models

curl http://127.0.0.1:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen/Qwen2.5-0.5B-Instruct",
    "messages": [{"role": "user", "content": "用一句话介绍 vLLM"}],
    "max_tokens": 128
  }'
```

Windows 浏览器可打开 `http://127.0.0.1:8000/docs`。

---

## 7. FlashInfer 采样开关

解码每一步都会先得到词表上的 logits，再按 temperature、top-k、top-p 抽出下一个 token。这一步叫 **sampling（采样）**，发生在注意力计算之后，和 FlashAttention 不是同一套核。

**FlashInfer** 是面向 LLM 推理的 CUDA 核库（注意力、采样、gemm 等）。vLLM 默认可用它的 **top-k / top-p 采样核**，把「裁剪分布 + 抽样」放在 GPU 上一次做完，高并发、大 batch 时比纯 PyTorch / Triton 路径更省调度开销。仓库见 [FlashInfer](https://github.com/flashinfer-ai/flashinfer)。

日志出现 `Using FlashInfer for top-p & top-k sampling` 后，预热会 JIT 编译采样扩展，于是去找 `nvcc` 和 `/usr/local/cuda`。WSL 只复用宿主机驱动、没有完整 CUDA Toolkit 时，会报 `Could not find nvcc`。

```bash
export VLLM_USE_FLASHINFER_SAMPLER=0
```

关闭后改走 vLLM 自带采样实现（如 Gumbel / Triton）。**对话接口和采样语义仍在**，temperature、top-p 照常生效。关掉的是这条 CUDA 实现，不是「不再随机采样」。

| 维度 | 开启（默认） | 关闭 `=0` |
|------|--------------|-----------|
| 作用 | GPU 融合核做 top-k / top-p | 框架内置采样路径 |
| 生成质量 | 同一套采样公式，不换模型 | 不换模型 |
| 吞吐 | 并发高时通常更好 | 单路小模型差别往往不明显 |
| 启动依赖 | 需要 `nvcc`、CUDA Toolkit 或可编译的 FlashInfer | WSL 体验部署够用 |
| 注意力 | 仍可用已经成功的 FlashAttention | 不受影响 |

笔记本上先关采样核，只为把服务拉起来。以后若在 Linux 主机装好 Toolkit，去掉该环境变量即可重新启用。不要为此在 WSL 里再装一份完整 `/usr/local/cuda`，除非要对比 FlashInfer 吞吐。

---

## 8. 模型缓存路径与查看

未改环境变量时，Hugging Face / vLLM 默认把权重放在 Linux 家目录：

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

同一模型名再次 `vllm serve` **不会整包重下**，只读本地 snapshot，最多核对元数据。换模型名才会再下一份。

---

## 9. 服务就绪的日志标志

出现 logo、`Resolved architecture`、`Loading model from scratch`、`Using FLASH_ATTN` **还不算出就绪**，只是在读配置并加载权重。第一次还会拉 `config.json`、tokenizer 和 `.safetensors`。

等到类似下面两行，服务才真正可请求：

```text
Application startup complete
Uvicorn running on http://0.0.0.0:8000
```

下列提示可忽略：未设置 `HF_TOKEN`、`Pinned memory is not available`、`Enforce eager set`。它们不是启动失败。

---

## 10. 运行监测

vLLM 没有类似昇腾 `npu-smi info` 的独立命令。GPU 占用看 NVIDIA 工具；引擎队列和 KV 占用看服务自己的 HTTP 接口与日志。在 **另一个 WSL 窗口**里执行，不要停掉 `vllm serve`。

**GPU（对应 `npu-smi`）**

```bash
nvidia-smi
watch -n 1 nvidia-smi
nvidia-smi --query-gpu=name,utilization.gpu,memory.used,memory.total,temperature.gpu,power.draw --format=csv
nvidia-smi pmon -s um
```

服务起来后这里应出现 Python / vLLM 进程。显存大约是权重加上 KV Cache（0.5B、`--gpu-memory-utilization 0.75` 时日志里 KV 会再占一块）。

**进程是否就绪、负载**

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/load
curl -s http://127.0.0.1:8000/version
curl -s http://127.0.0.1:8000/v1/models
```

`/health` 返回 `200` 表示引擎活着；`503` 表示 EngineCore 已挂。`/load` 的 `server_load` 统计正在打 GPU 的请求。

**Prometheus 指标（KV、吞吐、排队）**

```bash
curl -s http://127.0.0.1:8000/metrics | grep -E "vllm_num_requests|kv_cache|gpu_cache|prompt_throughput|generation_throughput"
```

未加 `--disable-log-stats` 时，serve 日志大约每 5～10 秒还会打 `Avg prompt throughput`、`GPU KV cache usage` 一类行，适合盯着启动窗口看。

| 观测项 | 昇腾习惯 | 本次环境 |
|--------|----------|----------|
| 卡是否在、温度功耗 | `npu-smi info` | `nvidia-smi` |
| 显存 | 同上 | `nvidia-smi` 的 Memory-Usage |
| 推理队列、KV 比例 | 各框架接口 | `/load`、`/metrics`、serve 日志 |

指标名随 vLLM 小版本可能增减，以 `/metrics` 实际输出为准。官方说明见 [Metrics](https://docs.vllm.ai/en/latest/serving/metrics.html)。

---

## 11. 常见问题

| 现象 | 处理 |
|------|------|
| `~/.local/bin/env` 不存在 | 新版 uv 安装脚本可能不再生成该文件；`uv --version` 能跑即可 |
| 清华源 403 | 换阿里云或 `pypi.org`，删掉半成品 `.venv` 再建 |
| CUDA OOM | 降 `gpu-memory-utilization` 到 0.6，或继续用 0.5B、缩短 `max_model_len` |
| `docker` 在发行版里不可用 | Docker Desktop 未勾选该 WSL 发行版；本次用 uv，不必先打通 Docker |
| `Failed to find C compiler` | 权重其实已经下完。`sudo apt install -y build-essential` 后再 `vllm serve`，不必重下模型 |
| `Could not find nvcc` / `cuda_home` | 见第 7 节。体验部署设 `VLLM_USE_FLASHINFER_SAMPLER=0`，不必在 WSL 里装 `/usr/local/cuda` |
| 权重落到 `/mnt/c` | 确认 `HF_HOME` 在 `$HOME/.cache/huggingface` |
| 再次 serve 与本地缓存 | 同一仓库已在 `hub/models--*` 下则走缓存；用第 8 节命令确认目录 |

下次进 WSL 后：

```bash
cd ~/vllm-lab
source .venv/bin/activate
export HF_ENDPOINT=https://hf-mirror.com
export HF_HOME="$HOME/.cache/huggingface"
export VLLM_WORKER_MULTIPROC_METHOD=spawn
export VLLM_USE_FLASHINFER_SAMPLER=0
```

再执行第 6 节的 `vllm serve`。

---

## 12. 小结

| 要点 | 结论 |
|------|------|
| 安装面 | Windows 原生不作为目标；WSL2 + Linux 轮子 |
| 驱动 | 只维护宿主机 NVIDIA 驱动；WSL 复用，不在 Ubuntu 里装 nvidia-driver |
| 磁盘 | 权重和虚拟环境放 Linux 家目录，不要写到 `/mnt/c` |
| 镜像 | uv 拉 whl 遇 403 换源；模型走 `HF_ENDPOINT` |
| 验证 | 0.5B Instruct + `/v1/chat/completions` 即可确认部署链路 |
| 监测 | 卡况用 `nvidia-smi`；队列和 KV 用 `/health`、`/load`、`/metrics` 与 serve 日志 |

先把「能起服务、能返回一段 chat」稳住，再换 1.5B，或对照 SGLang、CUDA Graph 与吞吐。
