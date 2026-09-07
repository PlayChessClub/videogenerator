using Microsoft.UI;
using Microsoft.UI.Windowing;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Media;
using WinRT.Interop;

namespace ClipForgeAI.Win;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        this.InitializeComponent();

        // 标题栏
        this.Title = "ClipForge · AI 视频编辑助手";
        this.ExtendsContentIntoTitleBar = true;
        this.SetTitleBar(AppTitleBar);
        AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1180, 760));

        // 设置窗口图标。Assets\app.ico 随 publish 输出;找不到时静默忽略(不抛异常,
        // 否则 MainWindow 构造失败会连窗口都建不出来,表现为"双击无反应")。
        try { AppWindow.SetIcon("Assets\\app.ico"); } catch { /* 图标缺失不致命 */ }

        // Mica / Acrylic 背景(Win11 原生材质,对应 macOS 的 Liquid Glass 角色)
        TrySetSystemBackdrop();
    }

    private void TrySetSystemBackdrop()
    {
        // 虚拟机 / 无 DWM 合成环境下 Mica 初始化可能抛异常,失败就退回默认实色背景。
        // 绝不能让它炸掉窗口构造。
        try
        {
            this.SystemBackdrop = new MicaBackdrop { Kind = Microsoft.UI.Composition.SystemBackdrops.MicaKind.BaseAlt };
        }
        catch
        {
            // 保持默认背景
        }
    }

    public new AppWindow AppWindow
    {
        get
        {
            var hwnd = WindowNative.GetWindowHandle(this);
            var id = Win32Interop.GetWindowIdFromWindow(hwnd);
            return AppWindow.GetFromWindowId(id);
        }
    }

    private void OnRootFrameLoaded(object sender, RoutedEventArgs e)
    {
        RootFrame.Navigate(typeof(Views.ShellPage));
    }
}
