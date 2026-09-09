//go:build linux && !cgo

// Linux 纯静态构建(无 CGO):不嵌 webkit,回退打开系统浏览器。
// 供服务器/无桌面环境使用;桌面用户请用 deb 安装(内嵌 webkit 窗口)。
package main

// launchUI 打开系统默认浏览器访问本地 UI。
func launchUI(url string) {
	openBrowser(url)
}
