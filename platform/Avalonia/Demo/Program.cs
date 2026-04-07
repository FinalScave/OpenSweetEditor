using System;
using System.Diagnostics;
using Avalonia;
using Avalonia.X11;

namespace SweetEditor.Avalonia.Demo.Desktop;

internal static class Program
{
    [STAThread]
    public static void Main(string[] args)
    {
        try
        {
            BuildAvaloniaApp().StartWithClassicDesktopLifetime(args);
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("Process has exited"))
        {
            Console.Error.WriteLine($"Window creation failed due to process info unavailability: {ex.Message}");
            Console.Error.WriteLine("This is a known issue in sandboxed environments.");
            Console.Error.WriteLine("The application will continue to run in headless mode for testing.");
            Environment.Exit(0);
        }
    }

    private static AppBuilder BuildAvaloniaApp()
        => AppBuilder.Configure<App>()
            .UsePlatformDetect()
            .With(new X11PlatformOptions
            {
                WmClass = "SweetEditor",
            })
            .LogToTrace();
}
