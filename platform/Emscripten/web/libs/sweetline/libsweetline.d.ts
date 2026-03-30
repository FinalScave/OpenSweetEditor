export namespace sweetline {
    /**
     * Text position descriptor
     */
    export class TextPosition {
        /**
         * Line number (0-based)
         */
        line: number;
        /**
         * Column number (0-based)
         */
        column: number;
        /**
         * Character index in the full text (0-based)
         */
        index: number;
    }

    /**
     * Text range descriptor
     */
    export class TextRange {
        /**
         * Start position
         */
        start: TextPosition;
        /**
         * End position
         */
        end: TextPosition;
    }

    /**
     * Managed document with incremental update support
     */
    export class Document {
        /**
         * Constructor
         * @param uri Document URI
         * @param content Document content
         */
        constructor(uri: string, content: string);

        /**
         * Get the URI of the managed document
         */
        getUri(): string;
    }

    /**
     * Inline style definition embedded in syntax rules
     */
    export class InlineStyle {
        /**
         * Foreground color
         */
        foreground: number;
        /**
         * Background color
         */
        background: number;
        /**
         * Whether to display in bold
         */
        isBold: boolean;
        /**
         * Whether to display in italic
         */
        isItalic: boolean;
        /**
         * Whether to display with strikethrough
         */
        isStrikethrough: boolean;
    }

    /**
     * Each highlight token span
     */
    export class TokenSpan {
        /**
         * Highlight range
         */
        range: TextRange;
        /**
         * Highlight style ID
         */
        styleId: number;
        /**
         * Detailed style info for the token span (only in inlineStyle mode)
         */
        inlineStyle: InlineStyle;
    }

    export class TokenSpanList {
        get(index: number): TokenSpan;
        set(index: number, element: TokenSpan): void;
        add(element: TokenSpan): void;
        remove(element: TokenSpan): void;
        isEmpty(): boolean;
        size(): number;
    }

    /**
     * Highlight token span sequence for each line
     */
    export class LineHighlight {
        /**
         * Highlight sequence
         */
        spans: TokenSpanList;

        /**
         * Convert to JSON string
         */
        toJson(): string;
    }

    export class LineHighlightList {
        get(index: number): LineHighlight;
        set(index: number, element: LineHighlight): void;
        add(element: LineHighlight): void;
        remove(element: LineHighlight): void;
        isEmpty(): boolean;
        size(): number;
    }

    /**
     * Highlight result for the entire document
     */
    export class DocumentHighlight {
        /**
         * Highlight sequence for each line
         */
        lines: LineHighlightList;

        /**
         * Convert to JSON string
         */
        toJson(): string;
    }

    /**
     * Line range descriptor (0-based)
     */
    export class LineRange {
        /**
         * Start line number
         */
        startLine: number;
        /**
         * Line count
         */
        lineCount: number;
    }

    /**
     * Highlight slice for the specified line range
     */
    export class DocumentHighlightSlice {
        /**
         * Slice start line
         */
        startLine: number;
        /**
         * Total line count after patch
         */
        totalLineCount: number;
        /**
         * Highlight sequence for slice lines
         */
        lines: LineHighlightList;
    }

    /**
     * Line scope state for indent guide analysis
     */
    export class LineScopeState {
        /**
         * Nesting level of the line
         */
        nestingLevel: number;
        /**
         * Scope state of the line: 0=START, 1=END, 2=CONTENT
         */
        scopeState: number;
        /**
         * Column of the scope marker
         */
        scopeColumn: number;
        /**
         * Indentation level of the line
         */
        indentLevel: number;
    }

    /**
     * Single indent guide line (vertical line segment)
     */
    export class IndentGuideLine {
        /**
         * Column of the guide line (character column)
         */
        column: number;
        /**
         * Start line number
         */
        startLine: number;
        /**
         * End line number
         */
        endLine: number;
        /**
         * Nesting level (0-based)
         */
        nestingLevel: number;
        /**
         * Associated ScopeRule ID (matching pair mode), -1 for indentation mode
         */
        scopeRuleId: number;
        /**
         * Branch point list (line/column positions of else/case etc.)
         */
        branches: BranchPointList;
    }

    /**
     * Branch point (e.g. position of else/case)
     */
    export class BranchPoint {
        line: number;
        column: number;
    }

    export class BranchPointList {
        get(index: number): BranchPoint;
        set(index: number, element: BranchPoint): void;
        add(element: BranchPoint): void;
        remove(element: BranchPoint): void;
        isEmpty(): boolean;
        size(): number;
    }

    export class Int32List {
        get(index: number): number;
        set(index: number, element: number): void;
        add(element: number): void;
        remove(element: number): void;
        isEmpty(): boolean;
        size(): number;
    }

    export class IndentGuideLineList {
        get(index: number): IndentGuideLine;
        set(index: number, element: IndentGuideLine): void;
        add(element: IndentGuideLine): void;
        remove(element: IndentGuideLine): void;
        isEmpty(): boolean;
        size(): number;
    }

    export class LineScopeStateList {
        get(index: number): LineScopeState;
        set(index: number, element: LineScopeState): void;
        add(element: LineScopeState): void;
        remove(element: LineScopeState): void;
        isEmpty(): boolean;
        size(): number;
    }

    /**
     * Indent guide analysis result
     */
    export class IndentGuideResult {
        /**
         * All vertical guide lines
         */
        guideLines: IndentGuideLineList;
        /**
         * Scope state for each line
         */
        lineStates: LineScopeStateList;
    }

    /**
     * Text line metadata
     */
    export class TextLineInfo {
        /**
         * Line index
         */
        line: number;

        /**
         * Start highlight state of the line
         */
        startState: number;

        /**
         * Start character offset in the full text (not bytes), used for computing TokenSpan index; not needed when showIndex is disabled in HighlightConfig
         */
        startCharOffset: number;
    }

    /**
     * Single line syntax highlight analysis result
     */
    export class LineAnalyzeResult {
        /**
         * Highlight sequence of the current line
         */
        highlight: LineHighlight;

        /**
         * End state after line analysis
         */
        endState: number;

        /**
         * Total character count analyzed in the current line, excluding line ending
         */
        charCount: number;
    }

    /**
     * Plain text highlight analyzer, no incremental update support, suitable for full analysis scenarios
     */
    export class TextAnalyzer {
        /**
         * Analyze a text and return the highlight result for the entire text
         * @param text Full text content
         * @return Highlight result
         */
        analyzeText(text: string): DocumentHighlight;

        /**
         * Analyze a single line of text
         * @param text Single line text content
         * @param info Metadata for the current line
         * @return Single line analysis result
         */
        analyzeLine(text: string, info: TextLineInfo): LineAnalyzeResult;

        /**
         * Perform indent guide analysis on a text (performs highlight analysis internally)）
         * @param text Full text content
         * @return Indent guide analysis result
         */
        analyzeIndentGuides(text: string): IndentGuideResult;
    }

    /**
     * Managed document highlight analyzer with automatic patch and incremental analysis support
     */
    export class DocumentAnalyzer {
        /**
         * Perform full highlight analysis on the managed document
         * @return Highlight result
         */
        analyze(): DocumentHighlight;

        /**
         * Incrementally re-analyze the managed document based on patch content
         * @param range Change range of the patch
         * @param newText Patched text
         * @return Highlight result
         */
        analyzeIncremental(range: TextRange, newText: string): DocumentHighlight;

        /**
         * Incrementally re-analyze the managed document based on patch content
         * @param startOffset Start character index of the patch change
         * @param endOffset End character index of the patch change
         * @param newText Patched text
         * @return Highlight result
         */
        analyzeIncremental(startOffset: number, endOffset: number, newText: string): DocumentHighlight;

        /**
         * Incrementally re-analyze and return only highlight slice for the specified line range
         * @param range Change range of the patch
         * @param newText Patched text
         * @param visibleRange Visible line range
         * @return Highlight slice for the specified line range
         */
        analyzeIncrementalInLineRange(range: TextRange, newText: string, visibleRange: LineRange): DocumentHighlightSlice;

        /**
         * Perform indent guide analysis on the managed document (requires prior call to analyze or analyzeIncremental)
         * @return Indent guide analysis result
         */
        analyzeIndentGuides(): IndentGuideResult;
    }

    /**
     * Highlight configuration
     */
    export class HighlightConfig {
        /**
         * Whether the analysis result includes character index; without it, each TokenSpan only has line and column
         */
        showIndex: boolean;
        /**
         * Whether to use inline styles, i.e. style definitions are embedded directly in syntax rule JSON, and the analysis result contains style info instead of returning style IDs
         */
        inlineStyle: boolean;
        /**
         * Tab width, used for indent guide level calculation (1 tab = tabSize spaces))
         */
        tabSize: number;
    }

    /**
     * Syntax rule
     */
    export class SyntaxRule {
        /**
         * Get the name of the syntax rule
         */
        getName(): string;
    }

    /**
     * Highlight engine
     */
    export class HighlightEngine {
        /**
         * Constructor
         * @param config Highlight configuration
         */
        constructor(config: HighlightConfig);

        /**
         * Register a highlight style for name mapping
         * @param styleName Style name
         * @param styleId Style ID
         */
        registerStyleName(styleName: string, styleId: number): void;

        /**
         * Get the registered style name by style ID
         * @param styleId Style ID
         * @return Style name
         */
        getStyleName(styleId: number): string;

        /**
         * Define a macro
         * @param macroName Macro name
         */
        defineMacro(macroName: string): void;

        /**
         * Undefine a macro
         * @param macroName Macro name
         */
        undefineMacro(macroName: string): void;

        /**
         * Compile syntax rule from JSON
         * @param json JSON content of the syntax rule
         * @throws SyntaxRuleParseError on compilation error
         */
        compileSyntaxFromJson(json: string): SyntaxRule;

        /**
         * Compile syntax rule
         * @param path Syntax rule definition file path (JSON)
         * @throws SyntaxRuleParseError on compilation error
         */
        compileSyntaxFromFile(path: string): SyntaxRule;

        /**
         * Get syntax rule by name (e.g. java)
         * @param syntaxName Syntax rule name
         */
        getSyntaxRuleByName(syntaxName: string): SyntaxRule;

        /**
         * Get syntax rule by file extension (e.g. .t)
         * @param extension File extension
         */
        getSyntaxRuleByExtension(extension: string): SyntaxRule;

        /**
         * Create a text highlight analyzer by syntax rule name (no incremental analysis support, but supports single-line analysis with line state for custom incremental analysis)
         * @param syntaxName Syntax rule name (e.g. java)
         */
        createAnalyzerByName(syntaxName: string): TextAnalyzer;

        /**
         * Create a text highlight analyzer by file extension (no incremental analysis support, but supports single-line analysis with line state for custom incremental analysis)
         * @param extension File extension (e.g. .t)
         */
        createAnalyzerByExtension(extension: string): TextAnalyzer;

        /**
         * Load a managed document and get a document highlight analyzer
         * @param document Managed document
         * @return Document highlight analyzer
         */
        loadDocument(document: Document): DocumentAnalyzer;

        /**
         * Remove a managed document
         * @param uri Managed document URI
         */
        removeDocument(uri: string): void;
    }
}
