using System;
using System.Collections.Generic;
using System.Runtime.CompilerServices;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
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
