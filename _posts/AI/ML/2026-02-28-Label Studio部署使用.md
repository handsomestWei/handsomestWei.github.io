---
title: Label Studio部署使用
date: 2026-02-28 17:00:00
categories: [AI, ML]
tags: [AI, ML, Label Studio]
image:
  path: /assets/img/posts/common/ml.jpg
---

# Label Studio部署使用

Label Studio 是一款开源数据标注工具，支持图像、文本、音频、视频等多种类型的数据标注，并可直接在 Web 界面完成导入、标注、导出，供 Jupyter 等环境使用。

**Git 仓库：**

- 主仓库（后端 + 前端）：[github.com/HumanSignal/label-studio](https://github.com/HumanSignal/label-studio)
- ML 后端（自动标注）：[github.com/HumanSignal/label-studio-ml-backend](https://github.com/HumanSignal/label-studio-ml-backend)
- Gitee 镜像（国内）：[gitee.com/mirrors/label-studio](https://gitee.com/mirrors/label-studio)
- 中文汉化版：[github.com/Zhaoqj2016/label_studio](https://github.com/Zhaoqj2016/label_studio)

## 快速开始

```bash
docker run -d \
  --name label-studio \
  -p 8080:8080 \
  -v $(pwd)/label-studio-data:/label-studio/data \
  heartexlabs/label-studio:latest
```

> Windows 下 `$(pwd)` 改为 `%cd%`。

## 访问 Label Studio

启动成功后，在浏览器中访问：

- http://localhost:8080

首次访问需创建账号（邮箱 + 密码），用于本地数据持久化。

## 数据持久化

Label Studio 数据目录默认为 `/label-studio/data`，启动脚本已将其挂载到宿主机 `label-studio-data` 子目录，重启容器后数据保留。

## 常用公开开源数据集

可从以下网站获取用于标注与训练的公开数据集：

| 网站 | 链接 | 说明 |
|------|------|------|
| Kaggle Datasets | [kaggle.com/datasets](https://www.kaggle.com/datasets) | 海量数据集，涵盖图像、文本、表格等，需注册 |
| Hugging Face Datasets | [huggingface.co/datasets](https://huggingface.co/datasets) | 各类 NLP、CV 数据集，支持 streaming 与一键加载 |
| Open Images | [storage.googleapis.com/openimages](https://storage.googleapis.com/openimages/web/index.html) | Google 开放图像数据集，约 900 万张，多类别标注 |
| COCO | [cocodataset.org](https://cocodataset.org/) | 通用物体检测、分割、字幕等，常用于目标检测基准 |
| ImageNet | [image-net.org](https://www.image-net.org/) | 大规模图像分类数据集，需申请下载 |
| Roboflow Universe | [universe.roboflow.com](https://universe.roboflow.com/) | 大量预标注 CV 数据集，支持导出多种格式 |
| Papers With Code Datasets | [paperswithcode.com/datasets](https://paperswithcode.com/datasets) | 与论文绑定的数据集，便于复现 |
| 阿里天池 | [tianchi.aliyun.com/dataset](https://tianchi.aliyun.com/dataset) | 中文场景数据集，含图像、NLP、时序等 |
| UCI ML Repository | [archive.ics.uci.edu/ml](https://archive.ics.uci.edu/ml) | 经典机器学习数据集，多用于表格与分类任务 |
| Microsoft Azure Open Datasets | [azure.microsoft.com/open-datasets](https://azure.microsoft.com/products/open-datasets) | 多种领域开放数据，可集成 Azure 服务 |

## 与 Jupyter 配合使用

标注完成后，可将导出的文件上传到 Jupyter 工作目录，或在 Jupyter 中通过 `pandas`、`pycocotools` 等库加载标注数据进行训练。

## API 方式对接

Label Studio 提供 HTTP API 与 Python SDK，可编程完成项目创建、任务导入、标注导出等操作；并支持 **ML 后端自动标注**：接入自研或官方示例模型后，可对任务进行预标注、交互式标注辅助，详见 [labelstud.io/guide/ml](https://labelstud.io/guide/ml)。

### 获取 Token

1. 登录 Label Studio，点击右上角用户头像
2. 选择 **Account & Settings**
3. 左侧进入 **Personal Access Tokens** 或 **Legacy Tokens**
4. 创建 Token 后复制保存（Personal Access Token 创建后仅显示一次）

| 类型 | HTTP 认证方式 | 说明 |
|------|---------------|------|
| Personal Access Token (PAT) | `Authorization: Bearer <token>` | JWT，需定期刷新（约 5 分钟），更安全 |
| Legacy Token | `Authorization: Token <token>` | 长期有效，无需刷新，可直接用于 HTTP 请求 |

> 若页面中看不到 Token 选项，需组织管理员在 **Organization Settings > Access Token Settings** 中启用。

### HTTP API

**Legacy Token（推荐用于脚本调用，简单直接）：**

```bash
# 示例：列出项目
curl -X GET "http://localhost:8080/api/projects" \
  -H "Authorization: Token <your-legacy-token>"
```

**Personal Access Token：**

PAT 为 JWT 刷新令牌，需先换取短期 access token 再调用 API：

```bash
# 1. 换取 access token
curl -X POST "http://localhost:8080/api/token/refresh" \
  -H "Content-Type: application/json" \
  -d '{"refresh": "<your-personal-access-token>"}'
# 返回 {"access": "<short-lived-token>"}

# 2. 使用 access token 调用 API
curl -X GET "http://localhost:8080/api/projects" \
  -H "Authorization: Bearer <short-lived-token>"
```

### Python SDK

```bash
pip install label-studio-sdk
```

```python
from label_studio_sdk import LabelStudio

LABEL_STUDIO_URL = 'http://localhost:8080'
LABEL_STUDIO_API_KEY = 'your-token'  # PAT 或 Legacy Token 均可

client = LabelStudio(base_url=LABEL_STUDIO_URL, api_key=LABEL_STUDIO_API_KEY)

# 列出项目
projects = client.projects.list()
# 创建项目、导入任务、导出标注等
# 详见 https://labelstud.io/guide/sdk 与 https://api.labelstud.io
```

也可通过环境变量 `LABEL_STUDIO_API_KEY` 传入，SDK 会自动读取。

## 端口与配置

| 配置项   | 默认值      | 说明                    |
|----------|-------------|-------------------------|
| 容器端口 | 8080        | Label Studio 监听端口   |
| 宿主机端口 | 8080      | 映射到宿主机            |
| 数据目录 | ./label-studio-data | 宿主机持久化路径 |
