# ClipForge AI · Windows 11 版本

> AI 视频编辑辅助软件。**WinUI 3 + .NET 8 + Mica 系统材质**(对应 macOS 的 Liquid Glass 角色)。

## 这是什么

完整可用的 Windows 11 桌面应用源码,行为与 macOS 客户端(v1.1.1)完全一致:

| 能力 | 模型 | API |
|---|---|---|
| 声音克隆 | `cosyvoice-v3.5-plus` | DashScope REST `create_voice` + 轮询 |
| 语音合成 | `cosyvoice-v3.5-plus` | DashScope WebSocket `run-task / continue-task / finish-task` |
| 图生视频 | `wan2.6-i2v` | DashScope REST 异步任务 + 轮询 + 下载 |

API Key 通过 Windows **DPAPI**(Data Protection API)以当前用户身份加密,落在
`%APPDATA%\ClipForge\settings.dat`,其他用户无法解密,等价于 macOS Keychain 的行为。

UI 用 WinUI 3 控件,主窗口背景是 **Mica**(Win11 22H2+ 原生材质),Win10 自动回退到 Acrylic。
整体观感与 macOS 端的 Liquid Glass 接近 — 半透明、跟随桌面壁纸、不会遮挡内容。

## 目录结构

```
Windows/
├── ClipForgeAI.Win.sln                   # Visual Studio 解决方案
├── .gitignore
├── README.md                              # 本文件
├── docs/
│   └── 手动编译打包发布指南.md             # ⭐ 给你的手把手教程
└── src/
    ├── ClipForgeAI.Win.csproj             # 工程文件
    ├── app.manifest                       # DPI/兼容性清单
    ├── App.xaml(.cs)                      # 应用入口
    ├── MainWindow.xaml(.cs)               # 主窗口(Mica + 自定义标题栏)
    ├── Assets/
    │   ├── app.png                        # 应用图标(占位,可替换)
    │   └── app.ico                        # 多尺寸图标
    ├── Models/
    │   └── MediaModels.cs                 # 数据模型 + FixedModel
    ├── Services/
    │   ├── DashScopeClient.cs             # REST 客户端(克隆/OSS/视频)
    │   ├── CosyVoiceTtsService.cs         # WebSocket TTS
    │   ├── VideoGenerationService.cs      # 视频任务高层封装
    │   └── SettingsService.cs             # DPAPI 加密的 Key 存储
    ├── Helpers/
    │   └── BindableBase.cs                # 极简 INotifyPropertyChanged
    └── Views/
        ├── ShellPage.xaml(.cs)            # 导航外壳
        ├── VoiceStudioPage.xaml(.cs)      # 声音工坊
        ├── VideoStudioPage.xaml(.cs)      # 视频工坊
        ├── TimelinePage.xaml(.cs)         # 时间线 + 预览
        └── SettingsPage.xaml(.cs)         # 设置
```

## 关键技术决策

### 根命名空间 = `ClipForgeAI.Win`
**不是** `ClipForgeAI.Windows`。原因:WinUI 3 工程的根命名空间如果是 `*.Windows`,
编译器会优先把 `using Windows.Graphics;` 解析成 `ClipForgeAI.Windows.Graphics`
(子命名空间),导致 `SizeInt32`、`MediaSource` 等系统类型无法解析。改用 `.Win` 后
再无歧义。

### 凭据存储 = DPAPI,不是 PasswordVault
`Windows.Security.Credentials.PasswordVault` 在 **unpackaged** WinAppSDK 应用
(`WindowsPackageType=None`)中行为不稳定。改用 .NET 内置的
`System.Security.Cryptography.ProtectedData.Protect()`:
- 用当前用户的 Windows 凭据做加密,等同 Keychain 保护级别
- 文件落在 `%APPDATA%\ClipForge\settings.dat`
- 不需要特殊权限,不依赖 WinAppSDK runtime 行为

### 背景材质 = Mica
直接设置 `this.SystemBackdrop = new MicaBackdrop { Kind = MicaKind.BaseAlt };`。
Win11 22H2+ 自动用 Mica;Win10/早期 Win11 自动用 Acrylic 兜底;再老的系统用纯色。
代码里没有任何 `MicaController` 反射调用,不会因系统 API 变化崩。

## 一键运行

需要本机有 **.NET 8 SDK** + **Windows 10 1809+**(强烈建议 Win11 22H2+ 看 Mica):

```cmd
cd Windows
dotnet restore src\ClipForgeAI.Win.csproj
dotnet build   src\ClipForgeAI.Win.csproj -c Release -p:Platform=x64
dotnet run     --project src\ClipForgeAI.Win.csproj -c Debug -p:Platform=x64
```

也可以直接用 Visual Studio 2022(17.10+)打开 `ClipForgeAI.Win.sln`,F5 即可。

## 发布 Release

详见 `docs/手动编译打包发布指南.md`。
