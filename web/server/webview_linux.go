//go:build linux && cgo

// Linux 原生窗口:内嵌 webkit2gtk(与 Windows 版 WebView2 同源的 webview 库)。
// 需要 libwebkit2gtk-4.1(deb 安装时自动补依赖);无桌面/GTK 初始化失败时回退开浏览器。
package main

import (
	"fmt"
	"os"
	"path/filepath"

	webview "github.com/webview/webview_go"
)

// uiLog 把关键事件追加到用户缓存目录,GUI 启动时 stderr 不可见,
// 「按了打开没反应」可以看这个文件定位。
func uiLog(format string, args ...any) {
	dir, err := os.UserCacheDir()
	if err != nil {
		return
	}
	p := filepath.Join(dir, "clipforge")
	_ = os.MkdirAll(p, 0o755)
	f, err := os.OpenFile(filepath.Join(p, "ui.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return
	}
	fmt.Fprintf(f, format+"\n", args...)
	_ = f.Close()
}

func launchUI(url string) {
	// VM(UTM/QEMU) 下 WebKitGTK 的 DMABUF 渲染器常导致窗口创建即崩,
	// 与各发行版打包脚本一致地强制传统渲染路径
	os.Setenv("WEBKIT_DISABLE_DMABUF_RENDERER", "1")
	os.Setenv("WEBKIT_DISABLE_COMPOSITING_MODE", "1")

	defer func() {
		if r := recover(); r != nil { // GTK 初始化失败(无显示环境等) → 浏览器回退
			uiLog("GTK 初始化失败, 回退浏览器: %v", r)
			openBrowser(url)
		}
	}()
	w := webview.New(false)
	if w == nil {
		uiLog("webview.New 返回 nil, 回退浏览器")
		openBrowser(url)
		return
	}
	uiLog("webkit 窗口已创建, %s", url)
	defer w.Destroy()
	w.SetTitle("ClipForge AI")
	w.SetSize(1280, 880, webview.HintNone)
	w.Navigate(url)
	w.Run() // 阻塞:GTK 主循环,直到窗口关闭
	uiLog("窗口已关闭, 退出")
	os.Exit(0) // 关窗即退出(与 Windows 版一致)
}
