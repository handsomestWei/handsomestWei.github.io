---
title: 使用maven-archetype制作项目脚手架
date: 2025-02-16 22:40:00
categories: [后端, java, maven]
tags: [后端, java, maven]
image:
  path: /assets/img/posts/common/java.jpg
---

# 使用maven-archetype制作项目脚手架

## maven plugin依赖
```xml
<plugin>
    <groupId>org.apache.maven.plugins</groupId>
    <artifactId>maven-archetype-plugin</artifactId>
    <version>3.x.x</version>
</plugin>
```

## 导出模板

在模板项目执行`mvn archetype:create-from-project`，会在target目录下生成一个`archetype`目录，是一个脚手架的maven项目。

## 占位符替换
提取archetype目录项目，修改archetype-metadata.xml文件，将groupId、artifactId等用占位符替换，如`<groupId>${groupId}</groupId>`等

## 脚手架发布
在脚手架项目执行`mvn install`命令，把模板安装到本地仓库，安装完成即可在本地仓库看到生成的模板信息。会在本地仓库生成`archetype-catalog.xml`文件

## 脚手架使用
使用`-DarchetypeCatalog`参数指定私服地址
```
mvn org.apache.maven.plugins:maven-archetype-plugin:2.4:generate
-DarchetypeGroupId=com.xxx
-DarchetypeArtifactId=springbootdemo
-DarchetypeCatalog=https://repository.apache.org/content/repositories/snapshots/
-DarchetypeVersion=0.0.1-SNAPSHOT
-DgroupId={替换你要生成的项目的groupID，如：com.xxx.testdemo}
-DartifactId={替换你要生成的项目的artifactId，如：testdemo}
-Dversion={替换你要生成的项目的version，如：0.0.1-SNAPSHOT}
```
