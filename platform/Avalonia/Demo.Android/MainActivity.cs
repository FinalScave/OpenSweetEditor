using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Util;
using Android.Views;
using Avalonia.Android;
using SweetEditor.Avalonia.Demo;

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
    private const string LogTag = "SweetEditorDemo";
    private static readonly object ActivityLock = new();
    private static bool diagnosticsHooked;

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        EnsureDiagnostics();
        DemoHostDiagnostics.WriteLine("MainActivity.OnCreate enter");
        Window?.AddFlags(WindowManagerFlags.HardwareAccelerated);
        Window?.SetSoftInputMode(SoftInput.AdjustResize);

        base.OnCreate(savedInstanceState);

        DemoHostDiagnostics.WriteLine("MainActivity.OnCreate exit");
    }

    protected override void OnDestroy()
    {
        DemoHostDiagnostics.WriteLine("MainActivity.OnDestroy");
        base.OnDestroy();
    }

    private static void EnsureDiagnostics()
    {
        lock (ActivityLock)
        {
            if (diagnosticsHooked)
                return;

            DemoHostDiagnostics.InstallGlobalHandlers("Android.MainActivity");
            AndroidEnvironment.UnhandledExceptionRaiser += (_, e) =>
            {
                DemoHostDiagnostics.WriteException("AndroidEnvironment.UnhandledExceptionRaiser", e.Exception);
                try
                {
                    Log.Error(LogTag, e.Exception.ToString());
                }
                catch
                {
                    // ignore logcat failures
                }
            };

            diagnosticsHooked = true;
        }
    }
}
