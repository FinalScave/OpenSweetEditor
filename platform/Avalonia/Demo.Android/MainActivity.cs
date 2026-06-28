using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Avalonia.Android;

namespace SweetEditor.Avalonia.Demo.Android;

[Activity(
    Label = "SweetEditor Demo",
    Theme = "@style/Theme.AppCompat.DayNight.NoActionBar",
    MainLauncher = true,
    LaunchMode = LaunchMode.SingleTask,
    HardwareAccelerated = true,
    ConfigurationChanges =
        ConfigChanges.Orientation |
        ConfigChanges.ScreenSize |
        ConfigChanges.ScreenLayout |
        ConfigChanges.SmallestScreenSize |
        ConfigChanges.UiMode |
        ConfigChanges.Density)]
public sealed class MainActivity : AvaloniaMainActivity
{
    protected override void OnCreate(Bundle? savedInstanceState)
    {
        Window?.AddFlags(WindowManagerFlags.HardwareAccelerated);
        Window?.SetSoftInputMode(SoftInput.AdjustResize);

        base.OnCreate(savedInstanceState);
    }
}
