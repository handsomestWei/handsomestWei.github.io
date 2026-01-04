---
title: KubeEdge使用keadm工具部署
date: 2025-09-20 15:00:00
categories: [运维, k8s]
tags: [运维, k8s, kubeedge]
image:
  path: /assets/img/posts/common/k8s.jpg
---

# KubeEdge使用keadm工具部署
kubeedge安装需要依赖k8s环境。

## 镜像源配置
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

## k8s安装部署

### 安装docker
略

### 安装k8s
使用官方方法
```sh
# 添加Kubernetes官方GPG密钥
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# 添加Kubernetes APT仓库
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

# 更新并安装
sudo apt update
sudo apt-get install -y kubeadm kubelet kubectl
```

### 安装cri-dockerd
Kubernetes v1.24+ 默认使用 CRI（Container Runtime Interface），不再支持 Docker 直接作为容器运行时，需要安装cri-dockerd兼容Docker
下载并安装 cri-dockerd
```sh
wget https://github.com/Mirantis/cri-dockerd/releases/download/v0.3.10/cri-dockerd_0.3.10.3-0.ubuntu-jammy_amd64.deb
sudo dpkg -i cri-dockerd_0.3.10.3-0.ubuntu-jammy_amd64.deb
```
启动 cri-dockerd
```sh
sudo systemctl enable cri-docker
sudo systemctl start cri-docker
```

### 禁用swap
```sh
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
```

### pause镜像准备
手动拉取 pause 镜像（使用阿里云源）；打标签，使其匹配 Kubernetes 期望的镜像名
```sh
sudo docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9
sudo docker tag \
  registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.9 \
  registry.k8s.io/pause:3.9
```

### k8s初始化
使用kubeadm工具初始化k8s。使用cri-dockerd，配置忽略检查报错（还没有安装网络插件），使用国内镜像仓库，日志展示进度详情。
```sh
kubeadm init \
  --image-repository registry.cn-hangzhou.aliyuncs.com/google_containers \
  --cri-socket unix:///var/run/cri-dockerd.sock \
  --pod-network-cidr=10.244.0.0/16 \
  --kubernetes-version=v1.29.15 \
  --ignore-preflight-errors=all \
  --v=5
```
- 日志输出`Your Kubernetes control-plane has initialized successfully!`说明成功
- 问题排查使用`sudo journalctl -u kubelet -f`查看日志
- 重启`sudo systemctl restart kubelet`
- 重置`kubeadm reset --force --cri-socket=unix:///var/run/cri-dockerd.sock`

### 配置 kubectl
```sh
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 加载br_netfilter内核模块
Flannel插件用
```sh
sudo modprobe br_netfilter
lsmod | grep br_netfilter
```

### 安装 CNI 网络插件（如 Flannel）
```sh
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

### k8s状态检查
```sh
kubectl get nodes
kubectl get pods -n kube-system
```

## kubeedge安装部署

### 云端主节点部署
依赖镜像建议提前下载
```sh
docker pull kubeedge/cloudcore:v1.21.0
docker pull kubeedge/iptables-manager:v1.21.0
```
KubeEdge 提供了一个名为 keadm 的命令行工具，方便快速部署 KubeEdge。
```sh
# 下载最新版本的 keadm
wget https://github.com/kubeedge/kubeedge/releases/download/v1.21.0/keadm-v1.21.0-linux-amd64.tar.gz

# 解压文件
tar -zxvf keadm-v1.21.0-linux-amd64.tar.gz

# 进入解压后的目录
cd keadm-v1.21.0-linux-amd64

# 手动拉取国内镜像并改标签
sudo docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/cloudcore:v1.21.0
sudo docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/cloudcore:v1.21.0 kubeedge/cloudcore:v1.21.0

# 初始化
./keadm/keadm init --kubeedge-version=1.21.0 --v=5
```
如果失败后重试，建议先重置`./keadm/keadm reset`

#### 常见问题：单节点集群环境被阻止调度
查看节点状态`kubectl get pods -n kubeedge -o wide`是`pending`状态   
检查节点`kubectl describe node <your node name> | grep -i taint`配置，常见输出`Taints:             node-role.kubernetes.io/control-plane:NoSchedule`   
说明该节点默认不允许调度普通 Pod（包括 cloudcore），可以直接移除污点配置`kubectl taint node <your node name> node-role.kubernetes.io/control-plane:NoSchedule-`

### 边缘端子节点部署
依赖镜像建议提前下载
```sh
docker pull kubeedge/installation-package:v1.21.0
docker pull kubeedge/eclipse-mosquitto:1.6.15
docker pull eclipse-mosquitto:1.6.15
```
从云端获取令牌，该令牌将在加入边缘节点时使用。
```sh
./keadm/keadm gettoken
```
使用keadm join安装edgecore。正常条件，一般在另一台服务器上单独部署边缘端组件。单机环境部署，云端和边缘端共存容易出现问题，需要使用`edgenode-name`设置节点名称避免冲突，和指定容器运行时引擎
```sh
./keadm/keadm join \
    --cloudcore-ipport=${node_ip}:10000 \
    --token=${TOKEN} \
    --edgenode-name=edge-node-01 \
    --remote-runtime-endpoint=unix:///var/run/cri-dockerd.sock \
	--cgroupdriver=systemd \
	--kubeedge-version=v1.21.0 \
	--v=5
```

#### 常见问题：边缘端kubelet组件冲突问题
使用`journalctl -u edgecore.service -xe`查看报错日志如下
```text
failed to check the running environment: kubelet should not be running on edge node when starting edgecore
```
在单机环境下部署，kubelet（Kubernetes主节点组件）和edgecore（KubeEdge边缘节点组件）不能同时运行。需要修改配置。
```sh
vi /etc/systemd/system/edgecore.service

# 在[Service]配置项下加入一行
# Environment="CHECK_EDGECORE_ENVIRONMENT=false"

systemctl daemon-reload
```

### kubeedge状态检查
```sh
kubectl get pods -n kubeedge
```

## 参考
- [kubeedge文档](https://release-1-20.docs.kubeedge.io/zh/docs/)
- [kubeedge应用示例](https://github.com/kubeedge/examples)