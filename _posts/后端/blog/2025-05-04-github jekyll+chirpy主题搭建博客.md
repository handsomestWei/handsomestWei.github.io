---
title: github jekyll+chirpy主题搭建博客
date: 2025-05-04 19:50:00
categories: [后端, blog]
tags: [后端, blog, jekyll]
image:
  path: /assets/img/posts/common/blog.jpg
---

# github jekyll+chirpy主题搭建博客

## github pages站点简介
可用于搭建个人博客。   
[站点使用快速入门](https://docs.github.com/zh/pages/quickstart)

## jekyll简介
jekyll是一个简单的免费的Blog博客生成工具，类似WordPress。jekyll只是一个生成静态网页的工具，不需要数据库支持，可以免费部署在Github上，可以绑定自己的域名。   
[jekyll使用文档](https://www.jekyll.com.cn/docs/)   
[使用jekyll设置github pages站点](https://docs.github.com/zh/pages/setting-up-a-github-pages-site-with-jekyll/about-github-pages-and-jekyll)   
[jekyll使用教程参考](https://juejin.cn/post/6844903623567081486)

## 使用chirpy作为博客主题
[chirpy git地址](https://github.com/cotes2020/chirpy-starter)   
[chirpy主题使用](https://chirpy.cotes.page/posts/getting-started/#creating-a-site-repository)，推荐使用`Use this template`方式fork源主题仓库   
[chirpy主题demo](https://chirpy.cotes.page/)

## chirpy主题使用
[参考：_config.yml配置文件示例](https://github.com/handsomestWei/handsomestWei.github.io/blob/main/_config.yml)   
[参考：使用Jekyll + Github Pages搭建静态网站](https://www.cnblogs.com/duanguyuan/p/16126654.html)

## 博客发布
chirpy主题自带有`flow`工作流脚本，位于`.github\workflows`，提交后会自动触发`GitHub Actions`自动构建和发布。   
注意事项：流水线构建时，可以关闭文档内容链接必须使用https的检测。如果博客文档里带有http的链接，会导致脚本检测失败，博客构建失败。通过修改项目根目录下的`.github\workflows\pages-deploy.yml`文件，注释掉整个`name: Test site`脚本模块。


