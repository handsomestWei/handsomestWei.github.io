---
title: 百度飞桨PaddleOCR图片印章检测技术简介
date: 2025-11-20 09:00:00
categories: [AI, OCR]
tags: [AI, OCR, PaddleOCR]
image:
  path: /assets/img/posts/common/ocr.jpg
---

# 百度飞桨PaddleOCR图片印章检测技术简介
3.X和2.X区别较大，建议使用3.X版本。

## PaddleX简介
- [PaddleX github地址](https://github.com/PaddlePaddle/PaddleX)
- [PaddleX模型产线使用概览](https://paddlepaddle.github.io/PaddleX/latest/pipeline_usage/pipeline_develop_guide.html)
- [PaddleX安装文档](https://paddlepaddle.github.io/PaddleX/latest/installation/installation.html)
- [PaddleX高性能推理部署](https://paddlepaddle.github.io/PaddleX/latest/pipeline_deploy/high_performance_inference.html)   

### PaddleX和PaddleOCR的区别
摘自官方文档[PaddleX和PaddleOCR的关系](https://github.com/PaddlePaddle/PaddleOCR/blob/release/3.0/docs/version3.x/paddleocr_and_paddlex.md)。   

PaddleOCR 与 PaddleX 在定位和功能上各有侧重：PaddleOCR 专注于 OCR 相关任务，而 PaddleX 则覆盖了包括时序预测、人脸识别等在内的多种任务类型。此外，PaddleX 提供了丰富的基础设施，具备多模型组合推理的底层能力，能够以统一且灵活的方式接入不同模型，支持构建复杂的模型产线。   

需要特别说明的是，尽管 PaddleOCR 在底层使用了 PaddleX，但得益于 PaddleX 的可选依赖安装功能，安装 PaddleOCR 推理包时并不会安装 PaddleX 的全部依赖，而只会安装 OCR 类任务需要使用到的依赖，用户通常无需关心依赖体积的过度膨胀问题。

## PaddleOCR简介
- [PaddleOCR github地址](https://github.com/PaddlePaddle/PaddleOCR)
- [PaddleOCR模型列表](https://github.com/PaddlePaddle/PaddleOCR/blob/release/3.0/docs/version3.x/model_list.md)
- [PaddleOCR快速开始](https://github.com/PaddlePaddle/PaddleOCR/blob/release/3.3/docs/quick_start.md)

模型使用建议（摘自官方文档）：PaddleOCR 内置了多条产线，每条产线都包含了若干模块，每个模块包含若干模型，具体使用哪些模型，您可以根据下边的 benchmark 数据来选择。如您更考虑模型精度，请选择精度较高的模型，如您更考虑模型推理速度，请选择推理速度较快的模型，如您更考虑模型存储大小，请选择存储大小较小的模型。

## 飞桨AI Studio产品
[飞桨ai studio图片识别在线体验地址](https://aistudio.baidu.com/community/app/91660/webUI?source=appMineRecent)

## PaddleOCR印章文本识别模型产品
整个识别流程包含印章位置检测、印章文本识别等子模型。

- [印章文本检测模块使用教程-github](https://github.com/PaddlePaddle/PaddleOCR/blob/release/3.0/docs/version3.x/module_usage/seal_text_detection.md)
- [印章文本检测模块使用教程](https://paddlepaddle.github.io/PaddleX/latest/module_usage/tutorials/ocr_modules/seal_text_detection.html)
- [印章文本识别产线使用教程](https://paddlepaddle.github.io/PaddleX/latest/pipeline_usage/tutorials/ocr_pipelines/seal_recognition.html)
- [印章文本识别模型微调](https://paddlepaddle.github.io/PaddleX/latest/pipeline_usage/tutorials/ocr_pipelines/seal_recognition.html#41)
- [版面区域检测模块使用教程-可用于印章位置检测模型微调](https://paddlepaddle.github.io/PaddleX/latest/module_usage/tutorials/ocr_modules/layout_detection.html)
