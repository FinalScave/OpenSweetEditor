using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace SweetEditor.Avalonia.Demo.Host;

public static class DemoHostDiagnostics
{
    private static readonly object Gate = new();
    private static bool handlersInstalled;
    private static string? logFilePath;

    public static void InstallGlobalHandlers(string source)
    {
        lock (Gate)
        {
            if (handlersInstalled)
                return;

            AppDomain.CurrentDomain.UnhandledException += (_, e) =>
            {
                if (e.ExceptionObject is Exception ex)
                    WriteException($"Unhandled exception from {source}", ex);
                else
                    WriteLine($"Unhandled exception from {source}: {e.ExceptionObject}");
            };

            TaskScheduler.UnobservedTaskException += (_, e) =>
            {
                WriteException($"Unobserved task exception from {source}", e.Exception);
            };

            handlersInstalled = true;
        }

        WriteLine($"Installed host diagnostics from {source}");
    }

    public static void WriteLine(string message)
    {
        string line = $"[{DateTimeOffset.Now:yyyy-MM-dd HH:mm:ss.fff zzz}] {message}";
        Console.Error.WriteLine(line);

        lock (Gate)
        {
            try
            {
                string path = GetLogFilePath();
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                File.AppendAllText(path, line + Environment.NewLine, Encoding.UTF8);
            }
            catch
            {
                // Ignore logging failures. Diagnostics must never crash the app.
            }
        }
    }

    public static void WriteException(string context, Exception ex)
    {
        WriteLine($"{context}: {ex}");
    }

    public static string GetLogFilePath()
    {
        lock (Gate)
        {
            logFilePath ??= BuildLogFilePath();
            return logFilePath;
        }
    }

    private static string BuildLogFilePath()
    {
        string root = string.Empty;
        try
        {
            root = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        }
        catch
        {
            root = string.Empty;
        }

        if (string.IsNullOrWhiteSpace(root))
            root = AppContext.BaseDirectory;

        return Path.Combine(root, "sweeteditor-demo-startup.log");
    }
}
