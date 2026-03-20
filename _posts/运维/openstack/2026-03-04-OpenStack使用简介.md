---
title: OpenStack使用简介
date: 2026-03-04 09:00:00
categories: [运维, openstack]
tags: [运维, openstack, 部署]
image:
  path: /assets/img/posts/common/openstack.jpg
---

# OpenStack使用简介

> 本文在简要介绍 OpenStack 作为虚拟化/云平台及其与常见平台的对比、核心组件功能之后，说明 CLI、配额、API 等日常使用方式。

---

## 1. 虚拟化平台简介与对比

**OpenStack** 是开源的 **IaaS（基础设施即服务）** 云平台，用于在自有机房或私有环境中提供类似公有云的虚拟机、网络、存储、镜像等能力。

与常见虚拟化/云平台的简要对比：

| 类型         | 代表产品              | 特点简述 |
|--------------|-----------------------|----------|
| 开源 IaaS 云 | **OpenStack**          | 组件多、生态成熟、可对接 Ceph/KVM 等，适合私有云、多租户、标准化 API |
| 商业虚拟化   | VMware vSphere         | 企业级、稳定、商业支持，成本高 |
| 开源虚拟化   | Proxmox VE、oVirt      | Proxmox 易上手、集成度高；oVirt 偏 KVM 管理，多节点 |
| 容器编排     | Kubernetes (K8s)       | 以容器/工作负载为主，与 OpenStack 可并存（OpenStack 管 VM，K8s 管容器） |
| 公有云       | 阿里云、AWS、Azure 等  | 托管服务，按量付费，无自建运维 |

**选型参考**：需要自建私有云、多项目/多租户、统一 API 与镜像管理时，OpenStack 是常见选择；若仅需单机或少量主机虚拟化，Proxmox 等更轻量。

---

## 2. 平台组件与功能

OpenStack 由多个**标准组件**组成，不同部署方式（如 Packstack、Kolla、Sunbeam、DevStack）安装与运维工具不同，但**组件功能一致**，用户看到的看板、镜像、实例、网络等能力相同。

| 组件       | 项目名   | 功能简述 |
|------------|----------|----------|
| **看板/控制台** | Horizon  | Web 管理界面：创建实例、管理镜像、网络、浮动 IP、查看用量与配额等 |
| **身份认证**   | Keystone | 用户、项目、角色、权限与 API 认证，签发 Token |
| **计算**       | Nova     | 虚拟机生命周期管理（创建、启停、删除）、调度到物理节点 |
| **镜像**       | Glance   | 镜像存储与管理（上传、删除、可见范围），实例从镜像启动 |
| **块存储**     | Cinder   | 云硬盘（卷）的创建、挂载、快照等 |
| **网络**       | Neutron  | 虚拟网络、子网、路由器、安全组、浮动 IP 等 |
| **对象存储**   | Swift    | 可选，对象存储服务 |

**说明**：无论用 Packstack 全包部署、Kolla 容器化部署，还是 Sunbeam 基于 K8s 部署，上述组件的**功能与 API 行为一致**，差异仅在安装路径、进程/容器管理和访问地址（如 Horizon 的 URL、凭证文件路径）。下文的 CLI、配额、API 用法在不同部署方式下通用。

---

## 3. OpenStack CLI

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

---

## 4. 项目配额（Quota）调整

项目配额限制实例、VCPU、内存、卷等资源的上限。admin 用户可通过 CLI 调大。

**查看当前配额：**
```bash
source ~/demo-openrc
openstack quota show
```

**调大配额：**（项目 ID 为必填，可用 `openstack project list` 查看；示例中为 admin 项目 ID，按实际替换）

```bash
source ~/demo-openrc
openstack quota set <project-id> \
  --instances 50 \
  --cores 100 \
  --ram 256000 \
  --volumes 50 \
  --gigabytes 5000 \
  --floating-ips 100 \
  --networks 200 \
  --ports 500 \
  --routers 50 \
  --secgroups 50
# 示例：openstack quota set 456305754919499a821fa3dd60cca120 --instances 50 ...
```

**参数对照：**

| 界面显示 | 参数名 | 说明 |
|----------|--------|------|
| 实例 | --instances | 实例数量上限 |
| VCPU | --cores | 虚拟核数上限 |
| 内存 | --ram | 单位 MB，如 256000 ≈ 250GB |
| 卷 | --volumes | 云盘数量上限 |
| 云硬盘 | --gigabytes | 云盘总容量(GB) |
| 浮动IP | --floating-ips | 浮动 IP 数量 |
| 网络 | --networks | 网络数量 |
| 端口 | --ports | 端口数量 |
| 路由 | --routers | 路由器数量 |
| 安全组 | --secgroups | 安全组数量 |

**查看项目 ID：**
```bash
openstack project list
```

---

## 5. API 接口使用

### 从控制台获取 API Token

**方式一：Horizon 页面**

1. 登录 Horizon：`http://<OpenStack_IP>/dashboard` 或 `http://<IP>:<NodePort>/openstack-horizon`
2. 进入「项目」→「API 访问」
3. 点击「下载 OpenStack RC 文件」获取环境变量；或在该页查看「API 端点」和「凭证」

**方式二：CLI 获取 Token**

```bash
source ~/demo-openrc   # 或 source /root/keystonerc_admin（Packstack）
openstack token issue
```

输出示例：
```
+------------+------------------------------------------------------------------+
| Field      | Value                                                            |
+------------+------------------------------------------------------------------+
| expires    | 2026-02-18T12:00:00.000000Z                                      |
| id         | gAAAAABh...                                                       |
| project_id | 456305754919499a821fa3dd60cca120                                |
| user_id    | 789315754919499a821fa3dd60cca130                                |
+------------+------------------------------------------------------------------+
```

其中 `id` 即为 API Token，在请求头中使用：`X-Auth-Token: <token>`。

---

### 查看 API URL 与端口

**方式一：CLI 列出端点**

```bash
source ~/demo-openrc   # 或 source /root/keystonerc_admin
openstack endpoint list
```

可查看各服务的 public/internal URL 和端口。

**方式二：从 openrc 获取**

openrc 中的 `OS_AUTH_URL` 即为 Keystone 地址，例如：

- **Sunbeam**：`http://192.168.1.230:32483/openstack-keystone/v3`（IP + NodePort）
- **Packstack**：`http://192.168.1.57:5000/v3`
- **DevStack**：`http://127.0.0.1:5000/v3`

---

### 常用服务端点与端口

| 服务 | 用途 | 典型 URL | 常用端口 |
|------|------|----------|----------|
| **Keystone** | 身份认证、Token | `{BASE}/v3` 或 `{BASE}/openstack-keystone/v3` | 5000（直接）或 NodePort |
| **Nova** | 计算、实例 | `{BASE}/v2.1` 或 `{BASE}/openstack-nova/v2.1` | 8774 |
| **Glance** | 镜像 | `{BASE}` 或 `{BASE}/openstack-glance` | 9292 |
| **Neutron** | 网络 | `{BASE}` 或 `{BASE}/openstack-neutron` | 9696 |
| **Cinder** | 块存储 | `{BASE}/v3/{project_id}` 或 `{BASE}/openstack-cinder/v3/{project_id}` | 8776 |
| **Placement** | 资源放置 | `{BASE}` 或 `{BASE}/openstack-placement` | 8780 |

说明：Sunbeam 下 `{BASE}` 通常为 `http://<IP>:<NodePort>`；Packstack/DevStack 下多为 `http://<IP>:<端口>`。

---

### 常用 API 接口示例

以下为 REST API 路径示例，均需在请求头加 `X-Auth-Token: <token>`。

| 服务 | 方法 | 路径 | 说明 |
|------|------|------|------|
| **Keystone** | POST | `/v3/auth/tokens` | 获取 Token |
| **Keystone** | GET | `/v3/projects` | 项目列表 |
| **Nova** | GET | `/v2.1/{project_id}/servers` | 实例列表 |
| **Nova** | POST | `/v2.1/{project_id}/servers` | 创建实例 |
| **Nova** | GET | `/v2.1/{project_id}/flavors` | 规格列表 |
| **Glance** | GET | `/v2/images` | 镜像列表 |
| **Glance** | POST | `/v2/images` | 创建镜像 |
| **Neutron** | GET | `/v2.0/networks` | 网络列表 |
| **Neutron** | GET | `/v2.0/subnets` | 子网列表 |
| **Cinder** | GET | `/v3/{project_id}/volumes` | 卷列表 |

**示例：获取实例列表**

```bash
TOKEN="<openstack token issue 中的 id>"
NOVA_URL="http://192.168.1.230:32483/openstack-nova/v2.1"
PROJECT_ID="<openstack project list 中的 admin 项目 id>"

curl -H "X-Auth-Token: $TOKEN" \
  "${NOVA_URL}/${PROJECT_ID}/servers"
```

---

## 6. 轻量桌面镜像（VNC 控制台需图形界面）制作和部署

以下做法基于标准 OpenStack（Glance + Nova + cloud-init 配置驱动器），**适用于 CentOS Packstack、Ubuntu Sunbeam/DevStack 等**。加载凭证：Sunbeam/DevStack 用 `source ~/demo-openrc`，Packstack 用 `source /root/keystonerc_admin`；Horizon 与 CLI 步骤一致。

官方云镜像多为 **无桌面**（CirrOS、Ubuntu Server、Debian、Fedora Cloud 等）。若需在 VNC 控制台中看到图形桌面，可选：

| 方案 | 体积 | 说明 |
|------|------|------|
| **Ubuntu Minimal + user-data 安装 XFCE** | 约 250MB + 200MB | 推荐。用 Ubuntu Minimal 创建实例，user-data 首次启动安装 `xfce4`，见下示例。 |
| **Ubuntu Server + user-data 安装 XFCE/LXDE** | 约 600MB + 200MB/150MB | 同上流程，镜像更大、包更全；LXDE 用 `lxde-core`+`lightdm` 更轻。 |
| **Debian Cloud + user-data 安装 XFCE** | 约 200MB + 200MB | [cloud.debian.org](https://cloud.debian.org/images/cloud/) 下载 generic 镜像，user-data 装 `xfce4`；默认用户 `debian`。 |
| **Fedora Cloud + user-data 安装 GNOME/XFCE** | 约 400MB + 桌面包 | [alt.fedoraproject.org/cloud](https://alt.fedoraproject.org/cloud/) 下载 qcow2，user-data 装 `@workstation-product-environment` 或 `@xfce-desktop`；默认用户 `fedora`。 |
| **Rocky / AlmaLinux + user-data 装 GNOME** | 约 500MB+ | RHEL 系云镜像 + user-data 安装 `gnome` 或 `server-with-gui`，适合需 CentOS 兼容环境时。 |
| **自建镜像** | 视配置 | 用 Packer 等基于 Ubuntu/Debian 构建带 XFCE 的 qcow2，一次构建、多次使用。 |
| **Live ISO 转 qcow2** | 约 2–4GB | Ubuntu Desktop / Debian Live 等 ISO 转成 qcow2 可带完整桌面，但无 cloud-init 或需自行配置，适合一次性桌面环境。 |

**说明**：各主流云镜像站（Ubuntu、Debian、Fedora、CentOS）均不提供“预装桌面”的 OpenStack 镜像，需通过 user-data 首次启动安装桌面，或自建/转制镜像。

### 示例：Ubuntu Minimal + XFCE（首次启动自动安装）

1. **上传 Ubuntu Minimal 镜像**：
   ```bash
   wget https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img
   source ~/demo-openrc   # Packstack 用 source /root/keystonerc_admin
   openstack image create "ubuntu-minimal-24" --file ubuntu-24.04-minimal-cloudimg-amd64.img \
     --disk-format qcow2 --container-format bare --public
   ```

2. **创建实例时设置用户数据并启用配置驱动器**（否则 cloud-init 收不到 user-data，会显示 DataSourceNone）：

   **user-data 示例（YAML）**：
   ```yaml
   #cloud-config
   chpasswd:
     expire: false
     list: |
       ubuntu:你的密码
   runcmd:
     - echo "nameserver 8.8.8.8" > /etc/resolv.conf
     - sed -i '/^Components:/ s/ main$/ main universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
     - sed -i '/^Components:/ s/ main restricted$/ main restricted universe multiverse/' /etc/apt/sources.list.d/ubuntu.sources
     - apt-get update
     - DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xfce4-goodies dbus-x11
     - systemctl set-default graphical.target
     - reboot
   ```
   将 `你的密码` 改为实际密码。若使用 Ubuntu 22.04 镜像，将 `noble` 改为 `jammy`。

   **Horizon**：登录 → **计算** → **实例** → **创建实例** → 填详情、源（选 `ubuntu-minimal-24`）、规格、网络 → 展开 **配置/高级选项** → 在 **用户数据** 中粘贴上述 YAML → **务必勾选「配置驱动器」** → 创建实例。

   **CLI**：
   ```bash
   source ~/demo-openrc   # Packstack 用 source /root/keystonerc_admin
   openstack server create \
     --image ubuntu-minimal-24 \
     --flavor m1.small \
     --network <网络名或ID> \
     --user-data user-data-xfce.yaml \
     --config-drive true \
     my-desktop-vm
   ```
   网络名或 ID 用 `openstack network list` 查看，默认可用 `public`。

3. 实例首次启动会安装 XFCE 并切换到图形模式，约 5–10 分钟。通过 VNC 控制台可看到桌面。**前提**：实例需能访问外网并具备 DNS，否则 apt 无法拉包。

**更轻量：LXDE**（约 150MB 额外占用）：
```yaml
packages:
  - lxde-core
  - lightdm
```
