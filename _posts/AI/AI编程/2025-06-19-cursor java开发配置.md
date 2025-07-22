---
title: cursor java开发配置
date: 2025-06-19 09:20:00
categories: [AI, AI编程, cursor]
tags: [AI, AI编程, cursor]
image:
  path: /assets/img/posts/common/AI.jpg
---

# cursor java开发配置

## 常用插件
+ Extension Pack for Java：java开发全家桶，多个插件的合集。
+ Spring Boot Extension Pack： spring开发全家桶，多个插件的合集。
+ IntelliJ IDEA Keybindings：在Cursor中使用IDEA快捷键。

## 全局配置
在Cursor中配置环境需要写入settings.json文件中，settings.json文件有3个级别，配置分了3个级别：默认配置、全局用户配置、工作空间配置。

全局配置入口在`File->Preference->Profile->Setting`，将打开配置文件，所有在界面做的配置，都会写入到该文件。

配置文件参考，调整几个路径即可。
<details>
<summary>完整配置</summary>
```json
{
    "window.commandCenter": true,
    "workbench.colorTheme": "Visual Studio Light",
    "java.jdt.ls.java.home": "C:/Program Files/Java/jdk1.8.0_311",
    "maven.executable.path": "D:/apache-maven-3.9.9/bin/mvn.cmd",
    "[java]": {
        "editor.defaultFormatter": "redhat.java"
    },
    "java.configuration.maven.globalSettings": "D:\\apache-maven-3.9.9\\conf\\settings.xml",
    "files.encoding": "utf8",
    "terminal.integrated.defaultProfile.windows": "PowerShell",
    "terminal.integrated.profiles.windows": {
        "PowerShell": {
            "source": "PowerShell",
            "args": [
                "-NoLogo"
            ],
            "icon": "terminal-powershell"
        }
    },
    "terminal.integrated.env.windows": {
        "LANG": "zh_CN.UTF-8"
    },
    "java.configuration.updateBuildConfiguration": "automatic",
    "java.debug.settings.console": "internalConsole",
    "debug.console.fontSize": 14,
    "debug.console.fontFamily": "Consolas, 'Courier New', monospace",
    // java 格式化配置 start
    // ===== 缩进配置 =====
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": false,
    // ===== 单行最大长度 =====
    "editor.rulers": [
        120
    ],
    "editor.wordWrap": "wordWrapColumn",
    "editor.wordWrapColumn": 120,
    // ===== 保存时自动操作 =====
    "editor.formatOnSave": true,
    "editor.formatOnPaste": true,
    "files.trimTrailingWhitespace": true,
    "files.insertFinalNewline": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    // ===== Java 特定格式化 =====
    "java.format.enabled": true,
    "java.format.onType.enabled": true,
    // "java.format.settings.profile": "GoogleStyle",
    // 插件市场没有p3c插件，本地配置仍然能使用部分功能，缺少规范自动检查和提示
    // "java.format.settings.url": "https://raw.githubusercontent.com/alibaba/p3c/master/p3c-formatter/eclipse-codestyle.xml", // 在线配置方式
    "java.format.settings.url": "file:///D:/p3c-formatter/eclipse-codestyle.xml",
    "java.format.settings.profile": "P3C",
    // ===== 导入优化 =====
    "java.saveActions.organizeImports": true,
    "java.completion.importOrder": [
        "java",
        "javax",
        "com",
        "org"
    ],
    // ===== 代码检查 =====
    "java.compile.nullAnalysis.mode": "automatic", // 启用增量编译
    "java.errors.incompleteClasspath.severity": "warning",
    // ===== 编辑器增强 =====
    "editor.bracketPairColorization.enabled": true,
    "editor.renderWhitespace": "boundary",
    "editor.renderLineHighlight": "all",
    // ===== 文件排除 =====
    "search.exclude": {
        "**/target": true,
        "**/build": true,
        "**/.gradle": true,
        "**/out": true,
        "**/bin": true
    }
    // java 格式化配置 end
}
```
</details>

## 常见问题和解决
### 窗口内整合多个工程
升级为工作空间，`File->Add Folder to WorkSpace...`，记得点`Save`保存工作空间。

### maven打包插件报错
+ 工程pom文件报错 `Failed to execute mojo org.apache.maven.plugins:maven-dependency-plugin:3.7.0:copy-dependencies {execution: copy-dependencies}`
+ 解决方案 插件兼容性问题，新增maven配置文件
+ 配置路径url`cursor://settings/java.configuration.maven.lifecycleMappings`
    文件名`vscode-maven-lifecycle-mappings-metadata.xml`
    ```xml
    <?xml version="1.0" encoding="UTF-8"?>
    <lifecycleMappingMetadata>
        <pluginExecutions>
            <pluginExecution>
                <pluginExecutionFilter>
                    <groupId>org.apache.maven.plugins</groupId>
                    <artifactId>maven-dependency-plugin</artifactId>
                    <versionRange>[2.10,)</versionRange>
                    <goals>
                        <goal>copy-dependencies</goal>
                    </goals>
                </pluginExecutionFilter>
                <action>
                    <ignore />
                </action>
            </pluginExecution>
        </pluginExecutions>
    </lifecycleMappingMetadata>
    ```
