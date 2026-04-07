using Avalonia;
using SweetEditor.Avalonia.Demo.Mac;

namespace SweetEditor.Avalonia.Demo.Mac;

/// <summary>
/// macOS application entry point.
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
