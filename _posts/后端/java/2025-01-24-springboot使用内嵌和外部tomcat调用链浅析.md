---
title: springboot使用内嵌和外部tomcat调用链浅析
date: 2025-01-04 16:00:00
categories: [后端, java]
tags: [后端, java, springboot, tomcat]
image:
  path: /assets/img/posts/common/java.jpg
---

# springboot使用内嵌和外部tomcat调用链浅析

## 关于外部tomcat
maven pom配置
```xml
// 打包时jar包改为war包
<packaging>war</packaging>

// 内嵌的tomcat的scope标签影响范围设置为provided，只在编译和测试时有效，打包时不带入
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-tomcat</artifactId>
    <scope>provided</scope>
</dependency>
```
启动类需继承SpringBootServletInitializer并复写configure方法
```java
@Override
protected SpringApplicationBuilder configure(SpringApplicationBuilder builder){
        return builder.sources(this.getClass());
	// 还可以显式声明应用类型WebApplicationType
	// return builder.sources(this.getClass()).web(WebApplicationType.NONE);
}
```
应用类型WebApplicationType分三种
```
NONE：应用程序不作为web应用启动，不启动内嵌的服务。
SERVLET：应用程序以基于servlet的web应用启动，需启动内嵌servlet web服务。
REACTIVE：应用程序以响应式web应用启动，需启动内嵌的响应式web服务。
```
configure调用链
![configure调用链](/assets/img/posts/2025-01-24-springboot使用内嵌和外部tomcat调用链浅析/configure调用链.jpg)

## 关于内嵌tomcat
利用了构造函数new Tomcat()创建tomcat对象。可以引入以下maven依赖。
```xml
<dependency>
    <groupId>org.apache.tomcat.embed</groupId>
    <artifactId>tomcat-embed-core</artifactId>
    <version>xxx</version>
</dependency>
<dependency>
    <groupId>org.apache.tomcat.embed</groupId>
    <artifactId>tomcat-embed-el</artifactId>
    <version>xxx</version>
</dependency>
<dependency>
    <groupId>org.apache.tomcat.embed</groupId>
    <artifactId>tomcat-embed-jasper</artifactId>
    <version>xxx</version>
</dependency>
```
## 消失的Web.xml    
servlet3.0后springMVC提供了**WebApplicationInitializer**接口替代了`Web.xml`。而JavaConfig的方式替代了`springmvc-config.xml`
### servlet3.0特性之ServletContainerInitializer
[参考](https://www.jcp.org/en/jsr/detail?id=315)8.2.4节。也称SCI接口，约定了servlet容器启动时，会扫描当前应用里面每一个jar包的`ServletContainerInitializer`的实现，利用了**SPI**机制。可参考tomcat的`org.apache.catalina.startup.ContextConfig#processServletContainerInitializers`方法。
```java
/**
 * Scan JARs for ServletContainerInitializer implementations.
 */
protected void processServletContainerInitializers()
```
tomcat启动时触发调用了configureStart方法   
![configureStart调用链](/assets/img/posts/2025-01-24-springboot使用内嵌和外部tomcat调用链浅析/configureStart调用链.jpg)

### springMVC之ServletContainerInitializer实现
调用链入口
```
spring-web-xxx.jar里META-INF/services/javax.servlet.ServletContainerInitializer文件，
定义了实现类org.springframework.web.SpringServletContainerInitializer
```
### onStartup调用链
![onStartup调用链](/assets/img/posts/2025-01-24-springboot使用内嵌和外部tomcat调用链浅析/onStartup调用链.jpg)

### 关于@HandlesTypes注解
属于servlet3.0规范，在javax.servlet.annotation包里。作用是在onStartup方法的入参上，传入注解@HandlesTypes定义的类型   
在springMVC上的使用
```java
@HandlesTypes(WebApplicationInitializer.class)
public class SpringServletContainerInitializer implements ServletContainerInitializer {

	@Override
	public void onStartup(@Nullable Set<Class<?>> webAppInitializerClasses, ServletContext servletContext)
			throws ServletException {
        ... 
    }
    ...
}
```
在tomcat上的使用，调用链为
```
参考org.apache.catalina.startup.ContextConfig
1）在processServletContainerInitializers方法，记录下注解名
2）在processAnnotationsStream方法，使用bcel字节码工具org.apache.tomcat.util.bcel直接读取字节码文件，判断是否与记录的注解类名相同
3）若相同再通过org.apache.catalina.util.Introspection类load为Class对象，最后保存起来
4）在Step 11中交给org.apache.catalina.core.StandardContext，也就是tomcat实际调用ServletContainerInitializer.onStartup()的地方。
```