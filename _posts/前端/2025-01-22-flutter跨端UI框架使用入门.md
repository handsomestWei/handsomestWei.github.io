---
title: flutter跨端UI框架使用入门
date: 2025-01-22 14:20:00
categories: [前端]
tags: [前端, flutter]
image:
  path: /assets/img/posts/common/flutter.jpg
---

# flutter跨端UI框架使用入门

## flutter简介
[Flutter](https://flutter.dev/)是由Google开发的开源应用开发框架，主要用于构建高性能、跨平台的移动、Web和桌面应用程序。Flutter使用Dart语言，提供了一套丰富的Widgets，使开发者能够快速创建美观的用户界面。其最大特点是热重载功能，使得开发者可以即时查看修改效果，从而提升开发效率‌。
## flutter特点
+ 跨平台‌：Flutter可以同时运行在iOS和Android平台上，并且支持Web、Windows、macOS和Linux等多个平台。开发者只需编写一套代码，即可实现多平台部署‌。
+ 高性能‌：Flutter编译为原生机器代码，保证了应用的流畅度和动画效果。其高性能渲染引擎能够提供高帧率的UI体验‌。
+ 丰富的组件‌：Flutter提供了丰富的Widgets，涵盖了各种常用的用户界面元素，方便开发者快速构建应用‌。
+ 热重载‌：Flutter支持热重载功能，开发者可以实时看到代码修改的效果，极大地提高了开发效率‌。
## flutter安装和配置
[下载](https://github.com/flutter/flutter/releases)   
[win环境配置参考](https://flutterchina.club/setup-windows/)

### 环境变量配置
```
Path添加变量<flutter目录>\bin
PUB_HOSTED_URL=https://pub.flutter-io.cn
FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

### 安装dart
```
执行<flutter目录>\bin\dart.bat
Path添加变量<flutter目录>\bin\cache\dart-sdk\bin
```

### 启动
```
执行<flutter目录>\flutter_console.bat
```

## android-sdk配置
[下载](https://www.androiddevtools.cn/)，选择SDK Tools

### 安装
```
运行SDK Manager.exe
选择一组platform-tools、build-tools、platform和Extras安装
确认选择的所有组件都安装成功，失败的重试多次，不然后面运行会提示Failed to install the following Android SDK packages as some licences have not been accepted
```

### 环境变量配置
```
ANDROID_HOME=<sdk目录>
Path添加变量%ANDROID_HOME%\platform-tools和%ANDROID_HOME%\tools
cmd执行adb命令验证
```

## vscode配置
[参考](https://flutterchina.club/get-started/editor/#vscode)
### 安装插件
```
安装flutter插件
安装dart插件
安装仿真器插件Android iOS Emulator
```

### 环境验证
```
View>Command Palette>Flutter: Run Flutter Doctor
```

### 新建flutter项目
```
View>Command Palette>Flutter: New Project
```

## 模拟器配置
[下载](https://www.yeshen.com/)

## 运行体验
```
运行第三方模拟器
进入模拟器目录下cmd执行nox_adb.exe connect 127.0.0.1:62001
vscode上终端执行adb connect 127.0.0.1:62001
vscode上运行flutter项目。将会打包apk并传输到模拟器上安装运行
注：flutter编译时如果遇到Failed to install the following Android SDK packages as some licences have not been accepted，则需确认安卓sdk组件是否全部安装成功
```