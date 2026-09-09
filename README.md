# ClipForge · AI 视频编辑助手

AI 视频/图片/语音创作工具，后端固定对接**阿里云 DashScope** 多模态模型，API Key 可在应用内随时更换。

> ⚠️ 模型固定、不可切换，以保证跨平台行为一致；唯一可配置项是 DashScope API Key。
> 调用产生的费用由你的 DashScope 账户承担（见文末「费用」）。

## 平台现状

| 平台 | 形态 | 状态 |
|---|---|---|
| **macOS 11+** | 原生 SwiftUI（arm64 + x86_64 通用二进制），.pkg 安装 | 🟢 主力维护 |
| **Windows 11** | Go + HTML5 单文件 exe（内嵌 WebView2 窗口），zip 发布 | 🟢 功能与 Mac 对齐 |
| **Linux** | Go + HTML5，deb/zip 发布（终端跑 CLI 菜单 / 桌面图标开浏览器） | 🟢 功能与 Mac 对齐（v3.2.x 命令行前端） |

- **macOS 版**采用 Liquid Glass 视觉语言：在 macOS 26 上呈现真·液态玻璃材质（`glassEffect`），低版本自动退化为 NSVisualEffectView 毛玻璃。
- **Windows / Linux 版**为 `web/` 目录下的 Go 单文件方案（v2.0 起取代旧 WinUI 3 实现；`Windows/` 目录已归档，见 `Windows/ARCHIVED.md`）。三端功能同步（声音克隆 / 语音合成 / 文生图 / 视频生成多模型 / 账本 / 价目表 / 费用确认）；仅「剪辑时间线」为 macOS 专属（依赖 AVFoundation 本地拼接引擎）。
- **Linux 前端路线**（v3.2.1 起）：终端（TTY）运行默认进入**命令行菜单**；桌面图标 / 无 TTY 时自动打开系统浏览器。曾尝试内嵌 webkit2gtk 原生窗口，因虚拟化环境渲染兼容差、维护成本高已移除，回归纯静态无 CGO 构建。

## 功能

- **声音工作室**：CosyVoice 声音克隆（voice enrollment）+ 文本转语音。支持公网音频 URL 或本地音频上传，音色状态自动轮询，合成参数可调（音量 / 语速 / 音高）。
- **音色素材**（macOS v1.7.3+）：应用内置若干公开许可的风格参考音频（中文/英文、男女声），可**试听**后一键作克隆参考；也可点「保存副本」把样音按自定义昵称复制到「音色素材文件夹」（默认 `~/Library/Application Support/ClipForge/VoiceSamples`，设置页可整体更改）。手动放进该文件夹的 wav/mp3/m4a 会作为自备素材列出，同样可试听/克隆/重命名——素材文件原样保留、可跨项目复用。
- **图片生成**：文生图（同步接口，无需轮询）。模型可选 `qwen-image-2.0`（默认）/ `qwen-image-2.0-pro` / `wan2.7-image` / `wan2.7-image-pro`，尺寸与张数可控，结果自动下载。
- **视频生成**：支持文生视频（`wan2.6-t2v` / `wan2.7-t2v`，无需首帧图）与图生视频（`wan2.6-i2v` / `wan2.7-i2v` / `wan2.6-i2v-flash`，需首帧图），模型可切换，异步任务提交 + 自动轮询 + 结果下载。分辨率 / 时长 / 单多镜头 / prompt 扩写 / 音轨开关可控（flash 模型无声更省）。
- **剪辑时间线**（macOS 版）：把生成的视频按顺序拼接导出，支持「保留原声」或「整体替换配音」，纯 AVFoundation 实现。
- **消费预估值**：发起生成前提示**预计消耗 token 区间（±30%）** 与**预估金额**，确认后才调用模型（CLI 中同样确认）。
- **生成账单**：每次确认生成自动记录一条明细（时间 / 操作 / 模型 / 内容摘要 / 计量单位与数量 / token 区间 / 预估金额 / 任务 ID / 状态），账本存于 `~/Library/Application Support/ClipForge/bill.jsonl`（macOS）/ 平台配置目录 `bill.jsonl`，可查看今日/本月/累计汇总，并一键导出 CSV 核对实际扣费。
- **试试手气 / 试试手气 Pro**：视频 / 图片 / 语音三页均有。「试试手气」从本地词库随机取一条（不联网、不计费）；「试试手气 Pro」（金色按钮，v1.7.2 起为两阶段）支持先填「目的 / 关键词」或选主题，阶段一用 `qwen3.7-text-embedding-flash` 把目的与候选词一起向量化、按余弦相似度挑出最贴合的 top3 参照句，阶段二交给 `qwen-plus` 按媒介定制指令扩写成 **~500 字全新提示词**（不复读原句，可直接作文生图 / 文生视频 / TTS 输入）——与其他生成一样：先弹两阶段合并的预计消耗确认，再调用并按实际 token 计入账单；任一步失败自动降级为免费随机且不记账。

## 关于阿里云 Token Plan（重要）

ClipForge 的生成功能使用**普通百炼按量付费 API Key**（`sk-` 开头，端点 `dashscope.aliyuncs.com`），**不使用** Token Plan 专属 Key（`sk-sp-` 开头）。

原因：阿里云官方规定 Token Plan 专属 Key 仅限在 Claude Code / Cursor / Qwen Code 等 AI 编程与智能体工具中**交互式**使用，禁止用于自定义应用程序后端或自动化脚本；且图像/视频生成模型无法通过文本类 Base URL 直接调用。

因此：

- ✅ ClipForge 内生成 → 消耗**普通百炼账户余额**（按量付费）
- ✅ 在 Claude Code / Cursor 里用 Token Plan 生图 → 消耗**套餐 Credits**（走 Skill 机制）
- ❌ 不要把 `sk-sp-` 开头的 Key 填进 ClipForge，否则可能违反订阅条款导致封禁

## 固定模型

| 能力 | 模型标识 |
|---|---|
| 语音合成 | `cosyvoice-v3.5-plus` |
| 音色复刻 | `voice-enrollment`（target_model 指向 cosyvoice-v3.5-plus） |
| 文生视频 | `wan2.6-t2v` / `wan2.7-t2v` |
| 图生视频 | `wan2.6-i2v`（默认）/ `wan2.7-i2v` / `wan2.6-i2v-flash` |
| 文生图 | `qwen-image-2.0`（默认）/ `qwen-image-2.0-pro` / `wan2.7-image` / `wan2.7-image-pro` |
| 文本向量 | `qwen3.7-text-embedding-flash`（「试试手气 Pro」阶段一选句，¥0.000125/千 token） |
| 文本生成 | `qwen-plus`（「试试手气 Pro」阶段二扩写，输入 ¥0.00096 · 输出 ¥0.0024 / 千 token） |

生图计费参考（华北2北京，按成功图片张数）：

| 模型 | 单价 |
|---|---|
| `qwen-image-2.0` | ¥0.20 / 张 |
| `wan2.7-image` | ¥0.20 / 张 |
| `qwen-image-2.0-pro` | ¥0.50 / 张 |
| `wan2.7-image-pro` | ¥0.50 / 张 |

## 下载与安装

所有版本安装包在 GitHub **Releases** 页：https://github.com/PlayChessClub/videogenerator/releases

### macOS

下载 `ClipForge-<版本>.pkg`，双击按向导安装（安装器会先展示 Apache-2.0 许可协议，点同意后输入管理员密码，装到 `/Applications`）。

> pkg 为 ad-hoc 未签名（个人账号无法创建 Developer ID 证书）。首次打开若被 Gatekeeper 拦截：右键 → 打开，或在「系统设置 → 隐私与安全性」点「仍要打开」。

装好后进入「设置」填入 DashScope API Key（百炼控制台创建，`sk-` 开头；**macOS 版存于钥匙串**），即可使用。

**产物保存位置**（设置页「下载位置」可整体更改一次，视频 / 图片 / 语音自动在同一根下分目录，不能按类型分开改）：默认分别落到系统标准目录——视频 `~/Movies/ClipForge`、图片 `~/Pictures/ClipForge`、语音 `~/Music/ClipForge`；点「更改…」选一个根文件夹后，三类产物改为存到 `<该文件夹>/ClipForge/视频、图片、语音`，可随时「恢复默认」。设置页每行右侧的按钮可在访达中打开对应目录。

### Windows

下载 `clipforge-windows-amd64.zip`（Intel/AMD）或 `clipforge-windows-arm64.zip`（ARM 设备），解压双击 exe——自动弹出内嵌 Chromium 应用窗口（关窗即退出），在「设置」填入 API Key 即可（**web 版以明文 yml 存于 `%APPDATA%\ClipForge\settings.yml`，注意保管，勿提交到仓库**）。

### Linux

推荐 deb 安装（零 GUI 依赖，仅 `xdg-utils`）：

```bash
sudo apt install ./clipforge_3.2.2_amd64.deb    # x64；ARM 设备用 _arm64.deb
clipforge                                          # 终端里跑 → 命令行菜单
clipforge --web                                    # 强制浏览器界面(桌面图标默认此模式)
```

**命令行前端**（终端里 `clipforge` 即进入，`clipforge -h` 看帮助）：

```
1. 视频生成    2. 文生图
3. 语音合成    4. 声音克隆
5. 我的音色    6. 账本
7. API Key     8. 打开 Web 界面
0. 退出
```

- 视频 5 模型 / 图片 4 模型，带费用估算与确认、自动轮询
- 生成的视频/图片/语音/账本 CSV **自动保存到系统下载文件夹**（Linux 优先 `xdg-user-dir`，回退 `~/Downloads`，启动横幅会打印实际目录）
- 语音合成走 WebSocket 实时协议；`API Key` 菜单输入时**终端不回显**
- 双开 / 残留进程会自动挂靠已有实例，不报错

免安装 zip：解压 `./clipforge-linux-amd64` 直接跑。无显示环境（纯服务器）用 `--web` 会回退打开浏览器或 `curl 127.0.0.1:8731` 使用 API。API Key 明文存于 `~/.config/ClipForge/settings.yml`。

## 构建

### macOS 版（.pkg）

前置：macOS 26 SDK + Swift 工具链（CommandLineTools 即可，无需完整 Xcode）。

```bash
./build.sh
```

产物：`build/ClipForge-<版本>.pkg`（component + distribution 两步打包：app 本体 + 安装向导许可协议页；Apache-2.0 LICENSE 同时装入 `ClipForge.app/Contents/Resources/LICENSE`）。可选正式签名：`SIGN_APP` / `SIGN_PKG` 环境变量传 Developer ID 证书名。

### Web 版（Windows exe / Linux deb）

`web/server` 为 Go 单文件后端（前端 `static/` 已 go:embed 内嵌；依赖已 vendor 进仓库，离线可编；纯标准库 + gorilla/websocket，**无 CGO**）。一键构建：

```bash
python3 web/build-pkgs.py                                  # 本地交叉编译 Windows 双架构 zip
```

Linux zip + deb 由 CI（`.github/workflows/build-web.yml`，`ubuntu-24.04` + `ubuntu-24.04-arm` 双原生 runner）在 push `v*` tag 时自动产出并待发布。产物命名与 Release 对齐（`clipforge_3.2.2_amd64.deb` 等，deb 由脚本内 `VERSION` 控制，可用 `CF_VERSION` 环境变量覆盖）。

## 项目结构

```
ClipForge/
├── Sources/                      # macOS 端 Swift 源码
│   ├── ClipForgeApp.swift        # 入口 / 中文菜单栏 / 顶部 TabBar / 根视图
│   ├── Compat.swift              # macOS 版本兼容层
│   ├── GlassKit.swift            # Liquid Glass 组件与调色板
│   ├── Models.swift
│   ├── DashScopeClient.swift     # 阿里云 DashScope REST 客户端
│   ├── CosyVoiceTTS.swift        # WebSocket 流式 TTS
│   ├── ExportEngine.swift        # AVFoundation 时间线拼接导出
│   ├── VoiceStudioView.swift / ImageStudioView.swift / VideoStudioView.swift / TimelineView.swift / SettingsView.swift
│   ├── TokenEstimator.swift      # 费用/token 预估
│   ├── TokenConfirmOverlay.swift # 生成前消耗确认浮层（±30% 区间）
│   ├── PriceList.swift / PromptBank.swift / VoiceKit.swift
├── Tools/                        # MakeIcon.swift（图标生成）等辅助工具
├── build.sh                      # macOS 一键构建 .pkg
├── VoiceSamples/                 # 内置音色素材（随 pkg 装入 Resources/VoiceSamples/，含 SOURCES.md 来源登记）
├── web/                          # Web 版（Go + HTML5）
│   ├── build-pkgs.py             # 一键构建脚本（本地 Windows 交叉编译）
│   ├── assets/icon-512.png       # deb 图标（入库,CI 可用）
│   └── server/
│       ├── main.go               # 本地服务 + REST/WS 代理 + 启动分流(CLI/Web)
│       ├── cli.go                # 命令行前端(全平台,--cli 进入)
│       ├── cli_term_linux.go     # Linux 终端关回显读 API Key(termios)
│       ├── webview_win.go        # Windows 内嵌 WebView2 窗口
│       ├── webview_linux_nocgo.go / webview_other.go  # 其他平台开浏览器
│       ├── static/               # 前端(index.html/app.js/style.css, 已内嵌)
│       └── vendor/               # 依赖已 vendor(离线可编,勿删)
├── Windows/                      # ⚠️ 已归档的 WinUI 3 实现（不再构建，参考用）
├── .github/workflows/build-web.yml  # Linux zip/deb CI（ubuntu-24.04 双原生 runner）
└── LICENSE                       # Apache-2.0
```

## 技术要点

- **Liquid Glass**：SwiftUI `glassEffect(_:in:)` + `.buttonStyle(.glass/.glassProminent)`，配合 Aurora 渐变背景与半透明卡片。
- **TTS 协议**：DashScope 全双工 WebSocket（`run-task → continue-task → finish-task`，二进制帧累积为 mp3），与官方 Python SDK `SpeechSynthesizer` 行为一致；Mac 版 `URLSessionWebSocketTask` 原生复刻，web 版经 `/api/tts/ws`（gorilla/websocket）服务端代理，CLI 用 gorilla 客户端直连同一代理。
- **OSS 临时上传**：本地图片/音频经 `getPolicy → 表单直传 OSS` 得到 `oss://` 资源，请求头带 `X-DashScope-OssResourceResolve: enable` 供服务端解析。
- **WebView2 内嵌**（Windows）：`jchv/go-webview2` 把 WebView2Loader 内嵌进 exe，仍是单文件；缺 Runtime 时自动退回系统浏览器。
- **启动分流**（web 版）：Linux/终端有 TTY 默认进 CLI 菜单；无 TTY（桌面图标）或 `--web` 起服务 + 开浏览器；`--cli` 强制命令行（darwin 调试亦可用）。端口被占且检测到本应用在跑时自动挂靠已有实例。
- **单实例记账**：所有生成（GUI/CLI）走同一 `bill.jsonl`，字段同口径，Web 端与 CLI 看到的账本一致。

## 许可

[Apache License 2.0](LICENSE)。API 调用产生的费用由你的 DashScope 账户承担。
