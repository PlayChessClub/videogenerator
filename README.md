# ClipForge · AI 视频编辑助手

一款 macOS AI 视频编辑辅助软件，采用 **Liquid Glass（液态玻璃）** SwiftUI 视觉语言，向后兼容 **macOS 11（Big Sur）及以上**，同时提供 Apple Silicon（arm64）与 Intel（x86_64）通用二进制。在 macOS 26 上呈现真·液态玻璃材质，在低版本系统自动退化为 NSVisualEffectView 毛玻璃。后端固定对接阿里云 DashScope 的两个模型，API Key 可在应用内随时更换。

> ⚠️ 模型固定、不可切换，以保证兼容性；唯一可配置项是 DashScope API Key。

## 功能

- **声音工作室**：CosyVoice 声音克隆（voice enrollment）+ 文本转语音。支持公网音频 URL 或本地音频上传，音色状态自动轮询，合成参数可调（音量 / 语速 / 音高）。
- **视频生成**：图生视频（首帧 + 可选配音），异步任务提交 + 自动轮询 + 结果下载。分辨率 / 时长 / 单多镜头 / prompt 扩写 / 音轨开关可控。
- **剪辑时间线**：把生成的视频按顺序拼接导出，支持「保留原声」或「整体替换配音」两种模式，纯 AVFoundation 实现，无外部依赖。
- **设置**：DashScope API Key 存于 macOS 钥匙串（`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`，仅本机、解锁后可用），可随时更换。

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
- `build/ClipForge-<版本>.dmg`（含 Applications 快捷方式，可直接拖拽安装）

## 安装与首次运行

1. 双击 `ClipForge-1.1.0.dmg`，把 ClipForge 拖入「应用程序」。
2. 首次打开若被 Gatekeeper 拦截（ad-hoc 签名，未经苹果公证），右键 → 打开，或在「系统设置 → 隐私与安全性」点「仍要打开」。
3. 进入「设置」填入你的 DashScope API Key（阿里云百炼控制台创建，`sk-` 开头），保存后即可使用。

生成结果默认输出到 `~/Downloads/ClipForge/`。

## 项目结构

```
ClipForge/
├── Sources/
│   ├── ClipForgeApp.swift      # App 入口、TabView、通用组件（Player / FilePicker）
│   ├── Compat.swift            # 兼容层：glassEffect/NSVisualEffectView 双路径、网络/AVFoundation 版本抹平
│   ├── GlassKit.swift          # Liquid Glass 视图组件（GlassCard / AuroraBackground …）
│   ├── Models.swift            # 固定模型常量、AppSettings(钥匙串)、素材库
│   ├── DashScopeClient.swift   # REST：OSS 上传 / 音色 / 视频任务 / 下载
│   ├── CosyVoiceTTS.swift      # 全双工 WebSocket 语音合成
│   ├── ExportEngine.swift      # AVFoundation 时间线拼接 / 配音导出
│   ├── VoiceStudioView.swift   # 声音工作室页
│   ├── VideoStudioView.swift   # 视频生成页
│   ├── TimelineView.swift      # 剪辑时间线页
│   └── SettingsView.swift      # 设置页
├── Tools/MakeIcon.swift        # 应用图标生成器
└── build.sh                    # 一键编译 + 打包 dmg
```

## 技术要点

- **Liquid Glass**：SwiftUI `glassEffect(_:in:)` + `.buttonStyle(.glass/.glassProminent)`，配合 Aurora 渐变背景与半透明卡片。
- **TTS 协议**：DashScope 全双工 WebSocket（`run-task → continue-task → finish-task`，二进制帧累积为 mp3），与官方 Python SDK `SpeechSynthesizer` 行为一致，用 Swift `URLSessionWebSocketTask` 原生复刻。
- **OSS 临时上传**：本地图片/音频经 `getPolicy → 表单直传 OSS` 得到 `oss://` 资源，请求头带 `X-DashScope-OssResourceResolve: enable` 供服务端解析。

## 许可

仅供学习与个人使用。API 调用产生的费用由你的 DashScope 账户承担。
