---
title: ubuntu搭建docker环境
date: 2025-01-20 15:50:00
categories: [运维, 容器]
tags: [运维, 容器, docker]
image:
  path: /assets/img/posts/common/docker.jpg
---

# ubuntu搭建docker环境

## docker引擎安装
高版本docker引擎安装时已经自带有docker compose
安装参考docker官网[Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
### 方式一： 在线安装
[参考apt方式安装](https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository)
#### 1、Set up Docker's apt repository.
```sh
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```
#### 2、Install the Docker packages.
```sh
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 方式二： 离线安装
[deb离线安装包资源链接](https://download.csdn.net/download/weixin_42112831/90302851)
```sh
## 解压后执行安装相关依赖
sudo dpkg -i ./*.deb -y
```

## 容器日志保留策略设置
修改后需重启docker引擎
```sh
sudo bash -c 'cat <<EOF >>/etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
EOF
'
sudo systemctl restart docker
```

## 其他常用命令
```sh
## docker导出离线镜像
docker save -o ./xxx.tar <tag>:<version>

## docker导入离线镜像
docker load -i ./xxx.tar
```