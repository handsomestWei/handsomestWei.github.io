---
title: KubeEdge单服务器keink模式构建和部署
date: 2025-09-19 14:10:00
categories: [运维, k8s, kubeedge]
tags: [运维, k8s, kubeedge]
image:
  path: /assets/img/posts/common/k8s.jpg
---

# KubeEdge单服务器keink模式构建和部署
正常部署需要两台服务器，分别部署云端节点和边缘节点。在条件受限的环境，使用单台服务部署，参考文档[kubeedge install-with-keink](https://release-1-20.docs.kubeedge.io/zh/docs/setup/install-with-keink/)

## docker环境准备
略

## kubectl环境准备

### 软件包源配置
```sh
# 备份当前源
sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup

# 替换为阿里云源
sudo tee /etc/apt/sources.list > /dev/null <<EOF
deb http://mirrors.aliyun.com/ubuntu/ jammy main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# 更新软件包列表
sudo apt update
```

### kubectl安装
```sh
# 添加Kubernetes官方GPG密钥
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 添加Kubernetes APT仓库
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 更新并安装
sudo apt update
#sudo apt-get install -y kubeadm kubelet kubectl
sudo apt-get install -y kubectl
```

## golang环境准备

### 目录设置
离线安装[golang release](https://github.com/golang/go/tags), 版本不能太高，建议使用1.23.0
```sh
# 删除旧版本（如果有）
sudo rm -rf /usr/local/go

# 解压和拷贝到默认目录
tar -xzf go1.23.0.linux-amd64.tar.gz
sudo mv go /usr/local/

# 创建go_path目录
mkdir -p /root/go/src
mkdir -p /root/go/bin
mkdir -p /root/go/pkg
```

### 环境量设置
```sh
# 设置Go环境变量，GOPATH目录一般是/root/go
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
echo 'export GOPATH=$HOME/go' >> ~/.bashrc
echo 'export GOROOT=/usr/local/go' >> ~/.bashrc

# 重新加载环境变量
source ~/.bashrc

# 验证Go安装
go version

# 设置go.mod依赖包下载阿里云代理
go env -w GOPROXY=https://mirrors.aliyun.com/goproxy/,direct
go env -w GOSUMDB=sum.golang.google.cn

# 验证设置
go env GOPROXY
```

## kubeedge源码编译环境准备
提前下载源码[github kubeedge](https://github.com/kubeedge/kubeedge)
```sh
unzip -o kubeedge-master.zip

# 拷贝kubeedge源码到go_path目录，注意是两级kubeedge
mkdir -p /root/go/src/github.com/kubeedge/
mv /home/omara/kubeedge-deploy/kubeedge /root/go/src/github.com/kubeedge/

# 脚本授权
chmod -R 777 /root/go/src/github.com/kubeedge/
cd /root/go/src/github.com/kubeedge/kubeedge

# 下载依赖
go mod download
```

## keink源码编译环境准备

### 编译工具准备
```sh
# 安装构建工具
sudo apt-get update
sudo apt-get install -y \
    build-essential \
    make \
    gcc \
    g++ \
    git \
    curl \
    wget

# 验证安装
make --version
gcc --version
```

### keink源码编译
提前下载源码[github keink](https://github.com/kubeedge/keink)。后续的构建需要使用keink编译的二进制程序。
```sh
unzip -o keink-main.zip
cd keink

# 下载go mod依赖
go mod download

# 编译
make
```

## 使用keink构建KubeEdge
```sh
# keink需要使用Kind（Kubernetes in Docker）来创建本地Kubernetes集群
docker pull kindest/node:v1.26.15

# 在keink源码工程内执行
bin/keink build edge-image --kube-root /root/go/src/github.com/kubeedge/kubeedge/ --base-image kindest/node:v1.26.15
```
构建后，可以看到新的kindest/node docker镜像，`docker ps`可以看到同一个镜像被用来创建运行两个容器，扮演不同的角色（控制平面和工作节点）。如果需要重新构建，先执行`rm -rf _output/`   

也可以直接使用制作好的docker镜像，使用文档参考[wjy2020/kubeedge-keink](https://hub.docker.com/repository/docker/wjy2020/kubeedge-keink/general)，`docker pull wjy2020/kubeedge-keink:v1.21.0-kindest-node1.26.15`

## KubeEdge运行
```sh
bin/keink create kubeedge --image kubeedge/node:latest --wait 120s
```

## KubeEdge状态检查
正常应该能看到`control-plane`和`edge`两个节点。
```sh
kubectl get node -owide
kubectl get pod -A
```

## 简单设备接入KubeEdge
设备接入后，可以部署[kubeedge/dashboard](https://github.com/kubeedge/dashboard)并在页面上看到设备信息。

### 设备模型定义
```yaml
apiVersion: devices.kubeedge.io/v1beta1
kind: DeviceModel
metadata:
  name: simple-temp-humidity-sensor
  namespace: default
spec:
  properties:
    - name: temperature
      description: Temperature reading in Celsius
      type: FLOAT
      unit: "°C"
      accessMode: ReadOnly
    - name: humidity
      description: Humidity reading in percentage
      type: FLOAT
      unit: "%"
      accessMode: ReadOnly
```

### 设备信息定义
```yaml
apiVersion: devices.kubeedge.io/v1beta1
kind: Device
metadata:
  name: simple-sensor-001
  namespace: default
  labels:
    device: simple-temp-humidity-sensor
    location: office
spec:
  deviceModelRef:
    name: simple-temp-humidity-sensor
  nodeName: kind-worker
```

### 设备部署
```sh
kubectl apply -f simple-device-model.yaml
kubectl apply -f simple-device.yaml

# 查看资源和验证
kubectl get devicemodels
kubectl get devices
```