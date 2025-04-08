---
title: 2025-04-07-win11安装docker desktop
date: 2025-04-07 22:20:00
categories: [后端, 容器]
tags: [后端, 容器, docker]
image:
  path: /assets/img/posts/common/docker.jpg
---

# win11安装docker desktop
高版本docker desktop已经默认将wsl（Windows Subsystem for Linux）作为docker后端（而不是Hype-V）

## wsl安装和更新
[github wsl下载](https://github.com/microsoft/WSL/releases)

## wsl子系统安装
[microsoft应用商店下载](https://apps.microsoft.com/search?query=ubuntu&hl=zh-cn&gl=CN)   
下载后点击运行安装

## win功能设置
```
控制面板—>程序—>启用或关闭Windows功能，勾选开启子系统和虚拟机平台等相关功能
```

## wsl子系统设置
管理员执行powershell
```sh
# 查看子系统列表，和运行状态
wsl -l -v

# 将某个子系统设置为默认
wslconfig /setdefault Ubuntu-22.04

# 注销某个子系统。（可选，会删除数据）
# wsl --unregister Ubuntu-20.04

# 启动和停止某个子系统
# wsl -d <名称>
# wsl -t  <名称>
```
可以为某个子系统设置为开机自动启动，这样启动`docker desktop`时不用手动启动`wsl`一次

## docker desktop配置
```
（默认勾选）设置->General->Use the WSL 2 based engine (Windows Home can only run the WSL 2 backend)
```
```
（可选）设置->Resources->WSL integration->指定win上安装的某个子系统（如果有多个）
```
