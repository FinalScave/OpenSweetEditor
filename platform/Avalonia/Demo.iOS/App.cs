using Avalonia;
using Avalonia.Controls;
using Avalonia.Controls.ApplicationLifetimes;
using Avalonia.Themes.Fluent;
using Foundation;
using SweetEditor.Avalonia.Demo.Host;
using SweetEditor.Avalonia.Demo.iOS.Platform;
using UIKit;

namespace SweetEditor.Avalonia.Demo.iOS;

[Register("AppDelegate")]
public sealed class AppDelegate : AvaloniaAppDelegate<App>
{
    protected override AppBuilder CustomizeAppBuilder(AppBuilder builder)
    {
        return base.CustomizeAppBuilder(builder)
            .WithInterFont();
    }
}

public sealed class App : Application
{
    public override void Initialize()
    {
        Styles.Add(new FluentTheme());
    }

    public override void OnFrameworkInitializationCompleted()
    {
        DemoPlatformServices.Current = new iOSDemoPlatformServices();

        if (ApplicationLifetime is ISingleViewApplicationLifetime singleView)
        {
            singleView.MainView = new DeferredMainViewHost();
        }

        base.OnFrameworkInitializationCompleted();
    }
}
