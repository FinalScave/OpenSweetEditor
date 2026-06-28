using System;
using Android.App;
using Android.Runtime;
using global::Avalonia;
using global::Avalonia.Android;
using global::Avalonia.Controls;
using global::Avalonia.Controls.ApplicationLifetimes;
using global::Avalonia.Themes.Fluent;
using SweetEditor.Avalonia.Demo;

namespace SweetEditor.Avalonia.Demo.Android;

public sealed class App : global::Avalonia.Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
    }

    public override void OnFrameworkInitializationCompleted()
    {
        switch (ApplicationLifetime)
        {
            case IActivityApplicationLifetime activity:
                activity.MainViewFactory = () => new DeferredMainViewHost();
                break;
            case ISingleViewApplicationLifetime singleView:
                singleView.MainView = new DeferredMainViewHost();
                break;
            case IClassicDesktopStyleApplicationLifetime desktop:
                desktop.MainWindow = new Window
                {
                    Title = "SweetEditor Avalonia Demo.Android",
                    Width = 1400,
                    Height = 900,
                    Content = new DeferredMainViewHost(),
                };
                break;
        }

        base.OnFrameworkInitializationCompleted();
    }
}

[Application]
public class AndroidApp : AvaloniaAndroidApplication<App>
{
    public AndroidApp(IntPtr javaReference, JniHandleOwnership transfer)
        : base(javaReference, transfer)
    {
    }

    public override void OnCreate()
    {
        base.OnCreate();
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
}
