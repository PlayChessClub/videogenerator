using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

namespace ClipForgeAI.Win.Services;

/// <summary>
/// DashScope API Key 存储。unpackaged 模式下不依赖 PasswordVault,
/// 改用 DPAPI(Windows Data Protection)加密后写入 %APPDATA%\ClipForge\settings.dat。
/// 只有当前 Windows 用户能解密,等价于 macOS 的 Keychain 行为。
/// </summary>
public static class SettingsService
{
    private static readonly string SettingsDir =
        Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "ClipForge");
    private static readonly string KeyFile = Path.Combine(SettingsDir, "settings.dat");

    public static string? LoadApiKey()
    {
        try
        {
            if (!File.Exists(KeyFile)) return null;
            var encrypted = File.ReadAllBytes(KeyFile);
            var plain = ProtectedData.Unprotect(encrypted, null, DataProtectionScope.CurrentUser);
            return Encoding.UTF8.GetString(plain);
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
        var plain = Encoding.UTF8.GetBytes(key.Trim());
        var encrypted = ProtectedData.Protect(plain, null, DataProtectionScope.CurrentUser);
        File.WriteAllBytes(KeyFile, encrypted);
    }

    public static void DeleteApiKey()
    {
        try { if (File.Exists(KeyFile)) File.Delete(KeyFile); }
        catch { /* 忽略 */ }
    }

    public static string OutputDirectory
    {
        get
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Downloads", "ClipForge");
            Directory.CreateDirectory(dir);
            return dir;
        }
    }
}
