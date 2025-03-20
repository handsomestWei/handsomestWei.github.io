---
title: 使用rsync+inotify简单实现文件实时双机双向同步
date: 2025-01-22 10:10:00
categories: [后端, 文件同步]
tags: [后端, 文件同步, rsync, inotify]
image:
  path: /assets/img/posts/common/rsync.jpg
---

# 使用rsync+inotify简单实现文件实时双机双向同步

## 实现思路
使用inotify-tools的inotifywait工具监控文件变化，触发后使用rsync做同步。加入系统服务项，实现实时监听，方便管理。

以下配置操作，单向同步，只需在单边部署。双机双向，需要在两台服务器分别执行。

## 依赖软件简介
### rsync简介
`Rsync‌`是一款开源的文件同步和数据传输工具，适用于文件同步、各种数据备份等场景。主要功能包括：
+ ‌增量传输‌：仅同步发生变化的文件或目录，减少数据传输量和时间。
+ ‌安全性‌：支持通过SSH等安全协议进行远程传输，确保数据传输的安全性。
+ ‌跨平台支持‌：可以在Linux和Windows之间进行数据同步。

`rsync`仅支持单向同步，若需要双向同步，需要在对端也同时部署。   
类似的工具还有`Unison`和`FreeFileSync`等，提供了更强大的功能和图形界面。

### inotify-tools简介
`‌inotify-tools`‌是由Red Hat开发的一款Linux文件系统监控工具，具有高效、细粒度和异步的特点，能够安全、高性能地监控用户空间文件。还能监控设备、网络、CPU等系统资源的变化‌。

## 依赖软件安装
```sh
sudo apt update
sudo apt-get install rsync inotify-tools=3.22.1.0-2 -y
```

## 方案一： 使用ssh方式传输文件
rsync使用ssh传输，指定密码文件的方式不安全，因此配合免密使用
### ssh免密登录配置
设置允许root用户使用公钥登录。在文件删除同步到对端的场景中，使用普通用户ssh容易出现没有权限删除对端文件问题，因此使用root用户。默认不允许root用户直接ssh登录，需要修改`sshd_config`配置。   
1、设置允许root用户ssh公钥密码登录。用来密钥拷贝时做密码验证
```sh
## 修改前先备份
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

# 修改配置，修改配置项PermitRootLogin值
# 改为PermitRootLogin yes
sudo vi /etc/ssh/sshd_config

# 修改后重启sshd服务
sudo systemctl restart sshd
```
2、生成密钥并拷贝到对端
```sh
## 使用ed25519算法生成密钥，指定私钥保存路径，静默安装无交互，使用空密码
ssh-keygen -t ed25519 -C "your_email@example.com" -f "/root/.ssh/id_ed25519" -q -N ""

## 指定公钥路径，将公钥复制到对端服务器。有交互，填对端服务器登录密码
ssh-copy-id -i "/root/.ssh/id_ed25519.pub" root@<ip>
```
3、修改root用户ssh登录策略。关闭密码验证，改为仅使用公钥
```sh
# 修改配置，修改配置项PermitRootLogin值
# 改为PermitRootLogin prohibit-password
sudo vi /etc/ssh/sshd_config

# 修改后重启sshd服务
sudo systemctl restart sshd
```

### 创建文件同步脚本
注意目录访问权限
```sh
#!/bin/bash

# 定义源目录和目标主机信息
SOURCE_DIR="/path/to/source"
REMOTE_USER="root"
REMOTE_HOST="remote ip"
REMOTE_DIR="/path/to/destination"

# 使用inotify-tools的inotifywait工具监控文件变化，并触发同步
inotifywait -m -r -e modify,create,delete,move --format '%w%f' "$SOURCE_DIR" | while read FILE; do
    echo "Change detected: $FILE"
    rsync -avz --progress --delete -e "ssh -o StrictHostKeyChecking=no" "$SOURCE_DIR/" "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"
done
```

### 创建系统服务项
创建`systemd`服务文件`file-sync.service`，放置到`/etc/systemd/system/`
```ini
[Unit]
Description=File Sync Service

[Service]
# 默认关闭日志输出到syslog，调试时可以注释以下配置并重新加载服务
StandardOutput=null
StandardError=null
# 指定脚本路径，注意授权可执行权限
ExecStart=/path/file-sync.sh
Restart=always

[Install]
WantedBy=multi-user.target
```
启用服务
```sh
sudo systemctl daemon-reload
sudo systemctl enable file-sync.service
sudo systemctl start file-sync.service
```

### 常见问题
+  rsync更新文件时间戳失败   
rsync: [generator] failed to set times on "xxx" Operation not permitted   
可能是服务器时间不同步，也可能是rsync配置的用户组问题，不关注权限可以忽略

+ rsync更新文件用户组失败   
rsync [generator] chgrp 'xxx' failed: Operation not permitted   
可能是rsync配置的用户组问题，不关注权限可以忽略

+ 已删除文件同步到对端失败    
rsync error: some files/attrs were not transferred (see previous errors)   
当前ssh用户无权限删除对端文件，建议改为root

## 方式二： 使用rsync-daemon方式传输文件
rsync守护进程（rsyncd）提供了一个独立的`rsync`服务器，允许远程客户端连接并执行文件同步操作。提供了单独的用户账号（区别于操作系统的）管理，使用`rsync://`协议做传输。


### 配置rsync服务
创建`/etc/rsyncd.conf`文件
```conf
# 全局设置
uid = root
gid = root
use chroot = yes
log file = /var/log/rsyncd.log
pid file = /var/run/rsyncd.pid
# 锁文件位置，用于解决冲突
lock file = /var/run/rsync.lock

# 模块设置。支持同步的文件路径，可多个
# 自定义模块名称
[xxx-path]
path = /yourPath
comment = Path for xxx
read only = no
# 当使用rsync rsync://xxx-user@ip/ 连接时，展示支持的模块名称和注释
list = yes
# 定义用户名，和操作系统用户无关，是rsync自己的用户认证体系
auth users = xxx-user
# 指定用户名和密码保存文件，对端校验用
secrets file = /etc/rsyncd.secrets
```

### 创建rsync认证文件
文件路径为`rsyncd.conf`里`secrets file`指定的，包含用户名和密码，每行一个用户，格式为`username:password`

### 启用rsync服务
```sh
sudo systemctl start rsync
sudo systemctl enable rsync
```

### 创建文件同步脚本
注意目录访问权限
```bash
#!/bin/bash

SOURCE_DIR="/path/to/source"
REMOTE_USER="root"
REMOTE_HOST="remote ip"
REMOTE_DIR="/path/to/destination"

# 设置变量
LOCAL_DIR="/path/to/source"
# 用户名为rsyncd.conf文件里auth users定义的，非操作系统 
REMOTE_USER="xxx-user"
REMOTE_HOST="remote ip"
# 填写rsyncd.conf文件里定义的模块名称，会自动关联对应模块里path项路径
REMOTE_MODULE="xxx-path"
LOG_FILE="/var/log/file_sync.log"

# 函数：本地到远程同步
sync_local_to_remote() {
    echo "[$(date)] Syncing from local to remote..." >> "$LOG_FILE"
    rsync -avz --delete --progress \
        --exclude '.sync_lock' \
        --filter='protect .sync_lock' \
        "$LOCAL_DIR/" "rsync://$REMOTE_USER@$REMOTE_HOST/$REMOTE_MODULE" >> "$LOG_FILE" 2>&1
}

# 函数：远程到本地同步
sync_remote_to_local() {
    echo "[$(date)] Syncing from remote to local..." >> "$LOG_FILE"
    rsync -avz --delete --progress \
        --exclude '.sync_lock' \
        --filter='protect .sync_lock' \
        "rsync://$REMOTE_USER@$REMOTE_HOST/$REMOTE_MODULE/" "$LOCAL_DIR" >> "$LOG_FILE" 2>&1
}

# 创建锁文件以防止重复同步
LOCKFILE="$LOCAL_DIR/.sync_lock"

if [ -f "$LOCKFILE" ]; then
    echo "[$(date)] Sync is already running, exiting." >> "$LOG_FILE"
    exit 1
fi

touch "$LOCKFILE"

# 使用 inotifywait 监听文件系统事件
inotifywait -m -r -e modify,create,delete,move "$LOCAL_DIR" | while read -r dir action file; do
    # 确保不因为同步脚本本身触发额外的同步
    if [ ! -f "$LOCKFILE" ]; then
        break
    fi

    # 忽略 .sync_lock 文件的变化
    if [[ "$file" == ".sync_lock" ]]; then
        continue
    fi

    # 检测到变化后进行双向同步
    sync_local_to_remote
    sync_remote_to_local
done

rm "$LOCKFILE"
```

### 创建系统服务项
配置参考上述ssh传输方式章节里的系统服务项创建

## ssh传输和rsync-daemon方案的区别
+ ssh方式需要使用操作系统用户，容易出现文件访问权限等问题。而rsync-daemon使用自有的用户体系做文件访问和操作控制，更加方便。
+ rsync-daemon需要额外使用rsync服务，引入了新的变量，服务挂掉会导致文件同步功能不可用。
+ ssh方式传输，是推送方式，只需要处理本地文件的变化，再同步到对端。rsync-daemon传输，是拉取方式，是在本地发起请求去拉取对端，因此在双向同步场景，每次同步需要做from/to和to/from两次操作。

## 冲突解决
冲突发生场景，例如同一个文件在双端同时被修改，需要合理使用rsync提供的参数，或者利用文件锁机制等方式解决。
