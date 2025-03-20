---
title: 使用自定义maven pom依赖项目实现spring boot工程包版本管理
date: 2025-02-05 09:00:00
categories: [后端, java, maven]
tags: [后端, java, maven]
image:
  path: /assets/img/posts/common/java.jpg
---

# 使用自定义maven pom依赖项目实现spring boot工程包版本管理
自定义`parent`和`dependency`模块，整合开发中常用到的`spring-boot-dependencies`和其他私有依赖。

## pom项目优点
+ 依赖包和版本号集中在一个文件做统一管理。适合制定统一规范，方便版本更新（如公共包有安全漏洞要做版本升级的场景）。还可以配合`maven archetype`搭建自定义脚手架。
+ 版本只需要声明一次，就能屏蔽下级引用的版本冲突。
+ 支持继承`parent`和组合`dependencies`两种方式灵活使用。

## pom项目定义
pom项目和普通maven工程类似，有`pom.xml`定义，但`packaging`标签打包类型为`pom`，和常见的`jar`和`war`不同。
### 文件构成
- ctm-spring-boot-pom-project
	- ctm-spring-boot-starter-parent
		- pom.xml
	- ctm-spring-boot-dependencies
		- pom.xml

maven工程构建成果为`.pom`文件，发布上传到maven私有仓库。

### parent模块pom定义
在本pom.xml中，自定义父工程，结合自定义dependency使用，用来屏蔽其他parent引入的dependencyManagement。
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <parent>
        <groupId>com.xxx</groupId>
        <artifactId>ctm-spring-boot-dependencies</artifactId>
        <version>0.0.1.RELEASE</version>
    </parent>
    <groupId>com.xxx</groupId>
    <artifactId>ctm-spring-boot-starter-parent</artifactId>
    <version>0.0.1.RELEASE</version>
    <packaging>pom</packaging>
    <modelVersion>4.0.0</modelVersion>
    <name>ctm-spring-boot-starter-parent</name>

    <properties>
        <java.version>1.8</java.version>
        <resource.delimiter>@</resource.delimiter>
        <maven.compiler.source>${java.version}</maven.compiler.source>
        <maven.compiler.target>${java.version}</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
    </properties>

    <dependencyManagement>
        <dependencies></dependencies>
    </dependencyManagement>

    <build>
		<!-- 略，copy from spring-boot-starter-parent-x.x.x.pom -->
    </build>

    <distributionManagement>
        <repository>
            <id>ctm-release</id>
            <name>ctm-release</name>
            <url>xxx</url>
        </repository>
        <snapshotRepository>
            <id>ctm-snapshot</id>
            <name>ctm-snapshot</name>
            <url>xxx</url>
        </snapshotRepository>
    </distributionManagement>

</project>
```

### dependencies模块pom定义
在本pom.xml中，声明依赖包和版本，做全局统一管理。
```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">

    <groupId>com.xxx</groupId>
    <artifactId>ctm-spring-boot-dependencies</artifactId>
    <version>0.0.1.RELEASE</version>
    <modelVersion>4.0.0</modelVersion>
    <packaging>pom</packaging>
    <name>ctm-spring-boot-dependencies</name>

    <dependencyManagement>
		<!-- add your dependencies -->
        <dependencies>
            <dependency>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-starter</artifactId>
                <version>x.x.x</version>
                <exclusions>
                    <exclusion>
                        <groupId>*</groupId>
                        <artifactId>*</artifactId>
                    </exclusion>
                </exclusions>
            </dependency>
        </dependencies>
    </dependencyManagement>

    <distributionManagement>
        <repository>
            <id>ctm-release</id>
            <name>ctm-release</name>
            <url>xxx</url>
        </repository>
        <snapshotRepository>
            <id>ctm-snapshot</id>
            <name>ctm-snapshot</name>
            <url>xxx</url>
        </snapshotRepository>
    </distributionManagement>
</project>
```

## pom项目引用
### 本地maven配置
使用时修改maven的settings.xml文件：   
1、在```<profiles>```节点新增一组```<profile>```配置。
```xml
<profile>
	<id>ctm-release</id>
	<repositories>
		<repository>
			<id>ctm-release</id>
			<name>ctm-release</name>
			<url>xxx</url>
			<releases>
				<enabled>true</enabled>
			</releases>
			<snapshots>
				<enabled>true</enabled>
			</snapshots>
		</repository>
	</repositories>
<profile>       
```
2、在```<activeProfiles>```节点新增```<activeProfile>```配置。
```xml
<activeProfile>ctm-release</activeProfile>
```

### pom项目使用
#### 方式一：继承（推荐）
1、在项目根pom，将原parent的spring-boot-starter-parent改为骨架工程。
```xml
<parent>
    <groupId>com.xxx</groupId>
    <artifactId>ctm-spring-boot-starter-parent</artifactId>
    <version>${last.version.RELEASE}</version>
</parent>
```
2、删除项目原```<dependencyManagement>```节点   
3、在```<dependencies>```节点中引用依赖时，不要显式声明依赖的版本号，会自动继承```<dependencyManagement>```节点中声明的。在多模块项目中，对子模块也适用。

#### 方式二：组合
原项目已经继承私有parent（非原生spring-boot-starter-parent），使用骨架提供`dependencies`模块，以组合的方式使用，做依赖包版本控制。   
1、在项目根pom的```<dependencyManagement>```节点，添加以下配置
```xml
<dependency>
    <groupId>com.xxx</groupId>
    <artifactId>ctm-spring-boot-dependencies</artifactId>
    <version>${last.version.RELEASE}</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
```
``` 
注：若版本控制失效，一般是父级私有parent内也声明有一份dependencyManagement，导致子的失效。在本级需要把引用type pom的方式，改为显式声明，手动复制所有dependency到dependencyManagement节点内。
```
2、在```<dependencies>```节点中引用依赖，不用带版本号。

## 附maven标签功能简介
### dependencyManagement简介
[依赖包版本的管理器](https://maven.apache.org/guides/introduction/introduction-to-dependency-mechanism.html)，dependencyManagement里只是声明依赖，并不实现引入。
+ 版本控制：如果dependencies里的dependency没有声明version元素，那么maven就会到dependencyManagement里面去找有没有对该artifactId和groupId进行过版本声明，如果有，就继承它。
+ 中断：如果dependencies中的dependency声明了version，那么无论dependencyManagement中有无对该jar的version声明，都以dependency里的version为准。   

在引用```<type>pom</type>```类型时，一般结合```<scope>import</scope>```一起使用。

### type pom简介
dependency的type类型默认是jar。当项目中需要引入很多jar包，容易导致单个pom.xml文件过大，可读性降低。可以单独定义一个type类型为pom的maven项目，做依赖包统一管理，不需要到处定义。使用时直接引用，利用maven依赖传递特性。
