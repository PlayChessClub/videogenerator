# ClipForge Web (Go + HTML5)

> v2.0.0+ 替代旧版 WinUI 3 实现。**零运行时依赖、跨平台、单文件 ~6MB**。

## 怎么跑

### 1) 装 Go

下载安装：https://go.dev/dl/ （需要 Go 1.21+）

### 2) 启动

```bash
cd web/server
go run .
# 浏览器会自动打开 http://127.0.0.1:8731
```

### 3) 打包成单文件 exe(Windows)

```powershell
# Windows PowerShell
cd web\server
$env:GOOS="windows"; $env:GOARCH="amd64"
go build -ldflags="-s -w" -o ..\..\clipforge.exe .
# ARM64 用 arm64 替换 amd64
```

最终 `clipforge.exe` 双击就开,会自动开浏览器到 `http://127.0.0.1:8731`。

### 4) 配置 API Key

首次启动后,在浏览器「设置」页填入 DashScope API Key,保存到本地明文 yml。

## 文件布局

```
web/
├── server/
│   ├── main.go        # Go HTTP server,代理 DashScope + 静态服务
│   ├── go.mod
│   └── go.sum
└── static/
    ├── index.html     # 单页 SPA
    ├── style.css      # 暗色玻璃风
    └── app.js         # 原生 JS,无框架
```

## API 端点

| 路径 | 方法 | 说明 |
|---|---|---|
| `/` | GET | 静态文件 |
| `/api/config` | GET/POST | 读写 API Key(GET 只返回 `configured: true/false`) |
| `/api/voice/create` | POST | 声音克隆(创建 voice_id) |
| `/api/voice/list` | GET | 音色列表 |
| `/api/video/submit` | POST | 视频任务提交 |
| `/api/video/task` | GET | 视频任务查询(`?taskId=xxx`) |
| `/api/video/download` | GET | 视频下载代理 |
| `/api/upload` | POST | 本地文件 → DashScope OSS(返回 resource URL) |

## 配置路径

- Windows: `%APPDATA%\ClipForge\settings.yml`
- macOS: `~/Library/Application Support/ClipForge/settings.yml`
- Linux: `~/.config/ClipForge/settings.yml`

明文存储,**自行保管,不要提交到代码仓库**。

## 已实现

- ✅ 声音克隆(cosyvoice-v3.5-plus)+ 音色列表
- ✅ 图生视频(wan2.6-i2v)+ 提示词/分辨率/时长/镜头/AI 增强
- ✅ 本地文件上传到 DashScope OSS

## 不实现

- ❌ 实时 TTS WebSocket 合成(协议复杂,踩过 task-failed 等坑)
- ❌ 视频时间线拼接(纯前端拼接需 ffmpeg.wasm,体积巨大且性能差)
