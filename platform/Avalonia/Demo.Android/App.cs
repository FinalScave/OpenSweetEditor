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
        DemoHostDiagnostics.InstallGlobalHandlers("Android.App.Initialize");
        DemoHostDiagnostics.WriteLine("App.Initialize");
        Styles.Add(new FluentTheme());
    }

    public override void OnFrameworkInitializationCompleted()
    {
        DemoHostDiagnostics.WriteLine("App.OnFrameworkInitializationCompleted enter");

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

        DemoHostDiagnostics.WriteLine("App.OnFrameworkInitializationCompleted exit");
        base.OnFrameworkInitializationCompleted();
    }
}
