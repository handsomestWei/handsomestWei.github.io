---
title: zlmediakit国标信令录像异步下载方案
date: 2025-04-18 16:00:00
categories: [后端, 音视频]
tags: [后端, 音视频, GB28181, zlmediakit]
image:
  path: /assets/img/posts/common/mpeg.jpg
---

# zlmediakit国标信令录像异步下载方案
国标GB28181视频接入场景。

## zlmediakit简介
+ [git地址](https://github.com/ZLMediaKit/ZLMediaKit)
+ [使用文档](https://docs.zlmediakit.com/zh/guide/)
+ [配置文件说明](https://github.com/zlmediakit/ZLMediaKit/blob/master/conf/config.ini)

## 异步下载思路
和传统的使用`/index/api/startRecord`和`/index/api/stopRecord`串行手动控制录像开始和结束方式不同。   
异步下载更加灵活，发送sip下载信令后，异步等待录像文件生成通知。参考[GB28181推流](https://github.com/ZLMediaKit/ZLMediaKit/wiki/GB28181%E6%8E%A8%E6%B5%81)的`高阶使用`章节，利用指定流id的方式完成录像文件关联。

## 下载流程
- 1、生成流id，调用openRtpServer接口，申请端口号，完成stream_id和端口号的绑定。
- 2、发送sip s=Download录像下载请求，在m=video <端口号>媒体信息里填入申请到的端口号。
- 3、将流id和业务信息关联。如录像开始和结束时间。
- 4、等待on_record_mp4接口回调（需要在zlmedia配置文件里配置webhook回调通知地址），从入参的stream字段拿到当初的流id，取回第3步关联的信息。

## 注意事项
### 录像文件生成
zlmediakit默认的文件网页查看端口8082
+ **文件目录** 默认为`/<流id>/<发送录像指令时间yyyy-mm-dd>/`格式，例`/1200005833/2025-04-15/`
+ **文件命名** 默认为`HH-MM-SS-<切片索引>.mp4`格式，例`14-07-01-0.mp4`
+ **文件切片** 受限于视频源的质量、网络抖动等原因，推流过程可能会断流，可能会产生多个录像文件而不是期望的完整一个，按切片索引递增。每次产生一个切片文件，都会触发一次`on_record_mp4`接口回调。

通常，发送录像指令时，录像内容时间和执行发送时间会不一致，比如在当前想录制几天前某段时间录像。zlmediakit本身的录像生成效果不太符合业务需求。可以在下载流程第4步，使用liuid关联缓存的业务信息后，对录像文件重命名。

## 附sip录像下载请求报文例
sdp内容`s=Download`录像下载请求
```
INVITE sip:45010700001320000009@192.168.0.173:5060 SIP/2.0
Call-ID: f61d3c18609af3fb3997d9c415235aa5@177.7.0.13
CSeq: 700 INVITE
From: <sip:34020000002000000001@3402000000>;tag=downloada9b9d35d0cb44d7ea6ecae46bf4f1d69
To: <sip:45010700001320000009@192.168.0.173:5060>
Via: SIP/2.0/UDP 192.168.0.173:5060;branch=z9hG4bK7965716963;rport
Max-Forwards: 70
Contact: <sip:34020000002000000001@177.7.0.13:5061>
Content-Type: APPLICATION/SDP
Content-Length: 289

v=0
o=45010700001320000009 0 0 IN IP4 192.168.0.196
s=Download
u=45010700001320000009:0
c=IN IP4 192.168.0.196
t=1744826520 1744826550
m=video 30090 RTP/AVP 96 97 98
a=recvonly
a=rtpmap:96 PS/90000
a=rtpmap:97 MPEG4/90000
a=rtpmap:98 H264/90000
a=downloadspeed:4
y=120000472
```