using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using SweetEditor;
using SweetEditor.Avalonia.Demo.Editor;
using SweetEditor.Avalonia.Demo.Host;
using SlDocument = SweetLine.Document;
using SlDocumentAnalyzer = SweetLine.DocumentAnalyzer;
using SlDocumentHighlight = SweetLine.DocumentHighlight;
using SlDocumentHighlightSlice = SweetLine.DocumentHighlightSlice;
using SlIndentGuideResult = SweetLine.IndentGuideResult;
using SlLineHighlight = SweetLine.LineHighlight;
using SlLineRange = SweetLine.LineRange;
using SlTextAnalyzer = SweetLine.TextAnalyzer;
using SlTextLineInfo = SweetLine.TextLineInfo;
using SlTextPosition = SweetLine.TextPosition;
using SlTextRange = SweetLine.TextRange;

namespace SweetEditor.Avalonia.Demo.Decoration;

internal sealed class DemoDecorationProvider : IDecorationProvider
{
    private const int LargeDocumentSequentialCatchUpLimit = 384;
    private const int LargeDocumentWindowBacktrackLines = 64;
    private const int LargeDocumentAsyncPrefetchLines = 192;

    private sealed class CachedRichLineDecorations
    {
        public string LineText = string.Empty;
        public List<DiagnosticItem> Diagnostics = new();
        public List<InlayHint> Inlays = new();
        public List<GutterIcon> GutterIcons = new();
        public List<PhantomText> Phantoms = new();
    }

    private static readonly Regex NumberRegex = new(@"\b\d+(?:\.\d+)?\b", RegexOptions.Compiled);
    private static readonly Regex HexColorRegex = new(@"#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b", RegexOptions.Compiled);
    private static readonly Regex IdentifierRegex = new(@"[A-Za-z_][A-Za-z0-9_]*", RegexOptions.Compiled);

    private static readonly HashSet<string> Keywords = new(StringComparer.Ordinal)
    {
        "if", "else", "for", "while", "return", "class", "struct", "public", "private", "protected",
        "fun", "function", "local", "val", "var", "void", "new", "switch", "case", "break", "continue",
        "namespace", "package", "using", "include", "static", "const", "auto"
    };

    private static readonly HashSet<string> Types = new(StringComparer.Ordinal)
    {
        "int", "float", "double", "bool", "string", "String", "size_t", "char", "long", "short", "byte"
    };

    private readonly Func<Document?> getDocument;
    private readonly Action requestRefresh;
    private readonly object gate = new();

    private string? activeFileName;
    private string? activeContent;
    private string? activeLanguageId;
    private string[]? activeLines;
    private string highlightBackendLabel = "SweetLine pending";

    private SlDocument? sweetLineDocument;
    private SlDocumentAnalyzer? sweetLineAnalyzer;
    private SlDocumentHighlight? sweetLineHighlight;
    private SlIndentGuideResult? sweetLineGuides;
    private SlTextAnalyzer? sweetLineLargeDocumentAnalyzer;
    private SlDocument? sweetLineLargeDocumentSliceDocument;
    private SlDocumentAnalyzer? sweetLineLargeDocumentSliceAnalyzer;
    private Task? sweetLineLargeDocumentPrimeTask;
    private bool sweetLineAvailable;
    private bool sweetLineInitialized;
    private int sweetLineSessionVersion;
    private bool activeDocumentLargeMode;
    private bool activeDocumentStreamingLoad;
    private bool largeDocumentNativeCacheReady;
    private int largeDocumentGeneration;
    private readonly Dictionary<int, List<StyleSpan>> largeDocumentSyntaxCache = new();
    private readonly Dictionary<int, int> largeDocumentLineEndStates = new();
    private readonly Dictionary<int, CachedRichLineDecorations> smallDocumentRichLineCache = new();
    private int largeDocumentCacheStartLine = -1;
    private int largeDocumentCachedUntilLine = -1;
    private Task? largeDocumentSyntaxFillTask;
    private int largeDocumentSyntaxRequestedStartLine = -1;
    private int largeDocumentSyntaxRequestedEndLine = -1;

    public const int IconType = 1;
    public const int IconNote = 2;
    public const int StyleColor = unchecked((int)EditorTheme.STYLE_USER_BASE) + 1;

    public event Action? HighlightBackendChanged;

    public string HighlightBackendLabel
    {
        get
        {
            lock (gate)
            {
                return highlightBackendLabel;
            }
        }
    }

    public DemoDecorationProvider(Func<Document?> getDocument, Action requestRefresh)
    {
        this.getDocument = getDocument;
        this.requestRefresh = requestRefresh;
    }

    public DecorationType Capabilities =>
        DecorationType.SyntaxHighlight |
        DecorationType.InlayHint |
        DecorationType.Diagnostic |
        DecorationType.FoldRegion |
        DecorationType.IndentGuide |
        DecorationType.BracketGuide |
        DecorationType.FlowGuide |
        DecorationType.SeparatorGuide |
        DecorationType.GutterIcon |
        DecorationType.PhantomText;

    public void PrimeDocument(string fileName, string content)
    {
        lock (gate)
        {
            bool sameDocument =
                string.Equals(activeFileName, fileName, StringComparison.Ordinal) &&
                string.Equals(activeContent, content, StringComparison.Ordinal);

            activeFileName = fileName;
            activeContent = content;
            activeLanguageId = GuessLanguageId(fileName);
            activeDocumentLargeMode = IsLargeDocument(content);
            activeDocumentStreamingLoad = false;
            activeLines = activeDocumentLargeMode ? null : SplitLines(content);
            smallDocumentRichLineCache.Clear();
            highlightBackendLabel = DemoPlatformServices.Current?.IsAndroid == true
                ? "SweetLine pending"
                : "Managed fallback";

            if (sameDocument &&
                (sweetLineInitialized ||
                 sweetLineLargeDocumentAnalyzer != null ||
                 sweetLineLargeDocumentSliceAnalyzer != null ||
                 (sweetLineLargeDocumentPrimeTask != null && !sweetLineLargeDocumentPrimeTask.IsCompleted) ||
                 largeDocumentCachedUntilLine >= 0))
            {
                return;
            }

            sweetLineSessionVersion++;
            ResetSweetLineState();
            if (activeDocumentLargeMode)
            {
                StartLargeDocumentPrimeLocked(content);
            }
        }
    }

    public void BeginStreamingDocument(string fileName, string languageId)
    {
        lock (gate)
        {
            activeFileName = fileName;
            activeContent = null;
            activeLanguageId = string.IsNullOrWhiteSpace(languageId) ? GuessLanguageId(fileName) : languageId;
            activeDocumentLargeMode = true;
            activeDocumentStreamingLoad = true;
            activeLines = null;
            smallDocumentRichLineCache.Clear();
            sweetLineSessionVersion++;
            ResetSweetLineState();
            highlightBackendLabel = DemoPlatformServices.Current?.IsAndroid == true
                ? "SweetLine async"
                : "Managed fallback";
        }

        HighlightBackendChanged?.Invoke();
    }

    public void CompleteStreamingDocument(string fileName, string content)
    {
        lock (gate)
        {
            if (!string.Equals(activeFileName, fileName, StringComparison.Ordinal))
                return;

            activeContent = content;
            activeLanguageId ??= GuessLanguageId(fileName);
            activeDocumentLargeMode = true;
            activeDocumentStreamingLoad = false;
            activeLines = null;
            StartLargeDocumentPrimeLocked(content);
        }
    }

    public Task WaitForPrimeAsync(string fileName, string content, int timeoutMs)
    {
        PrimeDocument(fileName, content);
        return Task.CompletedTask;
    }

    public Task WaitForPrimeCompletionAsync(string fileName, string content)
    {
        PrimeDocument(fileName, content);
        return Task.CompletedTask;
    }

    public void ActivatePrimedDocument(string fileName, string content, Document document)
    {
        lock (gate)
        {
            activeFileName = fileName;
            activeContent = content;
            activeLanguageId = GuessLanguageId(fileName);
            activeDocumentLargeMode = IsLargeDocument(content);
            activeDocumentStreamingLoad = false;
            activeLines = activeDocumentLargeMode ? null : SplitLines(content);
            smallDocumentRichLineCache.Clear();
            if (activeDocumentLargeMode)
            {
                StartLargeDocumentPrimeLocked(content);
            }
        }
    }

    public void ProvideDecorations(DecorationContext context, IDecorationReceiver receiver)
    {
        if (receiver.IsCancelled)
            return;

        Document? doc = getDocument();
        if (doc == null)
        {
            receiver.Accept(new DecorationResult());
            return;
        }

        int total = Math.Max(0, doc.GetLineCount());
        if (total == 0)
        {
            receiver.Accept(new DecorationResult());
            return;
        }

        bool largeMode = activeDocumentLargeMode || total >= 12000;
        bool richDemoMode = !largeMode;
        int pad = largeMode ? 0 : 24;
        int start = Math.Max(0, context.VisibleStartLine - pad);
        int end = Math.Min(total - 1, Math.Max(context.VisibleEndLine, context.VisibleStartLine) + pad);
        bool preferNativeSyntax = true;
        EnsureSmallDocumentLineCache(doc, context.TextChanges);

        var syntax = new Dictionary<int, List<StyleSpan>>();
        var inlays = new Dictionary<int, List<InlayHint>>();
        var diagnostics = new Dictionary<int, List<DiagnosticItem>>();
        var gutterIcons = new Dictionary<int, List<GutterIcon>>();
        var phantoms = new Dictionary<int, List<PhantomText>>();
        var folds = new List<FoldRegion>();
        var indentGuides = new List<IndentGuide>();
        var bracketGuides = new List<BracketGuide>();
        var flowGuides = new List<FlowGuide>();
        var separators = new List<SeparatorGuide>();
        DecorationApplyMode syntaxApplyMode = largeMode ? DecorationApplyMode.MERGE : DecorationApplyMode.REPLACE_ALL;
        bool usedSweetLine = TryBuildSyntaxWithSweetLine(doc, context, start, end, syntax, indentGuides, flowGuides, out DecorationApplyMode resolvedSyntaxApplyMode);
        syntaxApplyMode = resolvedSyntaxApplyMode;
        SetHighlightBackendLabel(usedSweetLine, preferNativeSyntax);
        var braceStack = new Stack<(int line, int column)>();
        int separatorEvery = richDemoMode ? 32 : 0;
        bool needLineText = richDemoMode || (!usedSweetLine && !preferNativeSyntax);

        if (needLineText)
        {
            for (int lineIndex = start; lineIndex <= end; lineIndex++)
            {
                string line = GetDocumentLineText(doc, lineIndex);
                if (!usedSweetLine && !preferNativeSyntax)
                    BuildSyntaxFallback(lineIndex, line, syntax);
                if (richDemoMode)
                {
                    CachedRichLineDecorations cachedLine = GetCachedRichLineDecorations(lineIndex, line);
                    CopyCachedLineDecorations(cachedLine, lineIndex, diagnostics, inlays, gutterIcons, phantoms);
                    if (!usedSweetLine)
                        BuildGuidesFallback(lineIndex, line, indentGuides, flowGuides);
                    BuildBraces(lineIndex, line, braceStack, folds, bracketGuides);
                }

                if (separatorEvery > 0 && lineIndex > start && lineIndex % separatorEvery == 0)
                    separators.Add(new SeparatorGuide(lineIndex, 0, 1, Math.Min(line.Length, 24)));
            }
        }

        var result = new DecorationResult
        {
            SyntaxSpans = syntax,
            InlayHints = inlays,
            Diagnostics = diagnostics,
            GutterIcons = gutterIcons,
            PhantomTexts = phantoms,
            FoldRegions = folds,
            IndentGuides = indentGuides,
            BracketGuides = bracketGuides,
            FlowGuides = flowGuides,
            SeparatorGuides = separators,
            SyntaxSpansMode = syntaxApplyMode,
            InlayHintsMode = DecorationApplyMode.REPLACE_ALL,
            DiagnosticsMode = DecorationApplyMode.REPLACE_ALL,
            GutterIconsMode = DecorationApplyMode.REPLACE_ALL,
            PhantomTextsMode = DecorationApplyMode.REPLACE_ALL,
            FoldRegionsMode = DecorationApplyMode.REPLACE_ALL,
            IndentGuidesMode = DecorationApplyMode.REPLACE_ALL,
            BracketGuidesMode = DecorationApplyMode.REPLACE_ALL,
            FlowGuidesMode = DecorationApplyMode.REPLACE_ALL,
            SeparatorGuidesMode = DecorationApplyMode.REPLACE_ALL,
        };

        receiver.Accept(result);
    }

    private bool TryBuildSyntaxWithSweetLine(
        Document doc,
        DecorationContext context,
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax,
        List<IndentGuide> indentGuides,
        List<FlowGuide> flowGuides,
        out DecorationApplyMode syntaxApplyMode)
    {
        lock (gate)
        {
            if (activeDocumentLargeMode)
            {
                InvalidateLargeDocumentSyntaxCacheIfNeeded(doc, context.TextChanges);
                bool builtLargeDocumentSyntax = TryBuildLargeDocumentSyntaxLocked(doc, context, start, end, syntax);
                syntaxApplyMode = DecorationApplyMode.REPLACE_RANGE;
                return builtLargeDocumentSyntax;
            }

            syntaxApplyMode = DecorationApplyMode.REPLACE_ALL;
            if (!EnsureSweetLineSession(context))
            {
                return false;
            }

            ApplyIncrementalChanges(context.TextChanges);
            if (sweetLineHighlight == null)
                return false;

            AppendHighlightLines(sweetLineHighlight, start, end, syntax);
            syntaxApplyMode = DecorationApplyMode.REPLACE_ALL;

            if (sweetLineGuides != null)
            {
                foreach (var guide in sweetLineGuides.GuideLines)
                {
                    if (guide.EndLine < start || guide.StartLine > end)
                        continue;

                    indentGuides.Add(new IndentGuide(
                        new TextPosition { Line = Math.Max(start, guide.StartLine), Column = guide.Column },
                        new TextPosition { Line = Math.Min(end, guide.EndLine), Column = guide.Column }));

                    foreach (var branch in guide.Branches)
                    {
                        if (branch.Line < start || branch.Line > end)
                            continue;
                        flowGuides.Add(new FlowGuide(
                            new TextPosition { Line = Math.Max(start, guide.StartLine), Column = guide.Column },
                            new TextPosition { Line = branch.Line, Column = branch.Column }));
                    }
                }
            }

            return true;
        }
    }

    private bool EnsureSweetLineSession(DecorationContext context)
    {
        if (sweetLineInitialized)
            return sweetLineAvailable;

        if (activeDocumentLargeMode)
            return false;

        sweetLineInitialized = true;
        DemoSweetLineRuntime? runtime = DemoSweetLineRuntime.TryGetOrCreate();
        if (runtime == null)
        {
            sweetLineAvailable = false;
            return false;
        }

        string fileName = activeFileName ?? "sample.txt";
        string content = activeContent ?? string.Empty;
        string languageId = context.LanguageConfiguration?.LanguageId ?? activeLanguageId ?? GuessLanguageId(fileName);

        try
        {
            sweetLineAnalyzer = runtime.CreateAnalyzer(languageId, fileName, content, out SlDocument document);
            sweetLineDocument = document;
            sweetLineAvailable = sweetLineAnalyzer != null;
            if (!sweetLineAvailable)
            {
                sweetLineDocument.Dispose();
                sweetLineDocument = null;
                return false;
            }

            sweetLineHighlight = sweetLineAnalyzer!.Analyze();
            sweetLineGuides = sweetLineAnalyzer.AnalyzeIndentGuides();
            activeLanguageId = languageId;
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SweetLine analysis unavailable: {ex.Message}");
            ResetSweetLineState();
            sweetLineInitialized = true;
            sweetLineAvailable = false;
            return false;
        }
    }

    private void ApplyIncrementalChanges(IReadOnlyList<TextChange> changes)
    {
        if (sweetLineAnalyzer == null || changes == null || changes.Count == 0)
            return;

        foreach (TextChange change in changes)
        {
            TextRange? range = change.Range;
            if (range == null)
                continue;

            string newText = change.Text ?? change.NewText ?? string.Empty;
            SlTextRange slRange = new(
                new SlTextPosition(range.Value.Start.Line, range.Value.Start.Column),
                new SlTextPosition(range.Value.End.Line, range.Value.End.Column));
            sweetLineHighlight = sweetLineAnalyzer.AnalyzeIncremental(slRange, newText);
        }

        sweetLineGuides = sweetLineAnalyzer.AnalyzeIndentGuides();
    }

    private SlDocumentHighlightSlice ApplyIncrementalChangesInLineRange(
        IReadOnlyList<TextChange> changes,
        SlLineRange visibleRange)
    {
        if (sweetLineAnalyzer == null)
            return new SlDocumentHighlightSlice();

        if (changes == null || changes.Count == 0)
            return EnsureVisibleHighlightSlice(visibleRange);

        SlDocumentHighlightSlice? latestSlice = null;
        foreach (TextChange change in changes)
        {
            TextRange? range = change.Range;
            if (range == null)
                continue;

            string newText = change.Text ?? change.NewText ?? string.Empty;
            SlTextRange slRange = new(
                new SlTextPosition(range.Value.Start.Line, range.Value.Start.Column),
                new SlTextPosition(range.Value.End.Line, range.Value.End.Column));
            latestSlice = sweetLineAnalyzer.AnalyzeIncrementalInLineRange(slRange, newText, visibleRange);
        }

        if (latestSlice != null && HasUsableSlice(latestSlice, visibleRange))
            return latestSlice;

        return EnsureVisibleHighlightSlice(visibleRange);
    }

    private SlDocumentHighlightSlice EnsureVisibleHighlightSlice(SlLineRange visibleRange)
    {
        if (sweetLineAnalyzer == null)
            return new SlDocumentHighlightSlice();

        SlDocumentHighlightSlice slice = sweetLineAnalyzer.GetHighlightSlice(visibleRange);
        if (HasUsableSlice(slice, visibleRange))
            return slice;

        sweetLineAnalyzer.PrimeHighlightCache();
        return sweetLineAnalyzer.GetHighlightSlice(visibleRange);
    }

    private static bool HasUsableSlice(SlDocumentHighlightSlice slice, SlLineRange visibleRange)
    {
        if (visibleRange.LineCount <= 0)
            return true;

        if (slice.TotalLineCount <= visibleRange.StartLine)
            return false;

        return slice.Lines.Count > 0;
    }

    private void ResetSweetLineState()
    {
        largeDocumentGeneration++;
        largeDocumentSyntaxCache.Clear();
        largeDocumentLineEndStates.Clear();
        smallDocumentRichLineCache.Clear();
        largeDocumentCacheStartLine = -1;
        largeDocumentCachedUntilLine = -1;
        largeDocumentSyntaxRequestedStartLine = -1;
        largeDocumentSyntaxRequestedEndLine = -1;
        largeDocumentNativeCacheReady = false;
        sweetLineLargeDocumentAnalyzer?.Dispose();
        sweetLineLargeDocumentAnalyzer = null;
        sweetLineLargeDocumentSliceAnalyzer?.Dispose();
        sweetLineLargeDocumentSliceAnalyzer = null;
        sweetLineLargeDocumentSliceDocument?.Dispose();
        sweetLineLargeDocumentSliceDocument = null;
        sweetLineLargeDocumentPrimeTask = null;
        sweetLineAnalyzer?.Dispose();
        sweetLineAnalyzer = null;
        sweetLineDocument?.Dispose();
        sweetLineDocument = null;
        sweetLineHighlight = null;
        sweetLineGuides = null;
        largeDocumentSyntaxFillTask = null;
        sweetLineInitialized = false;
        sweetLineAvailable = false;
    }

    private void SetHighlightBackendLabel(bool usedSweetLine, bool preferNativeSyntax)
    {
        string nextLabel;
        lock (gate)
        {
            bool hasAsyncSweetLinePipeline =
                activeDocumentStreamingLoad ||
                sweetLineLargeDocumentPrimeTask != null ||
                largeDocumentSyntaxFillTask != null ||
                sweetLineLargeDocumentAnalyzer != null ||
                sweetLineLargeDocumentSliceAnalyzer != null;

            if (activeDocumentLargeMode && preferNativeSyntax && !largeDocumentNativeCacheReady && hasAsyncSweetLinePipeline)
            {
                nextLabel = "SweetLine async";
            }
            else if (usedSweetLine)
            {
                nextLabel = "SweetLine native";
            }
            else if (preferNativeSyntax)
            {
                nextLabel = string.IsNullOrWhiteSpace(DemoSweetLineRuntime.LastInitErrorMessage)
                    ? "SweetLine unavailable"
                    : "SweetLine error";
            }
            else
            {
                nextLabel = "Managed fallback";
            }

            if (string.Equals(highlightBackendLabel, nextLabel, StringComparison.Ordinal))
                return;

            highlightBackendLabel = nextLabel;
        }

        HighlightBackendChanged?.Invoke();
    }

    private static string GuessLanguageId(string? fileName)
    {
        string extension = System.IO.Path.GetExtension(fileName ?? string.Empty).ToLowerInvariant();
        return extension switch
        {
            ".kt" => "kotlin",
            ".java" => "java",
            ".lua" => "lua",
            ".cpp" or ".cc" or ".cxx" or ".hpp" or ".h" or ".c" => "cpp",
            _ => "plaintext",
        };
    }

    private static bool IsLargeDocument(string? content)
    {
        if (string.IsNullOrEmpty(content))
            return false;

        if (content.Length >= 900_000)
            return true;

        int lineCount = 1;
        foreach (char ch in content)
        {
            if (ch != '\n')
                continue;

            lineCount++;
            if (lineCount >= 12_000)
                return true;
        }

        return false;
    }

    private static int NormalizeStyleId(int styleId)
    {
        if (styleId <= 0)
            return 0;
        return styleId;
    }

    private static void AppendHighlightLines(
        SlDocumentHighlight highlight,
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax,
        int lineOffset = 0)
    {
        if (highlight.Lines == null || highlight.Lines.Count == 0)
            return;

        int clampedStart = Math.Max(0, start);
        int clampedEnd = Math.Min(end, highlight.Lines.Count - 1);
        if (clampedEnd < clampedStart)
            return;

        for (int lineIndex = clampedStart; lineIndex <= clampedEnd; lineIndex++)
        {
            var line = highlight.Lines[lineIndex];
            foreach (var span in line.Spans)
            {
                int column = span.Range.Start.Column;
                int length = Math.Max(0, span.Range.End.Column - span.Range.Start.Column);
                AddSpan(syntax, lineIndex + lineOffset, column, length, NormalizeStyleId(span.StyleId));
            }
        }
    }

    private static void AppendHighlightSlice(
        SlDocumentHighlightSlice slice,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        if (slice.Lines == null || slice.Lines.Count == 0)
            return;

        for (int offset = 0; offset < slice.Lines.Count; offset++)
        {
            var line = slice.Lines[offset];
            foreach (var span in line.Spans)
            {
                int column = span.Range.Start.Column;
                int length = Math.Max(0, span.Range.End.Column - span.Range.Start.Column);
                AddSpan(syntax, slice.StartLine + offset, column, length, NormalizeStyleId(span.StyleId));
            }
        }
    }

    private bool TryBuildLargeDocumentSyntaxLocked(
        Document doc,
        DecorationContext context,
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        if (start < 0 || end < start)
            return false;

        int total = Math.Max(0, doc.GetLineCount());
        if (total <= 0)
            return false;

        SlLineRange visibleRange = CreateLineRange(start, end);
        if (TryBuildLargeDocumentSyntaxSliceLocked(context.TextChanges, visibleRange, syntax))
            return syntax.Count > 0 || visibleRange.LineCount == 0;

        if (!activeDocumentStreamingLoad)
            StartLargeDocumentPrimeLocked(activeContent);

        AppendCachedLargeDocumentSyntaxLocked(start, Math.Min(end, total - 1), syntax);
        QueueLargeDocumentSyntaxFillLocked(start, end);
        return syntax.Count > 0;
    }

    private bool TryBuildLargeDocumentSyntaxSliceLocked(
        IReadOnlyList<TextChange> changes,
        SlLineRange visibleRange,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        if (!largeDocumentNativeCacheReady || sweetLineLargeDocumentSliceAnalyzer == null)
            return false;

        try
        {
            SlDocumentHighlightSlice slice = changes == null || changes.Count == 0
                ? sweetLineLargeDocumentSliceAnalyzer.GetHighlightSlice(visibleRange)
                : ApplyLargeDocumentIncrementalChangesLocked(changes, visibleRange);

            if (!HasUsableSlice(slice, visibleRange))
                return false;

            AppendHighlightSlice(slice, syntax);
            return true;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine($"SweetLine slice analysis unavailable: {ex.Message}");
            DisposeLargeDocumentSliceSessionLocked();
            StartLargeDocumentPrimeLocked(activeContent);
            return false;
        }
    }

    private SlDocumentHighlightSlice ApplyLargeDocumentIncrementalChangesLocked(
        IReadOnlyList<TextChange> changes,
        SlLineRange visibleRange)
    {
        if (sweetLineLargeDocumentSliceAnalyzer == null || changes == null || changes.Count == 0)
            return new SlDocumentHighlightSlice();

        SlDocumentHighlightSlice? latestSlice = null;
        foreach (TextChange change in changes)
        {
            TextRange? range = change.Range;
            if (range == null)
                continue;

            string newText = change.Text ?? change.NewText ?? string.Empty;
            SlTextRange slRange = new(
                new SlTextPosition(range.Value.Start.Line, range.Value.Start.Column),
                new SlTextPosition(range.Value.End.Line, range.Value.End.Column));
            latestSlice = sweetLineLargeDocumentSliceAnalyzer.AnalyzeIncrementalInLineRange(slRange, newText, visibleRange);
        }

        return latestSlice ?? new SlDocumentHighlightSlice();
    }

    private void AppendCachedLargeDocumentSyntaxLocked(
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        if (end < start)
            return;

        for (int lineIndex = start; lineIndex <= end; lineIndex++)
        {
            if (!largeDocumentSyntaxCache.TryGetValue(lineIndex, out List<StyleSpan>? spans) || spans.Count == 0)
                continue;

            syntax[lineIndex] = new List<StyleSpan>(spans);
        }
    }

    private void QueueLargeDocumentSyntaxFillLocked(int visibleStartLine, int visibleEndLine)
    {
        if (visibleEndLine < visibleStartLine)
            return;

        int requestStart = Math.Max(0, visibleStartLine - LargeDocumentWindowBacktrackLines);
        int requestEnd = Math.Max(requestStart, visibleEndLine + LargeDocumentAsyncPrefetchLines);
        if (requestStart >= largeDocumentCacheStartLine &&
            requestEnd <= largeDocumentCachedUntilLine)
        {
            return;
        }

        if (largeDocumentSyntaxRequestedStartLine < 0)
        {
            largeDocumentSyntaxRequestedStartLine = requestStart;
            largeDocumentSyntaxRequestedEndLine = requestEnd;
        }
        else
        {
            largeDocumentSyntaxRequestedStartLine = Math.Min(largeDocumentSyntaxRequestedStartLine, requestStart);
            largeDocumentSyntaxRequestedEndLine = Math.Max(largeDocumentSyntaxRequestedEndLine, requestEnd);
        }

        if (largeDocumentSyntaxFillTask != null && !largeDocumentSyntaxFillTask.IsCompleted)
            return;

        int generation = largeDocumentGeneration;
        largeDocumentSyntaxFillTask = Task.Factory.StartNew(
            () => RunLargeDocumentSyntaxFillLoop(generation),
            TaskCreationOptions.LongRunning);
    }

    private void RunLargeDocumentSyntaxFillLoop(int generation)
    {
        try
        {
            while (true)
            {
                int requestStart;
                int requestEnd;
                lock (gate)
                {
                    if (generation != largeDocumentGeneration || !activeDocumentLargeMode)
                        return;

                    requestStart = largeDocumentSyntaxRequestedStartLine;
                    requestEnd = largeDocumentSyntaxRequestedEndLine;
                    largeDocumentSyntaxRequestedStartLine = -1;
                    largeDocumentSyntaxRequestedEndLine = -1;
                }

                if (requestStart < 0 || requestEnd < requestStart)
                    return;

                Document? doc = getDocument();
                if (doc == null)
                    continue;

                bool updated;
                lock (gate)
                {
                    if (generation != largeDocumentGeneration || !activeDocumentLargeMode)
                        return;

                    if (!EnsureLargeDocumentLineAnalyzerLocked())
                        continue;

                    updated = FillLargeDocumentSyntaxWindowLocked(doc, requestStart, requestEnd);
                }

                if (updated)
                    requestRefresh();
            }
        }
        finally
        {
            lock (gate)
            {
                if (generation == largeDocumentGeneration)
                    largeDocumentSyntaxFillTask = null;
            }
        }
    }

    private bool FillLargeDocumentSyntaxWindowLocked(Document doc, int requestStartLine, int requestEndLine)
    {
        int total = Math.Max(0, doc.GetLineCount());
        if (total <= 0)
            return false;

        int analyzeStart = Math.Max(0, requestStartLine);
        int analyzeEnd = Math.Min(requestEndLine, total - 1);
        if (analyzeEnd < analyzeStart)
            return false;

        if (largeDocumentCacheStartLine >= 0 &&
            analyzeStart >= largeDocumentCacheStartLine &&
            analyzeEnd <= largeDocumentCachedUntilLine)
        {
            return false;
        }

        bool canExtendSequentially =
            largeDocumentCacheStartLine >= 0 &&
            analyzeStart >= largeDocumentCacheStartLine &&
            analyzeStart <= largeDocumentCachedUntilLine + 1 &&
            analyzeEnd > largeDocumentCachedUntilLine &&
            analyzeEnd - largeDocumentCachedUntilLine <= LargeDocumentSequentialCatchUpLimit;

        int startState;
        if (!canExtendSequentially)
        {
            ResetLargeDocumentSyntaxWindowLocked(analyzeStart);
            startState = 0;
        }
        else
        {
            analyzeStart = Math.Max(analyzeStart, largeDocumentCachedUntilLine + 1);
            startState = largeDocumentLineEndStates.TryGetValue(analyzeStart - 1, out int previousState)
                ? previousState
                : 0;
        }

        bool updated = false;
        for (int lineIndex = analyzeStart; lineIndex <= analyzeEnd; lineIndex++)
        {
            string line = GetDocumentLineText(doc, lineIndex);
            var result = sweetLineLargeDocumentAnalyzer!.AnalyzeLine(line, new SlTextLineInfo(lineIndex, startState, 0));
            CacheLargeDocumentHighlightLine(lineIndex, result.Highlight);
            largeDocumentLineEndStates[lineIndex] = result.EndState;
            startState = result.EndState;
            largeDocumentCachedUntilLine = lineIndex;
            updated = true;
        }

        return updated;
    }

    private void CacheLargeDocumentHighlightLine(int lineIndex, SlLineHighlight lineHighlight)
    {
        if (!largeDocumentSyntaxCache.TryGetValue(lineIndex, out List<StyleSpan>? spans))
        {
            spans = new List<StyleSpan>();
            largeDocumentSyntaxCache[lineIndex] = spans;
        }
        else
        {
            spans.Clear();
        }

        foreach (var span in lineHighlight.Spans)
        {
            int column = span.Range.Start.Column;
            int length = Math.Max(0, span.Range.End.Column - span.Range.Start.Column);
            if (length <= 0 || column < 0)
                continue;
            spans.Add(new StyleSpan(column, length, NormalizeStyleId(span.StyleId)));
        }
    }

    private void InvalidateLargeDocumentSyntaxCacheIfNeeded(Document doc, IReadOnlyList<TextChange> changes)
    {
        if (changes == null || changes.Count == 0)
            return;

        largeDocumentSyntaxCache.Clear();
        largeDocumentLineEndStates.Clear();
        largeDocumentCacheStartLine = -1;
        largeDocumentCachedUntilLine = -1;
        if (largeDocumentNativeCacheReady && sweetLineLargeDocumentSliceAnalyzer != null)
            return;

        if (activeDocumentStreamingLoad)
        {
            largeDocumentGeneration++;
            largeDocumentNativeCacheReady = false;
            DisposeLargeDocumentSliceSessionLocked();
            return;
        }

        largeDocumentGeneration++;
        largeDocumentNativeCacheReady = false;
        DisposeLargeDocumentSliceSessionLocked();
        activeContent = doc.GetText();
        StartLargeDocumentPrimeLocked(activeContent);
    }

    private bool EnsureLargeDocumentLineAnalyzerLocked()
    {
        if (sweetLineLargeDocumentAnalyzer != null)
            return true;

        DemoSweetLineRuntime? runtime = DemoSweetLineRuntime.TryGetOrCreate();
        if (runtime == null)
            return false;

        string fileName = activeFileName ?? "sample.txt";
        string languageId = activeLanguageId ?? GuessLanguageId(fileName);
        sweetLineLargeDocumentAnalyzer = runtime.CreateTextAnalyzer(languageId, fileName);
        return sweetLineLargeDocumentAnalyzer != null;
    }

    private void StartLargeDocumentPrimeLocked(string? contentSnapshot)
    {
        if (!activeDocumentLargeMode || activeDocumentStreamingLoad || largeDocumentNativeCacheReady)
            return;

        if (sweetLineLargeDocumentPrimeTask != null && !sweetLineLargeDocumentPrimeTask.IsCompleted)
            return;

        string fileName = activeFileName ?? "sample.txt";
        string languageId = activeLanguageId ?? GuessLanguageId(fileName);
        string content = contentSnapshot ?? activeContent ?? string.Empty;
        int generation = largeDocumentGeneration;

        sweetLineLargeDocumentPrimeTask = Task.Factory.StartNew(() =>
        {
            DemoSweetLineRuntime? runtime = DemoSweetLineRuntime.TryGetOrCreate();
            if (runtime == null)
                return;

            SlDocument? document = null;
            SlDocumentAnalyzer? analyzer = null;
            try
            {
                analyzer = runtime.CreateAnalyzer(languageId, fileName, content, out document);
                if (analyzer == null)
                {
                    document?.Dispose();
                    return;
                }

                analyzer.PrimeHighlightCache();

                SlDocumentAnalyzer? previousAnalyzer = null;
                SlDocument? previousDocument = null;
                bool applied = false;
                lock (gate)
                {
                    if (generation == largeDocumentGeneration && activeDocumentLargeMode)
                    {
                        previousAnalyzer = sweetLineLargeDocumentSliceAnalyzer;
                        previousDocument = sweetLineLargeDocumentSliceDocument;
                        sweetLineLargeDocumentSliceAnalyzer = analyzer;
                        sweetLineLargeDocumentSliceDocument = document;
                        largeDocumentNativeCacheReady = true;
                        applied = true;
                    }
                }

                if (applied)
                {
                    previousAnalyzer?.Dispose();
                    previousDocument?.Dispose();
                    requestRefresh();
                    analyzer = null;
                    document = null;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"SweetLine large-document prime failed: {ex.Message}");
            }
            finally
            {
                analyzer?.Dispose();
                document?.Dispose();
                lock (gate)
                {
                    if (generation == largeDocumentGeneration)
                    {
                        sweetLineLargeDocumentPrimeTask = null;
                    }
                }
            }
        }, TaskCreationOptions.LongRunning);
    }

    private void DisposeLargeDocumentSliceSessionLocked()
    {
        sweetLineLargeDocumentSliceAnalyzer?.Dispose();
        sweetLineLargeDocumentSliceAnalyzer = null;
        sweetLineLargeDocumentSliceDocument?.Dispose();
        sweetLineLargeDocumentSliceDocument = null;
    }

    private void ResetLargeDocumentSyntaxWindowLocked(int startLine)
    {
        largeDocumentSyntaxCache.Clear();
        largeDocumentLineEndStates.Clear();
        largeDocumentCacheStartLine = startLine;
        largeDocumentCachedUntilLine = startLine - 1;
    }

    private void EnsureSmallDocumentLineCache(Document doc, IReadOnlyList<TextChange> changes)
    {
        if (activeDocumentLargeMode)
            return;

        if (changes != null && changes.Count > 0)
        {
            activeContent = doc.GetText();
            activeLines = SplitLines(activeContent);
            smallDocumentRichLineCache.Clear();
            return;
        }

        if (activeLines == null)
        {
            activeContent ??= doc.GetText();
            activeLines = SplitLines(activeContent);
            smallDocumentRichLineCache.Clear();
        }
    }

    private string GetDocumentLineText(Document doc, int lineIndex)
    {
        if (!activeDocumentLargeMode &&
            activeLines != null &&
            (uint)lineIndex < (uint)activeLines.Length)
        {
            return activeLines[lineIndex];
        }

        return doc.GetLineText(lineIndex) ?? string.Empty;
    }

    private static string[] SplitLines(string? content)
    {
        if (string.IsNullOrEmpty(content))
            return [string.Empty];

        var lines = new List<string>();
        int start = 0;
        for (int i = 0; i < content.Length; i++)
        {
            if (content[i] != '\n')
                continue;

            int length = i - start;
            if (length > 0 && content[i - 1] == '\r')
                length--;
            lines.Add(content.Substring(start, Math.Max(0, length)));
            start = i + 1;
        }

        int tailLength = content.Length - start;
        if (tailLength > 0 && content[^1] == '\r')
            tailLength--;
        lines.Add(content.Substring(start, Math.Max(0, tailLength)));
        return lines.ToArray();
    }

    private CachedRichLineDecorations GetCachedRichLineDecorations(int lineIndex, string line)
    {
        if (!smallDocumentRichLineCache.TryGetValue(lineIndex, out CachedRichLineDecorations? cached) ||
            !string.Equals(cached.LineText, line, StringComparison.Ordinal))
        {
            cached = new CachedRichLineDecorations
            {
                LineText = line,
            };
            BuildCachedDiagnostics(line, cached.Diagnostics);
            BuildCachedInlays(line, cached.Inlays);
            BuildCachedIcons(line, cached.GutterIcons);
            BuildCachedPhantoms(line, cached.Phantoms);
            smallDocumentRichLineCache[lineIndex] = cached;
        }

        return cached;
    }

    private static void CopyCachedLineDecorations(
        CachedRichLineDecorations cached,
        int lineIndex,
        Dictionary<int, List<DiagnosticItem>> diagnostics,
        Dictionary<int, List<InlayHint>> inlays,
        Dictionary<int, List<GutterIcon>> gutterIcons,
        Dictionary<int, List<PhantomText>> phantoms)
    {
        if (cached.Diagnostics.Count > 0)
            diagnostics[lineIndex] = new List<DiagnosticItem>(cached.Diagnostics);
        if (cached.Inlays.Count > 0)
            inlays[lineIndex] = new List<InlayHint>(cached.Inlays);
        if (cached.GutterIcons.Count > 0)
            gutterIcons[lineIndex] = new List<GutterIcon>(cached.GutterIcons);
        if (cached.Phantoms.Count > 0)
            phantoms[lineIndex] = new List<PhantomText>(cached.Phantoms);
    }

    private static void BuildCachedDiagnostics(string line, List<DiagnosticItem> diagnostics)
    {
        diagnostics.Clear();
        if (string.IsNullOrWhiteSpace(line))
            return;

        int todo = line.IndexOf("TODO", StringComparison.OrdinalIgnoreCase);
        if (todo >= 0)
            diagnostics.Add(new DiagnosticItem(todo, 4, 1, unchecked((int)0xFFE0AF68)));

        int fixme = line.IndexOf("FIXME", StringComparison.OrdinalIgnoreCase);
        if (fixme >= 0)
            diagnostics.Add(new DiagnosticItem(fixme, 5, 0, unchecked((int)0xFFF7768E)));

        if (line.Length > 120)
            diagnostics.Add(new DiagnosticItem(120, line.Length - 120, 2, unchecked((int)0xFF7DCFFF)));
    }

    private static void BuildCachedInlays(string line, List<InlayHint> inlays)
    {
        inlays.Clear();
        if (string.IsNullOrWhiteSpace(line))
            return;

        if (line.Contains("auto ", StringComparison.Ordinal) || line.Contains("var ", StringComparison.Ordinal) || line.Contains("val ", StringComparison.Ordinal))
            inlays.Add(InlayHint.TextHint(Math.Max(0, line.Length), " : inferred"));

        Match colorMatch = HexColorRegex.Match(line);
        if (colorMatch.Success)
            inlays.Add(InlayHint.ColorHint(colorMatch.Index + colorMatch.Length, ParseColor(colorMatch.Value)));

        if (line.Contains("@", StringComparison.Ordinal) || line.Contains("TODO", StringComparison.OrdinalIgnoreCase))
            inlays.Add(InlayHint.IconHint(Math.Max(0, line.Length), IconNote));
    }

    private static void BuildCachedIcons(string line, List<GutterIcon> gutterIcons)
    {
        gutterIcons.Clear();
        if (line.Contains("class ", StringComparison.Ordinal) || line.Contains("struct ", StringComparison.Ordinal))
            gutterIcons.Add(new GutterIcon(IconType));
        if (line.Contains("TODO", StringComparison.OrdinalIgnoreCase) || line.Contains("@", StringComparison.Ordinal))
            gutterIcons.Add(new GutterIcon(IconNote));
    }

    private static void BuildCachedPhantoms(string line, List<PhantomText> phantoms)
    {
        phantoms.Clear();
        if (line.Contains("return", StringComparison.Ordinal) || line.Contains("println", StringComparison.OrdinalIgnoreCase))
            phantoms.Add(new PhantomText(Math.Max(0, line.Length), "  // phantom"));
    }

    private static void AppendHighlightLine(
        SlLineHighlight lineHighlight,
        int lineIndex,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        foreach (var span in lineHighlight.Spans)
        {
            int column = span.Range.Start.Column;
            int length = Math.Max(0, span.Range.End.Column - span.Range.Start.Column);
            AddSpan(syntax, lineIndex, column, length, NormalizeStyleId(span.StyleId));
        }
    }

    private static SlLineRange CreateLineRange(int start, int end)
    {
        int lineCount = Math.Max(0, end - start + 1);
        return new SlLineRange(Math.Max(0, start), lineCount);
    }

    private static void AddSpan(Dictionary<int, List<StyleSpan>> map, int line, int column, int length, int styleId)
    {
        if (length <= 0 || column < 0)
            return;
        if (!map.TryGetValue(line, out List<StyleSpan>? spans))
        {
            spans = new List<StyleSpan>();
            map[line] = spans;
        }
        spans.Add(new StyleSpan(column, length, styleId));
    }

    private static void AddInlay(Dictionary<int, List<InlayHint>> map, int line, InlayHint item)
    {
        if (!map.TryGetValue(line, out List<InlayHint>? items))
        {
            items = new List<InlayHint>();
            map[line] = items;
        }
        items.Add(item);
    }

    private static void AddDiag(Dictionary<int, List<DiagnosticItem>> map, int line, DiagnosticItem item)
    {
        if (!map.TryGetValue(line, out List<DiagnosticItem>? items))
        {
            items = new List<DiagnosticItem>();
            map[line] = items;
        }
        items.Add(item);
    }

    private static void AddIcon(Dictionary<int, List<GutterIcon>> map, int line, int iconId)
    {
        if (!map.TryGetValue(line, out List<GutterIcon>? items))
        {
            items = new List<GutterIcon>();
            map[line] = items;
        }
        if (!items.Any(item => item.IconId == iconId))
            items.Add(new GutterIcon(iconId));
    }

    private static void AddPhantom(Dictionary<int, List<PhantomText>> map, int line, PhantomText item)
    {
        if (!map.TryGetValue(line, out List<PhantomText>? items))
        {
            items = new List<PhantomText>();
            map[line] = items;
        }
        items.Add(item);
    }

    private static void BuildSyntaxFallback(int lineIndex, string line, Dictionary<int, List<StyleSpan>> syntax)
    {
        if (string.IsNullOrEmpty(line))
            return;

        int commentStart = line.IndexOf("//", StringComparison.Ordinal);
        int scanLimit = commentStart >= 0 ? commentStart : line.Length;
        if (commentStart >= 0)
            AddSpan(syntax, lineIndex, commentStart, line.Length - commentStart, (int)EditorTheme.STYLE_COMMENT);

        foreach (Match match in NumberRegex.Matches(line))
        {
            if (match.Index >= scanLimit)
                continue;
            AddSpan(syntax, lineIndex, match.Index, match.Length, (int)EditorTheme.STYLE_NUMBER);
        }

        foreach (Match match in HexColorRegex.Matches(line))
        {
            if (match.Index >= scanLimit)
                continue;
            AddSpan(syntax, lineIndex, match.Index, match.Length, StyleColor);
        }

        int search = 0;
        while (search < scanLimit)
        {
            int quote = line.IndexOf('"', search);
            if (quote < 0 || quote >= scanLimit)
                break;
            int endQuote = quote + 1;
            bool escaped = false;
            while (endQuote < scanLimit)
            {
                char ch = line[endQuote++];
                if (ch == '"' && !escaped)
                    break;
                escaped = ch == '\\' && !escaped;
                if (ch != '\\')
                    escaped = false;
            }
            AddSpan(syntax, lineIndex, quote, Math.Max(1, endQuote - quote), (int)EditorTheme.STYLE_STRING);
            search = endQuote;
        }

        foreach (Match match in IdentifierRegex.Matches(line[..scanLimit]))
        {
            string token = match.Value;
            if (Keywords.Contains(token))
                AddSpan(syntax, lineIndex, match.Index, match.Length, (int)EditorTheme.STYLE_KEYWORD);
            else if (Types.Contains(token))
                AddSpan(syntax, lineIndex, match.Index, match.Length, (int)EditorTheme.STYLE_TYPE);
            else if (token.Length > 0 && char.IsUpper(token[0]))
                AddSpan(syntax, lineIndex, match.Index, match.Length, (int)EditorTheme.STYLE_CLASS);
        }

        if (line.TrimStart().StartsWith("#", StringComparison.Ordinal))
            AddSpan(syntax, lineIndex, 0, scanLimit, (int)EditorTheme.STYLE_PREPROCESSOR);
    }

    private static void BuildDiagnostics(int lineIndex, string line, Dictionary<int, List<DiagnosticItem>> diagnostics)
    {
        if (string.IsNullOrWhiteSpace(line))
            return;

        int todo = line.IndexOf("TODO", StringComparison.OrdinalIgnoreCase);
        if (todo >= 0)
            AddDiag(diagnostics, lineIndex, new DiagnosticItem(todo, 4, 1, unchecked((int)0xFFE0AF68)));

        int fixme = line.IndexOf("FIXME", StringComparison.OrdinalIgnoreCase);
        if (fixme >= 0)
            AddDiag(diagnostics, lineIndex, new DiagnosticItem(fixme, 5, 0, unchecked((int)0xFFF7768E)));

        if (line.Length > 120)
            AddDiag(diagnostics, lineIndex, new DiagnosticItem(120, line.Length - 120, 2, unchecked((int)0xFF7DCFFF)));
    }

    private static void BuildInlays(int lineIndex, string line, Dictionary<int, List<InlayHint>> inlays)
    {
        if (string.IsNullOrWhiteSpace(line))
            return;

        if (line.Contains("auto ", StringComparison.Ordinal) || line.Contains("var ", StringComparison.Ordinal) || line.Contains("val ", StringComparison.Ordinal))
            AddInlay(inlays, lineIndex, InlayHint.TextHint(Math.Max(0, line.Length), " : inferred"));

        Match colorMatch = HexColorRegex.Match(line);
        if (colorMatch.Success)
            AddInlay(inlays, lineIndex, InlayHint.ColorHint(colorMatch.Index + colorMatch.Length, ParseColor(colorMatch.Value)));

        if (line.Contains("@", StringComparison.Ordinal) || line.Contains("TODO", StringComparison.OrdinalIgnoreCase))
            AddInlay(inlays, lineIndex, InlayHint.IconHint(Math.Max(0, line.Length), IconNote));
    }

    private static int ParseColor(string value)
    {
        string hex = value.TrimStart('#');
        if (hex.Length == 6)
            hex = "FF" + hex;
        return int.TryParse(hex, System.Globalization.NumberStyles.HexNumber, null, out int color)
            ? unchecked((int)((uint)color))
            : unchecked((int)0xFF7DCFFF);
    }

    private static void BuildIcons(int lineIndex, string line, Dictionary<int, List<GutterIcon>> gutterIcons)
    {
        if (line.Contains("class ", StringComparison.Ordinal) || line.Contains("struct ", StringComparison.Ordinal))
            AddIcon(gutterIcons, lineIndex, IconType);
        if (line.Contains("TODO", StringComparison.OrdinalIgnoreCase) || line.Contains("@", StringComparison.Ordinal))
            AddIcon(gutterIcons, lineIndex, IconNote);
    }

    private static void BuildPhantoms(int lineIndex, string line, Dictionary<int, List<PhantomText>> phantoms, bool largeMode)
    {
        if (largeMode)
        {
            if (lineIndex > 0 && lineIndex % 400 == 0)
                AddPhantom(phantoms, lineIndex, new PhantomText(Math.Max(0, line.Length), "  • checkpoint"));
            return;
        }

        if (line.Contains("return", StringComparison.Ordinal) || line.Contains("println", StringComparison.OrdinalIgnoreCase))
            AddPhantom(phantoms, lineIndex, new PhantomText(Math.Max(0, line.Length), "  // phantom"));
    }

    private static void BuildGuidesFallback(int lineIndex, string line, List<IndentGuide> indentGuides, List<FlowGuide> flowGuides)
    {
        int indent = 0;
        while (indent < line.Length && line[indent] == ' ')
            indent++;

        if (indent >= 4)
        {
            indentGuides.Add(new IndentGuide(
                new TextPosition { Line = lineIndex, Column = 0 },
                new TextPosition { Line = lineIndex, Column = indent }));
        }

        string trimmed = line.TrimStart();
        if (trimmed.StartsWith("if ", StringComparison.Ordinal) ||
            trimmed.StartsWith("if(", StringComparison.Ordinal) ||
            trimmed.StartsWith("for ", StringComparison.Ordinal) ||
            trimmed.StartsWith("while ", StringComparison.Ordinal))
        {
            int startColumn = Math.Max(0, line.IndexOf(trimmed, StringComparison.Ordinal));
            flowGuides.Add(new FlowGuide(
                new TextPosition { Line = lineIndex, Column = startColumn },
                new TextPosition { Line = lineIndex, Column = Math.Min(line.Length, startColumn + trimmed.Length) }));
        }
    }

    private static void BuildBraces(int lineIndex, string line, Stack<(int line, int column)> braceStack, List<FoldRegion> folds, List<BracketGuide> brackets)
    {
        for (int column = 0; column < line.Length; column++)
        {
            char ch = line[column];
            if (ch == '{')
            {
                braceStack.Push((lineIndex, column));
            }
            else if (ch == '}' && braceStack.Count > 0)
            {
                var open = braceStack.Pop();
                if (lineIndex > open.line)
                {
                    folds.Add(new FoldRegion(open.line, lineIndex));
                    brackets.Add(new BracketGuide(
                        new TextPosition { Line = open.line, Column = open.column },
                        new TextPosition { Line = lineIndex, Column = column },
                        null));
                }
            }
        }
    }
}
