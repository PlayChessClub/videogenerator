# ClipForge · AI 视频编辑助手

一款跨平台 AI 视频编辑辅助软件：

- **macOS**：采用 **Liquid Glass** SwiftUI 视觉语言，向后兼容 **macOS 11（Big Sur）及以上**，Apple Silicon（arm64）+ Intel（x86_64）通用二进制。在 macOS 26 上呈现真·液态玻璃材质，在低版本系统自动退化为 NSVisualEffectView 毛玻璃。
- **Windows 11**：采用 **WinUI 3 + .NET 8 + Mica** 系统原生材质（WinUI 3 中 Mica 之于 Windows 相当于 Liquid Glass 之于 macOS）。同时提供 x64 与 ARM64 自包含发布。

后端固定对接阿里云 DashScope 的两个模型，API Key 可在应用内随时更换。

> ⚠️ 模型固定、不可切换，以保证跨平台行为一致；唯一可配置项是 DashScope API Key。

## 功能

- **声音工作室**：CosyVoice 声音克隆（voice enrollment）+ 文本转语音。支持公网音频 URL 或本地音频上传，音色状态自动轮询，合成参数可调（音量 / 语速 / 音高）。
- **图片生成**：文生图（同步接口，无需轮询）。模型可选 `qwen-image-2.0`（默认）/ `qwen-image-2.0-pro` / `wan2.7-image` / `wan2.7-image-pro`，尺寸与张数可控，结果自动下载并收录素材库。
- **视频生成**：图生视频（首帧 + 可选配音），异步任务提交 + 自动轮询 + 结果下载。分辨率 / 时长 / 单多镜头 / prompt 扩写 / 音轨开关可控。
- **剪辑时间线**：把生成的视频按顺序拼接导出，支持「保留原声」或「整体替换配音」两种模式，纯 AVFoundation 实现，无外部依赖。
- **消费预估值**：在发起语音合成 / 声音克隆 / 图生视频前，会弹窗提示**预计消耗的 token 区间（±30%）** 与**预估金额**，确认后才真正调用模型，避免无意产生费用。
- **设置**：DashScope API Key 存于 macOS 钥匙串（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`，仅本机、解锁后可用），可随时更换。

## 关于阿里云 Token Plan（重要）

ClipForge 的图生图功能使用**普通百炼按量付费 API Key**（`sk-` 开头，端点 `dashscope.aliyuncs.com`），
**不使用** Token Plan 专属 Key（`sk-sp-` 开头）。

原因：阿里云官方规定 Token Plan 专属 Key 仅限在 Claude Code / Cursor / Qwen Code 等
AI 编程与智能体工具中**交互式**使用，禁止用于自定义应用程序后端或自动化脚本；
且图像/视频生成模型无法通过文本类 Base URL 直接调用，只能通过工具的 Skill /
Slash Command / Agent 扩展机制接入。

因此：
- ✅ ClipForge 内生成图片 → 消耗**普通百炼账户余额**（按量付费）
- ✅ 在 Claude Code / Cursor 里用 Token Plan 生图 → 消耗**套餐 Credits**（走 Skill 机制）
- ❌ 不要把 `sk-sp-` 开头的 Key 填进 ClipForge，否则可能违反订阅条款导致封禁

生图计费参考（华北2北京，按成功图片张数）：

| 模型 | 单价 |
|---|---|
| `qwen-image-2.0` | ¥0.20 / 张 |
| `wan2.7-image` | ¥0.20 / 张 |
| `qwen-image-2.0-pro` | ¥0.50 / 张 |
| `wan2.7-image-pro` | ¥0.50 / 张 |

## 固定模型

| 能力 | 模型标识 |
|---|---|
| 语音合成 | `cosyvoice-v3.5-plus` |
| 音色复刻 | `voice-enrollment`（target_model 指向 cosyvoice-v3.5-plus） |
| 图生视频 | `wan2.6-i2v` |

## 构建

前置：macOS 26 SDK + Swift 工具链（CommandLineTools 即可，无需完整 Xcode）。产物为 arm64 + x86_64 通用二进制，最低支持 macOS 11.0（Big Sur）；在 macOS 26+ 呈现真·Liquid Glass，低版本自动退化为 NSVisualEffectView 毛玻璃。

```bash
./build.sh
```

产物：
- `build/ClipForge.app`（ad-hoc 签名）
- `build/ClipForge-<版本>.dmg`（**Finder 窗口自带美化背景** —— 紫青玻璃渐变 + 弧形虚线箭头 + 提示卡片；图标按 128px 居中布局，隐藏工具栏/状态栏。Retina 屏自动使用 2x 背景图）

## 安装与首次运行

1. 双击 `ClipForge-1.3.0.dmg`，把 ClipForge 拖入「应用程序」。
2. 首次打开若被 Gatekeeper 拦截（ad-hoc 签名，未经苹果公证），右键 → 打开，或在「系统设置 → 隐私与安全性」点「仍要打开」。
3. 进入「设置」填入你的 DashScope API Key（阿里云百炼控制台创建，`sk-` 开头），保存后即可使用。

生成结果默认输出到 `~/Downloads/ClipForge/`。

## Windows 11 版本

源码在 `Windows/`，**根命名空间为 `ClipForgeAI.Win`**（避开 `ClipForgeAI.Windows` 与系统 `Windows.*` 命名空间冲突）。WinUI 3 + .NET 8 + Windows App SDK 1.6。

主要差异（与 macOS 客户端）：
- API Key 以**明文 YAML** 存在 `%APPDATA%\ClipForge\settings.yml`，本机任何进程可读，请勿提交到仓库
- 不集成实时 TTS WebSocket 合成（协议复杂、踩过坑），需时用 DashScope 控制台或 Python SDK
- 时间线只做预览，不做拼接导出（macOS 端的 ExportEngine 用 AVFoundation 拼接，Windows 这边未实现）
- 背景材质用 Mica（Win11 22H2+），自动回退 Acrylic
- 工程名 `ClipForgeAI.Win.csproj`，不用 sln 也可以

### 本地编译

```powershell
cd Windows
dotnet restore src\ClipForgeAI.Win.csproj
dotnet build   src\ClipForgeAI.Win.csproj -c Release -p:Platform=x64
dotnet run     --project src\ClipForgeAI.Win.csproj -c Debug -p:Platform=x64
```

或者用 Visual Studio 2022 17.10+ 打开 `Windows\ClipForgeAI.Win.sln`，F5。

### GitHub Actions 自动编译

根目录 `.github/workflows/windows-build.yml` 已经配好：
- 触发：`push` 到 `Windows/**` 任意文件，或推送 `v*` tag，或手动 `workflow_dispatch`
- matrix：**x64 + ARM64** 双架构并行
- 产物：自包含（不依赖用户机装 .NET），打包成 `ClipForge-windows-x64.zip` / `ClipForge-windows-ARM64.zip`
- tag 触发自动创建 GitHub Release 并上传双架构 zip

发布新版本只需：
```bash
git tag v2.0.0-windows
git push origin v2.0.0-windows
```

## 项目结构

```
ClipForge/
├── Sources/                      # macOS 端 Swift 源码
│   ├── ClipForgeApp.swift
│   ├── Compat.swift              # 兼容层
│   ├── GlassKit.swift            # Liquid Glass 组件
│   ├── Models.swift
│   ├── DashScopeClient.swift
│   ├── CosyVoiceTTS.swift
│   ├── ExportEngine.swift
│   ├── VoiceStudioView.swift
│   ├── ImageStudioView.swift    # 文生图（prompt/模型/尺寸/张数 + 额度确认）
│   ├── VideoStudioView.swift
│   ├── TimelineView.swift
│   ├── SettingsView.swift
│   ├── TokenEstimator.swift       # 费用/token 预估（语音按字符、视频按秒、生图按张、克隆按出账）
│   └── TokenConfirmOverlay.swift  # 生成前 token 消耗确认浮层（含 ±30% 区间）
├── Tools/
│   ├── MakeIcon.swift            # 应用图标生成器
│   └── MakeDMGBackground.swift   # DMG 安装窗口背景图
├── build.sh                      # macOS 一键编译 + 打包 dmg
├── Windows/                      # Windows 11 端 .NET 源码
│   ├── ClipForgeAI.Win.sln
│   ├── README.md
│   ├── docs/手动编译打包发布指南.md
│   └── src/
│       ├── ClipForgeAI.Win.csproj
│       ├── App.xaml(.cs)         # 应用入口
│       ├── MainWindow.xaml(.cs)  # Mica 主窗口
│       ├── Models/MediaModels.cs
│       ├── Services/             # DashScopeClient / CosyVoiceTtsService / VideoGenerationService / SettingsService
│       ├── Views/                # 4 个页面(Shell/Voice/Video/Timeline/Settings)
│       ├── Helpers/BindableBase.cs
│       └── Assets/{app.png,app.ico}
└── .github/workflows/
    └── windows-build.yml         # Windows 自动编译 + Release
```

## 技术要点

- **Liquid Glass**：SwiftUI `glassEffect(_:in:)` + `.buttonStyle(.glass/.glassProminent)`，配合 Aurora 渐变背景与半透明卡片。
- **TTS 协议**：DashScope 全双工 WebSocket（`run-task → continue-task → finish-task`，二进制帧累积为 mp3），与官方 Python SDK `SpeechSynthesizer` 行为一致，用 Swift `URLSessionWebSocketTask` 原生复刻。
- **OSS 临时上传**：本地图片/音频经 `getPolicy → 表单直传 OSS` 得到 `oss://` 资源，请求头带 `X-DashScope-OssResourceResolve: enable` 供服务端解析。

## 许可

使用阿帕奇许可证（相见许可文件）。API 调用产生的费用由你的 DashScope 账户承担。
