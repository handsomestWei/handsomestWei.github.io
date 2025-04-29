---
title: zlmediakit接入Onvif设备方案
date: 2025-04-25 17:00:00
categories: [音视频, zlmediakit]
tags: [音视频, zlmediakit, Onvif]
image:
  path: /assets/img/posts/common/mpeg.jpg
---

# zlmediakit接入Onvif设备方案
zlmediakit本身不支持Onvif直接接入。

## 思路
国标级联。新部署流媒体服务使用Onvif方式接入设备，服务本身使用国标GB28181协议级联到上级zlmediakit，实现设备信息同步和接入。

## Onvif简介
onvif（Open Network Video Interface Forum）开放式网络视频接口论坛。实现不同厂商设备的互操作性，降低集成难度 。  
+ 规范内容：更侧重于不同视频厂商之间的设备管理和控制标准化接口定义。
+ 协议：设备管理和控制接口均以Web Services的形式提供，数据交互采用SOAP协议。音视频流部分通过RTP/RTSP进行传输。

### 协议特点
#### 设备自动探测发现
基于Web Services形式，ONVIF使用WS-Discovery标准，客户端预先不知道目标服务地址的情况下，可以动态地探测到可用的目标服务（视频设备），以便进行服务调用。

#### 连接鉴权
客户端使用Onvif协议连接视频设备时，需要输入用户名密码鉴权。需要在Onvif设备端配置。

## LiveNVR接入Onvif设备
[LiveNVR简介](https://www.liveqing.com/docs/manuals/LiveNVR.html#%E7%AE%80%E4%BB%8B)   
[LiveNVR部署](https://www.liveqing.com/docs/manuals/LiveNVR.html#%E9%83%A8%E7%BD%B2%E5%90%AF%E5%8A%A8)   
[LiveNVR接入Onvif设备](https://www.liveqing.com/docs/manuals/LiveNVR.html#%E9%80%9A%E9%81%93%E9%85%8D%E7%BD%AE-onvif%E6%8E%A5%E5%85%A5)，在Onvif设备端开启Onvif并获取设置的账号密码，在LiveNVR连接设备时填入。

## LiveNVR国标方式级联到上级zlmediakit
[LiveNVR接入gb28181国标流媒体平台配置](https://www.liveqing.com/docs/manuals/LiveNVR.html#%E6%8E%A5%E5%85%A5gb28181%E5%9B%BD%E6%A0%87%E6%B5%81%E5%AA%92%E4%BD%93%E5%B9%B3%E5%8F%B0)，信令传输协议建议选择udp