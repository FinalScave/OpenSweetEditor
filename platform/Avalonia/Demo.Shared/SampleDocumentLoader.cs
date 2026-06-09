using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Avalonia.Controls;
using Avalonia.Threading;
using SweetEditor;

namespace SweetEditor.Avalonia.Demo;

internal sealed class SampleDocumentLoader
{
    private const int ChunkedStatusUpdateInterval = 3;

    private readonly SweetEditorController controller;
    private readonly DemoDecorationProvider decorationProvider;
    private readonly ComboBox fileCombo;
    private readonly Action<string> updateStatus;
    private readonly Action<string> applyLanguageConfiguration;
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
        Action<DemoSampleFile>? beforeLoad = null,
        Action<bool>? setPickerEnabled = null)
    {
        this.controller = controller;
        this.decorationProvider = decorationProvider;
        this.fileCombo = fileCombo;
        this.updateStatus = updateStatus;
        this.applyLanguageConfiguration = applyLanguageConfiguration;
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
