---
title: 使用apt-rdepends制作软件离线deb安装包
date: 2025-02-18 10:00:00
categories: [运维, apt]
tags: [运维, apt]
image:
  path: /assets/img/posts/common/apt.jpg
---

# 使用apt-rdepends制作软件离线deb安装包
除基础软件外，还要获取软件依赖包。

## 依赖包工具安装
```sh
apt-get install apt-rdepends
```
## apt-rdepends工具使用
使用apt-rdepends工具，递归方式分析软件依赖，下载软件包本体，和依赖包。制作时先把下载目录下deb包清空，方便后续整理依赖包。脚本如下
```sh
#!/bin/bash

PACKAGE_NAME=$1

# 获取依赖树，并过滤掉不存在的包名
DEPENDENCIES=$(apt-rdepends "$PACKAGE_NAME" | grep -v "^ " | grep -v "^libc-dev$")

# 下载所有依赖项
for DEP in $DEPENDENCIES; do
    apt-get download "$DEP"
done

# 下载指定的软件包
apt-get download "$PACKAGE_NAME"
```
## deb包相关
### apt-get install默认下载目录
```
/var/cache/apt/archives
```
### deb包离线安装
先安装依赖包，最后再安装本体。
```sh
sudo dpkg -i ./dep/*.deb
sudo dpkg -i ./xxx.deb
```
### 只下载不安装
加`-d`参数。下载到默认目录，但只下载本体，会缺少依赖软件（如果有），会导致安装失败。
```sh
apt-get install -d <软件名称>
```
### 查看软件依赖
```sh
dpkg -s <软件名称>
```
### 软件卸载
```sh
sudo apt-get remove <软件名称>
```