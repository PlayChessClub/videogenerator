using Microsoft.UI.Xaml;
using System;

namespace ClipForgeAI.Win;

public partial class App : Application
{
    public static Window? MainAppWindow { get; private set; }

    public App()
    {
        this.InitializeComponent();
        this.UnhandledException += (s, e) =>
        {
            // 避免未捕获异常时进程静默退出;开发期会写入 stderr
            Console.Error.WriteLine($"[Unhandled] {e.Exception}");
            e.Handled = true;
        };
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        MainAppWindow = new MainWindow();
        MainAppWindow.Activate();
    }
}
