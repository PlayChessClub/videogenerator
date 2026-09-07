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
        AppWindow.SetIcon("Assets\\app.ico");

        // Mica / Acrylic 背景(Win11 原生材质,对应 macOS 的 Liquid Glass 角色)
        TrySetSystemBackdrop();
    }

    private void TrySetSystemBackdrop()
    {
        // 优先 Mica(Win11 22H2+);失败回退 Acrylic(Win10);再失败用纯色
        this.SystemBackdrop = new MicaBackdrop { Kind = Microsoft.UI.Composition.SystemBackdrops.MicaKind.BaseAlt };
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
