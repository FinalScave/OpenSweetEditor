using System;
using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Themes.Fluent;
using SweetEditor.Avalonia.Demo.Host;

namespace SweetEditor.Avalonia.Demo.Desktop;

public sealed class App : global::Avalonia.Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
    }

    public override void OnFrameworkInitializationCompleted()
    {
        DemoPlatformServices.Current = null;

        if (ApplicationLifetime is IClassicDesktopStyleApplicationLifetime desktop)
        {
            try
            {
                desktop.MainWindow = new Window
                {
                    Title = "SweetEditor Avalonia Demo",
                    Width = 1440,
                    Height = 920,
                    Content = new global::SweetEditor.Avalonia.Demo.MainView(),
                };
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Failed to create main window: {ex}");
                throw;
            }
        }

        base.OnFrameworkInitializationCompleted();
    }
}
