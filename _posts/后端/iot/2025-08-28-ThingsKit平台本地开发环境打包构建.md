---
title: ThingsKit平台本地开发环境打包构建
date: 2025-08-28 16:00:00
categories: [后端, iot]
tags: [后端, iot, ThingsKit]
image:
  path: /assets/img/posts/common/iot.jpg
---

# ThingsKit平台本地开发环境打包构建
[ThingsKit](https://www.yunteng.com/)是基于开源项目`ThingsBoard`基础上开发的物联网平台，源码需商业授权。

## 环境配置
### jdk安装
平台运行jdk版本需要至少`11`或以上。

### yarn安装
Yarn和npm类似，也是一个包管理工具，旨在解决npm的一些性能问题。
```sh
npm install -g yarn
yarn config set registry https://registry.npmmirror.com
```

### node安装
注意升级到`20`及以上高版本，否则yarn install会提示：The engine "node" is incompatible with this module. Expected version ">=20".

### gradle安装
gradle是后端依赖包管理工具，和maven类似，下载地址[https://gradle.org/releases/#close-notification](https://gradle.org/releases/#close-notification)

建议使用`7.6.3`版本，添加环境量GRADLE_HOME，和添加到PATH=%GRADLE_HOME%\bin

在thingskit/pom.xml根配置中，使用自己封装的打包插件，相比于原生的maven gradle插件，多了自动安装和卸载脚本等功能。gradle目录需要增加本地配置，避免触发网络下载和导致下载失败。新增以下配置内容：

```xml
<plugin>
	<groupId>org.thingsboard</groupId>
	<artifactId>gradle-maven-plugin</artifactId>
	<configuration>
		<gradleProjectDirectory>${main.dir}/packaging/${pkg.type}</gradleProjectDirectory>
		<!-- 指定本地gradle安装目录，避免网络下载 -->
		<gradleInstallationDir>D:/gradle-7.6.3</gradleInstallationDir>
		<!-- 指定gradle用户主目录 -->
		<gradleUserHomeDir>D:/gradle-user-home</gradleUserHomeDir>
		<!-- 指定gradle版本 -->
		<gradleVersion>7.6.3</gradleVersion>

		<!-- 略 -->
</plugin>
```

其他gradle配置参数可以反编译org.thingsboard的gradle-maven-plugin包查看。

## 后端工程编译打包常见问题和解决
后端工程`thingskit`

### 编译失败-依赖缺失
- 例`thingskit\msa\black-box-tests`模块编译报错，报错日志
  ```log
  Project 'org.thingsboard.msa-black-box-tests' is missing required Java project: 'org.thingsboard.msa-js-executor'
  ```
  解决方案：先编译缺失的msa-js-executor包
  ```sh
  mvn clean compile -pl msa/js-executor -am
  ```

- 例`thingskit\common\transport\transport-api`模块编译失败，日志提示程序包不存在。   

  缺失的类都是通过 Protocol Buffers (protobuf) 生成，需要先执行thingskit目录下的build_proto.sh脚本。

### 编译失败-依赖包下载慢
部分依赖包需要先从私有仓库下载到本地，参考[https://yunteng.yuque.com/avshoi/hlzqwf/ttyhd4v2z5a0z3sg#4123fc3d](https://yunteng.yuque.com/avshoi/hlzqwf/ttyhd4v2z5a0z3sg#4123fc3d)

例`msa-js-executor`模块编译失败，解决方案：根据编译时的报错日志，将包提前下载，放置到本地maven仓库。

```
源：https://nodejs.org/dist/v16.20.2/win-x64/node.exe
本地maven仓库路径：<local-mvn-repo>\com\github\eirslett\node\16.20.2\node-16.20.2-win-x64.exe
```

### 编译失败-pkg工具跨平台构建失败
例`thingskit\msa\js-executor`模块编译失败，
报错日志：`Error! Not able to build for 'linux' here, only for 'win'`

原因：在Windows系统上尝试构建Linux版本的Node.js二进制文件，但pkg工具无法在Windows上构建Linux目标。一般CI/CD流程，有专门的构建服务器，不需要在本地win开发环境构建，所以不会遇到这种问题。

解决方案：

1）修改thingskit\msa\js-executor\package.json文件，删除-linux包。修改前
```json
"pkg": "tsc && pkg -t node16-linux-x64,node16-win-x64 --out-path ./target ./target/src && node install.js"
```
修改后
```json
"pkg": "tsc && pkg -t node16-win-x64 --out-path ./target ./target/src && node install.js"
```

2）修改thingskit\msa\js-executor\install.js文件，将相关linux改为windows。修改前
```js
await fse.move(path.join(projectRoot(), 'target', 'thingsboard-js-executor-linux'),
                  path.join(targetPackageDir('linux'), 'bin', 'tb-js-executor'),
                  {overwrite: true});
```
修改后
```js
await fse.move(path.join(projectRoot(), 'target', 'thingsboard-js-executor-win.exe'),
        path.join(targetPackageDir('windows'), 'bin', 'tb-js-executor.exe'),
        { overwrite: true });
```

### 编译失败-yarn命令执行失败
```log
Caused by: com.github.eirslett.maven.plugins.frontend.lib.TaskRunnerException: 'yarn install --non-interactive --network-concurrency 4 --network-timeout 100000 --mutex network' failed.
```
例thingskit\ui-ngx模块通过maven插件执行构建时可能会失败，可以先把yarn install命令从pom里提取出来，在命令行执行并观察日志，定位原因。
```sh
 cd ui-ngx && yarn install --non-interactive --network-concurrency 4 --network-timeout 10000
```
依赖包会下载到thingskit\ui-ngx\node_modules目录内。

### 模块编译耗时过久
例`thingskit\msa\js-executor`模块编译耗时过久，待优化，目前暂时只能耐心等待。

## 前端工程编译打包常见问题和解决
前端工程`thingskit-front`

### front工程父依赖缺失
thingskit-front模块根pom，使用parent标签定义了父依赖。
```xml
<parent>
  <artifactId>yun-teng-iot</artifactId>
  <groupId>com.codeez</groupId>
  <version>0.0.1</version>
</parent>
```
该依赖可能存在于私有仓库，或依赖已发生变更但未调整。打包时可以不使用maven插件构建方式，规避依赖报错问题。可以直接使用`yarn install`和`yarn build`编译打包构建。
