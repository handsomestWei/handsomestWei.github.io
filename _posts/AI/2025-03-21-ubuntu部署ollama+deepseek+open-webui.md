---
title: ubuntu部署ollama+deepseek+open-webui
date: 2025-03-21 14:15:00
categories: [AI]
tags: [AI, ollama, deepseek, open-webui]
image:
  path: /assets/img/posts/common/AI.jpg
---

# ubuntu部署ollama+deepseek+open-webui

## 组件功能
+ ollama: 模型管理
+ deepseek： LLM模型
+ open-webui：提供交互web页面

## ollama部署
### ollama安装
```sh
apt install curl
curl -fsSL https://ollama.com/install.sh | sh
ollama -v 
```

### 网络访问配置
关联环境量`OLLAMA_HOST`   
允许外部访问ollama，方便后续http方式调用ollama的api接口。步骤如下   
1）`vi /etc/systemd/system/ollama.service`   
2）在`[Service]`标签下，添加一行`Environment="OLLAMA_HOST=0.0.0.0:11434"`   
3）刷新配置并重启服务，执行`systemctl daemon-reload`和`systemctl restart ollama`   
可使用浏览器访问`http://<ip>:11434/`

### 修改模型默认存储目录（选配）
关联环境量`OLLAMA_MODELS`   
ollama的默认下载和存储模型的路径是`/usr/share/ollama/.ollama/models`
1）`vi /etc/systemd/system/ollama.service`
2）在`[Service]`标签下，添加一行`Environments="OLLAMA_MODELS=/xxx/models"`
3）刷新配置并重启服务，执行`systemctl daemon-reload`和`systemctl restart ollama`

## deepseek模型部署

### 在线安装
使用ollama帮下载
```sh
ollama pull deepseek-r1:1.5b
```

### 离线导入
[从ollama官网下载deepseek-r1](https://ollama.com/library/deepseek-r1:1.5b)   
如果模型存储目录没有调整，放置目录如下：
+ 模型描述文件目录 `/usr/share/ollama/.ollama/models/manifests/registry.ollama.ai/library`
+ 模型目录 `/usr/share/ollama/.ollama/models/blobs`

### 模型运行测试
查看已安装的模型列表`ollama list`

#### 控制台交互方式
```sh
ollama run deepseek-r1:1.5b
```

### ollama api调用方式
```sh
curl http://<ip>:11434/api/chat -d '{"model": "deepseek-r1:1.5b", "messages": [{ "role": "user", "content": "why is the sky blue?"}]}'
```

## open-webui部署
open-webui依赖较多，包含python 3.11、数据库等。可以使用docker方式部署。   
[open-webui docker部署参考](https://github.com/open-webui/open-webui)   
[对应操作系统镜像链接](https://github.com/open-webui/open-webui/pkgs/container/open-webui)

### docker容器运行
官方推荐的参数如下
```sh
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always <镜像名>
```
在低版本操作系统和内核部署可能会出现网络设置失败导致启动失败，网络模式可以改为`--network host`   
运行后通过`http://localhost:3000`网页访问

### 配置从ollama获取模型
路径`点击右上角头像->设置->管理员设置->外部连接->管理Ollama API连接`   
修改ollama的url连接配置。配置完成后，可以看到ollama内管理的模型，并选择一个模型开始对话。