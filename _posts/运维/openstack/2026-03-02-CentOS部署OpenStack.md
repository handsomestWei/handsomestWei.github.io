---
title: CentOS部署OpenStack
date: 2026-03-02 09:00:00
categories: [运维, openstack]
tags: [运维, openstack, centos]
image:
  path: /assets/img/posts/common/openstack.jpg
---

# CentOS部署OpenStack

在 CentOS Stream 9 上通过**安装包方式**使用 Packstack 部署 OpenStack Caracal（单机 All-in-One）。

## 前置条件

- **系统**：CentOS Stream 9（或 RHEL 9）
- **内存**：建议 ≥8GB；不足时可加 swap：`fallocate -l 4G /swapfile && mkswap /swapfile && swapon /swapfile`
- **磁盘**：`/var/tmp` 所在分区至少 10GB 可用
- **网络**：可访问互联网及 CentOS/RDO 仓库
- **权限**：root 或 sudo

## 快速安装

- **一键安装**：执行下方「一键安装脚本」中的命令，或将脚本保存为 `install_openstack_packstack_centos9.sh` 后执行 `sudo bash install_openstack_packstack_centos9.sh`（需 root）。
- **手动安装**：启用 CRB，安装 `centos-release-openstack-caracal` 与 `openstack-packstack`，再执行 `packstack --allinone`。具体命令见下方「手动安装步骤」。
- **用已有 answer 重跑并观测**（调试用）：  
  `packstack --answer-file=/root/packstack-answers-20260127-144337.txt --debug`  
  将 `packstack-answers-20260127-144337.txt` 换成你本机实际的 answer 文件名即可；`--debug` 会输出详细日志便于观察各阶段。

### 一键安装脚本

以下脚本内容可直接复制保存为 `install_openstack_packstack_centos9.sh` 后执行 `sudo bash install_openstack_packstack_centos9.sh`，或在理解步骤后按需分步执行。

```bash
#!/bin/bash
# OpenStack Packstack 一键安装（CentOS Stream 9）
# 使用 centos-release-openstack-caracal + packstack --allinone

set -e
[ "$EUID" -ne 0 ] && { echo "请使用 root 运行: sudo $0"; exit 1; }

# 1. 启用 CRB 仓库
dnf config-manager --enable crb || true

# 2. 安装 OpenStack Caracal 仓库与 Packstack
dnf install -y centos-release-openstack-caracal
dnf update -y
dnf install -y openstack-packstack

# 3. 配置 root 本机 SSH（避免 Preparing servers 报错）
systemctl enable sshd 2>/dev/null || true
systemctl start sshd 2>/dev/null || true
mkdir -p /root/.ssh
chmod 700 /root/.ssh
[ ! -f /root/.ssh/id_rsa ] && ssh-keygen -t rsa -N "" -f /root/.ssh/id_rsa
[ ! -f /root/.ssh/id_ed25519 ] && ssh-keygen -t ed25519 -N "" -f /root/.ssh/id_ed25519
for key in id_rsa id_ed25519; do
  [ -f "/root/.ssh/${key}.pub" ] || continue
  grep -qF "$(cat /root/.ssh/${key}.pub)" /root/.ssh/authorized_keys 2>/dev/null || cat /root/.ssh/${key}.pub >> /root/.ssh/authorized_keys
done
chmod 600 /root/.ssh/authorized_keys 2>/dev/null || true
restorecon -R /root/.ssh 2>/dev/null || true

# 4. 运行 Packstack
packstack --allinone
```

安装完成后，Horizon 地址为 `http://<本机IP>/dashboard`，凭据见 `/root/keystonerc_admin` 或 Packstack 生成的 answer 文件。

### 手动安装步骤

若不使用脚本，可按以下顺序执行（需 root）：

```bash
dnf config-manager --enable crb
dnf install -y centos-release-openstack-caracal
dnf update -y
dnf install -y openstack-packstack
# 配置 root 本机 SSH（见上文一键安装脚本第 3 步），然后：
packstack --allinone
```

## 安装前建议（必读）

| 项目 | 建议配置 |
|------|----------|
| 磁盘 | `/var/tmp` 至少 10GB 可用 |
| 内存 | ≥8GB，不足时添加 swap（见上文） |
| **SELinux** | **不要禁用**；SSH 相关目录需执行：`restorecon -R ~/.ssh` |
| **NetworkManager** | **部署前建议关闭**；与 Neutron 不兼容，易导致 Puppet 阶段 Neutron 500 等错误，见下文「Neutron 500 (9696)」 |
| 防火墙 | 测试阶段可临时：`systemctl stop firewalld` |
| 时间同步 | `dnf install -y chrony && systemctl enable --now chronyd` |

## 安装后

- **Horizon**：`http://<本机IP>/dashboard/`（建议用本机 IP 访问，避免 127.0.0.1 路由到默认 vhost）
- **管理员凭据**：默认用户名 `admin`，密码可通过以下方式获取：
  - **从 keystonerc_admin 查看（推荐）**：`grep OS_PASSWORD /root/keystonerc_admin`
  - **从 Packstack answer 文件查看**：`strings /root/packstack-answers-*.txt | grep -E "CONFIG_KEYSTONE_ADMIN_PW"`
  - **登录 Horizon**：访问 `http://<本机IP>/dashboard/`，输入 `admin` 和上述密码，域留空或选 `Default`
- **CLI**：`source /root/keystonerc_admin` 后使用 `openstack` 命令

### Packstack 默认 API 端点（Horizon「访问 API」可查）

| 服务 | 端点 | 端口 |
|------|------|------|
| Identity (Keystone) | `http://<本机IP>:5000` | 5000 |
| Compute (Nova) | `http://<本机IP>:8774/v2.1` | 8774 |
| Image (Glance) | `http://<本机IP>:9292` | 9292 |
| Network (Neutron) | `http://<本机IP>:9696` | 9696 |
| Volume (Cinder) | `http://<本机IP>:8776/v3` | 8776 |

后端适配器会从 `OPENSTACK_AUTH_URL` 解析主机地址，强制使用 Nova/Glance 端点，避免服务目录返回内部主机名导致 404。

## 查看 OpenStack 版本

Packstack 安装的 OpenStack 版本由 `centos-release-openstack-caracal` 决定，当前为 **Caracal**。可用以下方式确认：

### 1. 客户端版本（非服务端）

```bash
openstack --version
```

仅显示 OpenStack 客户端版本，**不是**实际部署的服务端版本。

### 2. 各组件版本（推荐）

```bash
source /root/keystonerc_admin

# 查看各服务 API 版本
openstack versions show

# 或查看单个服务
openstack versions show --service keystone
openstack versions show --service nova
openstack versions show --service glance
```

### 3. 从包/发行版推断

```bash
# 查看安装的 OpenStack 发行包
rpm -qa | grep -E "centos-release-openstack|openstack-"

# 示例输出：centos-release-openstack-caracal-1-1.el9.noarch → Caracal
```

### 4. 各组件 manage 命令（需 root）

```bash
keystone-manage --version
nova-manage --version
glance-manage --version
```

将版本号对照 [releases.openstack.org](https://releases.openstack.org/) 可确定发行代号（如 Caracal、Antelope 等）。

## 镜像（创建实例前准备）

**创建服务器实例必须指定镜像**，Packstack 安装完成后 **Glance 默认不含任何镜像**，需手动上传。

### 是否需要镜像？

| 问题 | 答案 |
|------|------|
| 创建实例是否需要镜像？ | ✅ **必须**，创建虚拟机时必须指定 image_id |
| Packstack 默认有镜像吗？ | ❌ **没有**，Glance 初始为空 |
| 需要手动上传吗？ | ✅ **需要**，首次使用前需上传至少一个镜像 |

### 推荐：CirrOS 最小测试镜像（约 15MB）

CirrOS 是轻量级 Linux 测试镜像，体积小、启动快，适合验证环境：

```bash
# 加载环境变量
source /root/keystonerc_admin

# 检查当前镜像（通常为空）
openstack image list

# 下载 CirrOS（约 15MB）
wget https://download.cirros-cloud.net/0.6.1/cirros-0.6.1-x86_64-disk.img

# 上传到 Glance
openstack image create "cirros" \
    --file cirros-0.6.1-x86_64-disk.img \
    --disk-format qcow2 \
    --container-format bare \
    --public

# 验证
openstack image list
```


### 其他可选镜像

| 镜像 | 用途 | 下载/说明 |
|------|------|----------|
| **CirrOS** | 快速测试、验证环境（无桌面） | 见上文，约 15MB |
| **Ubuntu Minimal** | 轻量基础，可配合 user-data 装桌面 | [cloud-images.ubuntu.com/minimal](https://cloud-images.ubuntu.com/minimal/releases/) |
| **Ubuntu Server** | 通用 Linux，可 user-data 装 XFCE/LXDE | [cloud-images.ubuntu.com](https://cloud-images.ubuntu.com/releases/) |
| **Debian** | 稳定、轻量，可 user-data 装 XFCE | [cloud.debian.org/images/cloud](https://cloud.debian.org/images/cloud/) |
| **Fedora Cloud** | 新版本、可 user-data 装 GNOME/XFCE | [alt.fedoraproject.org/cloud](https://alt.fedoraproject.org/cloud/)（选 OpenStack/qcow2） |
| **CentOS Stream / Rocky / Alma** | RHEL 系，可 user-data 装 GNOME | [cloud.centos.org](https://cloud.centos.org/)、[almalinux.org](https://almalinux.org/)、[rockylinux.org](https://rockylinux.org/) |

**注意**：`--file` 需接本地文件路径，不支持直接填 URL。若网络受限，可先在其他机器下载后通过 SCP 传到 OpenStack 节点再上传。

### CLI 方式添加与删除镜像

以下命令需在已加载 OpenStack 凭证的环境下执行（如 `source /root/keystonerc_admin`）。

| 操作 | 命令 |
|------|------|
| **列出所有镜像** | `openstack image list` |
| **按名称查找镜像** | `openstack image list --name ubuntu-minimal-24` |
| **添加镜像** | `openstack image create "镜像名称" --file <本地文件> --disk-format qcow2 --container-format bare --public` |
| **删除镜像** | `openstack image delete <IMAGE_ID>`（ID 由 `image list` 得到） |

**示例：先查再删、再重新上传**

```bash
# 1. 查看当前是否已有该名称的镜像（记下 ID）
openstack image list --name ubuntu-minimal-24

# 2. 若要重新上传，先删除旧镜像（把 <IMAGE_ID> 换成上一步列出的 ID）
openstack image delete <IMAGE_ID>

# 3. 再创建并上传
openstack image create "ubuntu-minimal-24" \
  --file ubuntu-24.04-minimal-cloudimg-amd64.img \
  --disk-format qcow2 --container-format bare --public
```

说明：同一名称可以对应多个镜像（多次 `image create` 会生成多个 ID）；若希望只保留一份，需先删除旧镜像再创建。

## 关于 answer-file（packstack-answers-*.txt）

answer-file 是 Packstack 自动化部署用的配置文件，用于指定“装哪些服务、密码、网段”等，**不**用于改 Keystone/Horizon/RabbitMQ 等核心服务的监听端口。

### 如何生成或得到

| 方式 | 说明 |
|------|------|
| **推荐** | `packstack --gen-answer-file=/root/packstack-answers.txt`：按当前系统生成带注释的完整模板，可编辑后再用 `--answer-file=...` 执行。 |
| **自动产生** | 直接执行 `packstack --allinone` 时，会在 `/var/tmp/packstack/<当次目录>/` 下生成临时 answer 文件；若安装中断，可到该目录拷贝到 `/root/` 并重命名，修改后用于 `packstack --answer-file=...` 重跑。 |

编辑 answer-file 时可：开启/关闭某服务（如 Cinder、Swift）、改密码、指定 CONFIG_SSH_KEY、配置网络/网段等。

### 能否通过修改 answer-file 避免端口冲突？

**不能。** 核心服务的监听端口在 OpenStack/Packstack 中基本固定，answer-file 里**没有**“改 80/5000/5672/3306”的选项。

| 服务 | 典型端口 | 是否可在 answer-file 中配置 |
|------|----------|----------------------------|
| Keystone (API) | 5000, 35357 | ❌ 不可配 |
| Horizon (Dashboard) | 80 / 443 | ❌ 不可配（由 Apache 决定） |
| RabbitMQ | 5672 | ❌ 不可配 |
| MariaDB | 3306 | ❌ 不可配 |
| Nova API / Glance API 等 | 8774, 9292 等 | ❌ 不可配 |

answer-file 里与“网络”相关的多是：是否启用某服务、Provider 网络 VLAN 范围、是否用 HTTPS（仍为 443）等，**不解决** 80/5000 被 nginx、Docker 等占用的问题。

**正确做法**：部署前保证 80、5000、5672、3306 等端口**空闲**，停掉或迁移占用这些端口的进程（如 nginx、绑定 host 的容器、其它 Web/DB），再跑 Packstack。不要试图在 answer-file 里“改端口”规避冲突。

### 部署前建议：清理可能占用的服务与端口

在**已装有 nginx、Docker、其它 Web/DB** 的机器上部署前，建议先做端口与进程清理，再执行 `packstack --answer-file=...` 或 `--allinone`：

```bash
# 停止并禁用可能占用 80/5000 的服务
sudo systemctl stop nginx httpd
sudo systemctl disable nginx

# 若本机有 Docker 且曾把容器映射到 80/5000，按需停止
sudo docker stop $(sudo docker ps -q) 2>/dev/null || true

# 检查关键端口是否空闲（无输出表示空闲）
ss -tuln | grep -E ':(80|5000|5672|3306)'
```

若有输出，需根据 `ss -tulnp` 或 `systemctl status` 找到对应进程并停掉/改端口。**最佳实践**：在干净的系统（新装 CentOS Stream 9、未跑其它 Web/DB）上做 Packstack All-in-One，可最大限度减少端口冲突。

### 小结

| 问题 | 结论 |
|------|------|
| answer-file 如何得到？ | `packstack --gen-answer-file=xxx` 生成模板；或从 `packstack --allinone` 的临时目录拷贝。 |
| 能否通过改 answer-file 避免 80/5000 等冲突？ | ❌ 不能，这些端口不可在 answer-file 中配置。 |
| 端口冲突时该怎么办？ | ✅ 部署前停止占用 80/5000/5672/3306 的进程（如 nginx、相关容器），或使用干净系统。 |

## 常见问题（以实际验证为准）

### 1. 找不到 `centos-release-openstack-caracal`

确认为 CentOS Stream 9 且已启用 CRB，执行 `dnf config-manager --enable crb` 后重试。

### 2. 报错 “Connection closed by … port 22”

**现象**：运行 packstack 时出现  
`ERROR : Failed to run remote script, stderr: Connection closed by 192.168.1.57 port 22`。

**原因（按阶段区分）**：

1. **前期（如 Preparing servers）**：SSH **密钥不匹配**  
   - Packstack 会往 `~/.ssh/authorized_keys` 写一个固定的 ed25519 公钥，但默认用 `~/.ssh/id_rsa`（RSA）认证，公私钥类型不一致导致认证失败、连接被关。

2. **后期（如 Copying Puppet modules）**：SSH **并发连接超限**  
   - Packstack 会并行发起大量 SSH 连接，OpenSSH 默认 `MaxStartups 10:30:60`，超限后服务端主动断开，表现为 “Connection closed”。  
   - 日志中可见：`drop connection #0 from ... penalty: failed authentication`，以及大量 `Invalid user xxx`（多为重试噪音）。

### 3. 如何解决 SSH 密钥不匹配？（推荐做法）

以 **ed25519 密钥** 为准，保证 Packstack 使用的私钥与写入 `authorized_keys` 的公钥一致：

1. 生成 ed25519 密钥对（无密码）：  
   `ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519`
2. 将公钥写入 authorized_keys：  
   `cat ~/.ssh/id_ed25519.pub > ~/.ssh/authorized_keys`
3. 权限与属主：  
   `chmod 700 ~/.ssh`，`chmod 600 ~/.ssh/authorized_keys ~/.ssh/id_ed25519`，`chown -R root:root ~/.ssh`
4. **修复 SELinux 上下文（关键）**：  
   `restorecon -R ~/.ssh`
5. 在 answer 文件中指定私钥路径：  
   `echo "CONFIG_SSH_KEY=/root/.ssh/id_ed25519" >> /root/packstack-answers-*.txt`

验证：  
`ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@localhost "echo OK"`  
应能免密执行成功。

### 4. Puppet 报错 Sshkey：Invalid value "192.168.1.57:22"（compute 阶段）

**现象**：Applying 192.168.1.57_compute.pp 失败，报错  
`Parameter type failed on Sshkey[@]: Invalid value "192.168.1.57:22". Valid values are ssh-dss, ssh-ed25519, ssh-rsa, ...`

**原因**：Packstack 用 `ssh-keyscan` 获取主机密钥时，输出里包含**注释行**（如 `# 192.168.1.57:22 SSH-2.0-OpenSSH_9.9`）。生成 SSH_KEYS 的代码未跳过注释，把该行按三列解析，导致 `host_key_type` 被误设为 `192.168.1.57:22`，而 Puppet 的 sshkey type 只接受 `ssh-ed25519`、`ssh-rsa` 等。

**永久修复**：在 Packstack 的 `nova_300.py` 里，解析 HOST_KEYS 时**跳过以 `#` 开头的注释行**（ssh-keyscan 输出的 `# 192.168.1.57:22 SSH-2.0-...` 不应被当作密钥行解析）。

在 **192.168.1.57**（或执行 packstack 的机器）上执行：

```bash
NOVA_PY="/usr/lib/python3.9/site-packages/packstack/plugins/nova_300.py"
sudo cp "$NOVA_PY" /root/nova_300.py.bak

# 用 Python 在 "if not hostkey: continue" 之后插入两行（跳过注释行）
sudo python3 << 'PY'
path = "/usr/lib/python3.9/site-packages/packstack/plugins/nova_300.py"
with open(path) as f:
    lines = f.readlines()
new_lines = []
i = 0
while i < len(lines):
    new_lines.append(lines[i])
    if "if not hostkey:" in lines[i] and i + 1 < len(lines) and "continue" in lines[i + 1]:
        new_lines.append(lines[i + 1])
        new_lines.append("            if hostkey.startswith('#'):\n")
        new_lines.append("                continue\n")
        i += 2
    else:
        i += 1
with open(path, "w") as f:
    f.writelines(new_lines)
print("Patched: skip comment lines in SSH_KEYS")
PY
```

验证：`grep -A 2 "if not hostkey:" "$NOVA_PY"` 应看到其下多了 `if hostkey.startswith('#'):` 与 `continue`。

若上述脚本未生效，可手动编辑：

```bash
sudo vi "$NOVA_PY"
```

找到（约 340–346 行）：

```python
        for hostkey in config['HOST_KEYS_%s' % host].split('\n'):
            hostkey = hostkey.strip()
            if not hostkey:
                continue

            _, host_key_type, host_key_data = hostkey.split()
```

在 `continue` 与空行之后、`_, host_key_type, ...` 之前增加两行：

```python
            if hostkey.startswith('#'):
                continue
```

保存后，以后每次 `packstack --answer-file=...` 生成的 SSH_KEYS 将只包含真实密钥行，不再出现 `192.168.1.57:22` 作为 type。

**临时修复**（仅当次 run）：在当次 packstack 的 hieradata 里把 `192.168.1.57:22.openstack` 改为 `192.168.1.57.openstack`，`type: 192.168.1.57:22` 改为 `type: ssh-ed25519`，再重跑 compute manifest。

### 5. 如何解决 SSH 并发连接被拒绝？（Copying Puppet modules 等阶段）

提高 SSH 服务端未认证连接上限：

1. 追加配置：  
   `echo "MaxStartups 100:30:200" | sudo tee -a /etc/ssh/sshd_config`
2. 重启 sshd：  
   `sudo systemctl restart sshd`
3. 可选清理后重跑：  
   `rm -rf /var/tmp/packstack*`，再执行  
   `packstack --answer-file=/root/packstack-answers-*.txt`

参数含义：100＝最多 100 个未认证连接；30＝超过 100 后按 30% 概率拒绝；200＝达到 200 时全部拒绝。

### 6. 长时间停在 “Applying Puppet manifests” / “Testing if puppet apply is finished”

这是**正常等待**，不是卡死。Packstack 在等目标机上 `puppet apply 192.168.1.57_controller.pp` 跑完，该步骤会安装配置 Keystone、Glance、Nova、Neutron 等，通常需 **30～60 分钟或更久**。

**在本机（192.168.1.57）上可这样验证**：

- 看 puppet 是否在跑：  
  `ps aux | grep puppet`
- 看本次临时目录（日志里会有一串如 `cabb066ec0d24b4494d1ad8793ccdfd2`）：  
  `ls -la /var/tmp/packstack/*/manifests/`  
  若存在 `*_controller.pp.running`，说明仍在执行；出现 `*.finished` 即结束。
- 实时看 apply 输出：  
  `tail -f /var/tmp/packstack/<当次目录>/manifests/*_controller.pp.running`  
  将 `<当次目录>` 换成 `ls /var/tmp/packstack/` 下本次的目录名。

只要进程在、`.running` 有持续输出或体积在涨，即可耐心等待，无需中断。

若 `.running` 里出现 **“Connection refused” to 192.168.1.57:5000**、**“Retrying for XX more seconds”**：  
Puppet 在等 **Keystone** 在 5000 端口就绪。请先执行 `systemctl status mariadb rabbitmq-server httpd`：**若 rabbitmq-server 为 failed**，则 Keystone 无法正常起来，5000 会一直拒绝连接。处理方式见下一条「RabbitMQ 启动失败」。

### 7. Applying Puppet 报错 Neutron_subnet[public_subnet] / 500 (9696)

**现象**：Puppet 阶段失败，日志类似：

```text
Error: /Stage[main]/Packstack::Provision/Neutron_subnet[public_subnet]: Could not evaluate: Execution of '/usr/bin/openstack subnet set public_subnet --no-allocation-pool' returned 1: HttpException: 500: Server Error for url: http://192.168.1.57:9696/v2.0/subnets/...
请求失败：在处理请求时，发生内部服务器错误。
```

同时 Packstack 输出中可能出现：  
**“Warning: NetworkManager is active on … OpenStack networking currently does not work on systems that have the Network Manager service enabled.”**

**原因**（按排查顺序看）：

1. **Neutron 连不上 RabbitMQ（优先排查）**  
   若 `tail -100 /var/log/neutron/server.log` 里出现 **`OSError: Server unexpectedly closed connection`**，且堆栈中有 `oslo_messaging/_drivers/impl_rabbit.py`、`amqp/connection.py` 等，说明 **Neutron 与 RabbitMQ 的连接被服务端主动断开**。此时 Neutron 无法正常处理 RPC，API 请求（如 `subnet set`）会返回 500。  
   **根因在 RabbitMQ**：RabbitMQ 未就绪、崩溃、或曾因主机名（如 nodistribution）异常，导致连接被关。处理方式见下一条「RabbitMQ 启动失败」：修好 RabbitMQ 后执行 `systemctl restart neutron-server`，再重跑 Packstack 或继续 Puppet。
2. **NetworkManager 与 Neutron 不兼容**  
   OpenStack 官方文档及 RDO 均说明：在启用 Neutron 时，**不应**在部署节点上运行 NetworkManager。NetworkManager 会管理网卡、路由等，与 Neutron 使用的网桥、接口配置冲突，可能导致 Neutron API 在处理 subnet 等操作时返回 500 或行为异常。Packstack 会提示 “NetworkManager is active … OpenStack networking currently does not work …”。
3. Neutron 服务端在执行 `subnet set --no-allocation-pool` 时的其它内部错误（如 OVN 后端、网关/池冲突等），在 RabbitMQ 不稳或 NetworkManager 开启时更容易出现。
4. **Neutron API 对 list 处理不当（可永久修）**  
   若 `tail -100 /var/log/neutron/server.log` 里出现 **`AttributeError: 'list' object has no attribute 'split'`**，堆栈在 **`neutron_lib/api/converters.py`** 的 **`convert_ip_to_canonical_format`** 和 **`netaddr/strategy/ipv4.py`**：说明请求体里某 IP 字段（如 allocation_pools）被解析成 list，而转换器期望字符串。需改 neutron_lib 的 `convert_ip_to_canonical_format`，对 list 直接返回不转换。见下文「永久修复（改 neutron_lib）」。

**处理步骤**：

1. **先看 Neutron 日志，区分是 RabbitMQ、NetworkManager 还是 list 转换错误**  
   - 在控制节点上：  
     `sudo tail -100 /var/log/neutron/server.log`  
   - 若出现 **`OSError: Server unexpectedly closed connection`** 且堆栈含 **`impl_rabbit` / `amqp`**：先按「RabbitMQ 启动失败」修好 RabbitMQ，再 `sudo systemctl restart neutron-server`，然后重跑 `packstack --answer-file=...` 或等待 Puppet 重试。
2. **部署前关闭 NetworkManager（推荐从干净环境重装）**  
   - 关闭并禁用 NetworkManager，改用传统网络配置（若为 DHCP，可先记下当前 IP/网关等）：  
     `sudo systemctl stop NetworkManager`  
     `sudo systemctl disable NetworkManager`  
   - 启用传统 network 服务（若存在）：  
     `sudo systemctl enable network`  
     `sudo systemctl start network`  
   - 若系统只有 NetworkManager 管理网卡，需在禁用前在 `/etc/sysconfig/network-scripts/` 等处配置好静态 IP 或确保 `network` 服务能正确拉取地址，避免断网。
3. **清理后重跑 Packstack**  
   - 若此前安装已半失败，建议清理再重装：  
     `sudo packstack --cleanup`（会删除本次部署创建的资源与配置，慎用）  
     或重装系统后在**未启 NetworkManager** 的前提下重新执行 `packstack --answer-file=...`。
4. **永久修复（改 neutron_lib）——当日志为 `'list' object has no attribute 'split'` 时**  
   Neutron API 在解析 `subnet set --no-allocation-pool` 请求时，`convert_ip_to_canonical_format` 收到 list 仍当字符串处理导致崩溃。在 **192.168.1.57** 上对 neutron_lib 打补丁，使 list 直接返回不转换：

   ```bash
   CONVERTERS="/usr/lib/python3.9/site-packages/neutron_lib/api/converters.py"
   sudo cp "$CONVERTERS" "${CONVERTERS}.bak"

   # 在 convert_ip_to_canonical_format 里、ip = netaddr.IPAddress(value) 之前插入两行
   sudo python3 << 'PY'
   path = "/usr/lib/python3.9/site-packages/neutron_lib/api/converters.py"
   with open(path) as f:
       lines = f.readlines()
   for i in range(len(lines)):
       if "    ip = netaddr.IPAddress(value)" in lines[i]:
           # 在该行前插入两行（且在 try: 块内，缩进一致）
           lines.insert(i, "    if isinstance(value, list):\n")
           lines.insert(i + 1, "        return value\n")
           break
   with open(path, "w") as f:
       f.writelines(lines)
   print("Patched: convert_ip_to_canonical_format accepts list")
   PY
   ```

   验证：`sed -n '193,202p' "$CONVERTERS"` 应看到在 `try:` 下有 `if isinstance(value, list):`、`return value`，然后是 `ip = netaddr.IPAddress(value)`。  
   然后重启 Neutron 并重跑 Packstack：  
   `sudo systemctl restart neutron-server`  
   `sudo packstack --answer-file=/root/packstack-answers-*.txt`  

   **注意**：打补丁后，`subnet set --no-allocation-pool` 会成功，但会清空 public_subnet 的 allocation_pool；若后续 Puppet 有「router set --external-gateway」等步骤报 “No more IP addresses available”，需手动给 public_subnet 再加回 allocation_pool：  
   `openstack subnet set public_subnet --allocation-pool start=172.24.4.2,end=172.24.4.254`（CIDR 按实际为准）。

**小结**：Neutron 9696 返回 500 时，先看 **neutron/server.log**。若为 **RabbitMQ “Server unexpectedly closed connection”**，以修好 **RabbitMQ** 并重启 **neutron-server** 为首选；若为 **`'list' object has no attribute 'split'`**，用 **neutron_lib 补丁** 永久修复；若同时提示 NetworkManager is active，再关闭 NetworkManager 并视情况重装。

### 8. router set --external-gateway 报错 Could not load 'metric_clean-tombstones': 'HOME'

**现象**：Puppet 阶段失败，日志类似：

```text
Error: Execution of '/usr/bin/openstack router set router1 --external-gateway=public' returned 1: Could not load 'metric_clean-tombstones': 'HOME'
```

**原因**：`openstack` CLI 在执行时缺少 **HOME** 环境变量。Packstack 通过 Puppet 以非交互方式调用 openstack 命令，某些 OpenStack 插件（尤其是 Telemetry 计量服务相关的 Ceilometer/Gnocchi 等）在初始化时会读取 `~/.config/` 或临时目录，依赖 HOME；当 HOME 未设置时，Python 抛出上述异常。即使未显式启用计量服务，默认安装的 CLI 插件仍可能被加载。

**推荐解决：在 answer 文件中禁用 Telemetry（计量）服务**

单机 All-in-One 通常不需要 Telemetry，禁用可避免该错误并减少资源占用。

1. 编辑 answer 文件（将文件名换成实际路径）：
   ```bash
   vi /root/packstack-answers-20260127-144337.txt
   ```

2. 找到并修改以下项为 `n`：
   ```ini
   CONFIG_CEILOMETER_INSTALL=n
   CONFIG_AODH_INSTALL=n
   CONFIG_GNOCCHI_INSTALL=n
   CONFIG_PANKO_INSTALL=n
   ```

3. 清理后重新部署：
   ```bash
   rm -rf /var/tmp/packstack/*
   packstack --answer-file=/root/packstack-answers-20260127-144337.txt
   ```

**Telemetry 是什么？禁用有什么影响？**

| 服务 | 功能 |
|------|------|
| Ceilometer | 数据采集，监控 Nova/Cinder/Neutron 的 CPU、内存、网络等指标 |
| Gnocchi | 时间序列数据库，存储 Ceilometer 采集的指标 |
| Aodh | 告警引擎，基于阈值发送通知 |
| Panko | 事件存储，记录系统事件 |

**禁用影响**：VM 创建、网络、存储等核心功能**不受影响**；Horizon 中“监控”相关图表不可用，计费、自动扩缩容等高级功能不可用。对学习、开发、演示场景，**建议禁用**。

**若安装已接近完成、仅该步骤失败**：可手动设置路由器网关后继续（需先加载凭证）：
```bash
source /root/keystonerc_admin
HOME=/root openstack router set router1 --external-gateway public
```

### 9. RabbitMQ 启动失败（导致 Keystone/5000 不通、Puppet 一直重试）

**现象**：`systemctl status rabbitmq-server` 为 **failed**，日志中有 `failed_to_start_child,prelaunch`、`Runtime terminating during boot` 等。

**原因**：OpenStack 各组件依赖 RabbitMQ 做消息队列；RabbitMQ 起不来时，Keystone 等不会真正就绪，5000 端口不会监听，Puppet 会一直 “Connection refused” + “Retrying”。

**常见对应关系**（按日志快速定位）：

| 问题 | 原因 | 解决 |
|------|------|------|
| RabbitMQ 启动失败，日志有 `nodistribution`、`failed_to_start_child,net_kernel` | 主机名含 `localhost`，Erlang 拒绝在该主机名下启分布式 | 将主机名改为非 localhost 名称（如 `openstack`），并在 `/etc/hosts` 中写好解析 |

**推荐做法（nodistribution 时）**：将主机名改为非 localhost，再清空 RabbitMQ 数据后重启：

```bash
hostnamectl set-hostname openstack
echo "127.0.0.1 openstack" >> /etc/hosts
systemctl stop rabbitmq-server
rm -rf /var/lib/rabbitmq/mnesia
systemctl start rabbitmq-server
```

可将 `openstack` 换成其他非 localhost 名称；若本机对外使用固定 IP，建议在 `/etc/hosts` 中另加一行：`<本机IP> openstack`。

**其他排查与处理**（在上述做法仍失败时）：

1. **主机名解析**：`hostname -f` 与 `getent hosts $(hostname -f)` 必须能解析。在 `/etc/hosts` 中为本机主机名写好对应关系（含 127.0.0.1 或本机 IP）。

2. **资源与限额**：确认 `/etc/systemd/system/rabbitmq-server.service.d/90-limits.conf` 中有 `LimitNOFILE=65536` 等，然后 `systemctl daemon-reload`、`systemctl restart rabbitmq-server`。

3. **查看详细错误**：`journalctl -u rabbitmq-server -n 80 --no-pager`。若为 “enotsup”“Permission denied” 等，再结合 SELinux/审计日志排查。

4. **清空后重试**（会清掉已有队列数据，仅适合安装阶段）：  
   `systemctl stop rabbitmq-server`  
   `rm -rf /var/lib/rabbitmq/mnesia /var/lib/rabbitmq/.erlang.cookie`  
   `systemctl start rabbitmq-server`

修好后确认：`systemctl status rabbitmq-server` 为 active，再观察 `tail -f /var/tmp/packstack/*/192.168.1.57_controller.pp.running` 是否逐步通过；若 Puppet 已因超时退出，需重新运行 packstack 或重装。

### 10. 其他报错、Horizon 打不开

- 日志：`/var/tmp/packstack/` 下最新目录中的 `*.log`，可配合 `tail -f .../openstack-setup.log` 观察。
- HTTP/防火墙：确认 httpd 已启，防火墙放行 80/443，Horizon 配置在 `/etc/httpd/conf.d/` 等。

**httpd 无法启动，日志出现 “Address already in use” 绑定 80 端口**：  
说明 80 已被其它进程占用（常见为 nginx）。先查占用：`ss -tulnp | grep ':80'`；若为 nginx，且本机不需同时跑 nginx，可停用并让 httpd 使用 80：  
`sudo systemctl stop nginx`  
`sudo systemctl disable nginx`  
`sudo systemctl start httpd`  
若必须保留 nginx，需把 nginx 改到其它端口或改 Horizon/httpd 的监听端口（后者需改 Packstack 生成配置）。

**Dashboard 返回 500 / “Something went wrong!”**  
Horizon 能加载但页面报 500 或 “Something went wrong!”，需从 Horizon 日志获取真实错误。

**日志排查手段**：  
1. 查看 Horizon 错误日志：`sudo tail -100 /var/log/httpd/horizon_error.log`  
2. 若只有 DeprecationWarning、无 Traceback，可**临时开启 DEBUG** 获取完整错误：  
   `sudo sed -i "s/^DEBUG = False/DEBUG = True/" /etc/openstack-dashboard/local_settings`  
   `sudo systemctl restart httpd`  
   再访问 `http://<本机IP>/dashboard/`，错误会出现在页面或 horizon_error.log 中。  
3. 排查完后关闭 DEBUG：`sudo sed -i "s/^DEBUG = True/DEBUG = False/" /etc/openstack-dashboard/local_settings`  
   `sudo systemctl restart httpd`

**常见原因：InvalidCacheBackendError（Django 4 移除 MemcachedCache）**  
若 horizon_error.log 或 DEBUG 页面出现：  
`InvalidCacheBackendError: Could not find backend 'django.core.cache.backends.memcached.MemcachedCache': Module "django.core.cache.backends.memcached" does not define a "MemcachedCache" attribute/class`  

**原因**：Django 4.1+ 移除了 `MemcachedCache`（依赖已弃用的 python-memcached），Packstack 生成的 Horizon 配置仍使用该后端，导致 500。

**方案一：改用 PyMemcacheCache（沿用 memcached，推荐）**  
```bash
# 安装 pymemcache 与 memcached
sudo dnf install -y python3-pymemcache memcached
sudo systemctl start memcached
sudo systemctl enable memcached

# 修改 Horizon 配置
sudo sed -i "s/django.core.cache.backends.memcached.MemcachedCache/django.core.cache.backends.memcached.PyMemcacheCache/g" /etc/openstack-dashboard/local_settings

# 重启 httpd
sudo systemctl restart httpd
```  
确认 CACHES 中 `BACKEND` 为 `PyMemcacheCache`，`LOCATION` 为 `127.0.0.1:11211`。验证：`ss -tuln | grep 11211` 应有输出。

**方案二：改用 LocMemCache（无需 memcached，单机可用）**  
```bash
sudo sed -i "s/django.core.cache.backends.memcached.MemcachedCache/django.core.cache.backends.locmem.LocMemCache/g" /etc/openstack-dashboard/local_settings
# 若 LOCATION 指向 127.0.0.1:11211，可改为 'unique-snowflake' 或保留（locmem 会忽略）
sudo systemctl restart httpd
```  
单机 All-in-One 两种方案均可；多 worker 时 PyMemcacheCache 缓存共享更好。

**user-data 装 XFCE 报 Unable to locate package xfce4 或 Conflicting values set for option Signed-By**  
- **Unable to locate package**：Ubuntu Minimal 默认只开 **main**，xfce4 在 **universe**。在 user-data 中用 `apt.sources` 启用 universe/multiverse（见上文示例）；新增源须带 `[signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg]`，否则会与 Ubuntu 24 主源冲突。  
- **Conflicting values set for option Signed-By / The list of sources could not be read**：apt 源里对同一 noble 仓库出现了不同的 Signed-By 设置。解决：user-data 里 `apt.sources` 的 `source` 必须写成 `deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu noble universe`（multiverse 同理），与主源共用同一 keyring。  
- **实例已创建未生效**：在实例内执行（无需 add-apt-repository）：`echo "deb [signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://archive.ubuntu.com/ubuntu noble universe" | sudo tee /etc/apt/sources.list.d/universe.list`，再追加 multiverse 行，然后 `sudo apt update && sudo apt install -y xfce4 xfce4-goodies dbus-x11`，最后 `sudo systemctl set-default graphical.target` 并重启。

**实例无法连接外网（Temporary failure resolving / 无法 apt update）**  
实例有内网 IP（如 172.24.4.x）但 ping 不通外网、apt 报 `Temporary failure resolving 'archive.ubuntu.com'` 或 `Unable to locate package`。通常有两类原因：

1. **没有出网路由（NAT）**  
   实例所在网络是“内网”，需通过 **路由器** 做 SNAT 才能访问互联网。Packstack 常会建 `public`（外网）和 `private`（内网），路由器需：内网口接实例所在网络、外网口设 **external gateway** 到 public。  
   - **查看**：`openstack router list`、`openstack router show <router_id>`（看 `external_gateway_info` 是否非空）。  
   - **修复**：若无路由器，创建并挂接口；若有路由器但无外网网关，则设置：  
     ```bash
     source /root/keystonerc_admin
     openstack router list
     # 记下路由器 ID 和“外网”网络名（如 public）
     openstack network list   # 确认 public 的 ID
     openstack router set <router_id> --external-gateway <public_network_id>
     openstack router add subnet <router_id> <private_subnet_id>   # 若尚未加内网子网
     ```  
   - **在 Horizon（Dashboard）中配置**（推荐，全程在浏览器完成）：
     - 登录 Horizon：`http://<OpenStack 节点 IP>/dashboard/`，用 admin 及密码登录。
     - **一、为路由器设置外网网关（出网 NAT）**
       1. 左侧菜单 **网络** → **网络**，记下“外网”名称（如 **public**）和“实例所在网络”名称（如 **private** 或 **public**，若实例接在 public 上则可能已有外网）。
       2. 左侧菜单 **网络** → **路由**，在列表中找到路由器（如 **router1** 或 **router01**）。
       3. 点击该路由器名称进入详情。
       4. 若 **“外部网关”** 为空：点击 **设置网关**（或 **Set Gateway**），在 **外部网络** 下拉框选择 **public**（或你的外网网络名），**子网** 可留空或选外网子网，点击 **设置网关** 确认。
       5. 若已有外部网关，则无需再设。
     - **二、为路由器添加内网接口**（实例在“内网”如 private 时）
       1. 仍在 **网络** → **路由** → 该路由器详情页。
       2. 切到 **接口**（Interfaces）标签。
       3. 若列表里没有实例所在网络的子网：点击 **添加接口**（Add Interface），**子网** 选实例所在子网（如 **private_subnet** 或对应 172.24.4.0/24 / 10.0.0.0/24），**IP 地址** 可留空（自动分配），点击 **提交**。
       4. 若接口已存在，则无需再加。
     - **三、为子网配置 DNS**（解决“无法解析域名”）
       1. **网络** → **网络**，点击 **实例所在网络** 的名称（如 **private** 或 **public**）。
       2. 在 **子网** 列表中，点击该网络下的 **子网名称**（如 **private_subnet**）。
       3. 点击 **编辑子网**（Edit Subnet）。
       4. 找到 **DNS 名称服务器**（DNS Name Servers）或 **DNS 服务器**，填入 `8.8.8.8`，可再添加一行 `114.114.114.114`（视界面是否支持多行）。
       5. 保存。之后新获取 IP 的实例会通过 DHCP 收到该 DNS；已开机的实例可重启网口或在实例内执行 `echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf` 临时生效。

2. **没有 DNS**  
   子网未下发 DNS，实例无法解析域名。  
   - **为子网配置 DNS**（在 OpenStack 节点执行）：  
     ```bash
     openstack subnet list
     openstack subnet set <实例所在子网ID> --dns-nameserver 8.8.8.8 --dns-nameserver 114.114.114.114
     ```  
   - **临时补救（实例内）**：在实例里执行 `echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf`，再试 `ping archive.ubuntu.com`。  
   - **user-data 兜底**：若 DHCP 始终不下发 DNS，可在 runcmd 里在 `apt-get update` 前加一行：  
     `- echo "nameserver 8.8.8.8" > /etc/resolv.conf`

**验证**：实例内执行 `ping -c 2 8.8.8.8`（通则路由正常）、`ping -c 2 archive.ubuntu.com`（通则 DNS+路由均正常）。

**创建实例失败：没有可用的固定 IP（No more IP addresses available）**  
错误信息：`没有可用的固定IP给网络：xxx` 或 `IpAddressGenerationFailureClient: No more IP addresses available on network xxx`。**原因**：Neutron 子网的 IP 池已耗尽。**解决**（在 OpenStack 服务器上执行）：

1. **查看子网与分配池**：
   ```bash
   source /root/keystonerc_admin
   openstack subnet list
   openstack subnet show <subnet_id>  # 查看 allocation_pools、cidr
   ```

2. **方案一：设置/扩展子网分配池**（`allocation_pools` 为空或耗尽时）：
   ```bash
   # 查看子网详情
   openstack subnet show <subnet_id>
   # 为 public_subnet (172.24.4.0/24) 设置分配池（网关 172.24.4.1 不可用）
   openstack subnet set 873cc554-eb94-4aab-a402-e2db01cfa7ec \
     --allocation-pool start=172.24.4.2,end=172.24.4.254
   # 为 private_subnet (10.0.0.0/24) 设置分配池
   openstack subnet set c84e33a8-e4f9-4329-afbb-1889c54990e7 \
     --allocation-pool start=10.0.0.2,end=10.0.0.254
   ```
   将 `start/end` 调整为 CIDR 内可用范围（避开网关 IP）。

3. **方案二：清理未使用的端口**：
   ```bash
   openstack port list --status DOWN
   # 确认后删除孤儿端口
   openstack port delete <port_id>
   ```

4. **方案三：新建子网**（若当前子网无法扩展）：
   ```bash
   openstack subnet create --network <network_id> --subnet-range 192.168.123.0/24 --allocation-pool start=192.168.123.10,end=192.168.123.200 subnet-new
   ```

5. **查看网络与端口占用**：
   ```bash
   openstack network list
   openstack port list
   ```

### 11. 如何验证问题已解决？

1. SSH 免密：  
   `ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 root@localhost hostname`
2. 服务状态：  
   `systemctl status sshd`
3. Packstack 日志：  
   `tail -f /var/tmp/packstack/*/openstack-setup.log`
4. 部署成功后：  
   `source ~/keystonerc_admin`，再执行 `openstack server list`、`openstack network list` 等。

### 12. 与 DevStack 混用

不要在同一台机器上同时部署 Packstack 与 DevStack；若曾装过 DevStack，建议换干净环境或重装后再用 Packstack。

上述“Connection closed”等 SSH 问题处理以 **ed25519 + answer 中 CONFIG_SSH_KEY + restorecon + MaxStartups** 为准；一键安装脚本中的 id_rsa/id_ed25519 双钥为兼容用法，可按需参考。若坚持仅使用 id_rsa，需在 answer 文件中设置 `CONFIG_SSH_KEY=/root/.ssh/id_rsa`，并确保 authorized_keys 中写入的为 id_rsa.pub 公钥。
