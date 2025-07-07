---
title: java应用docker部署获取宿主机物理网卡信息方案
date: 2025-07-04 10:50:00
categories: [后端, java]
tags: [后端, java, docker]
image:
  path: /assets/img/posts/common/java.jpg
---

# java应用docker部署获取宿主机物理网卡信息方案

## 方案概述

本方案适用于 Docker 的 bridge 网络模式，便于为容器分配固定 IP 并支持通过容器名直接进行网络访问，无需切换到 host 模式。

通过文件挂载方式，将宿主机物理网卡的 MAC 地址信息传递到容器，并结合签名机制防止文件被篡改，确保数据安全可靠。

该方案特别适用于 lisense 授权验证等需要容器内获取并信任宿主机物理网卡 MAC 信息的场景。

---

## 1. 获取物理网卡MAC地址及签名的自动化脚本

### 1.1 脚本内容

保存为 `/data/mac-auth/get_and_sign_macs.sh`（宿主机）：

```bash
#!/bin/bash
# 1. 获取所有物理网卡及其MAC地址
cd /sys/class/net
> /data/mac-auth/macs.txt
for iface in *; do
  [[ "$iface" =~ ^(lo|docker|br-|veth) ]] && continue
  if [ -d "$iface/device" ]; then
    mac=$(cat $iface/address)
    echo "$iface:$mac" >> /data/mac-auth/macs.txt
  fi
done

# 2. 用私钥签名
openssl dgst -sha256 -sign /data/mac-auth/private.key -out /data/mac-auth/macs.sig /data/mac-auth/macs.txt
```

- `/data/mac-auth/private.key` 为授权方生成的私钥（只需生成一次，妥善保管）。
- `/data/mac-auth/macs.txt` 和 `/data/mac-auth/macs.sig` 为输出文件。

### 1.2 私钥、公钥生成（只需一次）

```sh
openssl genrsa -out /data/mac-auth/private.key 2048
openssl rsa -in /data/mac-auth/private.key -pubout -out /data/mac-auth/public.pem
```

---

## 2. docker-compose 自动化集成

### 2.1 在主容器 entrypoint/command 自动生成 MAC 文件

推荐将获取物理网卡 MAC 地址及签名的脚本直接集成到主容器（如 java 容器）的 entrypoint 或 command 中。这样可以确保每次主容器启动时，都会自动生成最新的 macs.txt 和 macs.sig 文件，无论是 docker-compose up 还是 docker restart java 都能生效。

#### 关键配置示例

假设你的基础镜像为 alpine，且 /data/mac-auth/get_and_sign_macs.sh、/data/mac-auth/private.key 已挂载到宿主机：

```yaml
version: '3.8'
services:
  java:
    image: your-java-image
    volumes:
      - /sys/class/net:/sys/class/net:ro
      - /data/mac-auth:/mac-auth
    entrypoint: ["/bin/sh", "-c", "/mac-auth/get_and_sign_macs.sh && java -jar your-app.jar"]
    # ... 其他配置
```

> 说明：  
> - 每次 java 容器启动时，都会自动执行 MAC 信息收集与签名脚本，然后启动主应用。
> - /mac-auth/macs.txt 和 /mac-auth/macs.sig 会被自动更新为最新内容。
> - 公钥已内置在 Java 程序中，无需挂载 public.pem。
> - 只需挂载自定义目录（如 /data/mac-auth），避免将整个 /opt 目录映射到容器内。
> - 如果基础镜像已自带 openssl，无需重复安装。

### 2.2 其他自动化方式

如需更高实时性，也可将 get_and_sign_macs.sh 作为 systemd 服务或 cron job，定期/每次重启时自动执行。

---

## 3. Java 程序校验签名并获取网卡地址

### 3.1 公钥生成（只需一次）

```sh
openssl genrsa -out /opt/private.key 2048
openssl rsa -in /opt/private.key -pubout -out /opt/public.pem
```

### 3.2 Java 关键代码（公钥内置）

将公钥内容（PEM格式）直接写死在 Java 代码中，例如：

```java
private static final String PUBLIC_KEY_PEM =
    "-----BEGIN PUBLIC KEY-----\n" +
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn...（省略）...IDAQAB\n" +
    "-----END PUBLIC KEY-----";

public static PublicKey loadPublicKeyFromString(String pem) throws Exception {
    String key = pem.replaceAll("-----\\w+ PUBLIC KEY-----", "").replaceAll("\\s", "");
    byte[] keyBytes = java.util.Base64.getDecoder().decode(key);
    java.security.spec.X509EncodedKeySpec spec = new java.security.spec.X509EncodedKeySpec(keyBytes);
    return java.security.KeyFactory.getInstance("RSA").generatePublic(spec);
}

public static void main(String[] args) throws Exception {
    byte[] macsData = java.nio.file.Files.readAllBytes(java.nio.file.Paths.get("/macs.txt"));
    byte[] sigData = java.nio.file.Files.readAllBytes(java.nio.file.Paths.get("/macs.sig"));
    PublicKey pubKey = loadPublicKeyFromString(PUBLIC_KEY_PEM);
    if (!verifySignature(macsData, sigData, pubKey)) {
        throw new SecurityException("MAC地址文件被篡改或签名无效！");
    }
    Map<String, String> macMap = parseMacs(new String(macsData));
    System.out.println(macMap);
}

/**
 * 该方法会将 macs.txt 文件内容按行解析为 Map<String, String>，key 为网卡名，value 为对应的 MAC 地址。
 */
public static Map<String, String> parseMacs(String content) {
    Map<String, String> macMap = new HashMap<>();
    for (String line : content.split("\n")) {
        String[] arr = line.trim().split(":");
        if (arr.length == 2) {
            macMap.put(arr[0], arr[1]);
        }
    }
    return macMap;
}

/**
 * 校验macs.txt的签名是否合法。
 * @param data macs.txt文件内容的字节数组
 * @param sig macs.sig文件内容的字节数组
 * @param pubKey 公钥对象
 * @return true表示签名校验通过，false表示校验失败
 */
public static boolean verifySignature(byte[] data, byte[] sig, PublicKey pubKey) throws Exception {
    Signature signature = Signature.getInstance("SHA256withRSA");
    signature.initVerify(pubKey);
    signature.update(data);
    return signature.verify(sig);
}
```

> 说明：
> - 将 `public.pem` 文件内容（PEM 格式）复制到 `PUBLIC_KEY_PEM` 字符串中。
> - Java 程序直接用内置公钥校验签名，无需再挂载 public.pem。
> - 如特殊场景下也可通过挂载 public.pem 文件传递公钥，但此方式存在被攻击者同时篡改 macs.sig 和 public.pem 的风险，安全性较低，不推荐用于生产环境。

---

## 4. 方案说明与安全建议

- **自动化**：每次容器启动时，主服务自动生成并签名物理网卡 MAC 信息，主服务挂载只读文件。
- **安全性**：  
  - 私钥仅存于宿主机，公钥已内置到 Java 程序，无需分发。
  - Java 程序校验签名，防止 macs.txt 被篡改。
- **可维护性**：如有多台宿主机，均可复用此方案。

---

## 5. 目录结构建议

建议在宿主机和容器内保持如下目录结构，便于管理和安全控制：

```
/data/mac-auth/
  get_and_sign_macs.sh   # 获取并签名脚本（宿主机）
  private.key            # 私钥，仅授权方持有（宿主机）
  public.pem             # 公钥（如需挂载方式，可选）
  macs.txt               # 物理网卡MAC信息（每次容器启动自动生成）
  macs.sig               # macs.txt 的签名文件（每次容器启动自动生成）
```

- 容器内通过挂载 `/mac-auth/macs.txt` 和 `/mac-auth/macs.sig` 只读访问。
- 推荐将公钥直接内置到 Java 程序中，避免挂载 public.pem。
- `get_and_sign_macs.sh` 和 `private.key` 仅应保存在宿主机，防止泄露。
- `/sys/class/net` 以只读方式挂载到容器，便于脚本获取物理网卡信息。
- 强烈建议仅挂载专用目录（如 `/data/mac-auth`），避免将整个 `/opt` 目录映射到容器内，提升安全性和可维护性。

---

## 6. 参考

- [Docker Compose init container](https://docs.docker.com/compose/compose-file/compose-file-v3/#init)
- [Java RSA签名与校验](https://docs.oracle.com/en/java/javase/11/docs/api/java.base/java/security/Signature.html)
- [OpenSSL命令参考](https://www.openssl.org/docs/man1.1.1/man1/openssl-dgst.html)

---

## 7. 常见问题与补充说明

- **Q: 如果物理网卡名不是 ens18，脚本能否识别？**  
  A: 能，脚本会自动过滤虚拟网卡，只输出有 `/sys/class/net/<iface>/device` 的物理网卡。
- **Q: 如果有多块物理网卡？**  
  A: `macs.txt` 会输出所有物理网卡及其 MAC 地址，Java 端可遍历 map 处理。
- **Q: 文件被篡改怎么办？**  
  A: Java 校验签名，签名不通过即拒绝授权。
- **Q: 公钥如何分发？**  
  A: 公钥已内置到 Java 程序，无需分发。

---
