---
title: Ubuntu部署OpenStack
date: 2026-03-03 09:00:00
categories: [运维, openstack]
tags: [运维, openstack, ubuntu]
image:
  path: /assets/img/posts/common/openstack.jpg
---

# Ubuntu部署OpenStack

本文档基于 Sunbeam（snap 方式）在 Ubuntu 上部署 OpenStack，适用于单机快速体验与学习。

---

## 0. 架构与组件简介

Sunbeam 部署的 OpenStack 由多层组件构成：**编排层**负责部署与生命周期管理，**控制平面**提供 OpenStack 核心 API 与服务，**数据平面**负责计算与存储。

### 编排层（由 Sunbeam 管理）

| 组件 | 作用 |
|------|------|
| **Sunbeam** | Canonical 的 OpenStack 部署框架，通过 CLI（`sunbeam`）完成集群引导、配置与扩缩容 |
| **Juju** | 应用编排引擎，以 Charm 形式部署 Keystone、Nova、Glance、MySQL 等，管理服务关系与配置 |
| **MicroK8s (k8s snap)** | 轻量 Kubernetes，承载 OpenStack 各服务 Pod（Keystone、Nova、Glance 等） |
| **LXD** | 容器 runtime，Juju 的 machine 与 controller 运行在 LXD 容器中 |

### 控制平面（OpenStack 核心服务）

| 组件 | 作用 |
|------|------|
| **Keystone** | 身份认证与授权，管理用户、项目、域及服务目录 |
| **Nova** | 计算 API 服务，负责虚拟机调度、生命周期管理 |
| **Glance** | 镜像管理，存储与分发 VM 镜像 |
| **Neutron** | 网络服务，管理虚拟网络、子网、路由、安全组 |
| **Cinder** | 块存储服务，基于 MicroCeph 提供云盘 |
| **Placement** | 资源调度与放置，配合 Nova 进行主机选择 |
| **Horizon** | Web 管理界面 |

### 共享基础设施

| 组件 | 作用 |
|------|------|
| **MySQL** |  relational 数据库，为 Keystone、Nova、Glance、Neutron、Cinder 等存储元数据 |
| **RabbitMQ** | 消息队列，各 OpenStack 服务之间的异步通信 |
| **etcd** | Kubernetes 数据存储，k8s 集群状态与配置 |
| **MicroCeph** | 分布式块存储，为 Cinder 提供后端，需至少一个 OSD 磁盘 |
| **Traefik** | 入口负载均衡，对外暴露 Horizon、Keystone 等 HTTP 服务（通过 NodePort） |

### 计算节点（数据平面）

| 组件 | 作用 |
|------|------|
| **openstack-hypervisor** | Nova Compute，在物理/虚拟机上运行虚拟机实例，与 Nova API、OVN、RabbitMQ 等集成 |

整体上，**控制平面**（Keystone、Nova、Glance、Neutron、Cinder、Horizon 等）运行在 K8s 的 `openstack` 命名空间，**计算节点**由 Juju 部署到 `openstack-machines` 模型中的 machine 上。

---

## 1. 操作系统版本要求

| 要求 | 说明 |
|------|------|
| **操作系统** | **仅支持 Ubuntu 24.04 LTS (Noble)** |
| **不支持** | Ubuntu 22.04 (Jammy) 及以下。若在 Jammy 上执行会报错：`ERROR: Sunbeam deploy only supported on noble` |
| **硬件建议** | 4 核+、16GB 内存、100GB SSD |
| **网络** | 可访问外网（或配置代理/镜像源） |

---

## 2. 环境配置说明（安装前必读）

### 防火墙（强烈建议在安装前配置）

启用 UFW 时，LXD 容器可能拿不到 IP，导致「Waiting for address」超时或各种网络异常。**建议在安装前关闭防火墙或正确放行相关流量**。

**方式 A：临时关闭防火墙（适用于测试环境）**

```bash
sudo ufw disable
```

**方式 B：保持防火墙开启，允许转发（推荐）**

```bash
# 修改默认转发策略为 ACCEPT
sudo sed -i 's/^DEFAULT_FORWARD_POLICY=.*/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
sudo ufw reload

# 若使用 Sunbeam 的 sunbeambr0 网桥，放行该网桥和 DHCP
sudo ufw allow in on sunbeambr0
sudo ufw allow 67/udp
sudo ufw reload
```

若不提前处理防火墙，可能导致容器无 IP、apt 连不上外网、镜像拉取失败等难以排查的网络问题。

---

## 3. 主要步骤

### 步骤 0：准备工作

```bash
sudo snap remove openstackclients   # 若已安装，需先移除
```

### 步骤 1：安装 openstack snap（需 root）

```bash
sudo snap install openstack --channel 2024.1/stable
```

### 步骤 2：创建普通用户（若无 ubuntu/cloudops 用户）

脚本全文见下方 [5. 创建用户脚本全文](#5-创建用户脚本全文)。

```bash
sudo bash create_sunbeam_user.sh
# 默认创建 cloudops，密码见脚本输出
```

### 步骤 3：准备节点（**必须由非 root 用户执行**）

```bash
# 切换到普通用户（如 cloudops）
ssh cloudops@本机IP
# 或 su - cloudops（可能触发 cgroup 警告，推荐 SSH 登录）

# 执行准备脚本
sunbeam prepare-node-script --bootstrap | bash -x

# 激活 snap_daemon 组
newgrp snap_daemon
```

### 步骤 4：引导云（约 15–30 分钟）

```bash
sunbeam cluster bootstrap --accept-defaults --role control,compute,storage
```

- 若提示输入密码，为 Juju 控制器密码，建议 8 位以上含字母和数字（如 `OpenStack123`）

### 步骤 4.1：创建并分配 OSD（MicroCeph 存储）

使用 `storage` 角色时，MicroCeph 需要至少一个 OSD 磁盘，否则 bootstrap 可能卡在「Cinder Volume 0/1」或「waiting for services」。

**前提**：主机上有一块未分区、可格式化的空闲磁盘（如 `/dev/sdb`）。可用 `lsblk` 确认。

**添加 OSD**（在 bootstrap 开始后、MicroCeph 已部署时执行；若 bootstrap 卡住，可在另一终端执行）：

```bash
# 查看可用磁盘
lsblk

# 添加磁盘为 OSD（替换为实际设备，如 /dev/sdb）
sudo microceph disk add /dev/sdb

# 确认 OSD 已就绪
microceph status
```

若 bootstrap 已卡在 Cinder/MicroCeph，添加 OSD 后通常会自动继续；若仍无进展，可重启相关服务后重试（见下方「常见问题」）。

### 步骤 5：配置云

```bash
sunbeam configure --accept-defaults --openrc demo-openrc
```

#### 5.1 sunbeam configure 失败时：确认状态并手动配置

**现象**：执行 `sunbeam configure` 报错 `Deployment not bootstrapped or bootstrap process has not completed successfully`，但应用实际已部署完成。

**1. 确认 Juju 状态**：若 glance、cinder-volume 等均为 `active`，可跳过 configure，改为手动配置：

```bash
juju status -m sunbeam-controller:gxcoder/openstack
juju status -m admin/openstack-machines
```

**2. 手动获取 admin 账号密码**：Keystone 密码在 Juju secret 中：

```bash
# 列出 keystone 相关 secret
juju list-secrets -m sunbeam-controller:gxcoder/openstack | grep keystone

# 获取 admin 密码（label 为 credentials_admin 的 secret）
juju show-secret --reveal secret:<keystone-secret-id> | grep -A2 credentials_admin
# 或逐个尝试
juju show-secret --reveal secret:d6j8govmp25c7d6jtqd0   # 示例 ID，以 list-secrets 输出为准
```

输出中 `content.username` 为 `admin`，`content.password` 即为 Keystone 密码。

**3. 确定访问地址**：内网 IP（如 172.16.1.202）外网不可达时，使用 NodePort：

```bash
# 查看 traefik-public 的 NodePort
sudo /snap/k8s/current/bin/kubectl -n openstack get svc traefik-public-lb
# 80 端口对应 NodePort 如 32483
```

外网访问：`http://<服务器物理IP>:<NodePort>/openstack-horizon`，Keystone 同理。

**4. 获取 admin 所在域（domain）**：若 `Default` 域登录失败，需从数据库确认。MySQL root 密码在 Juju secret（label `database-peers.mysql.app`）的 `root-password` 字段：

```bash
juju show-secret --reveal secret:$(juju list-secrets -m sunbeam-controller:gxcoder/openstack | grep "database-peers.mysql" | awk '{print $1}')
```

查询 admin 的 domain 名称：

```bash
sudo /snap/k8s/current/bin/kubectl -n openstack exec -i mysql-0 -c mysql -- \
  mysql -u root -p'<root-password>' -e "
USE keystone;
SELECT p.name AS domain_name FROM user u
JOIN local_user l ON u.id = l.user_id
JOIN project p ON u.domain_id = p.id AND p.is_domain = 1
WHERE l.name = 'admin';
"
```

常见结果为 `admin_domain` 或 `Default`。

**5. 手动创建 demo-openrc**：

```bash
KEYSTONE_PASS="<步骤2获取的密码>"
OPENSTACK_IP="<服务器物理IP>"      # 如 192.168.1.230
OPENSTACK_PORT="<NodePort>"        # 如 32483
OS_DOMAIN="admin_domain"           # 或 Default，以步骤4查询为准

cat > ~/demo-openrc << EOF
unset OS_USER_DOMAIN_ID OS_PROJECT_DOMAIN_ID
export OS_AUTH_URL=http://${OPENSTACK_IP}:${OPENSTACK_PORT}/openstack-keystone/v3
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=${KEYSTONE_PASS}
export OS_REGION_NAME=RegionOne
export OS_USER_DOMAIN_NAME=${OS_DOMAIN}
export OS_PROJECT_DOMAIN_NAME=${OS_DOMAIN}
export OS_IDENTITY_API_VERSION=3
EOF

source ~/demo-openrc
openstack token issue
```

**示例**：完整填写的 `~/demo-openrc` 内容（按实际环境替换 IP、端口、密码、域）：

```
unset OS_USER_DOMAIN_ID OS_PROJECT_DOMAIN_ID
export OS_AUTH_URL=http://192.168.1.230:32483/openstack-keystone/v3
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=z7Qj2uutfJ8S
export OS_REGION_NAME=RegionOne
export OS_USER_DOMAIN_NAME=admin_domain
export OS_PROJECT_DOMAIN_NAME=admin_domain
export OS_IDENTITY_API_VERSION=3
```

**6. Horizon 登录**：`http://<服务器IP>:<NodePort>/openstack-horizon`，用户名 `admin`，密码为 Keystone 密码，**域** 填写步骤 4 查询结果（如 `admin_domain`）。

**7. 部署计算节点（No valid host 时）**：若 `openstack compute service list` 无 `nova-compute`，或创建实例报 `No valid host was found`，需手动部署 openstack-hypervisor 并完成集成：

```bash
# 1. 部署 openstack-hypervisor 到 openstack-machines
juju deploy openstack-hypervisor -m admin/openstack-machines --to 0 --channel 2024.1/stable

# 2. 消费 openstack 模型的 offer 并集成（sunbeam-controller、gxcoder、admin 以 juju status 为准）
juju consume sunbeam-controller:gxcoder/openstack.nova -m admin/openstack-machines
juju integrate openstack-hypervisor nova -m admin/openstack-machines

juju consume sunbeam-controller:gxcoder/openstack.ovn-relay -m admin/openstack-machines
juju integrate openstack-hypervisor ovn-relay -m admin/openstack-machines

juju integrate openstack-hypervisor rabbitmq -m admin/openstack-machines
juju integrate openstack-hypervisor keystone-credentials -m admin/openstack-machines
juju integrate openstack-hypervisor cert-distributor -m admin/openstack-machines
juju consume sunbeam-controller:gxcoder/openstack.certificate-authority -m admin/openstack-machines
juju integrate openstack-hypervisor certificate-authority -m admin/openstack-machines

# 3. 等待 openstack-hypervisor 变为 active
juju status -m admin/openstack-machines

# 4. 验证
openstack compute service list
openstack hypervisor list
```

---

### 安装后

| 项目 | 说明 |
|------|------|
| **Horizon 控制台** | `http://<服务器IP>/dashboard` |
| **Keystone 密码** | `sudo snap get openstack config.credentials.keystone-password` |
| **openrc** | `source ~/demo-openrc` 后可使用 `openstack` CLI |

---

### 安装后初始化：规格与网络

若 `openstack flavor list` 或 `openstack network list` 为空，创建实例会失败，需先手动创建。

**创建规格（Flavor）**：

```bash
source ~/demo-openrc
openstack flavor create --id 1 --vcpus 1 --ram 512 --disk 10 --public m1.tiny
openstack flavor create --id 2 --vcpus 1 --ram 1024 --disk 20 --public m1.small
openstack flavor create --id 3 --vcpus 2 --ram 2048 --disk 40 --public m1.medium
```

**创建网络**：按实际物理网络调整网段。

```bash
source ~/demo-openrc

# 外网
openstack network create --share external
openstack subnet create --network external \
  --subnet-range 192.168.1.0/24 --gateway 192.168.1.1 \
  --allocation-pool start=192.168.1.100,end=192.168.1.220 \
  --dns-nameserver 8.8.8.8 external-subnet
openstack network set --external external

# 内网（实例使用）
openstack network create internal
openstack subnet create --network internal \
  --subnet-range 10.0.0.0/24 --gateway 10.0.0.1 \
  --dns-nameserver 8.8.8.8 internal-subnet

# 路由器
openstack router create demo-router
openstack router add subnet demo-router internal-subnet
openstack router set --external-gateway external demo-router

openstack network list
openstack subnet list
openstack router list
```

---

### 创建实例

**方式 A**：使用 `sunbeam launch`（自动拉取 Ubuntu 镜像，体积较大）：

```bash
sunbeam launch ubuntu --name test
```

**方式 B**：使用 CirrOS 小镜像（约 13MB，便于快速验证）：

```bash
source ~/demo-openrc

# 1. 下载并上传 CirrOS
wget -q https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create --file cirros-0.4.0-x86_64-disk.img \
  --container-format bare --disk-format qcow2 --public \
  --property hw_disk_bus=scsi --property hw_scsi_model=virtio-scsi \
  cirros-base

# 2. 确认网络、规格
openstack network list
openstack flavor list

# 3. 创建实例（网络选 internal）
openstack server create --flavor m1.tiny --image cirros-base --network internal test-cirros

# 4. 查看状态
openstack server list
```

CirrOS 默认账号 `cirros`，密码 `gocubsgo`（仅测试用，勿暴露公网）。

---

### 官方文档链接

| 资源 | 链接 |
|------|------|
| Install OpenStack | https://ubuntu.com/openstack/install |
| Canonical OpenStack 文档 | https://canonical-openstack.readthedocs-hosted.com/ |
| Sunbeam (OpenInfra) | https://opendev.org/x/sunbeam |

---

## 4. 常用命令

### OpenStack CLI

使用前需加载凭证：`source ~/demo-openrc`

| 用途 | 命令 |
|------|------|
| 验证认证 | `openstack token issue` |
| 实例 | `openstack server list` / `openstack server create` / `openstack server show <name>` |
| 镜像 | `openstack image list` / `openstack image create` |
| 规格 | `openstack flavor list` / `openstack flavor create` |
| 网络 | `openstack network list` / `openstack subnet list` / `openstack router list` |
| 浮动 IP | `openstack floating ip create external` / `openstack server add floating ip <server> <ip>` |
| 配额 | `openstack quota show` / `openstack quota set <project-id> --instances 50 ...` |
| 项目 | `openstack project list` |
| 计算服务 | `openstack compute service list` |
| 超算节点 | `openstack hypervisor list` |
| 服务端点 | `openstack endpoint list` / `openstack endpoint set --url <url> <id>` |

### Juju（Sunbeam 编排）

| 用途 | 命令 |
|------|------|
| 查看 openstack 模型 | `juju status -m sunbeam-controller:gxcoder/openstack` |
| 查看 openstack-machines | `juju status -m admin/openstack-machines` |
| 查看关系 | `juju status -m admin/openstack-machines --relations` |
| 列出 offer | `juju list-offers -m sunbeam-controller:gxcoder/openstack` |
| 消费 offer | `juju consume sunbeam-controller:gxcoder/openstack.nova -m admin/openstack-machines` |
| 建立集成 | `juju integrate openstack-hypervisor nova -m admin/openstack-machines` |
| 配置应用 | `juju config nova -m sunbeam-controller:gxcoder/openstack` |
| 获取密码 | `juju list-secrets -m sunbeam-controller:gxcoder/openstack` 后 grep keystone |
|  | `juju show-secret --reveal secret:<id>` |

### kubectl（K8s，Sunbeam 内部）

| 用途 | 命令 |
|------|------|
| 查看 openstack 命名空间 Pod | `sudo kubectl -n openstack get pods` |
| 查看服务/NodePort | `sudo kubectl -n openstack get svc traefik-public-lb` |
| 查看 Pod 日志 | `sudo kubectl -n openstack logs <pod-name> --tail=50` |
| 查看事件 | `sudo kubectl -n openstack get events` |

若使用 snap 安装的 k8s：`sudo /snap/k8s/current/bin/kubectl -n openstack ...`

### MicroCeph

| 用途 | 命令 |
|------|------|
| 状态 | `microceph status` |
| 添加 OSD | `sudo microceph disk add /dev/sdb` |
| 磁盘列表 | `lsblk` |

### Sunbeam

| 用途 | 命令 |
|------|------|
| 引导集群 | `sunbeam cluster bootstrap --accept-defaults --role control,compute,storage` |
| 配置云 | `sunbeam configure --accept-defaults --openrc demo-openrc` |
| 启动实例 | `sunbeam launch ubuntu --name test` |
| Snap 服务 | `snap services openstack` / `snap services microceph` / `snap restart openstack` |

---

## 5. 创建用户脚本全文

`create_sunbeam_user.sh` 内容如下，保存后执行 `sudo bash create_sunbeam_user.sh [用户名] [密码]`：

```bash
#!/bin/bash
# 创建 Sunbeam 安装所需的普通用户
# 用法：sudo bash create_sunbeam_user.sh [用户名] [密码]
# 注意：必须用 bash 运行。密码需至少 8 位（系统策略）。

# 若被 sh 调用则用 bash 重新执行
[ -n "$BASH_VERSION" ] || exec bash "$0" "$@"

set -e

USER_NAME="${1:-cloudops}"
USER_PASS="${2:-Xk9#mP2\$vL}"

if [ "$EUID" -ne 0 ]; then
    echo "请使用 root 运行: sudo bash $0 [用户名] [密码]"
    echo "  默认: 用户名=cloudops, 密码已内置"
    exit 1
fi

if id "$USER_NAME" &>/dev/null; then
    echo "用户 $USER_NAME 已存在，更新密码..."
    echo "$USER_NAME:$USER_PASS" | chpasswd && echo "密码已更新" || echo "密码设置失败，请手动: passwd $USER_NAME"
    echo "切换用户: su - $USER_NAME"
    exit 0
fi

echo "创建用户: $USER_NAME"
useradd -m -s /bin/bash -G sudo "$USER_NAME"
if echo "$USER_NAME:$USER_PASS" | chpasswd; then
    echo "密码设置成功"
else
    echo "警告: 密码设置失败（可能未通过字典/复杂度检查），请手动执行: sudo passwd $USER_NAME"
fi
echo "$USER_NAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/cloudops
chmod 0440 /etc/sudoers.d/cloudops

echo ""
echo "=========================================="
echo "用户创建完成"
echo "=========================================="
echo "用户名: $USER_NAME"
echo "密码:   Xk9#mP2\$vL"
echo ""
echo "切换用户后执行 Sunbeam 步骤 2-5:"
echo "  su - $USER_NAME"
echo "  sunbeam prepare-node-script --bootstrap | bash -x"
echo "  newgrp snap_daemon"
echo "  sunbeam cluster bootstrap --accept-defaults --role control,compute,storage"
echo "  ..."
echo ""
```

---

## 6. 使用和常见问题与故障排查

### （1）sunbeam cluster bootstrap 失败，直接提示 Clusterd service is not active

**现象**：执行 `sunbeam cluster bootstrap` 时报错 `Error: Clusterd service is not active`，`snap services openstack` 显示 `openstack.clusterd 已启用 不活动`。

**原因**：clusterd（microcluster）未正确初始化或运行异常，可能与系统环境、硬件、权限等有关。

**建议**：若多次尝试清理重装、重启服务仍无法解决，**建议重装操作系统**（Ubuntu 24.04 全新安装）后重新部署。

**干净卸载流程**（需先切回当时执行 bootstrap 的用户，不要用 root）：

```bash
# 1. 切换用户
su - cloudops   # 或执行过步骤 2/3 的用户名

# 2. 销毁 Juju 控制器
juju destroy-controller localhost-localhost --no-prompt --destroy-storage

# 3. 卸载 snap（按顺序）
sudo snap remove openstack --purge
sudo snap remove juju --purge
sudo snap remove lxd --purge
sudo snap remove k8s --purge
sudo snap remove openstackclients --purge   # 若存在

# 4. 确认清理完成
snap list | grep -E 'openstack|juju|lxd|k8s'
```

---

### （2）Adding K8S unit to machine ... waiting for services to come online (0/1) wait timed out after xxx

**现象**：步骤 3 或 2 长时间卡在「Adding K8S unit to machine ... waiting for services to come online (0/1)」，最终超时。

**原因**：

- `registry.k8s.io` 在国内访问较慢或被墙，K8s 组件镜像拉取失败或极慢
- 也可能是下载较慢，实际上已在后台下载

**处理**：

1. **先确认是否已下载完成**：执行 `sudo /snap/k8s/current/bin/kubectl get pods -A` 或 `sudo /snap/k8s/current/bin/kubectl get pods -n kube-system` 查看 pod 状态。若已 `Running`，可忽略超时，直接重试 bootstrap。
2. **配置 containerd 镜像源代理**：在 `/etc/containerd/hosts.d/`（或 `certs.d`）下为 `registry.k8s.io` 配置国内镜像（如 DaoCloud `k8s.m.daocloud.io`），并重启 containerd 服务。
3. **配置 HTTP 代理**：若环境有代理，为 containerd/kubelet 配置代理后重试。

---

### （3）ERROR failed to bootstrap model: creating controller stack: creating statefulset for controller: timed out waiting for controller pod: pending

**现象**：报错 `timed out waiting for controller pod: pending`，Juju 控制器 pod 长时间处于 Pending 状态。

**原因**：多半是 controller pod 依赖的镜像拉取失败，例如 `ghcr.io/juju/jujud-operator`、`ghcr.io/juju/juju-db` 等在国内拉取慢或被墙。

**处理**：

1. **查看 pod 状态及事件**：
   ```bash
   sudo /snap/k8s/current/bin/kubectl get pods -A
   sudo /snap/k8s/current/bin/kubectl describe pod -n controller-sunbeam-controller controller-0
   ```
   在 `Events` 中确认是否因镜像拉取失败（如 `Failed to pull image`、`ImagePullBackOff`）。

   **需手动拉取的 Juju 控制器镜像列表**（若上述确认是 ghcr.io 拉取失败）：
   - `ghcr.io/juju/jujud-operator:3.6.14`
   - `ghcr.io/juju/juju-db:4.4`

   拉取命令：
   ```bash
   sudo /snap/k8s/current/bin/ctr -n k8s image pull ghcr.io/juju/jujud-operator:3.6.14
   sudo /snap/k8s/current/bin/ctr -n k8s image pull ghcr.io/juju/juju-db:4.4
   ```
2. **为 ghcr.io 配置国内镜像**：在 `/etc/containerd/hosts.d/ghcr.io/` 下添加 `hosts.toml`，使用 DaoCloud `ghcr.m.daocloud.io` 等镜像源，然后重启 containerd（snap k8s 下使用 `sudo snap restart k8s.containerd`）。

---

### （4）sunbeam cluster bootstrap 在 Bootstrapping Juju onto machine 阶段卡住

**现象**：步骤 3 执行 `sunbeam cluster bootstrap` 时进度卡住，使用 `sudo /snap/k8s/current/bin/kubectl get pods -A` 查看，`controller-sunbeam-controller` 命名空间下的 `controller-0` pod 长时间处于 `PodInitializing` 状态。

**处理**：

1. **查看 pod 详情及 Events**：
   ```bash
   sudo /snap/k8s/current/bin/kubectl get pods -A
   sudo /snap/k8s/current/bin/kubectl describe pod controller-0 -n controller-sunbeam-controller
   ```
2. **查看 Events 最后一行**：确认是否有 `Pulling image "ghcr.io/..."` 等拉取事件，说明正在拉取镜像。若长时间无进展，多半是镜像拉取慢或失败。
3. **先手动拉取**：根据 Events 显示的镜像名，执行 `ctr` 手动拉取：
   ```bash
   sudo /snap/k8s/current/bin/ctr -n k8s image pull ghcr.io/juju/jujud-operator:3.6.14
   sudo /snap/k8s/current/bin/ctr -n k8s image pull ghcr.io/juju/juju-db:4.4
   sudo /snap/k8s/current/bin/ctr -n k8s image pull ghcr.io/juju/charm-base:ubuntu-24.04
   ```
   拉取完成后，kubelet 会检测到本地已有镜像并继续初始化。

---

### （5）sunbeam cluster bootstrap 报错 cannot log into controller "sunbeam-controller": no API addresses

**现象**：执行 `sunbeam cluster bootstrap` 时报错 `cannot log into controller "sunbeam-controller": no API addresses`。此前曾因 controller pod 卡在 PodInitializing 而**手动中断**过 bootstrap。

**原因**：bootstrap 被中断时，`sunbeam-controller` 已写入 Juju 本地配置，但 `api-endpoints` 为空。再次执行 bootstrap 时，Juju 尝试登录该 controller 而非创建新的，导致失败。且 `juju kill-controller` 因无法连接也会失败。

**处理**：需手动从 Juju 配置中删除 `sunbeam-controller` 条目后，删除 namespace 再重试。

1. **备份并编辑 controllers.yaml**：
   ```bash
   cp ~/.local/share/juju/controllers.yaml ~/.local/share/juju/controllers.yaml.bak
   python3 -c "import yaml,os;p=os.path.expanduser('~/.local/share/juju/controllers.yaml');d=yaml.safe_load(open(p));d['controllers'].pop('sunbeam-controller',None);d['current-controller']='localhost-localhost';yaml.dump(d,open(p,'w'),default_flow_style=False,allow_unicode=True,sort_keys=False);print('Done')"
   ```
   （需先 `pip install pyyaml` 或 `sudo apt install python3-yaml`。或手动用 nano 编辑：删除 `sunbeam-controller` 整段，将 `current-controller` 改为 `localhost-localhost`。）

2. **备份并编辑 accounts.yaml**：
   ```bash
   cp ~/.local/share/juju/accounts.yaml ~/.local/share/juju/accounts.yaml.bak
   python3 -c "import yaml,os;p=os.path.expanduser('~/.local/share/juju/accounts.yaml');d=yaml.safe_load(open(p));d['controllers'].pop('sunbeam-controller',None);yaml.dump(d,open(p,'w'),default_flow_style=False,allow_unicode=True,sort_keys=False);print('Done')"
   ```

3. **删除 controller 命名空间并重试**：
   ```bash
   sudo /snap/k8s/current/bin/kubectl delete namespace controller-sunbeam-controller --force --grace-period=0 2>/dev/null || true
   sunbeam cluster bootstrap --accept-defaults --role control,compute,storage
   ```

**说明**：删除 namespace 不会删除已缓存的容器镜像，重试 bootstrap 时会复用。

---

### （6）使用 snap services 查看与重启服务

**现象**：`kubectl get pods -A` 报 `TLS handshake timeout`，或 bootstrap 卡在「waiting for services to come online (0/1)」。

**原因**：部分 snap 服务（如 k8s.etcd、microceph.daemon）未启动或异常退出，导致依赖它们的组件无法正常工作。

**处理**：使用 `snap services` 检查状态，并按需重启相关服务。

**1. 查看所有 snap 服务状态**：

```bash
snap services
```

关注以下服务：

| 服务 | 说明 | 若 inactive 的影响 |
|------|------|--------------------|
| k8s.etcd | Kubernetes 数据存储 | kubectl TLS handshake timeout |
| k8s.kube-apiserver | Kubernetes API | kubectl 无法连接 |
| microceph.daemon | MicroCeph 主服务 | bootstrap 卡在 MicroCeph 等待 |
| microceph.mon / mgr / osd | Ceph 组件 | 存储不可用 |
| openstack.clusterd | Sunbeam 集群管理 | cluster bootstrap 失败 |

**2. 启动/重启指定服务**：

```bash
# 启动单个服务
sudo snap start k8s.etcd
sudo snap start microceph.daemon
sudo snap restart openstack.clusterd

# 重启整个 snap 下的所有服务
sudo snap restart k8s
sudo snap restart microceph
sudo snap restart openstack
```

**3. 常见场景**：

- **kubectl TLS handshake timeout**：先检查 `k8s.etcd`，若 inactive 则执行 `sudo snap start k8s.etcd`。
- **bootstrap 卡在 MicroCeph / Cinder Volume 0/1**：先检查 `microceph.daemon`，若 inactive 则执行 `sudo snap start microceph.daemon`；若服务正常但仍卡住，通常是**无 OSD 磁盘**，按步骤 4.1 添加 OSD。
- **clusterd 无法绑定 IP**：确认网卡 IP 存在（`ip addr`），或重启 `sudo snap restart openstack.clusterd`。

---

### （7）重装前强制清理 Juju（destroy-controller 卡住时）

**现象**：执行 `juju destroy-controller` 长时间无响应；或 `pkill -9 -f juju` 后进程反复被拉起。

**原因**：Juju machine agent 由 systemd 管理，单纯杀进程会被自动重启；`destroy-controller` 可能在等待不可达的机器而卡住。

**处理**：在**执行过 bootstrap 的用户**下（如 cloudops）执行下列强制清理一条龙：

```bash
# 1. 停服务
sudo systemctl stop 'jujud-machine-*' 2>/dev/null
sudo systemctl disable 'jujud-machine-*' 2>/dev/null

# 2. 杀进程
sudo pkill -9 -f jujud

# 3. 删数据和服务文件
sudo rm -rf /var/lib/juju
sudo rm -f /etc/systemd/system/jujud-machine-*
sudo systemctl daemon-reload

# 4. 清理用户配置
rm -rf ~/.local/share/juju/* ~/.config/juju/ ~/.juju/ ~/.config/openstack/*

# 5. 确认无进程
ps aux | grep jujud | grep -v grep
```

执行后应无 jujud 进程。后续可按需继续删除 LXD 容器、移除 k8s 等，或重新执行 `sunbeam prepare-node-script` 和 bootstrap。

---

### （8）ctr 镜像备份导出与离线导入

**场景**：重装或迁移前备份 containerd 镜像；离线环境导入已导出的镜像。使用 k8s snap 自带的 `ctr`（`/snap/k8s/current/bin/ctr`）。

**导出（有网或本机）**：

```bash
mkdir -p ~/ctr-images-export
cd ~/ctr-images-export

for ns in k8s k8s.io; do
  for img in $(sudo /snap/k8s/current/bin/ctr -n $ns image list -q 2>/dev/null); do
    safe_name=$(echo "$img" | tr '/:@' '___')
    out="ctr_${ns}_${safe_name}.tar"
    echo "导出: $ns / $img -> $out"
    sudo /snap/k8s/current/bin/ctr -n $ns image export "$out" "$img"
  done
done

cd ~
tar -czvf ctr-images-export.tar.gz ctr-images-export/
```

**离线导入**：

```bash
# 解压（若已打包）
tar -xzvf ctr-images-export.tar.gz
cd ctr-images-export

for f in ctr_*.tar; do
  ns=$(echo "$f" | cut -d'_' -f2)
  echo "导入: $f 到命名空间 $ns"
  sudo /snap/k8s/current/bin/ctr -n $ns image import "$f"
done
```

**说明**：导出文件命名为 `ctr_{namespace}_{镜像名}.tar`，导入时从文件名解析 namespace（k8s 或 k8s.io）。需在已安装 k8s snap 的节点上执行。

---

### （9）状态与日志排查（Juju + kubectl）

**场景**：bootstrap 卡在「waiting for services to come online」或部分应用 blocked/waiting，需要定位未就绪的组件并查看日志。

**1. 查看 Juju 模型列表**：

```bash
juju models
```

典型输出包含 `sunbeam-controller:admin/openstack-machines`、`sunbeam-controller:gxcoder/openstack` 等。若无选中模型，后续 `juju status` 会报错「No selected model」。

**2. 切换到指定模型并查看整体状态**：

```bash
# 切换到 openstack 模型
juju switch sunbeam-controller:gxcoder/openstack

# 或直接指定模型查看
juju status -m sunbeam-controller:gxcoder/openstack

# 查看 openstack-machines 模型（cinder-volume、microceph 等）
juju status -m admin/openstack-machines
```

关注 `Status` 列为 `blocked`、`waiting` 的应用及 `Message` 列说明。

**3. 查看关系与异常单元**：

```bash
juju status -m sunbeam-controller:gxcoder/openstack --relations
juju status -m sunbeam-controller:gxcoder/openstack | grep -E 'blocked|waiting'
```

**4. 查看 K8s Pod 状态**（kubectl 在 k8s snap 下，需用完整路径）：

```bash
sudo /snap/k8s/current/bin/kubectl get pods -A

# 筛选未 Running 的 Pod（第 4 列为 STATUS）
sudo /snap/k8s/current/bin/kubectl get pods -A --no-headers | awk '$4!="Running" && $4!="Completed" {print}'
```

**5. 查看指定 Pod 日志**：

```bash
# 按 Pod 名查看（如 glance-0）
sudo /snap/k8s/current/bin/kubectl -n openstack logs glance-0 --tail=100

# 若 Pod 有多容器，指定容器
sudo /snap/k8s/current/bin/kubectl -n openstack logs glance-0 -c glance-api --tail=100

# 或先查看容器名
sudo /snap/k8s/current/bin/kubectl -n openstack get pod glance-0 -o jsonpath='{.spec.containers[*].name}'
```

**6. 排查顺序建议**：

| 步骤 | 命令 | 目的 |
|------|------|------|
| 1 | `juju models` | 确认可用模型 |
| 2 | `juju status -m <model>` | 找出 blocked/waiting 应用 |
| 3 | `juju status --relations` | 检查关系是否缺失 |
| 4 | `kubectl get pods -A` | 确认 Pod 是否 Running |
| 5 | `kubectl logs <pod> -n openstack` | 查看具体错误日志 |

---

### （10）VNC/SPICE 控制台外网访问

**现象**：在 Horizon 中点击实例控制台后，控制台 URL 使用内网 IP（如 `172.16.1.202`），外网无法打开，页面空白或无法连接。

**原因**：控制台代理（nova-spiceproxy）的 base URL 取自 Keystone 服务目录中的内网 endpoint，外网访问时需通过 NodePort 映射的地址。

**处理**：手动将控制台 URL 中的内网地址替换为外网访问地址。

- 原：`http://172.16.1.202/openstack-nova-spiceproxy/...`
- 改：`http://<物理IP>:<NodePort>/openstack-nova-spiceproxy/...`

例如，若物理 IP 为 `192.168.1.230`，NodePort 为 `32483`，则改为：

```
http://192.168.1.230:32483/openstack-nova-spiceproxy/spice_auto.html?path=...&token=...&title=...
```

**查看 NodePort：**
```bash
sudo /snap/k8s/current/bin/kubectl -n openstack get svc traefik-public-lb
```

---

### （11）API 及控制台 URL 统一改为外网访问

**现象**：Horizon「访问API」、控制台 URL 等均使用内网 IP（如 `172.16.1.202`），外网无法访问。

**原因**：Keystone 服务目录中的 endpoint 指向内网地址，需手动更新为外网可访问地址（物理 IP + NodePort）。

**处理**：批量更新 Keystone 中各服务的 public endpoint（IP 与 NodePort 按实际替换）：

```bash
source ~/demo-openrc
BASE="http://192.168.1.230:32483"
ADMIN_PROJECT=$(openstack project show admin -f value -c id)

# 逐条更新各服务
openstack endpoint set --url "${BASE}/openstack-keystone/v3" $(openstack endpoint list --service keystone --interface public -c ID -f value)
openstack endpoint set --url "${BASE}/openstack-nova/v2.1" $(openstack endpoint list --service nova --interface public -c ID -f value)
openstack endpoint set --url "${BASE}/openstack-glance" $(openstack endpoint list --service glance --interface public -c ID -f value)
openstack endpoint set --url "${BASE}/openstack-neutron" $(openstack endpoint list --service neutron --interface public -c ID -f value)
openstack endpoint set --url "${BASE}/openstack-placement" $(openstack endpoint list --service placement --interface public -c ID -f value)
openstack endpoint set --url "${BASE}/openstack-cinder/v3/${ADMIN_PROJECT}" $(openstack endpoint list --service cinderv3 --interface public -c ID -f value)
```

更新后刷新 Horizon，访问 API 页面和控制台 URL 将使用 `http://192.168.1.230:32483/...`。
