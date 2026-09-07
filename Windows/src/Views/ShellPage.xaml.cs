using Microsoft.UI.Xaml.Controls;

namespace ClipForgeAI.Win.Views;

public sealed partial class ShellPage : Page
{
    public ShellPage()
    {
        this.InitializeComponent();
        Nav.SelectedItem = Nav.MenuItems[0];
        ContentFrame.Navigate(typeof(VoiceStudioPage));
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is NavigationViewItem item)
        {
            switch (item.Tag as string)
            {
                case "voice": ContentFrame.Navigate(typeof(VoiceStudioPage)); break;
                case "video": ContentFrame.Navigate(typeof(VideoStudioPage)); break;
                case "timeline": ContentFrame.Navigate(typeof(TimelinePage)); break;
                case "settings": ContentFrame.Navigate(typeof(SettingsPage)); break;
            }
        }
    }
}
