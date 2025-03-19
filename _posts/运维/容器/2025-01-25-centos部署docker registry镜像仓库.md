---
title: centos部署docker registry镜像仓库
date: 2025-01-25 21:00:00
categories: [运维, 容器]
tags: [运维, 容器, docker]
image:
  path: /assets/img/posts/common/docker.jpg
---

# centos部署docker registry镜像仓库

## 仓库简介
docker registry是一个存储和分发docker镜像的服务。它允许用户上传、下载和管理docker镜像，为容器化应用的部署提供了便利。

## 仓库安装部署
### 仓库证书配置
创建镜像仓库的镜像数据目录和证书目录，便于挂载
```sh
mkdir /data/registry/data
mkdir /data/registry/certs
```
生成镜像仓库证书
```sh
cd /data/registry/certs
openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key -x509 -days 365 -out ca.crt -subj \
"/C=CN/ST=GX/L=Bei Jing/O=xxx Technology Co., Ltd./CN=xxx Root Certificate"
openssl req -newkey rsa:4096 -nodes -sha256 -keyout registry.key -out registry.csr -subj \
"/C=CN/ST=GX/L=Bei Jing/O=xxxx Technology Co., Ltd./CN=registry.xxx.com"
openssl x509 -req -days 365 -in registry.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out registry.crt
```
ssl配置，将自签名证书加入系统证书中心，使操作系统信任
```sh
## 对于ubuntu系统则是/etc/ssl/certs/ca-certificates.crt
cat /data/registry/certs/ca.crt >> /etc/pki/tls/certs/ca-bundle.crt
systemctl restart docker
```

### 仓库运行
```sh
docker run -d -p 5000:5000 --restart=always --name registry \
-v /data/registry/data:/var/lib/registry \
-v /data/registry/certs:/certs \
-e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/registry.crt \
-e REGISTRY_HTTP_TLS_KEY=/certs/registry.key \
registry:2
```

## 仓库使用
### 客户端访问
使用registry.xxx.com:5000访问，配置镜像仓库的域名解析
```sh
echo 'x.x.x.x registry.xxx.com' >> /etc/hosts/hosts
```

### 镜像拉取
```sh
docker image pull registry
```

### 镜像迁移
镜像从旧仓库导出
```sh
docker tag registry:2 registry.xxx.com:5000/public/registry:2
docker save -o registry.tar registry.xxx.com:5000/public/registry:2
```
镜像导入到新镜像仓库
```sh
docker load -i registry.tar
```
镜像推送到新镜像仓库
```sh
docker push registry.xxx.com:5000/public/registry:2
```
也可以直接把整个镜像仓库数据文件挂载到新仓库
```sh
-v /data/registry/data:/var/lib/registry
```

## 参考
[docker registry官方文档](https://docs.docker.com/registry/deploying/#run-an-externally-accessible-registry)