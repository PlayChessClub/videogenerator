using ClipForgeAI.Win.Models;
using ClipForgeAI.Win.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace ClipForgeAI.Win.Views;

public sealed partial class SettingsPage : Page
{
    public SettingsPage()
    {
        this.InitializeComponent();
        Loaded += (_, __) => Refresh();
    }

    private void Refresh()
    {
        var key = SettingsService.LoadApiKey();
        PbKey.Password = key ?? "";
        TxtStatus.Text = string.IsNullOrEmpty(key) ? "尚未保存 API Key" : "✓ 已加密保存到本地";
        TxtTts.Text = $"语音合成:{FixedModel.Tts}";
        TxtVoice.Text = $"音色复刻:{FixedModel.VoiceEnrollment}";
        TxtVideo.Text = $"图生视频:{FixedModel.VideoI2V}";
        TxtOutDir.Text = SettingsService.OutputDirectory;
    }

    private void OnSave(object sender, RoutedEventArgs e)
    {
        try { SettingsService.SaveApiKey(PbKey.Password); TxtStatus.Text = "✓ 已加密保存到本地"; }
        catch (System.Exception ex) { TxtStatus.Text = "保存失败:" + ex.Message; }
    }

    private void OnDelete(object sender, RoutedEventArgs e)
    {
        SettingsService.DeleteApiKey();
        PbKey.Password = "";
        TxtStatus.Text = "已清除";
    }
}
