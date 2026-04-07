using Avalonia;
using SweetEditor.Avalonia.Demo.Desktop;

namespace SweetEditor.Avalonia.Demo.Desktop;

/// <summary>
/// Desktop application entry point.
/// </summary>
public static class Program
{
    public static void Main(string[] args)
    {
        BuildAvaloniaApp()
            .StartWithClassicDesktopLifetime(args);
    }

    private static AppBuilder BuildAvaloniaApp()
    {
        return AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .WithInterFont()
            .LogToTrace();
    }
}
