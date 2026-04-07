using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Reflection;
using SlDocument = SweetLine.Document;
using SlDocumentAnalyzer = SweetLine.DocumentAnalyzer;
using SlHighlightConfig = SweetLine.HighlightConfig;
using SlHighlightEngine = SweetLine.HighlightEngine;
using SlTextAnalyzer = SweetLine.TextAnalyzer;

namespace SweetEditor.Avalonia.Demo.Decoration;

internal sealed class DemoSweetLineRuntime : IDisposable
{
    private const string SyntaxResourcePrefix = "SweetEditor.PlatformRes.syntaxes.";

    private static readonly object SyncRoot = new();
    private static DemoSweetLineRuntime? instance;
    private static bool initAttempted;
    private static Exception? initError;

    private readonly SlHighlightEngine documentEngine;
    private SlHighlightEngine? lineEngine;
    private bool disposed;

    private DemoSweetLineRuntime()
    {
        documentEngine = CreateEngine();
    }

    public static DemoSweetLineRuntime? TryGetOrCreate()
    {
        lock (SyncRoot)
        {
            if (instance != null)
                return instance;
            if (initAttempted)
                return null;

            initAttempted = true;
            try
            {
                instance = new DemoSweetLineRuntime();
                return instance;
            }
            catch (DllNotFoundException ex)
            {
                initError = ex;
                Console.Error.WriteLine($"SweetLine native library not found: {ex.Message}");
                Console.Error.WriteLine("Falling back to managed highlight implementation.");
                return null;
            }
            catch (Exception ex)
            {
                initError = ex;
                Console.Error.WriteLine($"SweetLine init failed: {ex.Message}");
                return null;
            }
        }
    }

    public static string? LastInitErrorMessage
    {
        get
        {
            lock (SyncRoot)
            {
                return initError?.Message;
            }
        }
    }

    public SlDocumentAnalyzer? CreateAnalyzer(string languageId, string fileName, string content, out SlDocument document)
    {
        ThrowIfDisposed();
        string normalizedFileName = NormalizeFileName(languageId, fileName);
        document = new SlDocument($"file:///{normalizedFileName}", content ?? string.Empty);
        return documentEngine.LoadDocument(document);
    }

    public SlTextAnalyzer? CreateTextAnalyzer(string languageId, string fileName)
    {
        ThrowIfDisposed();
        SlHighlightEngine target = EnsureLineEngine();

        string normalizedLanguageId = (languageId ?? string.Empty).Trim().ToLowerInvariant();
        if (!string.IsNullOrWhiteSpace(normalizedLanguageId))
        {
            SlTextAnalyzer? analyzerByName = target.CreateAnalyzerByName(normalizedLanguageId);
            if (analyzerByName != null)
                return analyzerByName;
        }

        string extension = Path.GetExtension(NormalizeFileName(languageId, fileName));
        if (string.IsNullOrWhiteSpace(extension))
            return null;

        return target.CreateAnalyzerByExtension(extension);
    }

    private static string NormalizeFileName(string? languageId, string? fileName)
    {
        string normalized = string.IsNullOrWhiteSpace(fileName) ? "sample.txt" : fileName.Replace('\\', '/');
        if (!string.IsNullOrWhiteSpace(Path.GetExtension(normalized)))
            return normalized;

        string extension = (languageId ?? string.Empty).Trim().ToLowerInvariant() switch
        {
            "java" => ".java",
            "kotlin" => ".kt",
            "lua" => ".lua",
            "cpp" or "c" or "c++" => ".cpp",
            _ => ".txt",
        };
        return normalized + extension;
    }

    public void Dispose()
    {
        if (disposed)
            return;
        disposed = true;
        lineEngine?.Dispose();
        documentEngine.Dispose();
    }

    private SlHighlightEngine CreateEngine()
    {
        var engine = new SlHighlightEngine(new SlHighlightConfig(ShowIndex: false, InlineStyle: false));
        RegisterDefaultStyles(engine);
        CompileEmbeddedSyntaxes(engine);
        return engine;
    }

    private SlHighlightEngine EnsureLineEngine()
    {
        ThrowIfDisposed();
        return lineEngine ??= CreateEngine();
    }

    private static void RegisterDefaultStyles(SlHighlightEngine target)
    {
        KeyValuePair<string, int>[] styles =
        {
            new("keyword", (int)EditorTheme.STYLE_KEYWORD),
            new("string", (int)EditorTheme.STYLE_STRING),
            new("comment", (int)EditorTheme.STYLE_COMMENT),
            new("number", (int)EditorTheme.STYLE_NUMBER),
            new("builtin", (int)EditorTheme.STYLE_BUILTIN),
            new("type", (int)EditorTheme.STYLE_TYPE),
            new("class", (int)EditorTheme.STYLE_CLASS),
            new("interface", (int)EditorTheme.STYLE_CLASS),
            new("enum", (int)EditorTheme.STYLE_CLASS),
            new("function", (int)EditorTheme.STYLE_FUNCTION),
            new("method", (int)EditorTheme.STYLE_FUNCTION),
            new("variable", (int)EditorTheme.STYLE_VARIABLE),
            new("field", (int)EditorTheme.STYLE_VARIABLE),
            new("property", (int)EditorTheme.STYLE_VARIABLE),
            new("parameter", (int)EditorTheme.STYLE_VARIABLE),
            new("punctuation", (int)EditorTheme.STYLE_PUNCTUATION),
            new("operator", (int)EditorTheme.STYLE_PUNCTUATION),
            new("delimiter", (int)EditorTheme.STYLE_PUNCTUATION),
            new("annotation", (int)EditorTheme.STYLE_ANNOTATION),
            new("attribute", (int)EditorTheme.STYLE_ANNOTATION),
            new("preprocessor", (int)EditorTheme.STYLE_PREPROCESSOR),
            new("modifier", (int)EditorTheme.STYLE_KEYWORD),
            new("namespace", (int)EditorTheme.STYLE_CLASS),
            new("constant", (int)EditorTheme.STYLE_NUMBER),
            new("character", (int)EditorTheme.STYLE_STRING),
            new("regex", (int)EditorTheme.STYLE_STRING),
            new("escape", (int)EditorTheme.STYLE_STRING),
            new("label", (int)EditorTheme.STYLE_VARIABLE),
        };

        foreach (KeyValuePair<string, int> item in styles)
        {
            try
            {
                target.RegisterStyleName(item.Key, item.Value);
            }
            catch
            {
                // Ignore duplicates or unsupported names; engine keeps the previous mapping.
            }
        }
    }

    private void CompileEmbeddedSyntaxes(SlHighlightEngine target)
    {
        Assembly assembly = typeof(DemoSweetLineRuntime).Assembly;
        foreach (string resourceName in assembly.GetManifestResourceNames().Where(name =>
                     name.StartsWith(SyntaxResourcePrefix, StringComparison.OrdinalIgnoreCase)))
        {
            using Stream? stream = assembly.GetManifestResourceStream(resourceName);
            if (stream == null)
                continue;
            using StreamReader reader = new(stream);
            string json = reader.ReadToEnd();
            if (string.IsNullOrWhiteSpace(json))
                continue;
            target.CompileSyntaxFromJson(json);
        }
    }

    private void ThrowIfDisposed()
    {
        if (disposed)
            throw new ObjectDisposedException(nameof(DemoSweetLineRuntime), initError?.Message);
    }
}
