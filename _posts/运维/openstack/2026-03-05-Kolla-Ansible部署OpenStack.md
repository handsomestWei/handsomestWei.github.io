---
title: Kolla-Ansible 部署 OpenStack
date: 2026-03-05 09:00:00
categories: [运维, openstack]
tags: [运维, openstack, kolla, docker]
image:
  path: /assets/img/posts/common/openstack.jpg
---

# Kolla-Ansible 部署 OpenStack

本文档基于 **Kolla-Ansible** 使用 Docker 容器方式部署 OpenStack，适用于 Ubuntu 或 CentOS，适合测试与小规模部署。

---

## 0. 架构与组件简介

Kolla-Ansible 将各 OpenStack 服务打包为 Docker 镜像，通过 Ansible 编排部署。所有服务以容器形式运行，与宿主机隔离。

### 部署架构

| 层级 | 说明 |
|------|------|
| **Ansible** | 编排引擎，执行 bootstrap、prechecks、deploy、post-deploy |
| **Docker** | 容器 runtime，承载各 OpenStack 服务 |
| **Kolla 镜像** | 官方预构建镜像（Keystone、Nova、Glance、Neutron、Horizon 等） |

### 主要服务（容器化）

| 服务 | 说明 |
|------|------|
| Keystone | 身份认证 |
| Nova | 计算 API 与调度 |
| Glance | 镜像服务 |
| Neutron | 网络服务 |
| Cinder | 块存储 |
| Horizon | Web 管理界面 |
| MariaDB | 元数据存储 |
| RabbitMQ | 消息队列 |

### 局限与适用场景

| 方面 | 说明 |
|------|------|
| **规模** | 容器化但非 K8s，多节点编排能力有限，更适合测试与小规模部署 |
| **资源** | 各服务独立容器，内存、磁盘占用相对较高 |
| **部署耗时** | 首次部署需拉取大量镜像，通常需 30–60 分钟 |
| **升级** | 大版本升级需重新部署，回滚成本较高 |
| **依赖** | 强依赖 Docker 与宿主机，宿主机故障影响整体可用性 |

---

## 1. 前置条件

| 项目 | 要求 |
|------|------|
| **操作系统** | Ubuntu 22.04 / 24.04 或 CentOS Stream 9 |
| **硬件** | 8GB+ 内存，40GB+ 磁盘（建议 150GB+），2 块网卡（单网卡可单机 All-in-One） |
| **网络** | 可访问互联网及 Docker 镜像仓库 |
| **权限** | root 或 sudo |

---

## 2. 环境准备

### 2.1 安装 Docker

**Ubuntu：**

```bash
sudo apt update
sudo apt install -y docker.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
```

**CentOS Stream 9：**

```bash
sudo dnf install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable docker
sudo systemctl start docker
```

### 2.2 安装 Python 与 Kolla-Ansible 依赖

**Ubuntu：**

```bash
sudo apt install -y python3-dev python3-pip python3-venv libffi-dev gcc libssl-dev
```

**CentOS：**

```bash
sudo dnf install -y python3-pip python3-devel libffi-devel gcc openssl-devel
```

### 2.3 安装 Ansible 与 Kolla-Ansible

```bash
sudo pip3 install -U pip
sudo pip3 install 'ansible-core>=2.14' kolla-ansible
```

或使用虚拟环境（推荐）：

```bash
python3 -m venv /opt/kolla-venv
source /opt/kolla-venv/bin/activate
pip install -U pip
pip install 'ansible-core>=2.14' kolla-ansible
```

---

## 3. 配置 Kolla-Ansible

### 3.1 创建配置目录

```bash
sudo mkdir -p /etc/kolla
cd /etc/kolla
```

### 3.2 生成配置文件

```bash
# 安装依赖并复制示例配置
sudo kolla-ansible install-deps

# 若 /etc/kolla 下无配置，从示例复制
sudo cp -r /usr/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
sudo cp /usr/share/kolla-ansible/ansible/inventory/* /etc/kolla/
```

### 3.3 编辑 globals.yml

关键配置示例（按实际网卡名调整）：

```yaml
---
openstack_release: "caracal"   # 或 zed、antelope，视 kolla-ansible 版本

kolla_base_distro: "ubuntu"    # CentOS 用 "centos"
kolla_install_type: "binary"

# 单机 All-in-One
network_interface: "eth0"                    # 管理网卡
neutron_external_interface: "eth1"           # 外网网卡；单网卡时与 network_interface 相同

enable_horizon: "yes"
enable_neutron: "yes"
enable_cinder: "yes"

kolla_internal_vip_address: "192.168.1.230"  # 本机 IP 或 VIP
```

### 3.4 配置 inventory（单机 All-in-One）

编辑 `/etc/kolla/ansible/inventory/all-in-one`，若无此文件则使用 `multinode`。单机时将各节点均设为 localhost：

```ini
[control]
localhost ansible_connection=local

[network]
localhost ansible_connection=local

[compute]
localhost ansible_connection=local

[monitoring]
localhost ansible_connection=local

[storage]
localhost ansible_connection=local
```

### 3.5 生成密码

```bash
cd /etc/kolla
sudo kolla-genpwd
```

密码写入 `passwords.yml`，管理员密码为 `keystone_admin_password`。

---

## 4. 部署步骤

```bash
cd /etc/kolla

# 指定 inventory（all-in-one 或 multinode，按实际路径）
INVENTORY="ansible/inventory/all-in-one"
# 若无 all-in-one，使用：INVENTORY="ansible/inventory/multinode"

# 1. 检查系统要求
sudo kolla-ansible -i $INVENTORY bootstrap-servers

# 2. 预检查
sudo kolla-ansible -i $INVENTORY prechecks

# 3. 部署（约 30–60 分钟）
sudo kolla-ansible -i $INVENTORY deploy

# 4. 生成 admin-openrc
sudo kolla-ansible -i $INVENTORY post-deploy
```

---

## 5. 安装后

| 项目 | 说明 |
|------|------|
| **Horizon** | `http://<本机IP>` 或 `http://<本机IP>:80` |
| **管理员密码** | `sudo grep keystone_admin_password /etc/kolla/passwords.yml` |
| **加载凭证** | `source /etc/kolla/admin-openrc.sh` |
| **验证** | `openstack service list`、`openstack image list` |
| **容器状态** | `docker ps` |

---

## 6. 初始化：规格与网络

若 `openstack flavor list` 或 `openstack network list` 为空，需手动创建。

---

## 7. 常见问题

### 7.1 镜像拉取慢或超时

配置 Docker 镜像加速或代理；或提前拉取 Kolla 镜像：

```bash
sudo kolla-ansible -i ansible/inventory/all-in-one pull
```

### 7.2 网卡名不匹配

`globals.yml` 中 `network_interface`、`neutron_external_interface` 需与本机实际网卡名一致。可用 `ip link` 查看。

### 7.3 端口冲突

确保 80、3306、5672、5000、8774、9292、9696 等端口未被占用：

```bash
ss -tulnp | grep -E ':80|:3306|:5672|:5000'
```

### 7.4 部署失败

查看 Ansible 输出中的具体错误；或检查容器日志：

```bash
docker ps -a
docker logs <容器名>
```
