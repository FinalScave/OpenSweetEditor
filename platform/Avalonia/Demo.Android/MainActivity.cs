using System;
using System.IO;
using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Runtime;
using Android.Util;
using Android.Views;
using Avalonia;
using Avalonia.Android;
using SweetEditor.Avalonia.Demo.Host;

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
public sealed class MainActivity : AvaloniaMainActivity<App>
{
    private const string LogTag = "SweetEditorDemo";
    private const string SweetLineEnvironmentVariable = "SWEETLINE_LIB_PATH";
    private const string SweetLineLibraryName = "libsweetline.so";
    private const string SweetLineAssetName = "libsweetline.asset";
    private static readonly object ActivityLock = new();
    private static MainActivity? current;
    private static bool diagnosticsHooked;

    public static MainActivity? Current
    {
        get
        {
            lock (ActivityLock)
            {
                return current;
            }
        }
    }

    protected override void OnCreate(Bundle? savedInstanceState)
    {
        EnsureDiagnostics();
        DemoHostDiagnostics.WriteLine("MainActivity.OnCreate enter");
        EnsureSweetLineLibraryPath();
        Window?.AddFlags(WindowManagerFlags.HardwareAccelerated);
        Window?.SetSoftInputMode(SoftInput.AdjustResize);
        
        base.OnCreate(savedInstanceState);
        
        lock (ActivityLock)
        {
            current = this;
        }

        DemoHostDiagnostics.WriteLine("MainActivity.OnCreate exit");
    }

    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        DemoHostDiagnostics.WriteLine("MainActivity.CustomizeAppBuilder");
        return base.CustomizeAppBuilder(builder)
            .With(new AndroidPlatformOptions
            {
                RenderingMode =
                [
                    AndroidRenderingMode.Egl,
                    AndroidRenderingMode.Software,
                ],
            });
    }

    protected override void OnDestroy()
    {
        DemoHostDiagnostics.WriteLine("MainActivity.OnDestroy");
        lock (ActivityLock)
        {
            if (ReferenceEquals(current, this))
                current = null;
        }
        base.OnDestroy();
    }

    public static bool TryGetVisibleFrameAndImeTop(out global::Android.Graphics.Rect visibleFrame, out int imeTopOnScreen)
    {
        visibleFrame = new global::Android.Graphics.Rect();
        imeTopOnScreen = 0;

        MainActivity? activity = Current;
        if (activity?.Window?.DecorView == null)
            return false;

        View decorView = activity.Window.DecorView;
        decorView.GetWindowVisibleDisplayFrame(visibleFrame);
        if (visibleFrame.Width() <= 0 || visibleFrame.Height() <= 0)
            return false;

        int imeBottom = 0;
        WindowInsets? insets = OperatingSystem.IsAndroidVersionAtLeast(23) ? decorView.RootWindowInsets : null;
        if (insets != null)
        {
            if (OperatingSystem.IsAndroidVersionAtLeast(30))
                imeBottom = insets.GetInsets(WindowInsets.Type.Ime()).Bottom;
            else
                imeBottom = Math.Max(0, insets.SystemWindowInsetBottom - insets.StableInsetBottom);
        }

        View? rootView = decorView.RootView;
        if (rootView == null || rootView.Height <= 0)
            return true;

        int[] rootLocation = new int[2];
        rootView.GetLocationOnScreen(rootLocation);

        if (imeBottom <= 0)
        {
            global::Android.Graphics.Rect rootVisible = new();
            rootView.GetWindowVisibleDisplayFrame(rootVisible);
            float density = decorView.Resources?.DisplayMetrics?.Density ?? 1f;
            int keyboardThreshold = (int)(80f * Math.Max(1f, density));
            int keyboardHeight = rootView.Height - rootVisible.Height();
            if (keyboardHeight > keyboardThreshold)
            {
                imeTopOnScreen = rootLocation[1] + rootVisible.Bottom;
                if (imeTopOnScreen > visibleFrame.Top && imeTopOnScreen < visibleFrame.Bottom)
                    visibleFrame.Bottom = imeTopOnScreen;
            }
            return true;
        }

        imeTopOnScreen = rootLocation[1] + rootView.Height - imeBottom;
        if (imeTopOnScreen > visibleFrame.Top && imeTopOnScreen < visibleFrame.Bottom)
            visibleFrame.Bottom = imeTopOnScreen;

        return true;
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

    private void EnsureSweetLineLibraryPath()
    {
        try
        {
            string? abi = ResolveSweetLineAbi();
            if (string.IsNullOrWhiteSpace(abi) || Assets == null)
                return;

            string assetPath = $"sweetline/{abi}/{SweetLineAssetName}";
            string rootDirectory = Path.Combine(FilesDir?.AbsolutePath ?? CacheDir?.AbsolutePath ?? AppContext.BaseDirectory, "sweetline", abi);
            Directory.CreateDirectory(rootDirectory);

            string libraryPath = Path.Combine(rootDirectory, SweetLineLibraryName);
            using (var assetStream = Assets.Open(assetPath))
            using (var output = File.Open(libraryPath, FileMode.Create, FileAccess.Write, FileShare.None))
            {
                assetStream.CopyTo(output);
            }

            System.Environment.SetEnvironmentVariable(SweetLineEnvironmentVariable, libraryPath);
            DemoHostDiagnostics.WriteLine($"SweetLine library staged from {assetPath} to {libraryPath}");
        }
        catch (Exception ex)
        {
            DemoHostDiagnostics.WriteException("MainActivity.EnsureSweetLineLibraryPath", ex);
        }
    }

    private static string? ResolveSweetLineAbi()
    {
        var supportedAbis = Build.SupportedAbis;
        if (supportedAbis == null || supportedAbis.Count == 0)
            return null;

        foreach (string abi in supportedAbis)
        {
            if (string.Equals(abi, "arm64-v8a", StringComparison.Ordinal) ||
                string.Equals(abi, "x86_64", StringComparison.Ordinal))
            {
                return abi;
            }
        }

        return null;
    }
}
