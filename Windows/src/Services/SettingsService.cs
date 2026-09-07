using System;
using System.IO;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace ClipForgeAI.Win.Services;

/// <summary>
/// 简化的设置存储。DashScope API Key 以明文写入
/// %APPDATA%\ClipForge\settings.yml。
///
/// ⚠️ 安全提示:本机任何进程都能读取此文件。请勿把 settings.yml 提交到代码仓库,
/// 也别通过云盘/聊天软件分享。如需更高安全性,自行在文件管理器上加密。
/// </summary>
public static class SettingsService
{
    private static readonly string SettingsDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ClipForge");
    private static readonly string YamlFile = Path.Combine(SettingsDir, "settings.yml");

    public sealed class Settings
    {
        public string? DashScopeApiKey { get; set; }
        public string? OutputDirOverride { get; set; }
    }

    private static Settings Read() => new();

    public static string? LoadApiKey()
    {
        try
        {
            if (!File.Exists(YamlFile)) return null;
            var deser = new DeserializerBuilder()
                .WithNamingConvention(CamelCaseNamingConvention.Instance)
                .Build();
            var s = deser.Deserialize<Settings>(File.ReadAllText(YamlFile));
            return string.IsNullOrWhiteSpace(s?.DashScopeApiKey) ? null : s!.DashScopeApiKey!.Trim();
        }
        catch
        {
            return null;
        }
    }

    public static void SaveApiKey(string key)
    {
        if (string.IsNullOrWhiteSpace(key)) throw new ArgumentException("key 不能为空", nameof(key));
        Directory.CreateDirectory(SettingsDir);

        var current = LoadApiKey() != null
            ? new Settings { DashScopeApiKey = key.Trim(), OutputDirOverride = Read().OutputDirOverride }
            : new Settings { DashScopeApiKey = key.Trim() };

        var ser = new SerializerBuilder()
            .WithNamingConvention(CamelCaseNamingConvention.Instance)
            .Build();
        File.WriteAllText(YamlFile, ser.Serialize(current));
    }

    public static void DeleteApiKey()
    {
        try { if (File.Exists(YamlFile)) File.Delete(YamlFile); }
        catch { /* 忽略 */ }
    }

    public static string OutputDirectory
    {
        get
        {
            // 默认放用户 Downloads/ClipForge;若用户在 yml 里指定了 outputDirOverride 则用之
            string? overrideDir = null;
            try
            {
                if (File.Exists(YamlFile))
                {
                    var deser = new DeserializerBuilder()
                        .WithNamingConvention(CamelCaseNamingConvention.Instance)
                        .Build();
                    overrideDir = deser.Deserialize<Settings>(File.ReadAllText(YamlFile))?.OutputDirOverride;
                }
            }
            catch { /* 读取失败就退回默认 */ }

            var dir = !string.IsNullOrWhiteSpace(overrideDir)
                ? overrideDir!
                : Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    "Downloads", "ClipForge");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }
}