using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Threading;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

public sealed class DemoSampleFile
{
    private readonly Func<string>? contentFactory;
    private readonly Func<IEnumerable<string>>? chunkFactory;
    private string? cachedContent;
    private Task<Document>? documentTask;

    public string FileName { get; }
    public string LanguageId { get; }
    public string Content => cachedContent ??= MaterializeContent();
    public bool IsGenerated { get; }
    public bool IsLargeDocument { get; }
    public bool SupportsChunkedLoad => chunkFactory != null;

    public DemoSampleFile(string fileName, string languageId, string content, bool isGenerated = false)
        : this(fileName, languageId, () => content, isGenerated, isLargeDocument: false)
    {
    }

    public DemoSampleFile(
        string fileName,
        string languageId,
        Func<string> contentFactory,
        bool isGenerated = false,
        bool isLargeDocument = false)
    {
        FileName = fileName;
        LanguageId = languageId;
        this.contentFactory = contentFactory;
        IsGenerated = isGenerated;
        IsLargeDocument = isLargeDocument;
    }

    public DemoSampleFile(
        string fileName,
        string languageId,
        Func<IEnumerable<string>> chunkFactory,
        bool isGenerated = false,
        bool isLargeDocument = false)
    {
        FileName = fileName;
        LanguageId = languageId;
        this.chunkFactory = chunkFactory;
        IsGenerated = isGenerated;
        IsLargeDocument = isLargeDocument;
    }

    public void WarmDocument()
    {
        if (SupportsChunkedLoad)
            return;

        _ = GetOrCreateDocumentAsync();
    }

    public Task<Document> GetOrCreateDocumentAsync()
        => documentTask ??= Task.Run(() => new Document(Content));

    public void CacheContent(string content)
    {
        cachedContent = content;
    }

    public async IAsyncEnumerable<string> ReadChunksAsync([EnumeratorCancellation] CancellationToken cancellationToken = default)
    {
        if (chunkFactory == null)
        {
            yield return await Task.Run(() => Content, cancellationToken).ConfigureAwait(false);
            yield break;
        }

        foreach (string chunk in chunkFactory())
        {
            cancellationToken.ThrowIfCancellationRequested();
            if (string.IsNullOrEmpty(chunk))
                continue;

            yield return chunk;
            await Task.Yield();
        }
    }

    private string MaterializeContent()
    {
        if (contentFactory != null)
            return contentFactory();

        if (chunkFactory == null)
            return string.Empty;

        StringBuilder builder = new();
        foreach (string chunk in chunkFactory())
            builder.Append(chunk);
        return builder.ToString();
    }

    public override string ToString() => FileName;
}

public static class EmbeddedSampleRepository
{
    private const string ResourcePrefix = "SweetEditor.PlatformRes.files.";
    private const int GeneratedChunkTargetChars = 64 * 1024;
    private static readonly string[] EmbeddedSampleNames =
    {
        "example.java",
        "example.kt",
        "example.lua",
        "gc.cpp",
    };

    public static List<DemoSampleFile> LoadAll(Assembly assembly)
    {
        List<DemoSampleFile> embedded = LoadEmbeddedSamples(assembly);
        embedded.AddRange(BuildGeneratedSamples());
        return embedded;
    }

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

    private static IEnumerable<DemoSampleFile> BuildGeneratedSamples()
    {
        yield return new DemoSampleFile(
            "generated/large-demo.cpp",
            "cpp",
            BuildLargeCppDocumentChunks,
            isGenerated: true,
            isLargeDocument: true);

        yield return new DemoSampleFile(
            "generated/huge-script.lua",
            "lua",
            BuildLargeLuaDocumentChunks,
            isGenerated: true,
            isLargeDocument: true);
    }

    private static IEnumerable<string> BuildLargeCppDocumentChunks()
    {
        var sb = new StringBuilder(GeneratedChunkTargetChars + 4096);
        sb.AppendLine("#include <string>");
        sb.AppendLine("#include <vector>");
        sb.AppendLine("#include <cstdint>");
        sb.AppendLine();
        sb.AppendLine("class GeneratedLargeDemo {");
        sb.AppendLine("public:");
        sb.AppendLine("    int checksum = 0;");
        for (int i = 0; i < 10000; i++)
        {
            sb.AppendLine($"    int section_{i}(int seed) {{");
            sb.AppendLine($"        int local = seed + {i}; // TODO: review section_{i}");
            sb.AppendLine($"        if ((local % 7) == 0) {{ checksum += local; }}");
            sb.AppendLine($"        std::string color = \"#{(i * 97) & 0xFFFFFF:X6}\";");
            sb.AppendLine($"        return local + checksum; }}");
            sb.AppendLine();

            if (sb.Length >= GeneratedChunkTargetChars)
                yield return DrainBuilder(sb);
        }
        sb.AppendLine("};");
        if (sb.Length > 0)
            yield return DrainBuilder(sb);
    }

    private static IEnumerable<string> BuildLargeLuaDocumentChunks()
    {
        var sb = new StringBuilder(GeneratedChunkTargetChars + 4096);
        sb.AppendLine("local Demo = {}");
        sb.AppendLine();
        for (int i = 0; i < 12000; i++)
        {
            sb.AppendLine($"function Demo.block_{i}(value)");
            sb.AppendLine($"    local current = value + {i}");
            sb.AppendLine("    if current % 5 == 0 then");
            sb.AppendLine("        return current, \"#22AAFF\"");
            sb.AppendLine("    end");
            sb.AppendLine("    return current");
            sb.AppendLine("end");
            sb.AppendLine();

            if (sb.Length >= GeneratedChunkTargetChars)
                yield return DrainBuilder(sb);
        }
        sb.AppendLine("return Demo");
        if (sb.Length > 0)
            yield return DrainBuilder(sb);
    }

    private static string DrainBuilder(StringBuilder builder)
    {
        string chunk = builder.ToString();
        builder.Clear();
        return chunk;
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
    private const int ChunkedStatusUpdateInterval = 3;

    private readonly SweetEditorController controller;
    private readonly DemoDecorationProvider decorationProvider;
    private readonly ComboBox fileCombo;
    private readonly Action<string> updateStatus;
    private readonly Action<string> applyLanguageConfiguration;
    private readonly Func<string?>? getInitialSampleFileName;
    private readonly Action<DemoSampleFile>? beforeLoad;
    private readonly Action<bool>? setPickerEnabled;

    private readonly List<DemoSampleFile> sampleFiles = new();
    private CancellationTokenSource? loadCts;
    private bool suppressSelectionChanged;

    public IReadOnlyList<DemoSampleFile> SampleFiles => sampleFiles;

    public SampleDocumentLoader(
        SweetEditorController controller,
        DemoDecorationProvider decorationProvider,
        ComboBox fileCombo,
        Action<string> updateStatus,
        Action<string> applyLanguageConfiguration,
        Func<string?>? getInitialSampleFileName = null,
        Action<DemoSampleFile>? beforeLoad = null,
        Action<bool>? setPickerEnabled = null)
    {
        this.controller = controller;
        this.decorationProvider = decorationProvider;
        this.fileCombo = fileCombo;
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
        suppressSelectionChanged = true;
        fileCombo.ItemsSource = sampleFiles.Select(sample => sample.FileName).ToList();
        fileCombo.SelectedItem = initialSample?.FileName;
        suppressSelectionChanged = false;
        setPickerEnabled?.Invoke(sampleFiles.Count > 0);

        if (sampleFiles.Count == 0)
        {
            controller.SetMetadata(new DemoMetadata("sample.txt", string.Empty));
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

    public async Task OnSelectedSampleChangedAsync()
    {
        if (suppressSelectionChanged)
            return;

        DemoSampleFile? selectedSample = ResolveSelectedSampleFromCombo();
        if (selectedSample == null)
            return;

        await LoadSampleAsync(selectedSample).ConfigureAwait(false);
    }

    public async Task LoadSampleAsync(DemoSampleFile sample)
    {
        beforeLoad?.Invoke(sample);

        loadCts?.Cancel();
        loadCts?.Dispose();
        loadCts = new CancellationTokenSource();
        CancellationToken token = loadCts.Token;

        SyncComboSelection(sample);
        applyLanguageConfiguration(sample.LanguageId);
        updateStatus($"Loading: {sample.FileName}");
        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            fileCombo.IsEnabled = false;
            setPickerEnabled?.Invoke(false);
        });

        try
        {
            if (sample.SupportsChunkedLoad && sample.IsLargeDocument)
            {
                await LoadChunkedSampleAsync(sample, token).ConfigureAwait(false);
                return;
            }

            string content = await Task.Run(() => sample.Content, token).ConfigureAwait(false);
            decorationProvider.PrimeDocument(sample.FileName, content);
            Document document = await sample.GetOrCreateDocumentAsync().ConfigureAwait(false);
            await decorationProvider.WaitForPrimeAsync(sample.FileName, content, GetPrimeWaitTimeoutMs(sample)).ConfigureAwait(false);
            token.ThrowIfCancellationRequested();

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (token.IsCancellationRequested)
                    return;

                decorationProvider.ActivatePrimedDocument(sample.FileName, content, document);
                controller.SetMetadata(new DemoMetadata(sample.FileName, content));
                controller.LoadDocument(document);
                controller.RequestDecorationRefresh();
                fileCombo.IsEnabled = true;
                setPickerEnabled?.Invoke(true);
                updateStatus($"Loaded: {sample.FileName}{(sample.IsGenerated ? " (generated)" : string.Empty)}");
            }, DispatcherPriority.Background);
        }
        catch (OperationCanceledException)
        {
        }
        catch (Exception ex)
        {
            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                fileCombo.IsEnabled = true;
                setPickerEnabled?.Invoke(true);
                updateStatus($"Load failed: {sample.FileName} ({ex.Message})");
            });
        }
    }

    private async Task LoadChunkedSampleAsync(DemoSampleFile sample, CancellationToken token)
    {
        decorationProvider.BeginStreamingDocument(sample.FileName, sample.LanguageId);

        await using IAsyncEnumerator<string> chunks = sample.ReadChunksAsync(token).GetAsyncEnumerator(token);
        string firstChunk = await ReadFirstChunkAsync(chunks).ConfigureAwait(false);
        Document document = await Task.Run(() => new Document(firstChunk), token).ConfigureAwait(false);
        StringBuilder contentBuilder = new(Math.Max(firstChunk.Length * 2, 128 * 1024));
        contentBuilder.Append(firstChunk);

        TextPosition appendPosition = AdvancePosition(new TextPosition(), firstChunk);
        int chunkCount = string.IsNullOrEmpty(firstChunk) ? 0 : 1;
        int loadedChars = firstChunk.Length;

        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (token.IsCancellationRequested)
                return;

            controller.SetMetadata(new DemoMetadata(sample.FileName));
            controller.LoadDocument(document);
            controller.RequestDecorationRefresh();
            updateStatus($"Streaming: {sample.FileName}");
        }, DispatcherPriority.Background);

        while (await chunks.MoveNextAsync().ConfigureAwait(false))
        {
            token.ThrowIfCancellationRequested();

            string chunk = chunks.Current;
            if (string.IsNullOrEmpty(chunk))
                continue;

            TextPosition chunkStart = appendPosition;
            appendPosition = AdvancePosition(appendPosition, chunk);
            loadedChars += chunk.Length;
            chunkCount++;
            contentBuilder.Append(chunk);

            bool shouldUpdateStatus = chunkCount == 1 || chunkCount % ChunkedStatusUpdateInterval == 0;
            string statusText = shouldUpdateStatus
                ? $"Streaming: {sample.FileName} ({loadedChars / 1024} KB)"
                : string.Empty;

            await Dispatcher.UIThread.InvokeAsync(() =>
            {
                if (token.IsCancellationRequested)
                    return;

                controller.ReplaceText(new TextRange
                {
                    Start = chunkStart,
                    End = chunkStart,
                }, chunk);

                if (shouldUpdateStatus)
                    updateStatus(statusText);
            }, DispatcherPriority.Background);
        }

        string finalContent = contentBuilder.ToString();
        sample.CacheContent(finalContent);
        decorationProvider.CompleteStreamingDocument(sample.FileName, finalContent);
        token.ThrowIfCancellationRequested();

        await Dispatcher.UIThread.InvokeAsync(() =>
        {
            if (token.IsCancellationRequested)
                return;

            controller.SetMetadata(new DemoMetadata(sample.FileName, null));
            controller.RequestDecorationRefresh();
            fileCombo.IsEnabled = true;
            setPickerEnabled?.Invoke(true);
            updateStatus($"Loaded: {sample.FileName}{(sample.IsGenerated ? " (generated)" : string.Empty)}");
        }, DispatcherPriority.Background);
    }

    private DemoSampleFile? ResolveSelectedSampleFromCombo()
    {
        if (fileCombo.SelectedItem is DemoSampleFile sampleItem)
            return sampleItem;

        if (fileCombo.SelectedItem is string fileName)
        {
            return sampleFiles.FirstOrDefault(sample =>
                string.Equals(sample.FileName, fileName, StringComparison.Ordinal));
        }

        int index = fileCombo.SelectedIndex;
        return index >= 0 && index < sampleFiles.Count ? sampleFiles[index] : null;
    }

    private void SyncComboSelection(DemoSampleFile sample)
    {
        int index = sampleFiles.FindIndex(x => string.Equals(x.FileName, sample.FileName, StringComparison.Ordinal));
        if (index < 0)
            return;

        suppressSelectionChanged = true;
        try
        {
            if (fileCombo.SelectedIndex != index)
                fileCombo.SelectedIndex = index;
            fileCombo.SelectedItem = sampleFiles[index].FileName;
        }
        finally
        {
            suppressSelectionChanged = false;
        }
    }

    private static int GetPrimeWaitTimeoutMs(DemoSampleFile sample)
    {
        return sample.IsGenerated ? 64 : 1;
    }

    private static async Task<string> ReadFirstChunkAsync(IAsyncEnumerator<string> chunks)
    {
        while (await chunks.MoveNextAsync().ConfigureAwait(false))
        {
            if (!string.IsNullOrEmpty(chunks.Current))
                return chunks.Current;
        }

        return string.Empty;
    }

    private static TextPosition AdvancePosition(TextPosition position, string text)
    {
        if (string.IsNullOrEmpty(text))
            return position;

        int line = position.Line;
        int column = position.Column;
        foreach (char ch in text)
        {
            if (ch == '\n')
            {
                line++;
                column = 0;
                continue;
            }

            if (ch != '\r')
                column++;
        }

        return new TextPosition
        {
            Line = line,
            Column = column,
        };
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
            "example.kt",
            "example.java",
            "example.lua",
        };

        foreach (string preferred in preferredOrder)
        {
            DemoSampleFile? matched = sampleFiles.FirstOrDefault(sample =>
                !sample.IsGenerated &&
                string.Equals(sample.FileName, preferred, StringComparison.OrdinalIgnoreCase));
            if (matched != null)
                return matched;
        }

        DemoSampleFile? embedded = sampleFiles.FirstOrDefault(sample => !sample.IsGenerated);
        return embedded ?? sampleFiles[0];
    }
}

internal sealed class DemoMetadata : IEditorMetadata
{
    public string FilePath { get; }
    public string? InitialText { get; }

    public DemoMetadata(string filePath, string? initialText = null)
    {
        FilePath = filePath;
        InitialText = initialText;
    }
}
