using System;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using Avalonia.Threading;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

/// <summary>
/// View model for demo state, settings, and UI bindings.
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
    /// Initializes the view model and loads persisted settings.
    /// </summary>
    public MainViewModel()
    {
        settings = DemoSettings.Load();
        ApplySettings(settings);
        Samples = new ObservableCollection<SampleItem>();
    }

    /// <summary>
    /// Raised when a property value changes.
    /// </summary>
    public event PropertyChangedEventHandler? PropertyChanged;

    /// <summary>
    /// Raised when a sample load is requested.
    /// </summary>
#pragma warning disable CS0067
    public event Func<string, Task>? LoadSampleRequested;
#pragma warning restore CS0067

    /// <summary>
    /// Raised when settings should be saved.
    /// </summary>
    public event Action? SaveSettingsRequested;

    /// <summary>
    /// Sample entries shown in the sample picker.
    /// </summary>
    public ObservableCollection<SampleItem> Samples { get; }

    /// <summary>
    /// Whether a document is loading.
    /// </summary>
    public bool IsLoading
    {
        get => isLoading;
        set => SetProperty(ref isLoading, value);
    }

    /// <summary>
    /// Status bar message.
    /// </summary>
    public string StatusMessage
    {
        get => statusMessage;
        set => SetProperty(ref statusMessage, value);
    }

    /// <summary>
    /// Summary text shown on the right side of the status bar.
    /// </summary>
    public string SummaryText
    {
        get => summaryText;
        set => SetProperty(ref summaryText, value);
    }

    /// <summary>
    /// Whether the welcome view is visible.
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
    /// Current sample file name.
    /// </summary>
    public string? CurrentSampleName
    {
        get => currentSampleName;
        set => SetProperty(ref currentSampleName, value);
    }

    /// <summary>
    /// Current language identifier.
    /// </summary>
    public string? CurrentLanguageId
    {
        get => currentLanguageId;
        set => SetProperty(ref currentLanguageId, value);
    }

    /// <summary>
    /// Whether dark theme is enabled.
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
    /// Current text wrapping mode.
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
    /// Current UI scale.
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
    /// Whether the performance overlay is enabled.
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
    /// Whether VS Code style key bindings are enabled.
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
    /// Whether inline suggestions are enabled automatically.
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
    /// One-based cursor line.
    /// </summary>
    public int CursorLine
    {
        get => cursorLine;
        set => SetProperty(ref cursorLine, value);
    }

    /// <summary>
    /// One-based cursor column.
    /// </summary>
    public int CursorColumn
    {
        get => cursorColumn;
        set => SetProperty(ref cursorColumn, value);
    }

    /// <summary>
    /// Total document line count.
    /// </summary>
    public int TotalLines
    {
        get => totalLines;
        set => SetProperty(ref totalLines, value);
    }

    /// <summary>
    /// Whether undo is available.
    /// </summary>
    public bool CanUndo
    {
        get => canUndo;
        set => SetProperty(ref canUndo, value);
    }

    /// <summary>
    /// Whether redo is available.
    /// </summary>
    public bool CanRedo
    {
        get => canRedo;
        set => SetProperty(ref canRedo, value);
    }

    /// <summary>
    /// Whether the document has finished loading.
    /// </summary>
    public bool IsDocumentLoaded
    {
        get => isDocumentLoaded;
        set => SetProperty(ref isDocumentLoaded, value);
    }

    /// <summary>
    /// Formatted cursor position text.
    /// </summary>
    public string CursorPositionText => $"Ln {CursorLine}, Col {CursorColumn}";

    /// <summary>
    /// Formatted scale text.
    /// </summary>
    public string ScaleText => $"{CurrentScale * 100:F0}%";

    /// <summary>
    /// Formatted wrap mode text.
    /// </summary>
    public string WrapModeText => WrapMode switch
    {
        WrapMode.WORD_BREAK => "Word Wrap",
        WrapMode.CHAR_BREAK => "Char Wrap",
        _ => "No Wrap"
    };

    /// <summary>
    /// Updates the sample file list.
    /// </summary>
    /// <param name="files">Sample files.</param>
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
    /// Updates the cursor position.
    /// </summary>
    /// <param name="line">Zero-based line.</param>
    /// <param name="column">Zero-based column.</param>
    public void UpdateCursorPosition(int line, int column)
    {
        CursorLine = line + 1;
        CursorColumn = column + 1;
        OnPropertyChanged(nameof(CursorPositionText));
    }

    /// <summary>
    /// Updates the UI scale.
    /// </summary>
    /// <param name="scale">UI scale.</param>
    public void UpdateScale(float scale)
    {
        CurrentScale = scale;
        OnPropertyChanged(nameof(ScaleText));
    }

    /// <summary>
    /// Updates the text wrapping mode.
    /// </summary>
    /// <param name="mode">Text wrapping mode.</param>
    public void UpdateWrapMode(WrapMode mode)
    {
        WrapMode = mode;
        OnPropertyChanged(nameof(WrapModeText));
    }

    /// <summary>
    /// Gets the current settings instance.
    /// </summary>
    /// <returns>The settings instance.</returns>
    public DemoSettings GetSettings() => settings;

    /// <summary>
    /// Saves the current settings.
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
    /// Saves settings before disposing the view model.
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
/// Sample item displayed in the sample picker.
/// </summary>
public sealed class SampleItem
{
    /// <summary>
    /// File name.
    /// </summary>
    public string FileName { get; set; } = "";

    /// <summary>
    /// Language identifier.
    /// </summary>
    public string LanguageId { get; set; } = "";

    /// <summary>
    /// Whether this sample is generated.
    /// </summary>
    public bool IsGenerated { get; set; }

    /// <summary>
    /// Display name shown in the picker.
    /// </summary>
    public string DisplayName => IsGenerated ? $"{FileName} (generated)" : FileName;
}
