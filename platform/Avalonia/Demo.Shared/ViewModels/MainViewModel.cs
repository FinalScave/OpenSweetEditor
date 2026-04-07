using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using Avalonia.Threading;
using SweetEditor;
using SweetEditor.Avalonia.Demo.UI.Samples;

namespace SweetEditor.Avalonia.Demo.ViewModels;

/// <summary>
/// Demo应用程序的主视图模型类，实现MVVM模式。
/// 负责管理应用程序的状态、用户设置和UI数据绑定。
/// </summary>
public sealed class MainViewModel : INotifyPropertyChanged, IDisposable
{
    private readonly DemoSettings settings;
    private bool isLoading;
    private string statusMessage = "Ready";
    private string summaryText = "";
    private bool showWelcome;
    private string? currentSampleName;
    private string? currentLanguageId;
    private bool darkTheme = true;
    private WrapMode wrapMode = WrapMode.NONE;
    private float currentScale = 1.0f;
    private bool perfOverlayEnabled;
    private bool useVsCodeKeyMap = true;
    private bool inlineSuggestionAutoEnabled = true;
    private int cursorLine = 1;
    private int cursorColumn = 1;
    private int totalLines;
    private bool canUndo;
    private bool canRedo;
    private bool isDocumentLoaded;

    /// <summary>
    /// 初始化MainViewModel实例，加载用户设置。
    /// </summary>
    public MainViewModel()
    {
        settings = DemoSettings.Load();
        ApplySettings(settings);
        Samples = new ObservableCollection<SampleItem>();
    }

    /// <summary>
    /// 属性变更事件，用于通知UI更新。
    /// </summary>
    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// 加载示例文件请求事件。
    /// </summary>
    public event Func<string, Task>? LoadSampleRequested;

    /// <summary>
    /// 保存设置请求事件。
    /// </summary>
    public event Action? SaveSettingsRequested;

    /// <summary>
    /// 示例文件集合，用于绑定到示例选择器。
    /// </summary>
    public ObservableCollection<SampleItem> Samples { get; }

    /// <summary>
    /// 是否正在加载文档。
    /// </summary>
    public bool IsLoading
    {
        get => isLoading;
        set => SetProperty(ref isLoading, value);
    }

    /// <summary>
    /// 状态栏消息文本。
    /// </summary>
    public string StatusMessage
    {
        get => statusMessage;
        set => SetProperty(ref statusMessage, value);
    }

    /// <summary>
    /// 摘要文本，显示在状态栏右侧。
    /// </summary>
    public string SummaryText
    {
        get => summaryText;
        set => SetProperty(ref summaryText, value);
    }

    /// <summary>
    /// 是否显示欢迎界面。
    /// </summary>
    public bool ShowWelcome
    {
        get => showWelcome;
        set
        {
            if (SetProperty(ref showWelcome, value))
            {
                settings.ShowWelcome = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 当前示例文件名。
    /// </summary>
    public string? CurrentSampleName
    {
        get => currentSampleName;
        set => SetProperty(ref currentSampleName, value);
    }

    /// <summary>
    /// 当前语言ID。
    /// </summary>
    public string? CurrentLanguageId
    {
        get => currentLanguageId;
        set => SetProperty(ref currentLanguageId, value);
    }

    /// <summary>
    /// 是否启用深色主题。
    /// </summary>
    public bool DarkTheme
    {
        get => darkTheme;
        set
        {
            if (SetProperty(ref darkTheme, value))
            {
                settings.DarkTheme = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 文本换行模式。
    /// </summary>
    public WrapMode WrapMode
    {
        get => wrapMode;
        set
        {
            if (SetProperty(ref wrapMode, value))
            {
                settings.WrapMode = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 当前UI缩放比例。
    /// </summary>
    public float CurrentScale
    {
        get => currentScale;
        set
        {
            if (SetProperty(ref currentScale, value))
            {
                settings.CurrentScale = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 是否启用性能监控覆盖层。
    /// </summary>
    public bool PerfOverlayEnabled
    {
        get => perfOverlayEnabled;
        set
        {
            if (SetProperty(ref perfOverlayEnabled, value))
            {
                settings.PerfOverlayEnabled = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 是否使用VS Code风格的键盘映射。
    /// </summary>
    public bool UseVsCodeKeyMap
    {
        get => useVsCodeKeyMap;
        set
        {
            if (SetProperty(ref useVsCodeKeyMap, value))
            {
                settings.UseVsCodeKeyMap = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 是否自动启用内联建议功能。
    /// </summary>
    public bool InlineSuggestionAutoEnabled
    {
        get => inlineSuggestionAutoEnabled;
        set
        {
            if (SetProperty(ref inlineSuggestionAutoEnabled, value))
            {
                settings.InlineSuggestionAutoEnabled = value;
                RequestSaveSettings();
            }
        }
    }

    /// <summary>
    /// 光标所在行号（从1开始）。
    /// </summary>
    public int CursorLine
    {
        get => cursorLine;
        set => SetProperty(ref cursorLine, value);
    }

    /// <summary>
    /// 光标所在列号（从1开始）。
    /// </summary>
    public int CursorColumn
    {
        get => cursorColumn;
        set => SetProperty(ref cursorColumn, value);
    }

    /// <summary>
    /// 文档总行数。
    /// </summary>
    public int TotalLines
    {
        get => totalLines;
        set => SetProperty(ref totalLines, value);
    }

    /// <summary>
    /// 是否可以执行撤销操作。
    /// </summary>
    public bool CanUndo
    {
        get => canUndo;
        set => SetProperty(ref canUndo, value);
    }

    /// <summary>
    /// 是否可以执行重做操作。
    /// </summary>
    public bool CanRedo
    {
        get => canRedo;
        set => SetProperty(ref canRedo, value);
    }

    /// <summary>
    /// 文档是否已加载完成。
    /// </summary>
    public bool IsDocumentLoaded
    {
        get => isDocumentLoaded;
        set => SetProperty(ref isDocumentLoaded, value);
    }

    /// <summary>
    /// 光标位置文本，格式为"Ln X, Col Y"。
    /// </summary>
    public string CursorPositionText => $"Ln {CursorLine}, Col {CursorColumn}";

    /// <summary>
    /// 缩放比例文本，格式为"XX%"。
    /// </summary>
    public string ScaleText => $"{CurrentScale * 100:F0}%";

    /// <summary>
    /// 换行模式文本描述。
    /// </summary>
    public string WrapModeText => WrapMode switch
    {
        WrapMode.WORD_BREAK => "Word Wrap",
        WrapMode.CHAR_BREAK => "Char Wrap",
        _ => "No Wrap"
    };

    /// <summary>
    /// 更新示例文件列表。
    /// </summary>
    /// <param name="files">示例文件列表</param>
    public void UpdateSamples(System.Collections.Generic.IReadOnlyList<DemoSampleFile> files)
    {
        Dispatcher.UIThread.Post(() =>
        {
            Samples.Clear();
            foreach (var file in files)
            {
                Samples.Add(new SampleItem
                {
                    FileName = file.FileName,
                    LanguageId = file.LanguageId,
                    IsGenerated = file.IsGenerated
                });
            }
        });
    }

    /// <summary>
    /// 更新光标位置。
    /// </summary>
    /// <param name="line">行号（从0开始）</param>
    /// <param name="column">列号（从0开始）</param>
    public void UpdateCursorPosition(int line, int column)
    {
        CursorLine = line + 1;
        CursorColumn = column + 1;
        OnPropertyChanged(nameof(CursorPositionText));
    }

    /// <summary>
    /// 更新缩放比例。
    /// </summary>
    /// <param name="scale">缩放比例</param>
    public void UpdateScale(float scale)
    {
        CurrentScale = scale;
        OnPropertyChanged(nameof(ScaleText));
    }

    /// <summary>
    /// 更新换行模式。
    /// </summary>
    /// <param name="mode">换行模式</param>
    public void UpdateWrapMode(WrapMode mode)
    {
        WrapMode = mode;
        OnPropertyChanged(nameof(WrapModeText));
    }

    /// <summary>
    /// 获取当前设置实例。
    /// </summary>
    /// <returns>设置实例</returns>
    public DemoSettings GetSettings() => settings;

    /// <summary>
    /// 保存当前设置到文件。
    /// </summary>
    public void SaveCurrentSettings()
    {
        settings.DarkTheme = DarkTheme;
        settings.WrapMode = WrapMode;
        settings.CurrentScale = CurrentScale;
        settings.PerfOverlayEnabled = PerfOverlayEnabled;
        settings.UseVsCodeKeyMap = UseVsCodeKeyMap;
        settings.InlineSuggestionAutoEnabled = InlineSuggestionAutoEnabled;
        settings.LastSampleFileName = CurrentSampleName;
        settings.Save();
    }

    /// <summary>
    /// 释放资源并保存设置。
    /// </summary>
    public void Dispose()
    {
        SaveCurrentSettings();
    }

    private void ApplySettings(DemoSettings s)
    {
        darkTheme = s.DarkTheme;
        wrapMode = s.WrapMode;
        currentScale = s.CurrentScale;
        perfOverlayEnabled = s.PerfOverlayEnabled;
        useVsCodeKeyMap = s.UseVsCodeKeyMap;
        inlineSuggestionAutoEnabled = s.InlineSuggestionAutoEnabled;
        showWelcome = s.ShowWelcome;
        currentSampleName = s.LastSampleFileName;
    }

    private void RequestSaveSettings()
    {
        SaveSettingsRequested?.Invoke();
    }

    private bool SetProperty<T>(ref T field, T value, [CallerMemberName] string? propertyName = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value))
            return false;
        field = value;
        OnPropertyChanged(propertyName);
        return true;
    }

    private void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }
}

/// <summary>
/// 示例文件项，用于在示例选择器中显示。
/// </summary>
public sealed class SampleItem
{
    /// <summary>
    /// 文件名。
    /// </summary>
    public string FileName { get; set; } = "";

    /// <summary>
    /// 语言ID。
    /// </summary>
    public string LanguageId { get; set; } = "";

    /// <summary>
    /// 是否为生成的示例。
    /// </summary>
    public bool IsGenerated { get; set; }

    /// <summary>
    /// 显示名称，生成的示例会添加"(generated)"后缀。
    /// </summary>
    public string DisplayName => IsGenerated ? $"{FileName} (generated)" : FileName;
}
