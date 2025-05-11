---
title: github jekyll博客本地win开发环境搭建
date: 2025-05-03 17:10:00
categories: [后端, blog]
tags: [后端, blog, jekyll]
image:
  path: /assets/img/posts/common/blog.jpg
---

# github jekyll博客win本地开发环境搭建
jekyll依赖Ruby环境

## 环境搭建
[参考](https://jekyllrb.com/docs/installation/windows/)

### 1、Ruby工具包下载
Download and install a Ruby+Devkit version from [RubyInstaller Downloads](https://rubyinstaller.org/downloads/). Use default options for installation.

### 2、Ruby环境搭建
Run the `ridk install` step on the last stage of the installation wizard. This is needed for installing gems with native extensions. You can find additional information regarding this in the RubyInstaller Documentation. From the options choose
```
MSYS2 and MINGW development toolchain
```

### 3、安装jekyll
Open a new command prompt window from the start menu, so that changes to the `PATH` environment variable becomes effective. Install Jekyll and Bundler using `gem install jekyll bundler`

### 4、jekyll验证
Check if Jekyll has been installed properly: `jekyll -v`

## 本地运行
在项目根目录下
```sh
jekyll server
```

## Ruby相关
### gem
gem是Ruby中的包管理器。   
包默认下载路径为`C:\Users\<userName>\.local\share\gem\ruby\<version>\`，可以整个文件夹拷贝迁移
```sh
# gem列出已有源
gem sources -l

# gem添加国内源。移除默认源（可选）--remove https://rubygems.org/
gem sources --add https://mirrors.tuna.tsinghua.edu.cn/rubygems/
```

### bundler
bundler是Ruby的依赖管理器。
```sh
# bundle配置国内源加速下载
bundle config mirror.https://rubygems.org https://mirrors.tuna.tsinghua.edu.cn/rubygems
```