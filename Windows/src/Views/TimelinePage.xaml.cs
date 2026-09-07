using System;
using System.Collections.ObjectModel;
using ClipForgeAI.Win.Models;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Storage.Pickers;
using WinRT.Interop;

namespace ClipForgeAI.Win.Views;

public sealed partial class TimelinePage : Page
{
    public ObservableCollection<MediaItem> Clips { get; } = new();

    public TimelinePage()
    {
        this.InitializeComponent();
        LstClips.ItemsSource = Clips;
    }

    private async void OnAddVideo(object sender, RoutedEventArgs e) => await AddFile(MediaKind.Video);
    private async void OnAddAudio(object sender, RoutedEventArgs e) => await AddFile(MediaKind.Audio);

    private async System.Threading.Tasks.Task AddFile(MediaKind kind)
    {
        var picker = new FileOpenPicker();
        var hwnd = WindowNative.GetWindowHandle(App.MainAppWindow);
        InitializeWithWindow.Initialize(picker, hwnd);
        picker.FileTypeFilter.Add(".mp4");
        picker.FileTypeFilter.Add(".mp3");
        picker.FileTypeFilter.Add(".wav");
        picker.FileTypeFilter.Add(".m4a");
        var f = await picker.PickSingleFileAsync();
        if (f != null) Clips.Add(new MediaItem { Name = f.Name, LocalPath = f.Path, Kind = kind });
    }

    private void OnClear(object sender, RoutedEventArgs e)
    {
        Clips.Clear();
        PreviewPlayer.Source = null;
    }

    private void OnClipSelected(object sender, SelectionChangedEventArgs e)
    {
        if (LstClips.SelectedItem is MediaItem m)
            PreviewPlayer.Source = global::Windows.Media.Core.MediaSource.CreateFromUri(new Uri(m.LocalPath));
    }
}
