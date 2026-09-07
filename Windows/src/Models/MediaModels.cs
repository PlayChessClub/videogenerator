using System;
using System.Collections.Generic;

namespace ClipForgeAI.Win.Models;

public enum MediaKind { Audio, Video, Image }

public sealed class MediaItem
{
    public string Id { get; init; } = Guid.NewGuid().ToString("N");
    public required string Name { get; init; }
    public required string LocalPath { get; set; }
    public string? RemoteUrl { get; set; }
    public MediaKind Kind { get; init; }
    public DateTime AddedAt { get; init; } = DateTime.Now;
    public double DurationSeconds { get; set; }
    public string? VoiceId { get; set; }   // 音色 ID(TTS 用)
    public string? TaskId { get; set; }     // DashScope 视频任务 ID
}

public sealed class VoiceCloneRequest
{
    public string LocalAudioPath { get; set; } = "";
    public string Prefix { get; set; } = "myvoice";
}

public sealed class TtsRequest
{
    public string Text { get; set; } = "";
    public string VoiceId { get; set; } = "";   // 空 = 默认女声
    public double Volume { get; set; } = 1.0;
    public double Rate { get; set; } = 1.0;
    public double Pitch { get; set; } = 1.0;
}

public sealed class VideoGenRequest
{
    public string Prompt { get; set; } = "";
    public string? ReferenceImagePath { get; set; }
    public string? ReferenceAudioPath { get; set; }
    public string Resolution { get; set; } = "720P";  // 720P / 1080P
    public int Duration { get; set; } = 10;
    public bool PromptExtend { get; set; } = true;
    public string ShotType { get; set; } = "multi";
}

public sealed class VideoGenStatus
{
    public string TaskId { get; set; } = "";
    public string Status { get; set; } = "PENDING";   // PENDING / RUNNING / SUCCEEDED / FAILED
    public string? VideoUrl { get; set; }
    public string? ErrorMessage { get; set; }
}

public sealed class TimelineClip
{
    public MediaItem Item { get; set; } = null!;
    public double StartSeconds { get; set; }
    public double EndSeconds { get; set; }
    public double Duration => Math.Max(0, EndSeconds - StartSeconds);
}

public sealed class ExportPlan
{
    public List<TimelineClip> Clips { get; set; } = new();
    public MediaItem? DubAudio { get; set; }       // 替换配音模式
    public string OutputPath { get; set; } = "";
}

/// <summary>
/// 模型固定配置 — 与 macOS 客户端保持完全一致,跨平台行为统一。
/// </summary>
public static class FixedModel
{
    public const string Tts = "cosyvoice-v3.5-plus";
    public const string VoiceEnrollment = "cosyvoice-v3.5-plus";
    public const string VideoI2V = "wan2.6-i2v";
    public const string Endpoint = "https://dashscope.aliyuncs.com/api/v1";
    public const string WssEndpoint = "wss://dashscope.aliyuncs.com/api-ws/v1/inference";
}
