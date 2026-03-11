---
title: JupyterLab部署使用
date: 2026-03-02 17:00:00
categories: [AI, ML]
tags: [AI, ML, jupyterLab]
image:
  path: /assets/img/posts/common/ml.jpg
---

# JupyterLab部署使用

JupyterLab 是 Jupyter 的下一代 Web 界面，支持 Notebook、终端、文本编辑器、数据查看器等，适用于数据科学、机器学习、深度学习等场景。本文档介绍如何部署与使用 JupyterLab，与实训平台无关。

---

## 快速开始

### 本地 Windows 环境（pip 方式）

**安装：**

```powershell
pip install jupyterlab
```

**启动：**

```powershell
python -m jupyterlab --ip=0.0.0.0 --port=8888 --no-browser
```

**运行目录说明：** JupyterLab 的根目录（文件浏览器中显示的起点）为**执行上述命令时所在的当前目录**。例如在 `D:\projects\my-work` 下执行启动命令，则 Web 界面中的文件树将以 `D:\projects\my-work` 为根目录。建议先 `cd` 到工作目录再启动。

```powershell
cd D:\projects\my-work
python -m jupyterlab --ip=0.0.0.0 --port=8888 --no-browser
```

**上传与地址映射：** 文件浏览器中的路径与本地磁盘路径一一对应。在 Web 中浏览到某目录并上传文件时，文件会保存到该目录对应的本地路径。若需显式指定根目录（与当前工作目录解耦），可使用 `--ServerApp.root_dir`：

```powershell
# 指定根目录，不受启动时 cd 位置影响
python -m jupyterlab --ip=0.0.0.0 --port=8888 --no-browser --ServerApp.root_dir="D:/projects/my-work"
```

此时 Web 文件树的根目录为 `D:\projects\my-work`，上传文件将落在此目录及其子目录下。

### Docker 运行

使用官方镜像快速启动：

```bash
docker run -d \
  --name jupyterlab \
  -p 8888:8888 \
  -v "$(pwd)/work:/home/jovyan/work" \
  jupyter/scipy-notebook:latest
```

> Windows 下 `$(pwd)` 改为 `%cd%`。首次运行会生成 token，通过 `docker logs jupyterlab` 查看访问地址。

---

## 访问地址

启动成功后，在浏览器中访问：

- http://localhost:8888/lab
- http://127.0.0.1:8888/lab

---

## 停止服务器

- **本地运行**：在运行 JupyterLab 的终端按 `Ctrl+C` 停止
- **Docker 运行**：`docker stop jupyterlab`

---

## 自定义镜像（中文界面）

官方 `jupyter/scipy-notebook:latest` 默认是英文界面。如需**界面语言**（菜单、按钮等）为中文，可使用本目录下的 Dockerfile 构建自定义镜像，预装 `jupyterlab-language-pack-zh-CN`。

### 安装中文语言包（已运行容器内）

```bash
pip install jupyterlab-language-pack-zh-CN
```

安装后，在 Jupyter Lab 中：**Settings → Language → 选择 Chinese (Simplified, China)** 即可切换为中文界面。

### 构建自定义镜像

**Windows：**

```powershell
build_image.bat

# 可选：指定镜像名和标签
build_image.bat my-jupyter 1.0
```

**Linux / WSL：**

```bash
chmod +x build_image.sh
./build_image.sh

# 可选：指定镜像名和标签
./build_image.sh my-jupyter 1.0
```

默认构建结果为 `jupyter/scipy-notebook-zh:latest`。

### 首次使用：切换为中文界面

构建并运行容器后，首次打开 Jupyter Lab 时：

1. 点击菜单 **Settings**（设置）
2. 选择 **Language**（语言）
3. 选择 **Chinese (Simplified, China)**（中文（简体，中国））
4. 页面会刷新，界面即显示为中文

---

## 扩展与依赖预装

### 基础镜像选择

| 镜像 | 预装内容 | 适用场景 |
|------|----------|----------|
| `jupyter/scipy-notebook` | NumPy、SciPy、pandas、matplotlib、scikit-learn | 数据科学、传统 ML，可按需装深度学习 |
| `jupyter/tensorflow-notebook` | 上述 + TensorFlow | 以 TensorFlow 为主的深度学习 |
| `jupyter/pytorch-notebook` | 上述 + PyTorch | 以 PyTorch 为主的深度学习 |
| `jupyter/datascience-notebook` | 上述 + R、Julia | 多语言数据科学 |

**建议**：以 `scipy-notebook` 为基础，通过 pip 按需补充深度学习与大模型生态；若主用 PyTorch，可直接选用 `pytorch-notebook`。

### 推荐预装包（按场景）

| 场景 | 包名 | 用途 |
|------|------|------|
| 图像与视觉 | `opencv-python-headless` | 图像处理（无 GUI，适合无显示器环境） |
| 图像与视觉 | `albumentations` | 数据增强 |
| 文本与 NLP | `transformers` | Hugging Face 预训练模型（BERT、GPT 等） |
| 文本与 NLP | `datasets` | Hugging Face 数据集 |
| 文本与 NLP | `sentence-transformers` | 文本向量与检索 |
| 文本与 NLP | `spacy` | NLP 流程（可配合中文模型） |
| 深度学习 | `torch` | PyTorch |
| 深度学习 | `tensorflow` | TensorFlow |
| 深度学习 | `accelerate` | 大模型加载与分布式训练 |
| 深度学习 | `bitsandbytes` | 量化（8bit/4bit，节省显存） |
| AI 大模型 | `langchain` | 大模型应用框架 |
| AI 大模型 | `gradio` | 快速构建 Web 演示界面 |
| 通用工具 | `xgboost`、`lightgbm` | 梯度提升 |
| 通用工具 | `plotly` | 交互式可视化 |

### Dockerfile 预装示例

在 `Dockerfile` 中追加预装包，例如（精简版 + 中文语言包）：

```dockerfile
RUN pip install --no-cache-dir \
    jupyterlab-language-pack-zh-CN \
    opencv-python-headless \
    torch \
    transformers \
    datasets \
    accelerate \
    sentence-transformers \
    xgboost \
    plotly \
    && fix-permissions "${CONDA_DIR}" && fix-permissions "/home/${NB_USER}"
```

### 注意事项

1. **PyTorch vs TensorFlow**：二者同时安装会明显增大镜像体积，可按主力框架选其一
2. **GPU 支持**：若需 GPU 加速，应使用带 CUDA 的 PyTorch 镜像，或基于 `nvidia/cuda` 构建并安装对应 CUDA 版 PyTorch
3. **中文 NLP**：使用 `spacy` 时，可下载中文模型：`python -m spacy download zh_core_web_sm`
4. **镜像大小**：可维护轻量版（仅基础 ML + 中文）与完整版（含深度学习与大模型）两个 Dockerfile，按场景选择构建
