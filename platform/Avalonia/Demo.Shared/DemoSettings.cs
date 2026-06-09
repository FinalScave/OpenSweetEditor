using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace SweetEditor.Avalonia.Demo;

/// <summary>
/// Stores persisted user preferences for the demo application.
/// </summary>
public sealed class DemoSettings
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SweetEditor",
        "demo_settings.json");

    /// <summary>
    /// Whether dark theme is enabled.
    /// </summary>
    public bool DarkTheme { get; set; } = true;

    /// <summary>
    /// Whether VS Code style key bindings are enabled.
    /// </summary>
    public bool UseVsCodeKeyMap { get; set; } = true;

    /// <summary>
    /// Whether inline suggestions are enabled automatically.
    /// </summary>
    public bool InlineSuggestionAutoEnabled { get; set; } = true;

    /// <summary>
    /// Whether the performance overlay is enabled.
    /// </summary>
    public bool PerfOverlayEnabled { get; set; }

    /// <summary>
    /// Current text wrapping mode.
    /// </summary>
    public WrapMode WrapMode { get; set; } = WrapMode.NONE;

    /// <summary>
    /// Current UI scale.
    /// </summary>
    public float CurrentScale { get; set; } = 1.0f;

    /// <summary>
    /// Last opened sample file name.
    /// </summary>
    public string? LastSampleFileName { get; set; }

    /// <summary>
    /// Window width in pixels.
    /// </summary>
    public double WindowWidth { get; set; } = 1440;

    /// <summary>
    /// Window height in pixels.
    /// </summary>
    public double WindowHeight { get; set; } = 920;

    /// <summary>
    /// Whether the welcome view is shown at startup.
    /// </summary>
    public bool ShowWelcome { get; set; } = true;

    /// <summary>
    /// Loads settings from disk, falling back to defaults when unavailable.
    /// </summary>
    /// <returns>The loaded settings or a default instance.</returns>
    public static DemoSettings Load()
    {
        try
        {
            if (!File.Exists(SettingsPath))
                return new DemoSettings();

            string json = File.ReadAllText(SettingsPath);
            return JsonSerializer.Deserialize<DemoSettings>(json) ?? new DemoSettings();
        }
        catch
        {
            return new DemoSettings();
        }
    }

    /// <summary>
    /// Saves the current settings to disk.
    /// </summary>
    public void Save()
    {
        try
        {
            string? directory = Path.GetDirectoryName(SettingsPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                Directory.CreateDirectory(directory);

            string json = JsonSerializer.Serialize(this, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            File.WriteAllText(SettingsPath, json);
        }
        catch
        {
        }
    }

    /// <summary>
    /// Saves the current settings to disk asynchronously.
    /// </summary>
    public async Task SaveAsync()
    {
        try
        {
            string? directory = Path.GetDirectoryName(SettingsPath);
            if (!string.IsNullOrEmpty(directory) && !Directory.Exists(directory))
                Directory.CreateDirectory(directory);

            string json = JsonSerializer.Serialize(this, new JsonSerializerOptions
            {
                WriteIndented = true
            });
            await File.WriteAllTextAsync(SettingsPath, json).ConfigureAwait(false);
        }
        catch
        {
        }
    }
}
