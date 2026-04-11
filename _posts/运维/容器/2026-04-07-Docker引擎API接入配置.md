---
title: Docker引擎API接入配置
date: 2026-04-07 11:00:00
categories: [运维, 容器]
tags: [运维, 容器, docker]
image:
  path: /assets/img/posts/common/docker.jpg
---

# Docker引擎API接入配置

> 说明 Docker Engine **HTTP API** 的能力与接入形态、**2375 / 2376** 端口含义、Linux（systemd）下默认仅 Unix Socket 的行为，以及如何检查与为本机开启 **TCP** 接入（如 `DOCKER_HOST=tcp://127.0.0.1:2375`）。适用于需通过 HTTP 调用 Docker 的应用与运维场景；细节以当前 Engine 版本及 [Docker Engine API](https://docs.docker.com/engine/api/) 为准。

---

## 一、API 介绍：接入后能做什么

Docker 守护进程（`dockerd`）对外提供 **REST 风格的 Engine HTTP API**（[Docker Engine API](https://docs.docker.com/engine/api/)）。通过 **TCP** 或 **Unix 套接字**上的同源协议接入后，效果等价于把 Docker 变成 **可被 HTTP 客户端调用的服务**——能力与终端 `docker` 子命令一致（容器/镜像/网络等），调用方式由 CLI 换为 HTTP。

- **`docker` CLI 与 API**：CLI 在多数场景下同样调用该 API，并非另一套私有协议。
- **典型用途**：自研平台启停实训容器、CI/CD、脚本用 `curl` 健康检查或批量查询等。

请求路径需带 **API 版本前缀**，形如 **`/v1.xx/`**。可先取本机支持版本再写死路径：

```bash
# TCP 示例（需已监听 2375，见后文）
curl -s http://127.0.0.1:2375/version

# Unix Socket 示例（与是否开启 2375 无关）
curl -s --unix-socket /run/docker.sock http://localhost/version
```

响应 JSON 中 **`ApiVersion`** 与 URL 中 **`v1.47`** 等对应。

### 示例：用 HTTP 列出容器（对应 `docker ps`）

**`GET /containers/json`**；**`all=true`** 时接近 **`docker ps -a`**。将 **`${API_VER}`** 换为 `/version` 返回值（如 `1.47`）。

**仅运行中：**

```bash
API_VER=1.47   # 按本机 /version 修改

curl -s "http://127.0.0.1:2375/v${API_VER}/containers/json"
```

**含已退出：**

```bash
curl -s "http://127.0.0.1:2375/v${API_VER}/containers/json?all=true"
```

**Unix Socket：**

```bash
curl -s --unix-socket /run/docker.sock \
  "http://localhost/v${API_VER}/containers/json?all=true"
```

返回为 JSON 数组；有 **`jq`** 时可简化查看：

```bash
curl -s "http://127.0.0.1:2375/v${API_VER}/containers/json?all=true" | jq '.[] | {Id: .Id[0:12], Names, State, Status, Image}'
```

其他常见对应（参数以官方文档为准）：**`docker images`** → `GET /images/json`；**`docker info`** → `GET /info`；**`docker run`** 多为创建 + 启动等组合请求。

---

## 二、端口与协议对照

| 端口 | 说明 |
|------|------|
| **2375** | Engine **未加密** HTTP API；**勿对公网暴露**。 |
| **2376** | 常见为 **TLS** API（需客户端证书，与 2375 不可混用）。 |

默认安装（尤其 **docker.socket**）通常 **不** 监听 2375，仅 **Unix 套接字**（如 `/run/docker.sock`）。

---

## 三、连接地址含义示例

| 配置示例 | 含义 |
|----------|------|
| `tcp://127.0.0.1:2375` | 仅 **本机** 进程经 TCP 访问本机 Docker。 |
| `tcp://192.168.x.x:2375` | 从 **其他机器** 访问该宿主机 Docker（需监听 + 防火墙/安全组）。 |
| `unix:///var/run/docker.sock` | 本机 **Unix socket**（与 `/run/docker.sock` 常等价）。 |

应用与 Docker **不在同一主机** 时不能使用对端的 `127.0.0.1`，应使用 **Docker 宿主机可达 IP**（或 VPN）。

---

## 四、如何查看当前是否已配置 TCP（2375 / 2376）

在 **安装 Docker 的服务器** 上执行。

### 是否已有进程监听

```bash
sudo ss -tlnp | grep -E '2375|2376'
# 或
sudo netstat -tlnp 2>/dev/null | grep -E '2375|2376'
```

- **有 2375**：已暴露未加密 HTTP API。
- **有 2376**：一般为 TLS API。
- **无输出**：多数仅 socket，未开 TCP。

### dockerd 启动参数

```bash
ps aux | grep dockerd | grep -v grep
```

示例：

```text
/usr/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
```

**`-H fd://`** 表示由 **systemd 套接字激活** 传入监听，是否 Unix/TCP 看 **`docker.socket`**。

### systemd：`docker.service`

```bash
systemctl cat docker
```

关注 **`ExecStart=`** 是否与 **`Requires=docker.socket`** 等配合。

### systemd：`docker.socket`

```bash
systemctl cat docker.socket
```

典型 **仅 Unix、无 TCP**：

```ini
[Socket]
ListenStream=/run/docker.sock
SocketMode=0660
SocketUser=root
SocketGroup=docker
```

本机用户常需加入 **`docker`** 组。若无 **`ListenStream=...:2375`** 等项，则未通过 socket 单元开 TCP。

### `/etc/docker/daemon.json`

```bash
sudo cat /etc/docker/daemon.json
```

若存在 **`"hosts": [...]`** 且含 **`tcp://...`**，需与 **`fd://` / docker.socket** 一并核对，避免冲突。

### `docker info`

```bash
docker info
```

可与 **ss、docker.socket、daemon.json** 交叉验证。

---

## 五、配置「写在哪里」：小结

| 位置 | 典型作用 |
|------|----------|
| **`docker.service`** 的 **`ExecStart`** | 常见 **`dockerd -H fd://`**，监听交给 systemd。 |
| **`docker.socket`**（及 **`docker.socket.d`**） | 声明 socket 激活监听；仅 **`ListenStream=/run/docker.sock`** 时无 2375。 |
| **`daemon.json` 的 `hosts`** | 可声明 `unix://` 与 `tcp://`；与 **`fd://`** 并存时改动面大，需按官方说明调整。 |

---

## 六、未监听 2375 时是否要显式配置？

**需要。** 默认 **docker.socket + fd://** 下通常 **只有 Unix socket**，在未增加 TCP 监听前 **`DOCKER_HOST=tcp://127.0.0.1:2375`** 不会成功。

---

## 七、推荐：用 systemd 为本机增加 2375（仅本机）

不改动 `daemon.json` 中镜像等配置，仅给 **`docker.socket`** 增加 **回环 TCP**：

```bash
sudo mkdir -p /etc/systemd/system/docker.socket.d
sudo tee /etc/systemd/system/docker.socket.d/tcp-local.conf <<'EOF'
[Socket]
ListenStream=127.0.0.1:2375
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker.socket
sudo systemctl restart docker
```

验证：

```bash
sudo ss -tlnp | grep 2375
curl -s --unix-socket /run/docker.sock http://localhost/_ping
curl -s http://127.0.0.1:2375/_ping
```

**安全**：`127.0.0.1:2375` 仅本机；**不要**将无 TLS 的 2375 绑到公网。

---

## 八、应用在「另一台机器」上访问 Docker

- 可让 Docker 监听 **内网 IP**（**须配合防火墙仅放行可信网段**），在 `docker.socket.d` 中使用形如 **`ListenStream=192.168.x.x:2375`**。
- **`0.0.0.0:2375`** 风险高，一般不推荐。
- 云上需安全组放行；长期暴露建议 **TLS（2376）** 或 **SSH 隧道**，而非明文 2375。

---

## 九、Windows / Docker Desktop

在 **Settings** 中开启类似 **Expose daemon on tcp://localhost:2375** 后，本机才可用 `tcp://127.0.0.1:2375`。与 Linux **systemd + docker.socket** 方式不同，以桌面版文档为准。

---

## 十、参考

| 资源 | 链接 |
|------|------|
| Docker Engine API | <https://docs.docker.com/engine/api/> |

daemon、systemd、security 等请以当前安装版本的官方文档为准。
