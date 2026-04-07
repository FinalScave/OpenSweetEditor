using System;
using Android.App;
using Android.Content.PM;
using Android.OS;
using Android.Views;
using Avalonia;
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
public sealed class MainActivity : AvaloniaMainActivity<App>
{
    private static readonly object ActivityLock = new();
    private static MainActivity? current;

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
        Window?.AddFlags(WindowManagerFlags.HardwareAccelerated);
        Window?.SetSoftInputMode(SoftInput.AdjustResize);
        
        base.OnCreate(savedInstanceState);
        
        lock (ActivityLock)
        {
            current = this;
        }
    }

    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
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
}
