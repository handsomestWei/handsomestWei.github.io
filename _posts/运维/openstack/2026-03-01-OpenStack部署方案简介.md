---
title: OpenStack部署方案简介
date: 2026-03-01 09:00:00
categories: [运维, openstack]
tags: [运维, openstack, 部署]
image:
  path: /assets/img/posts/common/openstack.jpg
---

# OpenStack部署方案简介

本文档对比多种 OpenStack 部署方式，说明各自架构、适用系统、运维工具及选择建议。

---

## 方案总览

| 方案 | 适用系统 | 底层架构 | 是否使用 k8s | 复杂度 | 耗时 | 典型场景 |
|------|----------|----------|--------------|--------|------|----------|
| **Sunbeam** | 仅 Ubuntu 24.04 | snap + Juju + MicroK8s | ✅ 是 | ⭐ 最低 | 15–30 分钟 | 单机、学习、快速体验 |
| **Packstack** | CentOS/RHEL 9 | 系统包 + systemd | ❌ 否 | ⭐⭐ 低 | 30–60 分钟 | PoC、测试、学习 |
| **DevStack** | Ubuntu / CentOS | 源码 + systemd | ❌ 否 | ⭐⭐⭐ 较高 | 30–60 分钟 | 开发、CI、最新代码 |
| **Docker DevStack** | 通用 | Docker Compose | ❌ 否 | ⭐⭐ 低 | 10–20 分钟 | 测试、隔离环境 |
| **Kolla-Ansible Docker** | 通用 | Docker + Ansible | ❌ 否（容器化） | ⭐⭐⭐ 中 | 视规模 | 测试、小规模部署 |

---

## 核心区别：是否使用 Kubernetes

- **Sunbeam**：由 Canonical 提供，基于 **Juju + MicroK8s** 编排，OpenStack 组件以 Pod 形式运行在 K8s 中。因此需要用到 **kubectl**、**juju**、**microceph**、**sunbeam** 等命令。
- **Packstack / DevStack / Docker**：采用传统 **systemd 服务**或 **Docker 容器**，**不使用 Kubernetes**。运维主要依赖 `openstack` CLI 和 `systemctl`（或 `docker`）。

**结论**：在 CentOS 上部署（Packstack 或 DevStack）时，不会有 k8s，也就没有 kubectl、juju、sunbeam 等命令，只需使用 `openstack` 和 `systemctl`。

---

## 各方案详解

### 1. Sunbeam（Ubuntu 24.04）

Canonical 官方推荐，OpenInfra 上游项目，通过 snap 安装，自动化程度最高。

| 项目 | 说明 |
|------|------|
| 系统要求 | **仅支持 Ubuntu 24.04 (Noble)**；不支持 22.04 |
| 架构 | snap (`openstack`) + Juju + MicroK8s + LXD |
| 存储 | MicroCeph（可选，Ceph 存储） |
| 运维工具 | `openstack`、`juju`、`kubectl`、`microceph`、`sunbeam` |
| 凭证 | `source ~/demo-openrc` |
| Horizon | 通常通过 NodePort 暴露，如 `http://<IP>:32483` |

**安装方式**：snap 安装 openstack 后，按分步流程完成集群引导与配置。

---

### 2. Packstack（CentOS Stream 9 / RHEL 9）

RDO 社区方案，使用系统包部署，**仅支持 CentOS/RHEL**。

| 项目 | 说明 |
|------|------|
| 系统要求 | CentOS Stream 9 或 RHEL 9 |
| 架构 | `centos-release-openstack-caracal` + `openstack-packstack`，`packstack --allinone` |
| 服务管理 | systemd（如 `nova-api`、`keystone`、`neutron-server` 等） |
| 运维工具 | `openstack`、`systemctl` |
| 凭证 | `source /root/keystonerc_admin` |
| Horizon | `http://<本机IP>/dashboard` |

**安装方式**：启用 CRB 仓库，安装 centos-release-openstack-caracal 与 openstack-packstack，执行 packstack --allinone。

---

### 3. DevStack（Ubuntu / CentOS）

源码方式，克隆 DevStack 后通过 `stack.sh` 部署，适合开发与 CI。

| 项目 | 说明 |
|------|------|
| 系统要求 | Ubuntu 24.04/22.04 或 CentOS Stream 9 |
| 架构 | 从上游克隆 DevStack 源码，执行 stack.sh 部署 |
| 服务管理 | systemd 或进程方式 |
| 运维工具 | `openstack`、`systemctl` |
| 凭证 | Ubuntu: `source ~/devstack/openrc admin admin`；CentOS 类似 |
| Horizon | `http://<IP>:6080` |

**安装方式**：先准备环境（依赖、stack 用户等），再克隆 DevStack 源码并执行 stack.sh。

**注意**：CentOS Stream 9 可能遇到 RabbitMQ、Python 包依赖冲突，可改用 Docker 容器方案规避。

---

### 4. Docker 部署

在容器中运行 OpenStack，与宿主机服务隔离，降低依赖冲突。

#### 4.1 DevStack Docker

| 项目 | 说明 |
|------|------|
| 架构 | Docker Compose + DevStack 官方镜像 |
| 运维工具 | `docker`、`docker-compose`、`openstack`（容器内） |
| Horizon | `http://<IP>:6080` |

**安装方式**：使用 Docker Compose 拉取 DevStack 镜像并启动容器。

#### 4.2 Kolla-Ansible Docker

| 项目 | 说明 |
|------|------|
| 架构 | Kolla 镜像 + Ansible 编排 |
| 运维工具 | `docker`、`ansible`、`openstack` |
| Horizon | `http://<IP>:80`，密码在 Kolla 配置目录中 |

**安装方式**：使用 Kolla 镜像与 Ansible 编排部署。

---

## 运维命令对照

| 用途 | Sunbeam | Packstack / DevStack | Docker |
|------|---------|----------------------|--------|
| 加载凭证 | `source ~/demo-openrc` | `source /root/keystonerc_admin` 或 `source ~/devstack/openrc admin admin` | 容器内或挂载 openrc 文件 |
| OpenStack CLI | `openstack ...` | `openstack ...` | `openstack ...` |
| 编排/服务 | `juju status`、`sunbeam ...` | `systemctl status nova-api` 等 | `docker ps`、`docker-compose logs` |
| K8s | `kubectl -n openstack get pods` | 不适用 | 不适用 |
| 存储 | `microceph status` | 系统 Cinder/LVM | 由镜像/卷管理 |

---

## 选择建议

| 需求 | 推荐方案 |
|------|----------|
| Ubuntu 24.04，快速上手、学习 | **Sunbeam** |
| CentOS/RHEL 9，PoC、测试 | **Packstack** |
| 开发、CI、需最新源码 | **DevStack** |
| 避免系统依赖冲突、隔离环境 | **Docker DevStack** |
| 需多节点、生产级 | 考虑 Charmed OpenStack、Kolla-Ansible 等（通常以单机为主） |

