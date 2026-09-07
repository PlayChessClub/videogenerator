using System;
using System.IO;
using ClipForgeAI.Win.Models;
using ClipForgeAI.Win.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Storage.Pickers;
using WinRT.Interop;

namespace ClipForgeAI.Win.Views;

public sealed partial class VideoStudioPage : Page
{
    private string? _imagePath, _audioPath;
    public VideoStudioPage() { this.InitializeComponent(); }

    private async void OnPickImage(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        var hwnd = WindowNative.GetWindowHandle(App.MainAppWindow);
        InitializeWithWindow.Initialize(picker, hwnd);
        picker.FileTypeFilter.Add(".png");
        picker.FileTypeFilter.Add(".jpg");
        picker.FileTypeFilter.Add(".jpeg");
        picker.FileTypeFilter.Add(".webp");
        var f = await picker.PickSingleFileAsync();
        if (f != null) { _imagePath = f.Path; TxtImagePath.Text = Path.GetFileName(_imagePath); }
    }

    private async void OnPickAudio(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        var hwnd = WindowNative.GetWindowHandle(App.MainAppWindow);
        InitializeWithWindow.Initialize(picker, hwnd);
        picker.FileTypeFilter.Add(".mp3");
        picker.FileTypeFilter.Add(".wav");
        picker.FileTypeFilter.Add(".m4a");
        var f = await picker.PickSingleFileAsync();
        if (f != null) { _audioPath = f.Path; TxtAudioPath.Text = Path.GetFileName(_audioPath); }
    }

    private async void OnSubmit(object sender, RoutedEventArgs e)
    {
        var key = SettingsService.LoadApiKey();
        if (string.IsNullOrEmpty(key)) { TxtStatus.Text = "请先在「设置」中填入 API Key。"; return; }
        if (string.IsNullOrWhiteSpace(TxtPrompt.Text)) { TxtStatus.Text = "请输入提示词。"; return; }

        BtnSubmit.IsEnabled = false;
        PbVideo.Visibility = Visibility.Visible;
        PbVideo.IsIndeterminate = true;
        TxtStatus.Text = "正在提交…";
        try
        {
            var client = new DashScopeClient(key);
            var svc = new VideoGenerationService(client);
            var req = new VideoGenRequest
            {
                Prompt = TxtPrompt.Text.Trim(),
                ReferenceImagePath = _imagePath,
                ReferenceAudioPath = _audioPath,
                Resolution = (CmbResolution.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "720P",
                Duration = int.Parse((CmbDuration.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "10"),
                ShotType = (CmbShotType.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? "multi",
                PromptExtend = ChkPromptExtend.IsChecked == true,
            };
            var progress = new Progress<VideoGenStatus>(s =>
            {
                TxtStatus.Text = $"任务 {s.TaskId[..Math.Min(8, s.TaskId.Length)]}… 状态:{s.Status}";
                if (s.Status == "SUCCEEDED" && s.VideoUrl != null) PbVideo.IsIndeterminate = false;
            });
            var videoUrl = await svc.GenerateAsync(req, progress);
            var outPath = Path.Combine(SettingsService.OutputDirectory, $"clip_{DateTime.Now:yyyyMMdd_HHmmss}.mp4");
            TxtStatus.Text = "下载到本地…";
            await client.DownloadAsync(videoUrl, outPath);
            TxtStatus.Text = $"✅ 已下载:{outPath}";
        }
        catch (Exception ex) { TxtStatus.Text = "❌ " + ex.Message; }
        finally { PbVideo.Visibility = Visibility.Collapsed; PbVideo.IsIndeterminate = false; BtnSubmit.IsEnabled = true; }
    }
}
