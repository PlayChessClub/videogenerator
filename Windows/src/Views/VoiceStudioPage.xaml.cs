using System;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using ClipForgeAI.Win.Models;
using ClipForgeAI.Win.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Storage.Pickers;
using WinRT.Interop;

namespace ClipForgeAI.Win.Views;

public sealed partial class VoiceStudioPage : Page
{
    private string? _cloneAudioPath;
    public VoiceStudioPage()
    {
        this.InitializeComponent();
        Loaded += async (_, __) => await LoadVoicesAsync();
    }

    private async void OnPickCloneAudio(object sender, RoutedEventArgs e)
    {
        var picker = new FileOpenPicker();
        var hwnd = WindowNative.GetWindowHandle(App.MainAppWindow);
        InitializeWithWindow.Initialize(picker, hwnd);
        picker.FileTypeFilter.Add(".wav");
        picker.FileTypeFilter.Add(".mp3");
        picker.FileTypeFilter.Add(".m4a");
        var file = await picker.PickSingleFileAsync();
        if (file != null)
        {
            _cloneAudioPath = file.Path;
            TxtClonePath.Text = Path.GetFileName(_cloneAudioPath);
        }
    }

    private async void OnSubmitClone(object sender, RoutedEventArgs e)
    {
        var key = SettingsService.LoadApiKey();
        if (string.IsNullOrEmpty(key)) { TxtCloneStatus.Text = "请先在「设置」中填入 API Key。"; return; }
        if (string.IsNullOrEmpty(_cloneAudioPath)) { TxtCloneStatus.Text = "请先选择参考音频。"; return; }
        BtnSubmitClone.IsEnabled = false;
        TxtCloneStatus.Text = "正在上传音频到 DashScope OSS…";
        try
        {
            var client = new DashScopeClient(key);
            var url = await client.UploadToOssAsync(_cloneAudioPath);
            TxtCloneStatus.Text = "已上传,提交克隆任务…";
            var voiceId = await client.CreateVoiceAsync(TxtPrefix.Text.Trim(), url);
            TxtCloneStatus.Text = $"已提交,voice_id = {voiceId},开始轮询…";
            for (int i = 0; i < 30; i++)
            {
                await Task.Delay(TimeSpan.FromSeconds(10));
                var info = await client.QueryVoiceAsync(voiceId);
                var status = info.GetProperty("output").GetProperty("status").GetString();
                TxtCloneStatus.Text = $"轮询 #{i+1}: status = {status}";
                if (status == "OK") { TxtCloneStatus.Text = $"✅ 克隆成功:{voiceId}"; break; }
                if (status == "UNDEPLOYED") { TxtCloneStatus.Text = "❌ 克隆失败(音频质量不达标)"; break; }
            }
            await LoadVoicesAsync();
        }
        catch (Exception ex) { TxtCloneStatus.Text = "❌ " + ex.Message; }
        finally { BtnSubmitClone.IsEnabled = true; }
    }

    private async void OnRefreshVoices(object sender, RoutedEventArgs e) => await LoadVoicesAsync();

    private async Task LoadVoicesAsync()
    {
        try
        {
            var key = SettingsService.LoadApiKey();
            if (string.IsNullOrEmpty(key)) return;
            var client = new DashScopeClient(key);
            var json = await client.ListVoicesAsync(TxtPrefix.Text.Trim());
            var voices = json.GetProperty("output").GetProperty("voices").EnumerateArray()
                .Select(v => v.GetProperty("voice_id").GetString() ?? "")
                .Where(s => !string.IsNullOrEmpty(s))
                .ToList();
            CmbVoices.ItemsSource = voices;
        }
        catch { /* 静默:用户可能未设置 key */ }
    }

    private async void OnSynthesize(object sender, RoutedEventArgs e)
    {
        var key = SettingsService.LoadApiKey();
        if (string.IsNullOrEmpty(key)) { TxtTtsStatus.Text = "请先在「设置」中填入 API Key。"; return; }
        if (string.IsNullOrWhiteSpace(TxtTtsText.Text)) { TxtTtsStatus.Text = "请输入要合成的文本。"; return; }
        var voice = CmbVoices.SelectedItem as string;
        if (string.IsNullOrEmpty(voice)) { TxtTtsStatus.Text = "请选择一个音色。"; return; }

        PbTts.Visibility = Visibility.Visible;
        BtnSynthesize.IsEnabled = false;
        TxtTtsStatus.Text = "合成中…";
        try
        {
            var outPath = Path.Combine(SettingsService.OutputDirectory, $"tts_{DateTime.Now:yyyyMMdd_HHmmss}.mp3");
            var tts = new CosyVoiceTtsService(key);
            var req = new TtsRequest
            {
                Text = TxtTtsText.Text,
                VoiceId = voice,
                Volume = 1.0 + SldVolume.Value / 100.0,
                Rate = 1.0 + SldRate.Value / 100.0,
                Pitch = 1.0 + SldPitch.Value / 100.0,
            };
            var progress = new Progress<double>(p => PbTts.Value = p * 100);
            await tts.SynthesizeAsync(req, outPath, progress);
            TxtTtsStatus.Text = $"✅ 已保存:{outPath}";
        }
        catch (Exception ex) { TxtTtsStatus.Text = "❌ " + ex.Message; }
        finally { PbTts.Visibility = Visibility.Collapsed; BtnSynthesize.IsEnabled = true; }
    }
}
