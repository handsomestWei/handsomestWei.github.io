---
title: html-video技能使用简介
date: 2026-07-03 10:53:00
categories: [AI, skill]
tags: [AI, skill, html-video, 视频制作]
image:
  path: /assets/img/posts/common/skill.jpg
---

# html-video技能使用简介

> 本文介绍 Open Design 出品的 **html-video** 技能：以 HTML/CSS 动画为画面、Playwright 录屏与 ffmpeg 编码生成 MP4，并可对接 MiniMax 合成旁白与烧录字幕。内容基于实际踩坑与跑通经验整理，路径与业务文案已做抽象化处理，便于在 Cursor Skills 工作区复用。

**参考与延伸阅读**：

- 上游仓库：<https://github.com/nexu-io/html-video>
- 技能本地路径示例：`.cursor/skills/html-video/`
- 中文 README：技能目录内 `README.zh-CN.md`
- Playwright 国内安装：技能目录内 `scripts/install-playwright-cn.md`

---

## 目录

- [1. 工具定位与产出能力](#1-工具定位与产出能力)
- [2. 环境准备](#2-环境准备)
- [3. MiniMax API 配置](#3-minimax-api-配置)
- [4. 本机 Chrome 渲染](#4-本机-chrome-渲染)
- [5. 文案与旁白准备](#5-文案与旁白准备)
- [6. 画面与字幕技术要点](#6-画面与字幕技术要点)
- [7. Studio 使用简介](#7-studio-使用简介)
- [8. 脚本一键出片流程](#8-脚本一键出片流程)
- [9. 工作区目录结构](#9-工作区目录结构)
- [10. 常用 CLI 速查](#10-常用-cli-速查)
- [11. 故障排查](#11-故障排查)
- [12. 成片检查清单](#12-成片检查清单)
- [13. 小结](#13-小结)
- [14. 参考与来源](#14-参考与来源)

---

## 1. 工具定位与产出能力

[html-video](https://github.com/nexu-io/html-video) 是 **HTML → MP4** 工具层：用 HTML/CSS 动画做画面，Playwright 录屏 + ffmpeg 编码成片，可选 MiniMax 合成旁白并混音。

典型目录约定（按本机仓库自行调整）：

| 角色 | 相对路径示例 |
|------|----------------|
| 技能源码 | `.cursor/skills/html-video/` |
| 视频产出工作区 | `<产出目录>/`（如项目下的 `video-output/`） |
| CLI 入口 | `.cursor/skills/html-video/packages/cli/dist/bin.js` |

下文用环境变量简化命令：

```powershell
$HV  = "<技能目录>/packages/cli/dist/bin.js"   # html-video CLI
$CWD = "<产出目录>"                            # Studio / 项目工作区
```

### 1.1 成片要素一览

| 要素 | 实现方式 |
|------|----------|
| **画面文案** | HTML 模板中的标题、标签、分镜文字（可参考产品官网或 PRD） |
| **旁白语音** | MiniMax TTS（音色如 `female-shaonv`、`male-qn-qingse` 等） |
| **烧录字幕** | HTML 内 JS 字幕轨，与旁白分句对齐，导出时烙进画面 |
| **时长控制** | **跟随旁白自然长度**（参考约 10s，通常 10–15s，不硬性卡死） |
| **成片格式** | `output.mp4`（默认 1920×1080） |

---

## 2. 环境准备

### 2.1 前置依赖

| 依赖 | 要求 | 检查命令 |
|------|------|----------|
| Node.js | ≥ 20 | `node --version` |
| pnpm | ≥ 9 | `pnpm --version` |
| ffmpeg | 较新版本 | `ffmpeg -version` |
| Google Chrome | 已安装 | 系统自带或手动安装 |

### 2.2 安装与构建

```powershell
cd <技能目录>

# Windows 建议 .npmrc 使用 hoisted，避免 pnpm 符号链接权限问题
# 文件内容：node-linker=hoisted

pnpm install
pnpm -r build
```

构建成功后应存在：`<技能目录>/packages/cli/dist/bin.js`

### 2.3 环境自检

```powershell
node $HV doctor --cwd $CWD
```

> `doctor` 在 Windows 上可能误报 ffmpeg/chromium 缺失，只要本机 `ffmpeg` 和 Chrome 实际可用即可。

---

## 3. MiniMax API 配置

html-video 的 **TTS 旁白**和**背景音乐**均走 **MiniMax**。

### 3.1 配置文件（推荐）

路径（建议加入 `.gitignore`，勿提交密钥）：

```text
<产出目录>/.html-video/media-config.json
```

示例结构：

```json
{
  "minimax": {
    "apiKey": "<YOUR_MINIMAX_API_KEY>",
    "baseUrl": "https://api.minimaxi.com/v1"
  }
}
```

### 3.2 区域与 Key 配对

| Key 类型 | baseUrl |
|----------|---------|
| 国内 | `https://api.minimaxi.com/v1` |
| 国际 | `https://api.minimax.io/v1` |

Key 与区域不匹配会报 `invalid api key`（错误码 2049）。旧域名 `api.minimaxi.chat` 已停用。

### 3.3 环境变量（可选）

```powershell
$env:MINIMAX_API_KEY = "<YOUR_MINIMAX_API_KEY>"
$env:MINIMAX_BASE_URL = "https://api.minimaxi.com/v1"
```

配置文件优先级高于环境变量。

### 3.4 TTS 连通性验证

在产出目录执行 TTS 测试脚本（若已提供），或临时调用 MiniMax API 合成一段短文本，确认能生成 mp3。

### 3.5 Studio 内配置

启动 Studio 后：**Settings → Audio** 填写 Key 并选择区域，效果与 `media-config.json` 相同。

---

## 4. 本机 Chrome 渲染

### 4.1 常见网络问题

执行 `playwright install chromium` 时，从 `cdn.playwright.dev` 下载浏览器包，国内经常 **0% 卡死** 或极慢。且 Playwright 版本升级后，所需 Chromium 修订号可能与本机已装版本不一致。

### 4.2 推荐方案：系统 Chrome

本机已安装 **Google Chrome** 时，无需下载 Playwright 内置浏览器：

```powershell
$env:HTML_VIDEO_USE_SYSTEM_CHROME = "1"
```

渲染器逻辑：

1. 优先使用 Playwright 内置 Chromium  
2. 若缺失 → **自动回退**到 `channel: 'chrome'`（系统 Chrome）

### 4.3 换源安装（备选）

```powershell
cd <技能目录>
$env:PLAYWRIGHT_DOWNLOAD_HOST = "https://cdn.npmmirror.com/binaries/playwright"
node node_modules/playwright/cli.js install chromium
```

> 必须用项目内 `node_modules/playwright/cli.js`，不要用 `npx playwright install`（易装错版本）。  
> 更多说明见：`<技能目录>/scripts/install-playwright-cn.md`

---

## 5. 文案与旁白准备

### 5.1 建议工作流

```text
产品资料 / 官网卖点梳理
    → 参考文案.md（意图与素材，内部文档）
    → 旁白分句（每句一条字幕）
    → 文案与字幕.md（时间轴 + 分镜）
    → source/<模板>.html（画面）
    → generate-sample.mjs（一键出片脚本，名称可自定）
```

### 5.2 文案撰写要点

- 从**官方渠道**（官网、产品说明、PRD）提炼卖点，保持口径一致  
- 结构建议：**痛点钩子 → 产品名 → 核心能力 → 行动号召（CTA）**  
- 避免把内部草稿、无关话术直接搬进成片  
- 具体业务文案放在内部文件（如 `参考文案和内容.md`），**不要写进可对外分享的通用文档**

### 5.3 旁白分句原则

- **一句旁白 = 一条烧录字幕**，便于时间轴对齐  
- 推荐 **4–6 句旁白 + 3–4 个画面场景**  
- 旁白数组维护在生成脚本的 `SEGMENTS`（或等价配置）中，改完后重新执行脚本即可

### 5.4 时长策略

| 策略 | 说明 |
|------|------|
| 参考目标 | 约 **10 秒**短视频 |
| 实际规则 | **旁白 TTS 多长，视频就多长**（通常 10–15s） |
| 禁止做法 | 视频固定短时长 + `-shortest` 硬裁旁白（会导致字幕/语音不全） |
| 微调语速 | `generateTts({ speed: 1.0 })`，可在 0.95–1.1 间微调 |

---

## 6. 画面与字幕技术要点

### 6.1 多场景与动画时长

单页 HTML 若开场动画 2s 内结束，后续会像「一张 PPT」。应使用：

- **多场景切换**（如：痛点 → 产品 → 能力 → CTA）  
- CSS 动画时长绑定 `--dur`（= 成片总秒数）  
- 进度条、背景微动等，让整段都有视觉变化  

画面模板示例路径：`source/<模板名>.html`

### 6.2 字幕与渲染时间轴对齐

html-video 渲染时会：

1. 冻结 CSS 动画，等待字体加载  
2. 解冻动画 → 此时才是成片 **t=0**  
3. 裁掉片头等待时间  

因此字幕计时**不能**从「页面加载」开始，应挂接渲染器提供的 `__hvUnfreeze`：

```javascript
const _orig = window.__hvUnfreeze;
window.__hvUnfreeze = function () {
  if (typeof _orig === 'function') _orig();
  t0 = performance.now();  // 字幕从成片 t=0 开始
  requestAnimationFrame(frame);
};
```

生成脚本宜按旁白字数比例计算 `CUES` 并注入 HTML，避免手写固定 10s 时间轴。

---

## 7. Studio 使用简介

Studio 是 html-video 的**浏览器可视化工作台**，适合交互式改模板、对话生成、合成配音、导出 MP4。

### 7.1 启动

```powershell
cd <技能目录>
$env:HTML_VIDEO_USE_SYSTEM_CHROME = "1"
node packages/cli/dist/bin.js studio --cwd $CWD --port 3071
```

浏览器打开：**http://127.0.0.1:3071**

也可在产出目录放置 `start-studio.bat`，内容指向上述命令（路径按本机修改）。

### 7.2 主要功能

| 功能 | 说明 |
|------|------|
| 模板库 | 浏览内置模板，实时预览 |
| 对话生成 | 用 Cursor 等 Agent 描述视频，生成多帧 HTML |
| Soundtrack | 填旁白 → 选音色 →「合成配音」 |
| Settings → Audio | 配置 MiniMax Key |
| 导出 | 导出 MP4，可混入旁白 |

### 7.3 Studio 与脚本对比

| 方式 | 适合场景 |
|------|----------|
| **Studio** | 探索模板、迭代改稿、可视化操作 |
| **生成脚本** | 固定流程、可重复执行、便于自动化 |

改业务文案后，建议优先用**脚本重生**；Studio 用于预览和试验其他模板。

---

## 8. 脚本一键出片流程

### 8.1 命令示例

```powershell
cd $CWD
$env:HTML_VIDEO_USE_SYSTEM_CHROME = "1"
node generate-sample.mjs    # 脚本名按项目实际为准
```

### 8.2 典型脚本步骤

```text
[1] MiniMax TTS 合成旁白 → assets/narration.mp3
[2] ffprobe 探测音频时长 → 设定视频总时长
[3] 按分句生成字幕 CUES，注入渲染用 HTML
[4] 系统 Chrome 渲染无声 MP4
[5] ffmpeg 混流旁白 → output.mp4
[6] 更新 文案与字幕.md（可选）
```

### 8.3 常用音色（MiniMax）

| 标签 | voice_id | 备注 |
|------|----------|------|
| 女声甜美 | `female-shaonv` | 常用 |
| 女声御姐 | `female-yujie` | |
| 女声主播 | `presenter_female` | |
| 男声温暖 | `male-qn-qingse` | |

---

## 9. 工作区目录结构

```text
<产出目录>/
├── 参考文案和内容.md            ← 内部业务素材（勿外传）
├── 文案与字幕.md                ← 旁白 + 字幕时间轴 + 分镜
├── generate-sample.mjs          ← 一键出片脚本（名称可自定）
├── start-studio.bat             ← 启动 Studio（可选）
├── output.mp4                   ← 成片输出（名称可自定）
├── source/
│   └── intro.html               ← 画面模板
├── assets/
│   ├── narration.mp3
│   └── intro.render.html        ← 注入字幕后用于渲染
├── scripts/
│   └── test-minimax-tts.mjs     ← TTS 连通性测试（可选）
└── .html-video/                 ← 运行时目录（勿提交 Git）
    ├── media-config.json        ← API Key（敏感）
    └── projects/                ← Studio 项目数据
```

---

## 10. 常用 CLI 速查

```powershell
node $HV doctor --cwd $CWD
node $HV search-templates --cwd $CWD --intent "产品宣传 旁白" --top 5
node $HV studio --cwd $CWD --port 3071
```

---

## 11. 故障排查

| 现象 | 原因 | 处理 |
|------|------|------|
| `pnpm install` EPERM symlink | Windows 权限 | `.npmrc` 加 `node-linker=hoisted` |
| Playwright 下载 0% | 国外 CDN | `HTML_VIDEO_USE_SYSTEM_CHROME=1` |
| MiniMax `invalid api key` | 区域不匹配 | 核对 Key 与 baseUrl |
| 字幕不全 | 视频短于旁白 | audio-driven 时长，勿硬裁 |
| 字幕不同步 | 计时起点错误 | 使用 `__hvUnfreeze`（见 6.2 节） |
| 画面一直静止 | 动画过早结束 | 多场景 + `--dur` 绑定总时长 |
| `chmod` 构建报错 | Windows 无 chmod | 忽略；`tsc` 成功即可 |
| Studio `EADDRINUSE` | 端口已占用 | 直接访问已有实例，或换端口/结束旧进程 |

---

## 12. 成片检查清单

```text
□ Node 20+、pnpm 9+、ffmpeg、Chrome 已就绪
□ html-video 已 pnpm install && pnpm -r build
□ MiniMax Key 已写入 <产出目录>/.html-video/media-config.json
□ TTS 连通性测试通过
□ 内部参考文案已更新（业务文档，不写入对外通用指南）
□ SEGMENTS / 画面 HTML 已按需修改
□ HTML_VIDEO_USE_SYSTEM_CHROME=1
□ 执行生成脚本
□ 检查成片：分镜、旁白、字幕、时长是否完整
```

---

## 13. 小结

| 要点 | 结论 |
|------|------|
| 工具定位 | HTML/CSS 动画 + Playwright 录屏 + ffmpeg，可选 MiniMax 旁白 |
| 国内环境 | 优先 `HTML_VIDEO_USE_SYSTEM_CHROME=1`，避免 Playwright CDN 卡死 |
| 旁白与时长 | 以 TTS 音频驱动总时长，勿用 `-shortest` 硬裁 |
| 字幕同步 | 字幕计时挂接 `__hvUnfreeze`，与渲染 t=0 对齐 |
| 业务文案 | 内部素材与通用操作指南分离，敏感 Key 勿提交 Git |

---

## 14. 参考与来源

- html-video 上游仓库：<https://github.com/nexu-io/html-video>
- 技能中文 README：`<技能目录>/README.zh-CN.md`
- Playwright 国内安装：`<技能目录>/scripts/install-playwright-cn.md`
- MiniMax 开放平台：<https://platform.minimaxi.com/>
