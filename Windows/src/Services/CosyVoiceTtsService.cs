using System;
using System.Collections.Generic;
using System.IO;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using ClipForgeAI.Win.Models;

namespace ClipForgeAI.Win.Services;

/// <summary>
/// CosyVoice 全双工 WebSocket TTS 客户端。
/// 协议与官方 dashscope SDK 一致:run-task → 多次 continue-task(送文本分片)→ finish-task。
/// 服务端下发的二进制帧拼接起来就是完整 mp3。
/// </summary>
public sealed class CosyVoiceTtsService
{
    private readonly string _apiKey;
    public CosyVoiceTtsService(string apiKey) { _apiKey = apiKey; }

    public async Task SynthesizeAsync(TtsRequest req, string outputPath,
        IProgress<double>? progress = null, CancellationToken ct = default)
    {
        var uri = new Uri($"{FixedModel.WssEndpoint}");
        using var ws = new ClientWebSocket();
        ws.Options.SetRequestHeader("Authorization", $"Bearer {_apiKey}");
        ws.Options.SetRequestHeader("user-agent", "clipforge");
        await ws.ConnectAsync(uri, ct);

        // run-task 起始帧
        var runHeader = new
        {
            action = "run-task",
            task_id = Guid.NewGuid().ToString("N"),
            model = FixedModel.Tts,
            parameters = new
            {
                text_type = "PlainText",
                voice = req.VoiceId,
                format = "mp3",
                sample_rate = 22050,
                volume = (int)(req.Volume * 50),
                speech_rate = (int)((req.Rate - 1.0) * 50),
                pitch = (int)((req.Pitch - 1.0) * 50),
            },
            input = new { }
        };
        await SendJsonAsync(ws, runHeader, ct);

        // 等 task-started
        var started = await WaitForEventAsync(ws, "task-started", ct);
        if (!started) throw new InvalidOperationException("TTS 启动超时");

        // 分片发送(每 200 字一段)
        var chunks = SplitText(req.Text, 200);
        for (int i = 0; i < chunks.Count; i++)
        {
            var contHeader = new
            {
                action = "continue-task",
                task_id = "",
                input = new { text = chunks[i] }
            };
            await SendJsonAsync(ws, contHeader, ct);
            progress?.Report((i + 0.5) / chunks.Count);
        }

        // finish
        var finish = new { action = "finish-task", task_id = "", input = new { } };
        await SendJsonAsync(ws, finish, ct);

        // 收集音频
        Directory.CreateDirectory(Path.GetDirectoryName(outputPath)!);
        await using var fs = File.Create(outputPath);
        var totalAudioBytes = 0L;
        while (ws.State == WebSocketState.Open)
        {
            var msg = await ReceiveMessageAsync(ws, ct);
            if (msg.Type == WebSocketMessageType.Binary)
            {
                await fs.WriteAsync(msg.Payload, ct);
                totalAudioBytes += msg.Payload.Length;
                progress?.Report(Math.Min(0.95, (double)totalAudioBytes / 200_000));
            }
            else
            {
                var text = Encoding.UTF8.GetString(msg.Payload);
                using var doc = JsonDocument.Parse(text);
                var ev = doc.RootElement.GetProperty("header").GetProperty("event").GetString();
                if (ev == "task-finished") break;
                if (ev == "task-failed")
                {
                    var err = doc.RootElement.GetProperty("header").TryGetProperty("error_message", out var em)
                        ? em.GetString() : "未知错误";
                    throw new InvalidOperationException($"TTS 失败: {err}");
                }
            }
        }
        try { await ws.CloseAsync(WebSocketCloseStatus.NormalClosure, "done", ct); } catch { }
        progress?.Report(1.0);
    }

    private static List<string> SplitText(string text, int size)
    {
        var list = new List<string>();
        for (int i = 0; i < text.Length; i += size)
            list.Add(text.Substring(i, Math.Min(size, text.Length - i)));
        return list;
    }

    private static async Task SendJsonAsync(ClientWebSocket ws, object payload, CancellationToken ct)
    {
        var s = JsonSerializer.Serialize(payload);
        var bytes = Encoding.UTF8.GetBytes(s);
        await ws.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, ct);
    }

    private static async Task<bool> WaitForEventAsync(ClientWebSocket ws, string eventName, CancellationToken ct)
    {
        for (int i = 0; i < 50; i++)   // 最多 ~5s
        {
            var m = await ReceiveMessageAsync(ws, ct);
            if (m.Type == WebSocketMessageType.Text)
            {
                using var doc = JsonDocument.Parse(Encoding.UTF8.GetString(m.Payload));
                if (doc.RootElement.GetProperty("header").GetProperty("event").GetString() == eventName)
                    return true;
            }
        }
        return false;
    }

    private static async Task<(WebSocketMessageType Type, byte[] Payload)> ReceiveMessageAsync(ClientWebSocket ws, CancellationToken ct)
    {
        using var ms = new MemoryStream();
        var buf = new byte[16 * 1024];
        WebSocketReceiveResult? result;
        do
        {
            result = await ws.ReceiveAsync(new ArraySegment<byte>(buf), ct);
            if (result.MessageType == WebSocketMessageType.Close)
                throw new IOException("WebSocket 关闭");
            ms.Write(buf, 0, result.Count);
        } while (!result.EndOfMessage);
        return (result.MessageType, ms.ToArray());
    }
}
