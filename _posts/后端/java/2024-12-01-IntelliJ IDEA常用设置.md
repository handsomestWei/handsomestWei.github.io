---
title: IntelliJ IDEA常用设置
date: 2024-12-01 12:00:00
categories: [后端, java]
tags: [后端, java, idea]
image:
  path: /assets/img/posts/common/java.jpg
---

# IntelliJ IDEA常用设置

## 常用插件列表
- lambda表达式debug：idea自带，`debug Tab窗口`->`Trace Current Stream Chain`
- UML类图：idea自带的`Diagrams`
- 类图：PlantUML Integration
- 方法时序图：SequenceDiagram
- mapper java接口和xml sql标签自动关联跳转：MyBatisX

## 方法注释模板设置
### 注意事项
模版开头一定不能带有/符，否则methodParameters()在方法外取不到值。

### 触发快捷键
```
*符。先按/，再按*和Enter。
```
### 模板
```
**
 * TODO 
 *
$params$        
 * @return $return$
 * @exception $exception$
 * @date $date$ $time$
 */
```

### 模板参数
![方法注释模板参数](/assets/img/posts/2024-12-01-IntelliJ IDEA常用设置/方法注释模板参数.jpg)   
其中`params`项配置如下
>  groovyScript("def result=''; def params=\"${_1}\".replaceAll('[\\\\[|\\\\]|\\\\s]', '').split(',').toList(); for(i = 0; i < params.size(); i++) {result+=' * @param ' + params[i] + ((i < params.size() - 1) ? '\\n' : '')}; return result", methodParameters())

## 全局设置
不是在`all setting`   
而是在`File—>New Projects Setup—>Settings for New Projects`   
设置后，新打开的项目会使用全局设置。之前已使用idea打开的可能不生效，可以尝试删除项目目录下的.idea重新打开。

## 其他常用设置
[参考博客](https://cloud.tencent.com/developer/article/2405464)