using global::Avalonia;
using global::Avalonia.Controls;
using global::Avalonia.Controls.ApplicationLifetimes;
using global::Avalonia.Themes.Fluent;
using SweetEditor.Avalonia.Demo.Host;
using SweetEditor.Avalonia.Demo.Android.Platform;

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
        DemoPlatformServices.Current = new AndroidDemoPlatformServices();
        Control mainView = new DeferredMainViewHost();

        switch (ApplicationLifetime)
        {
            case ISingleViewApplicationLifetime singleView:
                singleView.MainView = mainView;
                break;
            case IClassicDesktopStyleApplicationLifetime desktop:
                desktop.MainWindow = new Window
                {
                    Title = "SweetEditor Avalonia Demo.Android",
                    Width = 1400,
                    Height = 900,
                    Content = mainView,
                };
                break;
        }

        DemoHostDiagnostics.WriteLine("App.OnFrameworkInitializationCompleted exit");
        base.OnFrameworkInitializationCompleted();
    }
}
