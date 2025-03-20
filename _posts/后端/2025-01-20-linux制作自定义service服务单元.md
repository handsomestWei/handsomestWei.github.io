---
title: linux制作自定义service服务单元
date: 2025-01-20 18:00:00
categories: [后端, linux]
tags: [后端, linux]
image:
  path: /assets/img/posts/common/linux.jpg
---

# linux制作自定义service服务单元

## 服务单元简介
在Linux系统中，服务单元通常以`.service`后缀结尾，并存储在`/etc/systemd/system`目录下。
服务单元文件定义了服务的启动顺序、依赖关系、执行命令等参数。使得系统管理员能够方便地启动、停止、重启和管理系统中的各种服务。

## java服务单元示例
服务单元`myJava.service`文件示例。注意关闭标准输出，避免日志文件占用磁盘空间。
```ini
[Unit]
Description=My Java Service
After=network.target
 
[Service]
## 关闭日志输出到syslog
StandardOutput=null
StandardError=null
Type=simple
## 此处填写jar包启动命令和参数
ExecStart=java -jar /xxx/myJava.jar
RestartSec=10
 
[Install]
WantedBy=multi-user.target
```

## 服务单元发布
其中`xxx.service`替换为自定义service的文件名。
```sh
## 初次发布，将服务单元描述文件复制到systemd路径下。后续直接在该路径下修改文件
sudo cp ./xxx.service /etc/systemd/system/

## 重新加载systemd配置。后续每次修改后都需要执行
sudo systemctl daemon-reload

## 设置开机自启动
sudo systemctl enable xxx.service

## 启动服务
sudo systemctl start xxx.service

## 检查服务状态
sudo systemctl status xxx.service
```