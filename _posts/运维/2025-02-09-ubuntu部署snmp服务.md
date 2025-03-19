---
title: ubuntu部署snmp服务
date: 2025-02-09 19:40:00
categories: [运维, snmp]
tags: [运维, snmp]
image:
  path: /assets/img/posts/common/snmp.jpg
---

# ubuntu部署snmp服务

## snmp安装
```sh
sudo apt-get install -y snmpd
sudo apt-get install -y snmp 
sudo apt-get install -y libsnmp-dev
```

## snmp配置
修改配置文件`/etc/snmp/snmpd.conf`，内容如下。其他按需修改。
```conf
# 开启外部访问
# agentaddress 127.0.0.1,[::1]
agentAddress udp:161,udp6:[::1]:161

# 添加自定义MIB目录
mibdirs +/usr/share/mibs/site      
```
修改后重启服务
```sh
sudo systemctl restart snmpd
```

## snmp服务验证
```sh
snmpwalk -v 2c -c public localhost system
```

## 挂载外部mib
### 放置mib文件
查看mib文件加载目录，将mib文件放置到该目录下。
```sh
net-snmp-config --default-mibdirs
```

### 添加mib模块
修改配置文件`/etc/snmp/snmp.conf`，添加mib模块。Module名称从mib文件里的`MODULE-IDENTITY`关键字前段获取。
```conf
mibs +<Module名称>
```