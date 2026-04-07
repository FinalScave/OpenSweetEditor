using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Themes.Fluent;
using SweetEditor.Avalonia.Demo.Host;
using SweetEditor.Avalonia.Demo.Mac.Platform;

namespace SweetEditor.Avalonia.Demo.Mac;

/// <summary>
/// macOS platform application entry point.
/// </summary>
public sealed class App : Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
    }

    public override void OnFrameworkInitializationCompleted()
    {
        DemoPlatformServices.Current = new MacDemoPlatformServices();

        Control mainView = new DeferredMainViewHost();

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            desktop.MainWindow = new Window
            {
                Title = "SweetEditor Demo - macOS",
                Width = 1440,
                Height = 920,
                MinWidth = 800,
                MinHeight = 600,
                Content = mainView,
                WindowStartupLocation = WindowStartupLocation.CenterScreen,
            };

            desktop.Exit += OnApplicationExit;
        }

        base.OnFrameworkInitializationCompleted();
    }

    private void OnApplicationExit(object? sender, ControlledApplicationLifetimeExitEventArgs e)
    {
        DemoPlatformServices.Current?.Dispose();
    }
}
