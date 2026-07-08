---
title: Label Studio部署使用
date: 2026-02-28 17:00:00
categories: [AI, ML]
tags: [AI, ML, Label Studio]
image:
  path: /assets/img/posts/common/ml.jpg
---

# Label Studio部署使用

Label Studio 是一款开源数据标注工具，支持计算机视觉、NLP、语音（TTS）等传统机器学习场景，也支持 LLM 对齐类标注；可在 Web 界面完成导入、标注、导出，供 Jupyter 等环境使用。

**Git 仓库：**

- 主仓库（后端 + 前端）：[github.com/HumanSignal/label-studio](https://github.com/HumanSignal/label-studio)
- ML 后端（自动标注）：[github.com/HumanSignal/label-studio-ml-backend](https://github.com/HumanSignal/label-studio-ml-backend)
- Gitee 镜像（国内）：[gitee.com/mirrors/label-studio](https://gitee.com/mirrors/label-studio)
- 中文汉化版：[github.com/MindAsAI/label-studio-chinese](https://github.com/MindAsAI/label-studio-chinese)

## 快速开始

### Docker 方式

```bash
docker run -d \
  --name label-studio \
  -p 8080:8080 \
  -v $(pwd)/label-studio-data:/label-studio/data \
  heartexlabs/label-studio:latest
```

> Windows 下 `$(pwd)` 改为 `%cd%`。

### pip 方式

适合本地开发或不想使用 Docker 的场景：

```bash
conda create -n labelstudio python=3.11
conda activate labelstudio
pip install label-studio
label-studio start              # 默认 8080 端口
label-studio start --port 9001  # 指定端口
```

## 访问 Label Studio

启动成功后，在浏览器中访问：

- http://localhost:8080

首次访问需注册账号（邮箱 + 密码）并登录；登录后进入项目首页，可开始创建标注项目。

## 数据持久化

Label Studio 数据目录默认为 `/label-studio/data`，Docker 启动脚本已将其挂载到宿主机 `label-studio-data` 子目录，重启容器后数据保留。

## Web 界面标注流程

整体流程为：**创建项目 → 导入数据 → 配置标注模板 → 执行标注 → 导出结果**。

### 创建项目

在首页点击「创建项目」，按向导完成三步：

| 步骤 | 操作 |
|------|------|
| 1. 项目名称 | 填写项目名称与描述 |
| 2. 数据导入 | 上传本地文件，或填写 URL / 云存储路径 |
| 3. 标注模板 | 从内置模板选择（目标检测、语义分割、文本分类等），或自定义配置 |

创建完成后，项目会出现在项目列表中。

### 执行标注

在项目列表中选中任务图片，或点击「标注所有任务」进入标注页。先在侧边栏选择标签名称，再在画布上绘制框、多边形或填写文本等，完成单条标注后保存并切换下一条。

标注完成后，可在项目「数据管理」或「导出」菜单中将结果导出为 JSON、COCO、YOLO 等格式。

## 标注模板与界面配置

配置标签有两种方式：

| 方式 | 说明 |
|------|------|
| 代码式 | 直接编辑 XML 标注配置，灵活度高，适合复杂界面 |
| 可视化操作 | 在 UI 中点选添加标签名与组件，适合快速上手 |

以**边界框目标检测**为例，可在可视化界面中添加 `RectangleLabels` 等组件并定义类别名称（如 `person`、`car`）。代码式示例如下：

```xml
<View>
  <Image name="image" value="$image"/>
  <RectangleLabels name="label" toName="image">
    <Label value="person"/>
    <Label value="car"/>
  </RectangleLabels>
</View>
```

标注界面还可通过配置面板调整辅助选项：

| 配置项 | 作用 |
|--------|------|
| 区域边框宽度 | 标注时框线显示粗细 |
| 图像缩放 | 放大/缩小便于精细标注 |
| 图像旋转 | 旋转图像后标注 |
| 标签位置 | 标签列表显示在上下左右 |
| 标签筛选 | 标签类别较多时快速过滤 |

## 自动标注（ML 后端）

Label Studio 支持接入模型对数据进行**预标注**：模型推理结果呈现在标注页，标注员只需审核与修正，无需从零绘制。

### ML 后端原理

推理服务需实现 Label Studio ML Backend 约定的接口与响应格式。官方提供 [label-studio-ml-backend](https://github.com/HumanSignal/label-studio-ml-backend) 项目，内含目标检测、语义分割、OCR 等示例；也可使用 FastAPI、Django 等框架自行实现，只要路径与 JSON 格式符合约定即可。

部署示例有两种常见方式：

1. 克隆 `label-studio-ml-backend` 仓库，按 README 安装并启动对应算法示例
2. 使用 Docker 运行官方或社区封装好的 ML 后端镜像

以 YOLO 目标检测为例，容器启动时需传入两个环境变量：

```bash
docker run -d -p 9999:9090 \
  -e "LABEL_STUDIO_URL=http://<宿主机IP>:8080" \
  -e "LABEL_STUDIO_API_KEY=<your-token>" \
  --name yolo-ml-backend \
  <your-ml-backend-image>
```

| 环境变量 | 说明 |
|----------|------|
| `LABEL_STUDIO_URL` | Label Studio 访问地址，如 `http://192.168.1.10:8080` |
| `LABEL_STUDIO_API_KEY` | API Token，在账户设置中创建（见下文「获取 Token」） |

容器启动后，在浏览器访问 `http://<宿主机IP>:9999` 可验证 ML 后端是否正常运行。

### 在项目中连接模型

1. 进入目标项目，点击「设置」
2. 左侧选择「模型」菜单
3. 点击「连接模型」，填写模型名称、后端 URL（如 `http://192.168.1.10:9999`）、身份验证方式等
4. 点击「验证并保存」

### 开启自动标注

回到项目列表，打开标注页面，**勾选「自动标注」**后，系统会调用已连接的 ML 后端对当前任务进行预标注，标注员在此基础上修正即可。

> Web 界面使用与自动标注部分参考知乎专栏：[数据标注开源框架 Label Studio（中文版）](https://zhuanlan.zhihu.com/p/1911168946398295290)。

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
