using System;
using System.Threading;
using System.Threading.Tasks;
using ClipForgeAI.Win.Models;

namespace ClipForgeAI.Win.Services;

/// <summary>wan2.6-i2v 视频生成高层封装:提交 + 轮询 + 下载到本地。</summary>
public sealed class VideoGenerationService
{
    private readonly DashScopeClient _client;
    public VideoGenerationService(DashScopeClient client) { _client = client; }

    public async Task<string> GenerateAsync(VideoGenRequest req,
        IProgress<VideoGenStatus>? progress = null, CancellationToken ct = default)
    {
        // 1) 本地文件先上传到 DashScope OSS(如果是 http 链接则跳过)
        if (!string.IsNullOrEmpty(req.ReferenceImagePath) && !req.ReferenceImagePath.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            req.ReferenceImagePath = await _client.UploadToOssAsync(req.ReferenceImagePath, ct);
        if (!string.IsNullOrEmpty(req.ReferenceAudioPath) && !req.ReferenceAudioPath.StartsWith("http", StringComparison.OrdinalIgnoreCase))
            req.ReferenceAudioPath = await _client.UploadToOssAsync(req.ReferenceAudioPath, ct);

        // 2) 提交任务
        var taskId = await _client.SubmitVideoGenAsync(req, ct);
        progress?.Report(new VideoGenStatus { TaskId = taskId, Status = "PENDING" });

        // 3) 轮询(最多 30 分钟,每 8s 一次)
        var deadline = DateTime.UtcNow.AddMinutes(30);
        while (DateTime.UtcNow < deadline)
        {
            await Task.Delay(TimeSpan.FromSeconds(8), ct);
            var task = await _client.GetTaskAsync(taskId, ct);
            var output = task.GetProperty("output");
            var status = output.GetProperty("task_status").GetString() ?? "RUNNING";
            progress?.Report(new VideoGenStatus { TaskId = taskId, Status = status });

            if (status == "SUCCEEDED")
            {
                var videoUrl = output.GetProperty("video_url").GetString();
                progress?.Report(new VideoGenStatus { TaskId = taskId, Status = status, VideoUrl = videoUrl });
                return videoUrl!;
            }
            if (status == "FAILED" || status == "CANCELED")
            {
                var msg = output.TryGetProperty("message", out var m) ? m.GetString() : "未知失败原因";
                progress?.Report(new VideoGenStatus { TaskId = taskId, Status = status, ErrorMessage = msg });
                throw new InvalidOperationException($"视频任务失败: {msg}");
            }
        }
        throw new TimeoutException("视频生成超时(30 分钟)");
    }
}
