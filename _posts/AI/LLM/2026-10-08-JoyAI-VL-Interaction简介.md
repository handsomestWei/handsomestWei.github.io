---
title: JoyAI-VL-Interaction简介
description: >-
  京东开源的 JoyAI-VL-Interaction 是 8B 实时视觉语言交互系统：视频流每秒由主模型决定静默、说话或委托。双 vLLM 把交互模型和摘要模型分到两张 GPU；最小部署是 webinfer 加 WebUI。
date: 2026-10-08 12:00:00
categories: [AI, LLM]
tags: [AI, LLM, JoyAI]
image:
  path: /assets/img/posts/common/llm.jpg
---

# JoyAI-VL-Interaction简介

> **JoyAI-VL-Interaction** 是京东开源的实时视频语言交互系统（Apache-2.0）。核心是约 **8B** 的视觉优先模型：对着摄像头或直播流，由模型自己决定这一秒是说话、保持静默，还是把难题交给后台。语音识别和合成是可插拔服务，不焊进权重。部署默认用 **两套 vLLM**：一张卡跑主交互模型，另一张卡跑摘要模型。接口与端口以仓库文档当时说明为准。

**参考与延伸阅读**：

- 仓库：<https://github.com/jd-opensource/JoyAI-VL-Interaction>
- 中文架构：<https://github.com/jd-opensource/JoyAI-VL-Interaction/blob/main/doc/architecture.zh-CN.md>
- 中文入门：<https://github.com/jd-opensource/JoyAI-VL-Interaction/blob/main/doc/getting_started.zh-CN.md>
- 权重：<https://huggingface.co/jdopensource/JoyAI-VL-Interaction>
- 技术报告：<https://arxiv.org/abs/2606.14777>
- vLLM-Omni 配方：<https://github.com/vllm-project/vllm-omni/blob/main/recipes/JD/JoyAI-VL-Interaction.md>

---

## 目录

- [1. 定位](#1-定位)
- [2. 主要功能](#2-主要功能)
- [3. 双 vLLM 架构](#3-双-vllm-架构)
- [4. 处理流程](#4-处理流程)
- [5. 本地安装与部署](#5-本地安装与部署)
- [6. 适用边界](#6-适用边界)
- [7. 小结](#7-小结)

---

## 1. 定位

它不是「把整段视频丢进多模态模型再等一份摘要」。系统按大约 **每秒一帧** 看着画面，由主模型做一次三选一，再决定要不要出声。

| 项 | 说明 |
|----|------|
| 模型 | JoyAI-VL-Interaction，约 8B，架构沿用 Qwen3-VL，权重按流式交互重训 |
| 仓库内容 | 模型、训练配方、时间对齐数据、可部署的五服务栈 |
| 许可证 | Apache-2.0 |
| 必选服务 | `webinfer`（推理适配器）、`webui`（浏览器与 WebRTC） |
| 可选服务 | ASR、TTS、background-agent |
| 推理底座 | 主模型与摘要模型各起一个 vLLM；TTS 走 vLLM-Omni |

权重另有 INT4、INT8、FP8、NVFP4 仓库，显存不够时再换量化档，默认脚本指向全精度路径。

---

## 2. 主要功能

| 能力 | 做法 |
|------|------|
| 实时观看 | WebUI 用 WebRTC 取摄像头，或接 RTSP；约 1 fps 把 JPEG 帧交给推理 |
| 自主决策 | 每一拍输出静默、发言或委托，而不是每帧都生成长回答 |
| 语音外挂 | ASR 用 Qwen3-ASR，TTS 用 Qwen3-TTS；模型只负责看和判断 |
| 分层记忆 | 帧攒成 chunk，摘要模型压成中期摘要，再压成长期记忆，便于跨较长时间保留要点 |
| 后台委托 | 复杂或耗时的子任务交给 background-agent（封装 Codex CLI，可跑代码），主模型继续看视频 |
| 对外接口 | webinfer 适配器提供 OpenAI 兼容 HTTP（默认 `:8070`） |
| 离线视频 | 无摄像头时可用 ffmpeg 把本地文件推成 RTSP，再在 WebUI 里填地址 |

官方材料里还强调：画面变化用预测式编码压成少量视觉 token，避免上下文随视频时长线性膨胀。训练侧公开了约 400 万条时间对齐的交互样本。这些属于模型与数据配方，部署时不需要单独再装一套编码器服务。

---

## 3. 双 vLLM 架构

「双 vLLM」指 **webinfer 后面的两个推理进程**，不是 ASR/TTS。适配器自己不跑权重，只组上下文并转发。

| 进程 | 默认 GPU | 内部端口 | 模型 | 显存占用上限 |
|------|----------|----------|------|----------------|
| 主交互 vLLM | `MAIN_GPU=0` | 7060 | `jdopensource/JoyAI-VL-Interaction` | 0.9 |
| 摘要 vLLM | `SUMMARY_GPU=1` | 8065 | `Qwen/Qwen3-VL-4B-Instruct` | 0.9 |
| webinfer 适配器 | 不占推理卡 | 8070（对外） | 无 | — |

主模型决定这一秒说不说。摘要模型不参与这一拍的发言，只在记忆管道里把 chunk 压短，避免把几百帧原图再塞回主模型。两套服务都是标准 vLLM HTTP，端口只给本机适配器使用。

可选语音再各占一条推理：

| 进程 | 默认 GPU | 内部端口 | 对外适配器 |
|------|----------|----------|------------|
| ASR vLLM | `ASR_GPU=2`，显存上限 0.3 | 8993 | `:8994` |
| TTS vLLM-Omni | `TTS_GPU=2`，总预算约 0.6 | 8991 | `:8992` |

默认把 ASR 和 TTS 都放在 **GPU 2**。因此：只开视频交互要 **2 张卡**；再开语音，脚本默认要 **第 3 张卡**。单卡机器需要改 `MAIN_GPU` / `SUMMARY_GPU`，并下调显存占用，文档没有把单卡当成默认路径。官方测试环境写的是 NVIDIA Hopper、CUDA 12.x、驱动 535 及以上。

五个服务以 WebUI 为中心：浏览器连 WebUI（`:8099`，HTTPS），WebUI 再去连 webinfer、ASR、TTS 和 background-agent（`:8079`）。

---

## 4. 处理流程

一帧从摄像头到回复，按下面的顺序走。箭头表示数据方向，不是五个进程同时各干一遍。

```text
摄像头或 RTSP
    → WebUI（WebRTC，约 1 fps，JPEG）
    → webinfer 适配器 :8070
        组装：当前帧 + 视频历史 + 问答历史 + 长期记忆
    → 主 vLLM :7060（GPU 0，JoyAI-VL-Interaction）
    → 三选一
        ├─ 静默：本拍不发言
        ├─ 发言文本 →（若 TTS 已启动）TTS :8992 → 扬声器
        └─ 委托任务 → background-agent :8079 → 结果再交回 WebUI
用户说话（可选）
    → WebUI 采集 PCM16
    → ASR :8994
    → 转写文本注入为用户问题
    → 回到主 vLLM 的下一拍

记忆旁路（与「说不说」并行积累，不替代主模型）：
    每 CHUNK 帧（默认 100）成一个 chunk
    → 摘要 vLLM :8065（GPU 1，Qwen3-VL-4B）
    → 中期摘要
    → 每 COMPRESS_EVERY_N_CHUNKS 个 chunk（默认 5）再压成长期记忆
    → 下一拍适配器组上下文时读回
```

没有用户问题时，`FORCE_SILENCE_BEFORE_QUERY` 默认为 true，用来压住无问题的主动输出。主模型单次生成默认最多 `MAIN_MAX_TOKENS=256`，温度 `0.8`。

---

## 5. 本地安装与部署

前置：Linux、NVIDIA GPU、CUDA 12.x、驱动 535+、Python 3.12。包管理推荐 [uv](https://docs.astral.sh/uv/)。先克隆仓库再执行脚本。

```bash
git clone https://github.com/jd-opensource/JoyAI-VL-Interaction.git
cd JoyAI-VL-Interaction

./install/install.sh --with-all
./install/download-models.sh --all
```

只要语音时再装音频运行时：`./install/install-audio-runtime.sh --all`。权重默认落在 `/tmp/models/`：主模型、摘要用的 Qwen3-VL-4B，以及可选的 ASR / TTS。`/tmp` 重启可能被清空，长期机器应把 `MODEL_PATH` 和 `SUMMARY_MODEL_PATH` 指到持久目录。

最小部署只起推理和页面（仍会拉起双 vLLM）：

```bash
./services/scripts/run.sh minimal
```

浏览器打开 `https://127.0.0.1:8099`（自签名证书）。该终端里 WebUI 在前台，`Ctrl+C` 会停掉这次编排拉起的进程。

完整栈要先有后台 agent 的 `CODEX_HOME`（内含 `config.toml` 与 `auth.json`），再：

```bash
export CODEX_HOME=/path/to/your/codex-home
./services/scripts/run.sh all
```

不想开某一项时设 `START_ASR=0`、`START_TTS=0` 或 `START_BACKGROUND_AGENT=0`。手动顺序是：webinfer → ASR → TTS → background-agent → 最后 WebUI。从别的终端停服务：`./services/scripts/stop.sh all`。

健康检查：

```bash
curl http://127.0.0.1:8070/health   # webinfer
curl http://127.0.0.1:8994/health   # ASR，未启动会失败
curl http://127.0.0.1:8992/health   # TTS
curl http://127.0.0.1:8079/health   # background-agent
```

没有摄像头时，可用 MediaMTX 加 ffmpeg 把本地视频推成 `rtsp://127.0.0.1:8554/...`，填进 WebUI 的 RTSP 框。步骤见仓库里的 RTSP 说明。

只想要模型前向、不要这套编排时，vLLM-Omni 配方用普通 `vllm serve`（不要加 `--omni`，权重仍是 Qwen3-VL 结构）再套一层交互编排。那是另一条入口，端口和双 vLLM 脚本不同，不要两套同时抢同一张卡。

---

## 6. 适用边界

**适合。** 需要「一直看着画面、该说话才说话」的演示或内部原型：展厅摄像头、产线旁的实时讲解、把直播流接到一个 8B 视觉模型。服务拆得开，语音和后台 agent 可以后加。

**不适合当通用视频理解 API 的唯一方案。** 默认形态是双卡实时栈加 WebUI，不是单进程 `vllm serve` 打完就走。长视频离线批处理、多路高并发、没有 NVIDIA 的环境，都不在官方默认路径里。background-agent 还依赖本机 Codex 凭证，没有 `auth.json` 就不要开 `run.sh all`。

---

## 7. 小结

| 要点 | 结论 |
|------|------|
| 是什么 | 京东开源的 8B 实时视觉语言交互系统，Apache-2.0 |
| 决策 | 每拍静默、发言或委托；语音外挂 |
| 双 vLLM | GPU 0 主模型 `:7060`，GPU 1 摘要模型 `:8065`，适配器对外 `:8070` |
| 最小部署 | `install.sh` 与下载权重后，`run.sh minimal`，页面在 `:8099` |
| 完整部署 | 再加 ASR、TTS（默认 GPU 2）和 background-agent |
| 注意 | 双卡是默认；`/tmp/models` 不持久；委托功能要自备 Codex home |

先用两张卡跑通 `minimal`，确认 `:8070/health` 和页面能出静默或短回复，再决定要不要加语音和后台委托。
