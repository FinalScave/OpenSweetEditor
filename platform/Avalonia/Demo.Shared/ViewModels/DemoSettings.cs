using System;
using System.IO;
using System.Text.Json;
using System.Threading.Tasks;

namespace SweetEditor.Avalonia.Demo.ViewModels;

/// <summary>
/// Demo应用程序的用户设置模型类，用于持久化存储用户偏好配置。
/// 设置文件保存在用户应用数据目录下的SweetEditor文件夹中。
/// </summary>
public sealed class DemoSettings
{
    private static readonly string SettingsPath = Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "SweetEditor",
        "demo_settings.json");

    /// <summary>
    /// 是否启用深色主题。默认为true。
    /// </summary>
    public bool DarkTheme { get; set; } = true;

    /// <summary>
    /// 是否使用VS Code风格的键盘映射。默认为true。
    /// </summary>
    public bool UseVsCodeKeyMap { get; set; } = true;

    /// <summary>
    /// 是否自动启用内联建议功能。默认为true。
    /// </summary>
    public bool InlineSuggestionAutoEnabled { get; set; } = true;

    /// <summary>
    /// 是否启用性能监控覆盖层。默认为false。
    /// </summary>
    public bool PerfOverlayEnabled { get; set; }

    /// <summary>
    /// 文本换行模式。默认为不换行。
    /// </summary>
    public WrapMode WrapMode { get; set; } = WrapMode.NONE;

    /// <summary>
    /// 当前UI缩放比例。默认为1.0（100%）。
    /// </summary>
    public float CurrentScale { get; set; } = 1.0f;

    /// <summary>
    /// 上次打开的示例文件名。用于恢复用户上次的工作状态。
    /// </summary>
    public string? LastSampleFileName { get; set; }

    /// <summary>
    /// 窗口宽度（像素）。默认为1440。
    /// </summary>
    public double WindowWidth { get; set; } = 1440;

    /// <summary>
    /// 窗口高度（像素）。默认为920。
    /// </summary>
    public double WindowHeight { get; set; } = 920;

    /// <summary>
    /// 是否在启动时显示欢迎界面。默认为true。
    /// </summary>
    public bool ShowWelcome { get; set; } = true;

    /// <summary>
    /// 从设置文件加载用户设置。
    /// 如果设置文件不存在或读取失败，返回默认设置。
    /// </summary>
    /// <returns>加载的设置实例或默认设置实例</returns>
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
    /// 同步保存当前设置到设置文件。
    /// 如果目录不存在会自动创建。
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
    /// 异步保存当前设置到设置文件。
    /// 如果目录不存在会自动创建。
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
