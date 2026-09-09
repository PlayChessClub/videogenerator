//go:build linux && cgo

// Linux 原生窗口:内嵌 webkit2gtk(与 Windows 版 WebView2 同源的 webview 库)。
// 需要 libwebkit2gtk-4.1(deb 安装时自动补依赖);无桌面/GTK 初始化失败时回退开浏览器。
package main

import (
	"os"

	webview "github.com/webview/webview_go"
)

func launchUI(url string) {
	defer func() {
		if recover() != nil { // GTK 初始化失败(无显示环境等) → 浏览器回退
			openBrowser(url)
		}
	}()
	w := webview.New(false)
	if w == nil {
		openBrowser(url)
		return
	}
	defer w.Destroy()
	w.SetTitle("ClipForge AI")
	w.SetSize(1280, 880, webview.HintNone)
	w.Navigate(url)
	w.Run() // 阻塞:GTK 主循环,直到窗口关闭
	os.Exit(0) // 关窗即退出(与 Windows 版一致)
}
