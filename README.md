# ClipForge · AI 视频编辑助手

AI 视频/图片/语音创作工具，后端固定对接**阿里云 DashScope** 多模态模型，API Key 可在应用内随时更换。

> ⚠️ 模型固定、不可切换，以保证跨平台行为一致；唯一可配置项是 DashScope API Key。
> 调用产生的费用由你的 DashScope 账户承担（见文末「费用」）。

## 平台现状

| 平台 | 形态 | 状态 |
|---|---|---|
| **macOS 11+** | 原生 SwiftUI（arm64 + x86_64 通用二进制），.pkg 安装 | 🟢 主力维护 |
| **Windows 11** | Go + HTML5 单文件 exe（内嵌 WebView2 窗口），zip 发布 | 🔵 已冻结，仅保可用 |
| **macOS / Linux**（web 版） | 同一 Go 二进制，启动后开浏览器 | 🔵 随 web 版保留 |

- **macOS 版**采用 Liquid Glass 视觉语言：在 macOS 26 上呈现真·液态玻璃材质（`glassEffect`），低版本自动退化为 NSVisualEffectView 毛玻璃。
- **Windows 版**为 `web/` 目录下的 Go 单文件方案（v2.0 起取代旧 WinUI 3 实现；`Windows/` 目录已归档，见 `Windows/ARCHIVED.md`）。

## 功能

- **声音工作室**：CosyVoice 声音克隆（voice enrollment）+ 文本转语音。支持公网音频 URL 或本地音频上传，音色状态自动轮询，合成参数可调（音量 / 语速 / 音高）。
- **图片生成**：文生图（同步接口，无需轮询）。模型可选 `qwen-image-2.0`（默认）/ `qwen-image-2.0-pro` / `wan2.7-image` / `wan2.7-image-pro`，尺寸与张数可控，结果自动下载并收录素材库。
- **视频生成**：支持文生视频（`wan2.6-t2v` / `wan2.7-t2v`，无需首帧图）与图生视频（`wan2.6-i2v` / `wan2.7-i2v` / `wan2.6-i2v-flash`，需首帧图），模型可切换，异步任务提交 + 自动轮询 + 结果下载。分辨率 / 时长 / 单多镜头 / prompt 扩写 / 音轨开关可控（flash 模型无声更省）。
- **剪辑时间线**（macOS 版）：把生成的视频按顺序拼接导出，支持「保留原声」或「整体替换配音」，纯 AVFoundation 实现。
- **消费预估值**：发起生成前弹窗提示**预计消耗 token 区间（±30%）** 与**预估金额**，确认后才调用模型。
- **生成账单**：每次确认生成自动记录一条明细（时间 / 操作 / 模型 / 内容摘要 / 计量单位与数量 / token 区间 / 预估金额 / 任务 ID / 状态），账本存于 `~/Library/Application Support/ClipForge/bill.jsonl`，「账单」页可查看今日/本月/累计汇总，并一键导出 CSV 核对实际扣费。
- **试试手气**：视频 / 图片生成页提供「🎲 试试手气」，一键随机填入精选 Prompt。

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

装好后进入「设置」填入 DashScope API Key（百炼控制台创建，`sk-` 开头；**macOS 版存于钥匙串**），即可使用。生成结果默认输出到 `~/Downloads/ClipForge/`。

### Windows

下载 `clipforge-windows-amd64.zip`（Intel/AMD）或 `clipforge-windows-arm64.zip`（ARM 设备），解压双击 exe——自动弹出内嵌 Chromium 应用窗口（关窗即退出），在「设置」填入 API Key 即可（**web 版以明文 yml 存于 `%APPDATA%\ClipForge\settings.yml`，注意保管，勿提交到仓库**）。

## 构建

### macOS 版（.pkg）

前置：macOS 26 SDK + Swift 工具链（CommandLineTools 即可，无需完整 Xcode）。

```bash
./build.sh
```

产物：`build/ClipForge-<版本>.pkg`（component + distribution 两步打包：app 本体 + 安装向导许可协议页；Apache-2.0 LICENSE 同时装入 `ClipForge.app/Contents/Resources/LICENSE`）。可选正式签名：`SIGN_APP` / `SIGN_PKG` 环境变量传 Developer ID 证书名。

### Web 版（含 Windows exe）

`web/server` 为 Go 单文件后端（前端 `static/` 已 go:embed 内嵌）。macOS 上可直接交叉编译 Windows：

```bash
cd web/server
GOOS=windows GOARCH=amd64 go build -ldflags="-s -w" -o clipforge-windows-amd64.exe .
GOOS=windows GOARCH=arm64 go build -ldflags="-s -w" -o clipforge-windows-arm64.exe .
```

另有 GitHub Actions（`.github/workflows/build-web.yml`）：push `v*` tag 且改动 `web/**` 时自动构建 Windows amd64/arm64、macOS arm64/amd64、Linux amd64 五平台 zip 并发布 Release。注意免费 runner 队列可能很慢，赶时间可本地交叉编译。

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
│   ├── PriceList.swift / PromptBank.swift
├── Tools/                        # MakeIcon.swift（图标生成）等辅助工具
├── build.sh                      # macOS 一键构建 .pkg
├── web/                          # Web 版（Go + HTML5）：server/{main.go, webview_win.go, webview_other.go, static/}
├── Windows/                      # ⚠️ 已归档的 WinUI 3 实现（不再构建，参考用）
├── .github/workflows/build-web.yml  # web 版五平台 CI + Release
└── LICENSE                       # Apache-2.0
```

## 技术要点

- **Liquid Glass**：SwiftUI `glassEffect(_:in:)` + `.buttonStyle(.glass/.glassProminent)`，配合 Aurora 渐变背景与半透明卡片。
- **TTS 协议**：DashScope 全双工 WebSocket（`run-task → continue-task → finish-task`，二进制帧累积为 mp3），与官方 Python SDK `SpeechSynthesizer` 行为一致，Swift `URLSessionWebSocketTask` 原生复刻。
- **OSS 临时上传**：本地图片/音频经 `getPolicy → 表单直传 OSS` 得到 `oss://` 资源，请求头带 `X-DashScope-OssResourceResolve: enable` 供服务端解析。
- **WebView2 内嵌**（Windows）：`jchv/go-webview2` 把 WebView2Loader 内嵌进 exe，仍是单文件；缺 Runtime 时自动退回系统浏览器。

## 许可

[Apache License 2.0](LICENSE)。API 调用产生的费用由你的 DashScope 账户承担。
