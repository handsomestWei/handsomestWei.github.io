---
title: KubeEdge dashboard看板部署
date: 2025-09-19 17:00:00
categories: [运维, k8s, kubeedge]
tags: [运维, k8s, kubeedge]
image:
  path: /assets/img/posts/common/k8s.jpg
---

# KubeEdge dashboard看板部署
源码本地运行方式，需要运行前端和后端两个工程，下载源码[github kubeedge/dashboard](https://github.com/kubeedge/dashboard)

## 环境依赖
- KubeEdge
- golang

## 后端部署
### 下载依赖
cd modules
go mod download

### 启动后端服务
```sh
# 获取API Server地址
kubectl cluster-info

# 启动后端（替换为实际的API Server地址）
cd ../api
# 填入控制平面api地址和端口，并指定dashboard后端api服务监听地址和端口
go run main.go --apiserver-host=https://127.0.0.1:33017 --apiserver-skip-tls-verify=true --insecure-bind-address=0.0.0.0 --insecure-port=8080
```

## 前端部署
### 前端Node.js环境配置
```sh
node --version
npm --version
```
如果没有Node.js，安装它
```sh
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 安装pnpm（推荐）
npm install -g pnpm
```

### 启动前端
```sh
cd modules/web
pnpm install
pnpm run build

# 指定dashboard后端ip和端口
#API_SERVER=http://127.0.0.1:8080 pnpm run start
API_SERVER=http://127.0.0.1:8080 pnpm run dev
```

## 看板访问
浏览器访问`http://localhost:3000`，需要填入token

### 生成token
```sh
# 创建账号和授权
kubectl create serviceaccount curl-user -n kube-system
kubectl create clusterrolebinding curl-user-binding --clusterrole=cluster-admin --serviceaccount=kube-system:curl-user -n kube-system
kubectl create token curl-user -n kube-system
```
如果登录失败，尝试生成新token并填入