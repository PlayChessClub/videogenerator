// ClipForge 后端 - Go 单文件 HTTP server
// 1. 静态文件服务(static/) - 前端 SPA
// 2. DashScope API 代理 - 把 API Key 保存在本地,前端不直接拿 Key
// 3. 轮询视频任务状态
// 4. 上传本地音频/图片到 DashScope OSS
//
// 编译: go build -o clipforge.exe main.go
// 运行: ./clipforge.exe
// 浏览器自动打开: http://127.0.0.1:8731
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// ============================================================
// 配置
// ============================================================

const (
	listenAddr = "127.0.0.1:8731"
	appDir     = "ClipForge"
	configFile = "settings.yml"
)

// 静态文件目录:可被环境变量 STATIC_DIR 覆盖,默认与二进制同级 static/
var staticDir = func() string {
	if v := os.Getenv("STATIC_DIR"); v != "" {
		return v
	}
	return "static"
}()

// ============================================================
// 配置管理(settings.yml 明文,用户自己保管)
// ============================================================

type Config struct {
	APIKey string `json:"apiKey"`
}

func configPath() string {
	dir, err := os.UserConfigDir()
	if err != nil {
		dir = "."
	}
	return filepath.Join(dir, appDir, configFile)
}

func loadConfig() Config {
	var c Config
	data, err := os.ReadFile(configPath())
	if err != nil {
		return c
	}
	// 简单 yml 解析:只取 apiKey: 后面的值
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "apiKey:") {
			v := strings.TrimSpace(strings.TrimPrefix(line, "apiKey:"))
			v = strings.Trim(v, `"'`)
			c.APIKey = v
		}
	}
	return c
}

func saveConfig(c Config) error {
	dir := filepath.Dir(configPath())
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	content := fmt.Sprintf("# ClipForge 设置(明文,自行保管不要提交到代码仓库)\napiKey: %q\n", c.APIKey)
	return os.WriteFile(configPath(), []byte(content), 0600)
}

// ============================================================
// 全局(读 API Key 一次,后续请求用)
// ============================================================

var (
	apiKeyMu sync.RWMutex
	apiKey   string
)

func getAPIKey() string {
	apiKeyMu.RLock()
	defer apiKeyMu.RUnlock()
	return apiKey
}

func setAPIKey(k string) {
	apiKeyMu.Lock()
	defer apiKeyMu.Unlock()
	apiKey = k
}

// ============================================================
// DashScope 代理
// ============================================================

func dashScopeProxy(w http.ResponseWriter, r *http.Request, path string) {
	key := getAPIKey()
	if key == "" {
		http.Error(w, `{"error":"未设置 API Key,请先在设置页填入"}`, http.StatusUnauthorized)
		return
	}
	body, _ := io.ReadAll(r.Body)
	req, err := http.NewRequest(r.Method,
		"https://dashscope.aliyuncs.com/api/v1"+path, bytes.NewReader(body))
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
		return
	}
	for k, v := range r.Header {
		if strings.EqualFold(k, "Host") || strings.EqualFold(k, "Content-Length") {
			continue
		}
		for _, vv := range v {
			req.Header.Add(k, vv)
		}
	}
	req.Header.Set("Authorization", "Bearer "+key)
	req.Header.Set("user-agent", "clipforge/2.0.0")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()
	for k, v := range resp.Header {
		for _, vv := range v {
			w.Header().Add(k, vv)
		}
	}
	w.WriteHeader(resp.StatusCode)
	io.Copy(w, resp.Body)
}

// 上传本地文件到 DashScope OSS(给声音克隆/视频生成引用)
func uploadLocalFile(w http.ResponseWriter, r *http.Request) {
	if r.Method != "POST" {
		http.Error(w, `{"error":"method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}
	key := getAPIKey()
	if key == "" {
		http.Error(w, `{"error":"未设置 API Key"}`, http.StatusUnauthorized)
		return
	}

	// 解析 multipart
	if err := r.ParseMultipartForm(100 << 20); err != nil { // 100MB
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	file, header, err := r.FormFile("file")
	if err != nil {
		http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusBadRequest)
		return
	}
	defer file.Close()

	// 1) 申请策略
	policyBody := strings.NewReader(`{"model":"cosyvoice-v3.5-plus","input":{"action":"get_policy"}}`)
	policyReq, _ := http.NewRequest("POST",
		"https://dashscope.aliyuncs.com/api/v1/uploads", policyBody)
	policyReq.Header.Set("Authorization", "Bearer "+key)
	policyReq.Header.Set("Content-Type", "application/json")
	policyResp, err := http.DefaultClient.Do(policyReq)
	if err != nil {
		http.Error(w, `{"error":"申请策略失败: `+err.Error()+`"}`, http.StatusBadGateway)
		return
	}
	defer policyResp.Body.Close()
	if policyResp.StatusCode != 200 {
		b, _ := io.ReadAll(policyResp.Body)
		http.Error(w, fmt.Sprintf(`{"error":"申请策略失败: %s"}`, string(b)), policyResp.StatusCode)
		return
	}
	var policyData struct {
		Output struct {
			Upload struct {
				Host            string `json:"host"`
				Policy          string `json:"policy"`
				AccessKeyID     string `json:"access_key_id"`
				AccessKeySecret string `json:"access_key_secret"`
				SecurityToken   string `json:"security_token"`
				OssKey          string `json:"oss_key"`
				Expiration      string `json:"expiration"`
			} `json:"upload"`
		} `json:"output"`
	}
	if err := json.NewDecoder(policyResp.Body).Decode(&policyData); err != nil {
		http.Error(w, `{"error":"解析策略失败"}`, http.StatusInternalServerError)
		return
	}
	u := policyData.Output.Upload

	// 2) multipart 直传 OSS
	var b bytes.Buffer
	mw := multipart.NewWriter(&b)
	mw.WriteField("OSSAccessKeyId", u.AccessKeyID)
	mw.WriteField("policy", u.Policy)
	mw.WriteField("SignatureVersion", "200")
	mw.WriteField("SignatureMethod", "OSS-HMAC-SHA256")
	mw.WriteField("dir", "oss")
	mw.WriteField("expire", u.Expiration)
	mw.WriteField("key", u.OssKey)
	mw.WriteField("x-oss-security-token", u.SecurityToken)
	mw.WriteField("success_action_status", "True")
	fw, _ := mw.CreateFormFile("file", header.Filename)
	io.Copy(fw, file)
	mw.Close()

	ossReq, _ := http.NewRequest("POST", u.Host, &b)
	ossReq.Header.Set("Content-Type", mw.FormDataContentType())
	ossResp, err := http.DefaultClient.Do(ossReq)
	if err != nil {
		http.Error(w, `{"error":"OSS 上传失败: `+err.Error()+`"}`, http.StatusBadGateway)
		return
	}
	defer ossResp.Body.Close()
	if ossResp.StatusCode != 200 {
		bb, _ := io.ReadAll(ossResp.Body)
		http.Error(w, fmt.Sprintf(`{"error":"OSS 上传失败: %s"}`, string(bb)), ossResp.StatusCode)
		return
	}

	// 3) 通知 DashScope 资源就绪
	submitBody := fmt.Sprintf(`{"model":"cosyvoice-v3.5-plus","input":{"action":"submit","oss_key":%q}}`, u.OssKey)
	submitReq, _ := http.NewRequest("POST",
		"https://dashscope.aliyuncs.com/api/v1/uploads", strings.NewReader(submitBody))
	submitReq.Header.Set("Authorization", "Bearer "+key)
	submitReq.Header.Set("Content-Type", "application/json")
	submitResp, err := http.DefaultClient.Do(submitReq)
	if err != nil {
		http.Error(w, `{"error":"提交资源失败: `+err.Error()+`"}`, http.StatusBadGateway)
		return
	}
	defer submitResp.Body.Close()
	if submitResp.StatusCode != 200 {
		bb, _ := io.ReadAll(submitResp.Body)
		http.Error(w, fmt.Sprintf(`{"error":"提交资源失败: %s"}`, string(bb)), submitResp.StatusCode)
		return
	}
	var submitData struct {
		Output struct {
			Resource string `json:"resource"`
		} `json:"output"`
	}
	json.NewDecoder(submitResp.Body).Decode(&submitData)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"resource": submitData.Output.Resource})
}

// 跨平台打开默认浏览器
func openBrowser(url string) {
	// 用一个短超时 goroutine 启动浏览器,不阻塞主线程
	go func() {
		var cmd *exec.Cmd
		switch {
		case fileExists("/Applications/Google Chrome.app") || isMac():
			_ = exec.Command("open", url).Start()
		case isWindows():
			_ = exec.Command("rundll32", "url.dll,FileProtocolHandler", url).Start()
		default:
			_ = exec.Command("xdg-open", url).Start()
		}
		_ = cmd
	}()
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

func isMac() bool     { return os.PathSeparator == '/' && fileExists("/System") }
func isWindows() bool { return os.PathSeparator == '\\' || fileExists("C:\\Windows") }

// ============================================================
// 路由
// ============================================================

func main() {
	cfg := loadConfig()
	apiKey = cfg.APIKey

	mux := http.NewServeMux()

	// 静态文件
	mux.Handle("/", http.FileServer(http.Dir(staticDir)))

	// 配置
	mux.HandleFunc("/api/config", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case "GET":
			w.Header().Set("Content-Type", "application/json")
			// 只告诉前端是否已设置,不返回 key
			out := map[string]any{"configured": getAPIKey() != ""}
			json.NewEncoder(w).Encode(out)
		case "POST":
			var body Config
			if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
				http.Error(w, `{"error":"invalid json"}`, http.StatusBadRequest)
				return
			}
			if err := saveConfig(body); err != nil {
				http.Error(w, `{"error":"`+err.Error()+`"}`, http.StatusInternalServerError)
				return
			}
			setAPIKey(body.APIKey)
			w.Write([]byte(`{"ok":true}`))
		default:
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		}
	})

	// 声音克隆 - 创建 voice
	mux.HandleFunc("/api/voice/create", func(w http.ResponseWriter, r *http.Request) {
		dashScopeProxy(w, r, "/services/audio/tts/customization")
	})

	// 音色查询/列表
	mux.HandleFunc("/api/voice/list", func(w http.ResponseWriter, r *http.Request) {
		dashScopeProxy(w, r, "/services/audio/tts/customization")
	})

	// 视频任务提交
	mux.HandleFunc("/api/video/submit", func(w http.ResponseWriter, r *http.Request) {
		dashScopeProxy(w, r, "/services/aigc/video-generation/video-synthesis")
	})

	// 视频任务查询
	mux.HandleFunc("/api/video/task", func(w http.ResponseWriter, r *http.Request) {
		taskID := r.URL.Query().Get("taskId")
		if taskID == "" {
			http.Error(w, `{"error":"missing taskId"}`, http.StatusBadRequest)
			return
		}
		dashScopeProxy(w, r, "/tasks/"+taskID)
	})

	// 视频下载(转发给 DashScope,前端用 a 标签直接打开 URL 也行)
	mux.HandleFunc("/api/video/download", func(w http.ResponseWriter, r *http.Request) {
		url := r.URL.Query().Get("url")
		if url == "" {
			http.Error(w, `{"error":"missing url"}`, http.StatusBadRequest)
			return
		}
		client := &http.Client{Timeout: 5 * time.Minute}
		req, _ := http.NewRequest("GET", url, nil)
		resp, err := client.Do(req)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadGateway)
			return
		}
		defer resp.Body.Close()
		w.Header().Set("Content-Type", resp.Header.Get("Content-Type"))
		w.Header().Set("Content-Disposition", `attachment; filename="`+filepath.Base(url)+`"`)
		io.Copy(w, resp.Body)
	})

	// 上传本地文件到 DashScope OSS
	mux.HandleFunc("/api/upload", uploadLocalFile)

	srv := &http.Server{
		Addr:              listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 10 * time.Second,
	}

	fmt.Printf("🎬 ClipForge 启动 → http://%s\n", listenAddr)
	fmt.Printf("   配置文件: %s\n", configPath())
	fmt.Printf("   按 Ctrl+C 退出\n")
	openBrowser("http://" + listenAddr)
	if err := srv.ListenAndServe(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
