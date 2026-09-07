# Windows/ 目录已归档(v2.0+ 不再使用)

> **状态**:归档,代码保留仅供参考,**不再编译/发布**。
>
> v2.0 起的 Windows 客户端改用 `web/` 目录的 **Go + HTML5** 方案(见仓库根目录 web/README.md)。
> 原因:WinUI 3 在 PD 虚拟机/裸 dotnet CLI 环境下打包存在深坑
> (缺 PRI/资源、Application 通道 0 条崩溃记录说明 exe 没启动),改用浏览器方案更可靠。

## 这份代码里有什么

- 完整 WinUI 3 / .NET 8 / Windows App SDK 1.6 项目
- 功能:声音克隆、图生视频、设置
- 已简化的功能(对比 macOS 客户端):无 TTS WebSocket 合成、无时间线拼接

## 还能用吗

理论上:装 Visual Studio 2022(选 ".NET 桌面开发" + "Windows 应用开发 C#") →
  双击 `Windows/ClipForgeAI.Win.sln` → F5。

实际:在很多环境下(尤其是 Parallels Desktop 虚拟 ARM Windows + 没装完整 VS Build Tools)
会卡在打包/启动。GitHub Actions 也已经不再构建它(.github/workflows/windows-build.yml
已删除,新的 .github/workflows/build-web.yml 构建 web/ 目录)。

## 保留原因

- 学习参考:完整的 WinUI 3 unpackaged 自包含 .NET 8 项目结构
- 应急回退:如果未来要重新尝试 WinUI 3,这里有踩过的所有坑的注释
