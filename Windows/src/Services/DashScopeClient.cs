using System;
using System.Collections.Generic;
using System.IO;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using ClipForgeAI.Win.Models;

namespace ClipForgeAI.Win.Services;

public sealed class ApiException : Exception
{
    public int StatusCode { get; }
    public ApiException(int status, string message) : base(message) { StatusCode = status; }
}

/// <summary>
/// DashScope REST 客户端(声音克隆 / OSS 上传 / 视频任务提交 + 轮询)。
/// 端点、文案与 macOS 客户端保持完全一致,便于跨平台行为统一。
/// </summary>
public sealed class DashScopeClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromMinutes(10) };
    private static readonly JsonSerializerOptions JsonOpts = new() { PropertyNamingPolicy = null };

    private readonly string _apiKey;
    public DashScopeClient(string apiKey) { _apiKey = apiKey; }

    private HttpRequestMessage Req(HttpMethod method, string url, bool async = false,
        IDictionary<string, string>? extra = null, HttpContent? body = null)
    {
        var r = new HttpRequestMessage(method, url);
        r.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _apiKey);
        r.Headers.Add("user-agent", "clipforge");
        if (async) r.Headers.Add("X-DashScope-Async", "enable");
        if (extra != null)
            foreach (var kv in extra) r.Headers.TryAddWithoutValidation(kv.Key, kv.Value);
        if (body != null) r.Content = body;
        return r;
    }

    private static async Task<JsonElement> SendAsync(HttpRequestMessage req, CancellationToken ct = default)
    {
        var resp = await Http.SendAsync(req, ct);
        var body = await resp.Content.ReadAsStringAsync(ct);
        if (!resp.IsSuccessStatusCode)
            throw new ApiException((int)resp.StatusCode, $"HTTP {(int)resp.StatusCode}: {body}");
        return string.IsNullOrWhiteSpace(body) ? default : JsonDocument.Parse(body).RootElement.Clone();
    }

    // ============= 声音克隆(create_voice + 轮询) =============

    public async Task<string> CreateVoiceAsync(string prefix, string audioUrl, CancellationToken ct = default)
    {
        var body = new
        {
            model = FixedModel.VoiceEnrollment,
            input = new
            {
                action = "create_voice",
                target_model = FixedModel.Tts,
                prefix,
                url = audioUrl
            }
        };
        using var req = Req(HttpMethod.Post,
            $"{FixedModel.Endpoint}/services/audio/tts/customization",
            body: JsonContent(body));
        var json = await SendAsync(req, ct);
        return json.GetProperty("output").GetProperty("voice_id").GetString()!;
    }

    public async Task<JsonElement> QueryVoiceAsync(string voiceId, CancellationToken ct = default)
    {
        using var req = Req(HttpMethod.Get,
            $"{FixedModel.Endpoint}/services/audio/tts/customization?voice_id={Uri.EscapeDataString(voiceId)}");
        return await SendAsync(req, ct);
    }

    public async Task<JsonElement> ListVoicesAsync(string prefix, CancellationToken ct = default)
    {
        using var req = Req(HttpMethod.Get,
            $"{FixedModel.Endpoint}/services/audio/tts/customization?prefix={Uri.EscapeDataString(prefix)}");
        return await SendAsync(req, ct);
    }

    // ============= OSS 临时上传(用于本地文件给 DashScope 引用) =============

    public async Task<string> UploadToOssAsync(string localPath, CancellationToken ct = default)
    {
        // 1) 申请策略
        var policyReq = Req(HttpMethod.Post, $"{FixedModel.Endpoint}/uploads");
        policyReq.Content = JsonContent(new
        {
            model = FixedModel.Tts,
            input = new { action = "get_policy" }
        });
        var policy = await SendAsync(policyReq, ct);
        var upload = policy.GetProperty("output").GetProperty("upload");
        var host = upload.GetProperty("host").GetString()!;
        var policyB64 = upload.GetProperty("policy").GetString()!;
        var accessKeyId = upload.GetProperty("access_key_id").GetString()!;
        var accessKeySecret = upload.GetProperty("access_key_secret").GetString()!;
        var securityToken = upload.GetProperty("security_token").GetString()!;
        var ossKey = upload.GetProperty("oss_key").GetString()!;
        var expiration = upload.GetProperty("expiration").GetString()!;

        // 2) 走 OSS POST(multipart/form-data)
        using var form = new MultipartFormDataContent();
        form.Add(new StringContent(accessKeyId), "OSSAccessKeyId");
        form.Add(new StringContent(policyB64), "policy");
        form.Add(new StringContent("200"), "SignatureVersion");
        form.Add(new StringContent("OSS-HMAC-SHA256"), "SignatureMethod");
        form.Add(new StringContent("oss"), "dir");
        form.Add(new StringContent(expiration), "expire");
        form.Add(new StringContent(ossKey), "key");
        form.Add(new StringContent(securityToken), "x-oss-security-token");
        form.Add(new StringContent("True"), "success_action_status");

        var fileBytes = await File.ReadAllBytesAsync(localPath, ct);
        var fileContent = new ByteArrayContent(fileBytes);
        fileContent.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");
        form.Add(fileContent, "file", Path.GetFileName(localPath));

        var uploadResp = await Http.PostAsync(host, form, ct);
        var uploadBody = await uploadResp.Content.ReadAsStringAsync(ct);
        if (!uploadResp.IsSuccessStatusCode)
            throw new ApiException((int)uploadResp.StatusCode, $"OSS 上传失败: {uploadBody}");

        // 3) 通知 DashScope 资源就绪
        var submitReq = Req(HttpMethod.Post, $"{FixedModel.Endpoint}/uploads");
        submitReq.Content = JsonContent(new
        {
            model = FixedModel.Tts,
            input = new { action = "submit", oss_key = ossKey }
        });
        var submitJson = await SendAsync(submitReq, ct);
        var resourceUrl = submitJson.GetProperty("output").GetProperty("resource").GetString()!;
        return resourceUrl;
    }

    // ============= 视频生成(异步任务) =============

    public async Task<string> SubmitVideoGenAsync(VideoGenRequest req, CancellationToken ct = default)
    {
        var input = new Dictionary<string, object>
        {
            ["prompt"] = req.Prompt,
        };
        if (!string.IsNullOrEmpty(req.ReferenceImagePath)) input["img_url"] = req.ReferenceImagePath;
        if (!string.IsNullOrEmpty(req.ReferenceAudioPath)) input["audio_url"] = req.ReferenceAudioPath;

        var parameters = new Dictionary<string, object>
        {
            ["resolution"] = req.Resolution,
            ["prompt_extend"] = req.PromptExtend,
            ["duration"] = req.Duration,
            ["shot_type"] = req.ShotType,
        };

        var body = new { model = FixedModel.VideoI2V, input, parameters };
        using var msg = Req(HttpMethod.Post,
            $"{FixedModel.Endpoint}/services/aigc/video-generation/video-synthesis",
            async: true,
            body: JsonContent(body));
        var json = await SendAsync(msg, ct);
        return json.GetProperty("output").GetProperty("task_id").GetString()!;
    }

    public async Task<JsonElement> GetTaskAsync(string taskId, CancellationToken ct = default)
    {
        using var req = Req(HttpMethod.Get, $"{FixedModel.Endpoint}/tasks/{Uri.EscapeDataString(taskId)}");
        return await SendAsync(req, ct);
    }

    public async Task DownloadAsync(string url, string destPath, CancellationToken ct = default)
    {
        using var resp = await Http.GetAsync(url, HttpCompletionOption.ResponseHeadersRead, ct);
        resp.EnsureSuccessStatusCode();
        await using var stream = await resp.Content.ReadAsStreamAsync(ct);
        Directory.CreateDirectory(Path.GetDirectoryName(destPath)!);
        await using var fs = File.Create(destPath);
        await stream.CopyToAsync(fs, ct);
    }

    private static StringContent JsonContent(object o)
    {
        var s = JsonSerializer.Serialize(o, JsonOpts);
        return new StringContent(s, Encoding.UTF8, "application/json");
    }
}
