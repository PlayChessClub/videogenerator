using Microsoft.UI.Xaml;
using System;
using System.IO;

namespace ClipForgeAI.Win;

public partial class App : Application
{
    public static Window? MainAppWindow { get; private set; }

    public App()
    {
        this.InitializeComponent();
        this.UnhandledException += (s, e) =>
        {
            // 把未捕获异常写入日志文件,方便排查"双击无反应"(窗口可能因初始化异常没建出来)。
            LogCrash(e.Exception);
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        try
        {
            MainAppWindow = new MainWindow();
            MainAppWindow.Activate();
        }
        catch (Exception ex)
        {
            // MainWindow 构造失败(如资源/图标/后台错误)会导致没有任何窗口,看起来像"无反应"。
            // 记录到日志文件,让用户能反馈真实原因。
            LogCrash(ex);
            System.Environment.Exit(1);
        }
    }

    /// <summary>把崩溃/启动异常写到 %LOCALAPPDATA%\ClipForge\crash.log,便于排查。</summary>
    private static void LogCrash(Exception ex)
    {
        try
        {
            var dir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ClipForge");
            Directory.CreateDirectory(dir);
            var logPath = Path.Combine(dir, "crash.log");
            File.AppendAllText(logPath,
                $"[{DateTime.Now:yyyy-MM-dd HH:mm:ss}] {ex}\n\n");
        }
        catch { /* 日志写不了就算了 */ }
    }
}
