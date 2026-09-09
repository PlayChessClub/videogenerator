# ClipForge · AI 视频编辑助手

面向个人创作的多模态生成工具：文生图、文生视频、图生视频、声音克隆 + 语音合成、试试手气 Pro 提示词，后端固定对接**阿里云 DashScope**，API Key 在应用内随时更换。

> - 生成费用由你的 DashScope 账户承担，发起前会弹预计消耗确认（见文末「费用」）。
> - **macOS 版**为主力发布线（当前 v1.7.3）；Windows / Linux 为 Web 版（当前 v3.2.2），覆盖核心生成功能。

## 一、平台现状

| 平台 | 形态 | 功能覆盖 |
|---|---|---|
| **macOS 11+** | 原生 SwiftUI，arm64+x86_64 通用二进制，.pkg 安装 | 🟢 全功能：核心生成 + 时间线拼接 + 内置音色素材 + 试试手气 Pro（主力） |
| **Windows 11** | Go + HTML5 单文件 exe（内嵌 WebView2），zip | 🟡 核心生成（文生图 / 多模型视频 / 声音克隆 / 语音合成 / 账本 / 价目 / 消耗确认 / 基础本地随机 prompt） |
| **Linux** | Go + HTML5，deb/zip（CLI 菜单或桌面开浏览器） | 🟡 与 Windows 相同核心范围 |

> 说明：**Web/Go 版不再把 macOS 列为支持平台**——macOS 请用上方原生 SwiftUI 版；darwin 上运行 `web/`（`--cli/--web`）仅为本地开发调试，非正式发布通道。

平台上文中**「macOS 专属」**的差异能力（不随 Web 版发布，见「功能」）：
- `试试手气 Pro`（embedding 选句 + qwen-plus 扩写两阶段，Web 仅有免费本地随机）
- 内置音色素材（VoiceKit）与音色素材文件夹
- 时间线素材库 / AVFoundation 本地拼接导出

---

## 二、功能

### 声音
- **声音克隆（voice enrollment）**：贴公网 URL 或用本地音频上传克隆个性音色，`target_model=cosyvoice-v3.5-plus`，任务自动轮询状态。
- **语音合成**：文本 → mp3，可调音量 / 语速 / 音高。
- **音色素材**（macOS v1.7.3+，见 `Sources/VoiceKit.swift`）：
  - 内置示例：两款随包带的中文播音样音（沉稳播音男 Reed / 标准播音女 Sandy，源自 macOS 系统 TTS 本机合成，无第三方版权，随 pkg 装在 `VoiceSamples/`）。
  - 每枚可**试听**、可一键“用作克隆参考”（走本地上传→OSS→clone）；可「保存副本」把样音按昵称复制到素材夹，甚至重命名。
  - **素材文件夹**默认 `~/Library/Application Support/ClipForge/VoiceSamples`，可在设置页「音色素材文件夹」整体更改。用户手动放入的 wav / mp3 / m4a / aac / caf 会自动作为「用户素材」列出（可试听 / 克隆 / 重命名），文件原样保留、跨项目可复用。
  - Bundle 永不写盘；写副本一律进素材夹，文件名自动净化、重名自动追加 `-1`。

#### 关于“音色文件在哪、为什么本地找不到”——三种音频要分清

声音流程里其实有三种对象，**只有第一种和第三种会落到本地，中间的“克隆音色”不在本地**：

| 对象 | 存放位置 | 说明 |
|---|---|---|
| ① 音色**参考素材**（克隆输入） | **本地**：包内 `VoiceSamples/`（只读）；或「音色素材文件夹」`~/Library/Application Support/ClipForge/VoiceSamples`（可写，可放自备文件） | 用来试听 / 上传做克隆的**样本人声**，不是成品的音色本体。 |
| ② 已克隆出的**个性化音色（voice）** | **阿里云（你的 DashScope 账户）** | 你在“音色复刻”里创建的 voice 是**云端登记实体**，App 只保存其 `voice_id` 字符串（如 `myvoice_…`）。语音页「音色下拉 / 刷新列表」（listVoices）就是在读你云账户上的 voice，**不在本地生成任何可用文件**。 |
| ③ 合成出的 **mp3 成品** | 本地（生成“产物保存”的语音目录 `…/ClipForge/语音/*.mp3`） | 选中某个 voice_id 朗读文本后，云端返回音频并落盘成 mp3。这才是你能在 Finder 找到的结果音频。 |

- 克隆链路：本地素材 → 上传临时 OSS → `createVoice`（云端登记 voice）→ 得到 `voice_id` → 之后每次 `synthesize(text, voiceId:)` 用该云端 voice 合成 mp3；
- 「删除音色」删除的是云端 voice 记录，不会删除你的本地素材；
- “为什么本地只有克隆用的素材而没有音色本体”——因为你克隆生成的 voice **存在服务器上（以 voice_id 引用）**，本地本来就不该有它的模型文件；本地你能看到的音频就是素材（①）和合成成品（③）。


### 图像 / 视频
- **文生图**：同步接口，模型可选 `qwen-image-2.0`（默认）/ `-pro` / `wan2.7-image` / `-pro`，尺寸 / 张数可调。
- **文生视频**：`wan2.6-t2v` / `wan2.7-t2v`，仅凭 prompt。
- **图生视频**：`wan2.6-i2v` / `wan2.7-i2v` / `wan2.6-i2v-flash`（flash 无声更省），异步提交 + 自动轮询。
- 分辨率 / 时长 / 单多镜头 / prompt 扩写 / 音轨开关均可控。

### 剪辑（macOS 专属）
- **时间线**：把多段生成视频顺序拼接导出，支持整体保留原声或替换配音（AVFoundation 本地实现，窗口 / 浏览器做不了，故只随 mac）。

### Prompt 助手 & 计费
- **试试手气**（免费、不联网）：从本地整句词库随机取一条填进 prompt。
- **试试手气 Pro**（macOS，金色按钮，`Sources/PromptBank.swift` / `LuckyPromptButtons.swift`）：填「目的 / 关键词」或从该媒介主题里选一个种子后触发两阶段：
  1. `qwen3.7-text-embedding-flash` 把目的 + 候选句一起向量化，按余弦相似度取 **top3 参照句**；
  2. `qwen-plus` 按媒介定制指令，把参照句扩写成 **约 500 字的全新提示词**（禁止复读原文），可直接作文生图 / 文生视频 / TTS 输入。
  - 与其他生成一致：先弹「两阶段合并」预计消耗，确认后执行，按**实际 token** 计入账单；任一阶段失败自动降级成免费本地随机且不记账。
- **消耗确认**：发起生成前 ×30% 区间与含金额预估，确认后才调用。
- **生成账单**：每次确认生成记录一条明细，落 `bill.jsonl`（macOS：`~/Library/Application Support/ClipForge/bill.jsonl`），可查看今日 / 本月 / 累计并可导出 CSV 核对官方账单。

---

## 三、关于阿里云 Token Plan

ClipForge 只用**普通百炼按量付费 Key**（`sk-` 开头，dashscope.aliyuncs.com），**不用** `sk-sp-`（Token Plan 专属 Key）：

- Token Plan 专属 Key 仅限 Claude Code / Cursor / Qwen Code 等**交互式**使用，禁止私自后端/自动化调用，且图像/视频无法经文本类 Base URL 走通。
- 所以：ClipForge 内生成 → 计**百炼余额**；把 `sk-sp-` 填入会违反条款并可能封禁 —— ❌ 请勿使用。

---

## 四、固定模型与价目（仅供参考，以官方账单为准）

### 模型清单

| 能力 | 模型标识 |
|---|---|
| 语音合成 | `cosyvoice-v3.5-plus` |
| 声线克隆 | `voice-enrollment`（→ cosyvoice） |
| 文生视频 | `wan2.6-t2v` / `wan2.7-t2v` |
| 图生视频 | `wan2.6-i2v` · `wan2.7-i2v` · `wan2.6-i2v-flash` |
| 文本生成（Pro 扩写） | `qwen-plus`（输入 ¥0.00096/千 · 输出 ¥0.0024/千） |
| 文本向量（Pro 选句） | `qwen3.7-text-embedding-flash`（¥0.000125/千 token） |

### 生图 / 视频参考价

| 操作 | 参考单价 |
|---|---|
| 文生图 `qwen-image-2.0` / `wan2.7-image` | ¥0.20 / 张 |
| 文生图 `qwen-image-2.0-pro` / `wan2.7-image-pro` | ¥0.50 / 张 |
| 视频 `wan2.6-t2v/i2v`·`wan2.7-t2v/i2v` | 720P ¥0.6/s · 1080P ¥1.0/s |
| 视频 `wan2.6-i2v-flash` | 有声 720P ¥0.3/s · 1080P ¥0.5/s；无声减半 |
| 语音合成 `cosyvoice-v3.5-plus` | ¥1.5 / 万字符 |

> 华北2（北京）按量付费口径（应用设置页内嵌价目同一份）。Token 区间为换算展示，非精确计量。

---

## 五、安装与使用

- **macOS**：Releases 下载 `ClipForge-<ver>.pkg` 安装（向导含 Apache-2.0 许可协议）。pkg 为 ad-hoc 未签名，首次打开如被 Gatekeeper 拦，右键 → 打开或「隐私与安全性 → 仍要打开」。装后「设置」填 DashScope `sk-`。
- **Windows**：解压 `clipforge-windows-{amd64,arm64}.zip` 双击 exe（内嵌 WebView2，缺运行时自动退回系统浏览器），在设置填 Key。web Key 密文明文存 `settings.yml`，注意保管、勿提交。
- **Linux**：`sudo apt install ./clipforge_*.deb` → `clipforge`（终端菜单）或 `clipforge --web`；或解压 zip 直接跑。API Key 存 `~/.config/ClipForge/settings.yml`。
- 全部安装包见 **Releases**：https://github.com/PlayChessClub/videogenerator/releases

### 产物保存（macOS「下载位置」）
设置页「下载位置」为**单一根目录**：视频 / 图片 / 语音会自动在同一根下的 `ClipForge/视频、图片、语音` 子目录分存，**不可按类型分开更改**（更改 / 恢复默认会三类同时切换）：
- 默认：系统标准目录 `~/Movies/ClipForge`、`~/Pictures/ClipForge`、`~/Music/ClipForge`；
- 自定义：「更改…」选定一个文件夹后即为 `<该文件夹>/ClipForge/<类型>`。设置页每行“>”按钮可在访达中打开对应目录。

---

## 六、构建（不想改代码就不用看）

仓库由两条独立发布线组成：

### macOS ✅
```bash
./build.sh          # 产 build/ClipForge-<版本>.pkg
```
- `Sources/*.swift` 用户代码；`build.sh` 顶 `VERSION=` 控制版本；
- `VoiceSamples/` 连同 `SOURCES.md` 会拷进 `App/Contents/Resources/VoiceSamples/`；
- 通用二进制 arm64+x86_64（swiftc，仅需 CommandLineTools + macOS SDK）；
- 可 `SIGN_APP` / `SIGN_PKG` 环境变量做正式签名，否则 ad-hoc。

### Web（Windows / Linux）
`web/server` 是 Go 单文件后端（`static/` 已 go:embed、第三方依赖已 vendor、无 CGO）。
```bash
python3 web/build-pkgs.py        # 本地产 Windows 双架构 zip；也跑静态 Linux 回退 ver
```
Linux deb/zip 由 CI（`.github/workflows/build-web.yml`，双原生 runner）在 push `v*` tag 时产出。

---

## 七、项目结构（macOS 主源码 + 两线）

```
./                       # git 仓库根（remote = github.com/PlayChessClub/videogenerator）
├── README.md            # 本文档
├── LICENSE              # Apache-2.0
├── build.sh             # 仅 macOS
├── Tools/               # MakeIcon 等构建辅助
├── VoiceSamples/        # 内置中文样音（wav）+ SOURCES.md；随 pkg 装入 Resources/VoiceSamples/
├── Sources/             # macOS Swift 源码
│   ├── ClipForgeApp.swift        # 应用入口 / 顶栏路由
│   ├── Compat.swift / GlassKit.swift / Models.swift      # 兼容层 / Liquid Glass 组件 / 常亮模型表
│   ├── DashScopeClient.swift     # REST + OSS 上传 + embedding / qwen-plus 文本生成
│   ├── CosyVoiceTTS.swift        # WS 流式 TTS
│   ├── VideoStudioView / ImageStudioView / VoiceStudioView / TimelineView / SettingsView / BillView
│   ├── VoiceKit.swift            # 内置音色素材 + 素材夹（v1.7.3）
│   ├── TokenEstimator.swift / TokenConfirmOverlay.swift  # 费用估算与确认浮层
│   ├── PriceList.swift           # 设置页价目
│   ├── PromptBank.swift          # 随机 / Pro 词库（试查手气）
│   ├── LuckyPromptButtons.swift  # 金色 Pro 按钮（两阶段）
│   ├── DownloadLocation.swift    # 单一根目录的产物保存
│   ├── BillStore.swift / ExportEngine.swift
├── web/                 # Web 版（Windows + Linux）
│   ├── build-pkgs.py
│   ├── server/          # Go main.go + cli.go + static/（index/app/style）+ vendor/
│   └── assets/icon-512.png
├── Windows/             # ⚠️ 已归档 WinUI 3 实现（不构建，参考用）
└── .github/workflows/build-web.yml
```

---

## 八、技术要点

- **Liquid Glass**：macOS 26 `glassEffect`；低版本自动退化 NSVisualEffectView 毛玻璃。
- **TTS**：DashScope 全双工 WebSocket 流式（mac 原生复刻；web 经 /api/tts/ws gorilla 代理）。
- **OSS 临时上传**：本地媒体 getPolicy→表单直传得到 `oss://`，随请求带 enable 解析头。
- **单实例记账**：GUI / CLI 同 `bill.jsonl` 同字段。
- **命名净化**（VoiceKit）：保存 / 重命名文件名清理 `/ :` 与控制字符、重名去重。

## 九、许可

[Apache License 2.0](LICENSE)。API 相关费用由你的 DashScope 账户承担。
