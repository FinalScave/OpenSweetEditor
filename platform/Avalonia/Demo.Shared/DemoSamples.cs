using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Threading;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoSampleFile
{
    private readonly Func<string> contentFactory;
    private string? cachedContent;
    private Task<Document>? documentTask;

    public string FileName { get; }
    public string LanguageId { get; }
    public string Content => cachedContent ??= contentFactory();

    public DemoSampleFile(
        string fileName,
        string languageId,
        Func<string> contentFactory)
    {
        FileName = fileName;
        LanguageId = languageId;
        this.contentFactory = contentFactory;
    }

    public void WarmDocument()
    {
        _ = GetOrCreateDocumentAsync();
    }

    public Task<Document> GetOrCreateDocumentAsync()
        => documentTask ??= Task.Run(() => new Document(Content));
}

internal static class EmbeddedSampleRepository
{
    private const string ResourcePrefix = "SweetEditor.PlatformRes.files.";
    private static readonly string[] EmbeddedSampleNames =
    {
        "example.java",
        "example.kt",
        "example.lua",
        "gc.cpp",
    };

    public static List<DemoSampleFile> LoadAll(Assembly assembly)
        => LoadEmbeddedSamples(assembly);

    private static List<DemoSampleFile> LoadEmbeddedSamples(Assembly assembly)
    {
        var result = new List<DemoSampleFile>(EmbeddedSampleNames.Length);
        foreach (string relativeName in EmbeddedSampleNames)
        {
            string resourceName = ResourcePrefix + relativeName;
            if (assembly.GetManifestResourceInfo(resourceName) == null)
                continue;

            result.Add(new DemoSampleFile(
                relativeName,
                ParseLanguageId(relativeName),
                () => ReadEmbeddedResourceText(assembly, resourceName)));
        }

        return result;
    }

    private static string ParseLanguageId(string fileName)
    {
        string extension = Path.GetExtension(fileName).ToLowerInvariant();
        return extension switch
        {
            ".kt" => "kotlin",
            ".java" => "java",
            ".lua" => "lua",
            ".cpp" or ".cc" or ".cxx" or ".hpp" or ".h" or ".c" => "cpp",
            _ => "plaintext",
        };
    }

    private static string ReadEmbeddedResourceText(Assembly assembly, string resourceName)
    {
        using Stream? stream = assembly.GetManifestResourceStream(resourceName);
        if (stream == null)
            return string.Empty;

        using var reader = new StreamReader(stream, Encoding.UTF8, true, 4096, leaveOpen: false);
        return reader.ReadToEnd();
    }
}

internal sealed class SampleDocumentLoader
{
    private readonly SweetEditorController controller;
    private readonly DemoDecorationProvider decorationProvider;
    private readonly Action<string> updateStatus;
    private readonly Action<string> applyLanguageConfiguration;
    private readonly Func<string?>? getInitialSampleFileName;
    private readonly Action<DemoSampleFile>? beforeLoad;
    private readonly Action<bool>? setPickerEnabled;

    private readonly List<DemoSampleFile> sampleFiles = new();
    private CancellationTokenSource? loadCts;

    public IReadOnlyList<DemoSampleFile> SampleFiles => sampleFiles;
    public DemoSampleFile? SelectedSample { get; private set; }

    public SampleDocumentLoader(
        SweetEditorController controller,
        DemoDecorationProvider decorationProvider,
        Action<string> updateStatus,
        Action<string> applyLanguageConfiguration,
        Func<string?>? getInitialSampleFileName = null,
        Action<DemoSampleFile>? beforeLoad = null,
        Action<bool>? setPickerEnabled = null)
    {
        this.controller = controller;
        this.decorationProvider = decorationProvider;
        this.updateStatus = updateStatus;
        this.applyLanguageConfiguration = applyLanguageConfiguration;
        this.getInitialSampleFileName = getInitialSampleFileName;
        this.beforeLoad = beforeLoad;
        this.setPickerEnabled = setPickerEnabled;
    }

    public void LoadInitialSamples(Assembly assembly)
    {
        sampleFiles.Clear();
        sampleFiles.AddRange(EmbeddedSampleRepository.LoadAll(assembly));

        DemoSampleFile? initialSample = SelectInitialSample();
        SelectedSample = initialSample;
        setPickerEnabled?.Invoke(sampleFiles.Count > 0);

        if (sampleFiles.Count == 0)
        {
            controller.LoadDocument(new Document(string.Empty));
            updateStatus("No demo samples found");
            return;
        }

        updateStatus(initialSample != null
            ? $"Preparing: {initialSample.FileName}"
            : "Preparing demo sample");
        initialSample?.WarmDocument();
        Dispatcher.UIThread.Post(() =>
        {
            if (initialSample != null)
                _ = LoadSampleAsync(initialSample);
        }, DispatcherPriority.Background);
    }

    public async Task LoadSampleAsync(DemoSampleFile sample)
    {
        SelectedSample = sample;
        beforeLoad?.Invoke(sample);

        loadCts?.Cancel();
        loadCts?.Dispose();
        loadCts = new CancellationTokenSource();
        CancellationToken token = loadCts.Token;

        applyLanguageConfiguration(sample.LanguageId);
        updateStatus($"Loading: {sample.FileName}");
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            setPickerEnabled?.Invoke(false);
        });

        try
        {
            string content = await Task.Run(() => sample.Content, token).ConfigureAwait(false);
            decorationProvider.PrimeDocument(sample.FileName, content);
            Document document = await sample.GetOrCreateDocumentAsync().ConfigureAwait(false);
            token.ThrowIfCancellationRequested();

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (token.IsCancellationRequested)
                    return;

                decorationProvider.ActivatePrimedDocument(sample.FileName, content, document);
                controller.LoadDocument(document);
                controller.RequestDecorationRefresh();
                setPickerEnabled?.Invoke(true);
                updateStatus($"Loaded: {sample.FileName}");
            }, DispatcherPriority.Background);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                setPickerEnabled?.Invoke(true);
                updateStatus($"Load failed: {sample.FileName} ({ex.Message})");
            });
        }
    }

    private DemoSampleFile? SelectInitialSample()
    {
        if (sampleFiles.Count == 0)
            return null;

        string? preferredFromSettings = getInitialSampleFileName?.Invoke();
        if (!string.IsNullOrWhiteSpace(preferredFromSettings))
        {
            DemoSampleFile? persisted = sampleFiles.FirstOrDefault(sample =>
                string.Equals(sample.FileName, preferredFromSettings, StringComparison.OrdinalIgnoreCase));
            if (persisted != null)
                return persisted;
        }

        string[] preferredOrder =
        {
            "example.java",
            "example.kt",
            "example.lua",
        };

        foreach (string preferred in preferredOrder)
        {
            DemoSampleFile? matched = sampleFiles.FirstOrDefault(sample =>
                string.Equals(sample.FileName, preferred, StringComparison.OrdinalIgnoreCase));
            if (matched != null)
                return matched;
        }

        return sampleFiles[0];
    }
}
