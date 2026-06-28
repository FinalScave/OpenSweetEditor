using System;
using System.IO;
using System.Text.Json;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoSettings
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SweetEditor",
        "demo_settings.json");

    public bool DarkTheme { get; set; } = true;

    public bool UseVsCodeKeyMap { get; set; } = true;

    public bool InlineSuggestionAutoEnabled { get; set; } = true;

    public bool PerfOverlayEnabled { get; set; }

    public WrapMode WrapMode { get; set; } = WrapMode.NONE;

    public float CurrentScale { get; set; } = 1.0f;

    public string? LastSampleFileName { get; set; }

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
}
