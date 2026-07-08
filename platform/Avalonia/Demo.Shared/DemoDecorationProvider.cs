using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using SweetEditor;
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

namespace SweetEditor.Avalonia.Demo;

internal sealed class DemoDecorationProvider : IDecorationProvider
{
    private const int LargeDocumentSequentialCatchUpLimit = 384;
    private const int LargeDocumentWindowBacktrackLines = 64;
    private const int LargeDocumentAsyncPrefetchLines = 192;

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
    private SlIndentGuideResult? sweetLineGuides;
    private SlTextAnalyzer? sweetLineLargeDocumentAnalyzer;
    private SlDocument? sweetLineLargeDocumentSliceDocument;
    private SlDocumentAnalyzer? sweetLineLargeDocumentSliceAnalyzer;
    private Task? sweetLineLargeDocumentPrimeTask;
    private bool sweetLineAvailable;
    private bool sweetLineInitialized;
    private int sweetLineSessionVersion;
    private bool activeDocumentLargeMode;
    private bool largeDocumentNativeCacheReady;
    private int largeDocumentGeneration;
    private readonly Dictionary<int, List<StyleSpan>> largeDocumentSyntaxCache = new();
    private readonly Dictionary<int, int> largeDocumentLineEndStates = new();
    private int largeDocumentCacheStartLine = -1;
    private int largeDocumentCachedUntilLine = -1;
    private Task? largeDocumentSyntaxFillTask;
    private int largeDocumentSyntaxRequestedStartLine = -1;
    private int largeDocumentSyntaxRequestedEndLine = -1;

    public const int IconType = 1;
    public const int IconNote = 2;
    public const int StyleColor = unchecked((int)EditorTheme.STYLE_USER_BASE) + 1;
    public const int StyleUrl = unchecked((int)EditorTheme.STYLE_USER_BASE) + 2;
    public const int CodeLensRun = 1;
    public const int CodeLensDebug = 2;

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
        DecorationType.FoldRegion |
        DecorationType.IndentGuide |
        DecorationType.FlowGuide;

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
            activeLines = activeDocumentLargeMode ? null : SplitLines(content);
            highlightBackendLabel = "SweetLine pending";

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
            if (activeDocumentLargeMode && !IsMobilePlatform())
            {
                StartLargeDocumentPrimeLocked(content);
            }
        }
    }

    public void ActivatePrimedDocument(string fileName, string content, Document document)
    {
        lock (gate)
        {
            activeFileName = fileName;
            activeContent = content;
            activeLanguageId = GuessLanguageId(fileName);
            activeDocumentLargeMode = IsLargeDocument(content);
            activeLines = activeDocumentLargeMode ? null : SplitLines(content);
            if (activeDocumentLargeMode && !IsMobilePlatform())
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
        int pad = largeMode ? 0 : 24;
        int start = Math.Max(0, context.VisibleLineRange.Start - pad);
        int end = Math.Min(total - 1, Math.Max(context.VisibleLineRange.End, context.VisibleLineRange.Start) + pad);

        var syntax = new Dictionary<int, List<StyleSpan>>();
        var folds = new List<FoldRegion>();
        var indentGuides = new List<IndentGuide>();
        var flowGuides = new List<FlowGuide>();

        bool usedSweetLine = TryBuildSyntaxWithSweetLine(
            doc,
            context,
            start,
            end,
            syntax,
            folds,
            indentGuides,
            flowGuides,
            out DecorationApplyMode syntaxApplyMode);
        SetHighlightBackendLabel(usedSweetLine);

        if (!usedSweetLine)
        {
            EnsureSmallDocumentLineCache(doc, context.TextChanges);
            for (int lineIndex = start; lineIndex <= end; lineIndex++)
            {
                string line = GetDocumentLineText(doc, lineIndex);
                BuildSyntaxFallback(lineIndex, line, syntax);
            }
        }

        var result = new DecorationResult
        {
            SyntaxSpans = syntax,
            FoldRegions = folds,
            IndentGuides = indentGuides,
            FlowGuides = flowGuides,
            SyntaxSpansMode = syntaxApplyMode,
            FoldRegionsMode = DecorationApplyMode.REPLACE_ALL,
            IndentGuidesMode = DecorationApplyMode.REPLACE_ALL,
            FlowGuidesMode = DecorationApplyMode.REPLACE_ALL,
        };

        receiver.Accept(result);
    }

    private bool TryBuildSyntaxWithSweetLine(
        Document doc,
        DecorationContext context,
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax,
        List<FoldRegion> folds,
        List<IndentGuide> indentGuides,
        List<FlowGuide> flowGuides,
        out DecorationApplyMode syntaxApplyMode)
    {
        lock (gate)
        {
            if (IsMobilePlatform())
            {
                InvalidateLargeDocumentSyntaxCacheIfNeeded(doc, context.TextChanges);
                syntaxApplyMode = DecorationApplyMode.REPLACE_RANGE;
                return TryBuildViewportDecorationsWithSweetLineLocked(
                    doc,
                    context,
                    start,
                    end,
                    syntax,
                    folds,
                    indentGuides,
                    flowGuides);
            }

            if (activeDocumentLargeMode)
            {
                InvalidateLargeDocumentSyntaxCacheIfNeeded(doc, context.TextChanges);
                bool builtLargeDocumentSyntax = TryBuildLargeDocumentSyntaxLocked(doc, context, start, end, syntax);
                syntaxApplyMode = DecorationApplyMode.REPLACE_RANGE;
                return builtLargeDocumentSyntax;
            }

            syntaxApplyMode = DecorationApplyMode.REPLACE_RANGE;
            if (!EnsureSweetLineSession(context))
            {
                return false;
            }

            SlLineRange visibleRange = CreateLineRange(start, end);
            SlDocumentHighlightSlice? slice = AnalyzeSweetLineRange(context.TextChanges, visibleRange);
            if (slice == null || !HasUsableSlice(slice, visibleRange))
                return false;

            AppendHighlightSlice(slice, syntax);

            AppendSweetLineGuides(sweetLineGuides, start, end, folds, indentGuides, flowGuides);

            return true;
        }
    }

    private bool EnsureSweetLineSession(DecorationContext context)
    {
        if (sweetLineInitialized)
            return sweetLineAvailable;

        if (activeDocumentLargeMode && !IsMobilePlatform())
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

    private SlDocumentHighlightSlice? AnalyzeSweetLineRange(IReadOnlyList<TextChange> changes, SlLineRange visibleRange)
    {
        if (sweetLineAnalyzer == null)
            return null;

        SlDocumentHighlightSlice? slice = null;
        if (changes != null && changes.Count > 0)
        {
            foreach (TextChange change in changes)
            {
                TextRange range = change.Range;
                string newText = change.Text ?? change.NewText ?? string.Empty;
                SlTextRange slRange = new(
                    new SlTextPosition(range.Start.Line, range.Start.Column),
                    new SlTextPosition(range.End.Line, range.End.Column));
                slice = sweetLineAnalyzer.AnalyzeIncrementalInLineRange(slRange, newText, visibleRange);
            }
        }
        else
        {
            slice = sweetLineAnalyzer.AnalyzeLineRange(visibleRange);
        }

        sweetLineGuides = sweetLineAnalyzer.AnalyzeIndentGuidesInLineRange(visibleRange);
        return slice;
    }

    private static bool HasUsableSlice(SlDocumentHighlightSlice slice, SlLineRange visibleRange)
    {
        if (visibleRange.LineCount <= 0)
            return true;

        if (slice.TotalLineCount <= visibleRange.StartLine)
            return false;

        return slice.Lines.Count > 0;
    }

    private bool TryBuildViewportDecorationsWithSweetLineLocked(
        Document doc,
        DecorationContext context,
        int start,
        int end,
        Dictionary<int, List<StyleSpan>> syntax,
        List<FoldRegion> folds,
        List<IndentGuide> indentGuides,
        List<FlowGuide> flowGuides)
    {
        if (start < 0 || end < start)
            return false;

        int total = Math.Max(0, doc.GetLineCount());
        if (total <= 0)
            return false;

        int safeStart = Math.Max(0, start);
        int safeEnd = Math.Min(end, total - 1);
        if (safeEnd < safeStart)
            return false;

        SlLineRange visibleRange = CreateLineRange(safeStart, safeEnd);
        if (TryBuildViewportDocumentAnalyzerDecorationsLocked(
                context,
                visibleRange,
                syntax,
                folds,
                indentGuides,
                flowGuides))
        {
            return true;
        }

        return TryBuildViewportSyntaxWithLineAnalyzerLocked(doc, safeStart, safeEnd, syntax);
    }

    private bool TryBuildViewportDocumentAnalyzerDecorationsLocked(
        DecorationContext context,
        SlLineRange visibleRange,
        Dictionary<int, List<StyleSpan>> syntax,
        List<FoldRegion> folds,
        List<IndentGuide> indentGuides,
        List<FlowGuide> flowGuides)
    {
        if (!EnsureSweetLineSession(context))
            return false;

        SlDocumentHighlightSlice? slice = AnalyzeSweetLineRange(context.TextChanges, visibleRange);
        if (slice == null || !HasUsableSlice(slice, visibleRange))
            return false;

        AppendHighlightSlice(slice, syntax);
        AppendSweetLineGuides(
            sweetLineGuides,
            visibleRange.StartLine,
            visibleRange.StartLine + Math.Max(0, visibleRange.LineCount) - 1,
            folds,
            indentGuides,
            flowGuides);
        return true;
    }

    private bool TryBuildViewportSyntaxWithLineAnalyzerLocked(
        Document doc,
        int safeStart,
        int safeEnd,
        Dictionary<int, List<StyleSpan>> syntax)
    {
        if (!EnsureLargeDocumentLineAnalyzerLocked())
            return false;

        if (!IsLargeDocumentSyntaxRangeCached(safeStart, safeEnd))
        {
            int analyzeStart = Math.Max(0, safeStart - LargeDocumentWindowBacktrackLines);
            FillLargeDocumentSyntaxWindowLocked(doc, analyzeStart, safeEnd);
        }

        AppendCachedLargeDocumentSyntaxLocked(safeStart, safeEnd, syntax);
        return syntax.Count > 0 || safeStart <= safeEnd;
    }

    private bool IsLargeDocumentSyntaxRangeCached(int start, int end)
    {
        return largeDocumentCacheStartLine >= 0 &&
               start >= largeDocumentCacheStartLine &&
               end <= largeDocumentCachedUntilLine;
    }

    private static void AppendSweetLineGuides(
        SlIndentGuideResult? guides,
        int start,
        int end,
        List<FoldRegion> folds,
        List<IndentGuide> indentGuides,
        List<FlowGuide> flowGuides)
    {
        if (guides == null)
            return;

        var seenFolds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var guide in guides.GuideLines)
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
                flowGuides.Add(new FlowGuide {
                    Start = new TextPosition { Line = Math.Max(start, guide.StartLine), Column = guide.Column },
                    End = new TextPosition { Line = branch.Line, Column = branch.Column }
                });
            }

            if (guide.EndLine > guide.StartLine)
            {
                string key = $"{guide.StartLine}:{guide.EndLine}";
                if (seenFolds.Add(key))
                    folds.Add(new FoldRegion(guide.StartLine, guide.EndLine));
            }
        }
    }

    private void ResetSweetLineState()
    {
        largeDocumentGeneration++;
        largeDocumentSyntaxCache.Clear();
        largeDocumentLineEndStates.Clear();
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
        sweetLineGuides = null;
        largeDocumentSyntaxFillTask = null;
        sweetLineInitialized = false;
        sweetLineAvailable = false;
    }

    private void SetHighlightBackendLabel(bool usedSweetLine)
    {
        string nextLabel;
        lock (gate)
        {
            bool hasAsyncSweetLinePipeline =
                sweetLineLargeDocumentPrimeTask != null ||
                largeDocumentSyntaxFillTask != null ||
                sweetLineLargeDocumentAnalyzer != null ||
                sweetLineLargeDocumentSliceAnalyzer != null;

            if (activeDocumentLargeMode && !largeDocumentNativeCacheReady && hasAsyncSweetLinePipeline)
            {
                nextLabel = "SweetLine async";
            }
            else if (usedSweetLine)
            {
                nextLabel = "SweetLine native";
            }
            else
            {
                nextLabel = string.IsNullOrWhiteSpace(DemoSweetLineRuntime.LastInitErrorMessage)
                    ? "SweetLine unavailable"
                    : "SweetLine error";
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

    private static bool IsMobilePlatform() => OperatingSystem.IsAndroid() || OperatingSystem.IsIOS();

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
            if (IsMobilePlatform() &&
                changes != null &&
                changes.Count > 0)
            {
                return false;
            }

            SlDocumentHighlightSlice slice = sweetLineLargeDocumentSliceAnalyzer.GetHighlightSlice(visibleRange);

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

        bool requiresNativeSliceReset = IsMobilePlatform();
        largeDocumentSyntaxCache.Clear();
        largeDocumentLineEndStates.Clear();
        largeDocumentCacheStartLine = -1;
        largeDocumentCachedUntilLine = -1;

        if (!requiresNativeSliceReset &&
            largeDocumentNativeCacheReady &&
            sweetLineLargeDocumentSliceAnalyzer != null)
        {
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
        if (IsMobilePlatform())
            return;

        if (!activeDocumentLargeMode || largeDocumentNativeCacheReady)
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

                _ = analyzer.Analyze();

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
            return;
        }

        if (activeLines == null)
        {
            activeContent ??= doc.GetText();
            activeLines = SplitLines(activeContent);
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

}
