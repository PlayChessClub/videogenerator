# ClipForge 维护文档（MAINTENANCE）

面向维护者的构建 / 签名 / 发布 / 隐私操作手册。功能与设计见 [README.md](README.md)。

---

## 1. 三版本仓库地图

| 版本 | 本地路径 | Remote | 默认分支 / HEAD | 技术栈 | 发布物 |
|---|---|---|---|---|---|
| **macOS（主）** | `~/WorkBuddy/2026-09-07-06-52-26/ClipForgeAI` | `PlayChessClub/videogenerator` | main `93e0347` | SwiftUI + swiftc | `.pkg`（Releases） |
| **Web / Windows / Linux** | `~/WorkBuddy/2026-09-07-06-52-26/clipforge-web` | `PlayChessClub/clipforge-web` | main `0cb53ab` | Go + HTML5 | exe / deb / zip（该仓库 Releases） |
| **iOS / iPadOS** | `~/Documents/clipforgeios` | `PlayChessClub/ClipForge-ios` | main `3f51f22` | SwiftUI + Xcode 26 | 仅源码，不发布预编译 IPA |

> 注：`ClipForgeAI/ios/` 为早期 swiftc 版 iOS 尝试（commit `93e0347` 引入），与独立 `clipforgeios` 仓库并存；以 `clipforgeios` 为准，`ClipForgeAI/ios/` 视为历史遗留、不再维护。

---

## 2. macOS 构建 / 签名 / 发布

### 构建
```bash
./build.sh        # 产出 build/ClipForge-<VERSION>.pkg
```
- 版本号：编辑 `build.sh` 顶部 `VERSION=`。
- 产物：`build/ClipForge-<ver>.pkg`（ad-hoc 未签名；设 `SIGN_APP` / `SIGN_PKG` 环境变量走正式签名）。
- 通用二进制 arm64+x86_64，仅需 Command Line Tools + macOS SDK（swiftc）。

### 签名
- 当前**未签名**（免费 Apple ID 无法创建 Developer ID 证书；付费 ¥688/年 才能正式签名 + 公证）。
- 正式签名：导出 `SIGN_APP` / `SIGN_PKG` 为证书标识后重跑 `build.sh`。
- pkg 首次打开若被 Gatekeeper 拦截：右键 → 打开，或「系统设置 → 隐私与安全性 → 仍要打开」。

### 发布
- 在 `PlayChessClub/videogenerator` 的 **Releases** 上传 `ClipForge-<ver>.pkg` + 更新 `VERSION`。
- 不再出 `.dmg`（用户定：只打 `.pkg`）。

---

## 3. Web / Windows / Linux（clipforge-web）

- 构建 / CI / 发布全部在独立仓库 `PlayChessClub/clipforge-web` 完成（Go 后端 `server/` + 前端 `server/static/` + `build-pkgs.py` 打 deb/zip + `.github` CI）。
- **本仓库（videogenerator）不再含 `web/` 源码**，任何 web 改动都提交到 `clipforge-web`。
- 历史：`622889e`「从主仓库移除 web/(迁至独立仓库 clipforge-web)」。

---

## 4. iOS 构建 / 签名 / 发布（ClipForge-ios）

- 工程：`~/Documents/clipforgeios/clipforgeios.xcodeproj`（Xcode 26，`PBXFileSystemSynchronizedRootGroup` 文件夹同步，增删文件自动进 target）。
- 运行目标：**iOS 16.1+ 真机** 或 **iOS 26.5+ 模拟器**。
- 签名（免费个人账号）：
  - `CODE_SIGN_STYLE = Automatic`；`DEVELOPMENT_TEAM` 在 pbxproj 中以占位符 `YOUR_TEAM_ID` 提交，**开发者本地改成自己的 Team ID**，但不提交该值。
  - 免费账号 7 天有效期，重跑 ⌘R 续期。
  - 免费账号不支持「推送通知 / iCloud」，`clipforgeios.entitlements` 保持为空 `<dict/>`。
- 模拟器无签名限制：`CODE_SIGNING_ALLOWED=NO` 即可构建，`xcrun simctl install/launch` 验证。
- 真机启动若报 `Code 7 invalid signature`：手机端开「开发者模式」+「设置 → 通用 → VPN 与设备管理」信任开发者证书（非代码问题）。
- **不发布预编译 IPA**：需要 IPA 自行本地 `archive` + `exportArchive`（method=development，含已注册设备）。`build-ipa/` 为本地构建产物，已 gitignore，不上云。

---

## 5. 版本号规则

- macOS：`build.sh` 内 `VERSION=`（如 `1.7.3`），与 Releases tag 对齐。
- Web：Go `server/` 内版本常量（见 `clipforge-web` README，当前 `v3.2.2`）。
- iOS：Xcode 工程 `MARKETING_VERSION`，独立演进。

---

## 6. 隐私红线（最高优先）

**绝不把含个人信息的文件推上云。** 维护时务必遵守：

- 禁止入库 / 推送：个人邮箱、Apple 开发者 **Team ID**、API Key（`sk-...`）、设备 **UDID**、任何 token。
- API Key 仅存本机 Keychain / 应用设置；源码、README、日志、提交历史都不得出现。
- `project.pbxproj` 的 Team ID 用占位符 `YOUR_TEAM_ID` 提交；本地填回真实值后**不要 `git add` 该文件**。
- 已在 `.gitignore` 屏蔽：`.env` / `*.key` / `settings.yml` / `settings.dat` / `build/` / `*.dmg` / `*.app` / `web/release/` / `ios/build_ios/` / `ios/ClipForgeCore/.build/` / `build-ipa/`。
- 提交前自查：`git status` + 全文搜索 `sk-` / 你的 Team ID / `@gmail` / `@126.com` / 40 位 hex（UDID）。

### 历史泄露修复（ClipForge-ios）
- 该仓库曾把个人邮箱写进 commit 作者、把 Team ID 写进 `project.pbxproj` 与 README。
- 撤回方式（按当时确认的深度）：占位符替换 + /或 `git filter-repo` 改写历史并 force push；本地 pbxproj 改回真实 Team ID 后可继续构建。

---

## 7. 常见故障

| 现象 | 原因 / 处理 |
|---|---|
| pkg 首次打不开 | Gatekeeper 拦；右键打开或「仍要打开」 |
| iOS 真机 `Code 7 invalid signature` | 手机未信任开发者证书 / 未开开发者模式 |
| Xcode 报 provisioning 不支持 push/iCloud | 免费账号；清空 `entitlements` 为 `<dict/>` |
| Combine 严格导入报错 | 含 `@Published`/`ObservableObject` 的文件补 `import Combine` |
| WebView2 / Linux 构建失败 | 看 `clipforge-web` 仓库 CI 与 README，不在本仓库 |
