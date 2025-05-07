---
title: github jekyll博客SEO搜索引擎优化
date: 2025-05-06 10:00:00
categories: [后端, blog]
tags: [后端, blog, jekyll]
image:
  path: /assets/img/posts/common/blog.jpg
---

# github jekyll博客SEO搜索引擎优化

## SEO简介
SEO（Search EngineOptimization，搜索引擎优化）是一种利用搜索引擎的内在规则，优化网站结构和内容，从而提升网站在搜索引擎结果中的自然排名的方法。其核心目标是提高网站的可见性，获得品牌效益，并为企业或个人获取更多流量和市场竞争优势。SEO 的核心原理是优化网站结构、内容和外部链接，使其更符合搜索引擎的抓取和索引规则，从而提升可见度和流量。

## 常用站长工具
不同的搜索引擎提供有各自的站长工具平台。
+ [百度站长工具](https://ziyuan.baidu.com/dashboard/index)
+ [必应搜索](https://www.bing.com/webmasters/home)

## 站点地图生成
使用`jekyll-sitemap`插件自动生成`sitemap.xml`站点地图文件，提供给搜索引擎爬取。
### 插件安装
```sh
# 在项目根目录下执行，将会自动添加依赖到项目的Gemfile文件
bundle add jekyll-sitemap
```
### 插件使用
```sh
jekyll build
```
执行后，Jekyll会自动在_site目录下生成一个名为sitemap.xml的文件，网站链接地址带域名。另外不要执行`jekyll server`，本地运行生成的链接地址是带`localhost`   
如果托管在git上，自带的`GitHub Actions`会自动生成和更新。   

## SEO自动化脚本
[百度站长工具-自动调用api推送网站链接脚本](https://github.com/handsomestWei/handsomestWei.github.io/tree/main/tools/baidu-seo)
