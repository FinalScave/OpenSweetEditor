#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum ImeContextPolicy {
        NONE = 0,
        LIMITED_FOR_CANDIDATES = 1
    }

    public enum ImeInputContextKind {
        NONE = 0,
        SELECTION_ONLY = 1,
        DOCUMENT_WINDOW = 2,
        TRANSIENT_INPUT = 3
    }

    public enum ImePreeditStorage {
        NONE = 0,
        VISIBLE_DOCUMENT_COMPOSITION = 1,
        SHADOW_ONLY = 2
    }

    public enum ImeScriptClass {
        UNKNOWN = 0,
        LATIN = 1,
        CJK = 2,
        KANA = 3,
        HANGUL = 4
    }

    public enum ImeTextModelMode {
        DOCUMENT_WINDOW = 0,
        TRANSIENT_INPUT = 1
    }

    public enum ImeTextUnit {
        GRAPHEME = 0,
        CODE_POINT = 1
    }

    public sealed partial class ImeDocumentTextReplacement {
        public int StartOffset { get; set; } = 0;
        public int EndOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public int CursorOffset { get; set; } = 1;
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeInputContext {
        public long Id { get; set; } = 0L;
        public int Revision { get; set; } = 0;
        public int DocumentStartOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public ImeTextRange Selection { get; set; } = new ImeTextRange();
        public bool HasComposition { get; set; } = false;
        public ImeTextRange Composition { get; set; } = new ImeTextRange();
        public ImeInputContextKind Kind { get; set; } = ImeInputContextKind.NONE;
    }

    public sealed partial class ImeInputContextTextReplacement {
        public int StartOffset { get; set; } = 0;
        public int EndOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public int CursorOffset { get; set; } = 1;
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeInputStateTextReplacement {
        public long ContextId { get; set; } = 0L;
        public int DocumentStartOffset { get; set; } = 0;
        public int StartOffset { get; set; } = 0;
        public int EndOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public int CursorOffset { get; set; } = 1;
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeSyncSnapshot {
        public TextPosition Cursor { get; set; } = new TextPosition();
        public TextRange Selection { get; set; } = new TextRange();
        public bool HasSelection { get; set; } = false;
        public bool HasComposingSession { get; set; } = false;
        public bool HasVisibleCompositionRange { get; set; } = false;
        public TextRange VisibleCompositionRange { get; set; } = new TextRange();
        public bool HasPlatformMarkedRange { get; set; } = false;
        public TextRange PlatformMarkedRange { get; set; } = new TextRange();
        public ImePreeditStorage PreeditStorage { get; set; } = ImePreeditStorage.NONE;
        public ImeContextPolicy ContextPolicy { get; set; } = ImeContextPolicy.NONE;
        public bool ClearPlatformPreedit { get; set; } = false;
    }

    public sealed partial class ImeTextModelDelta {
        public ImeTextModelMode Mode { get; set; } = ImeTextModelMode.DOCUMENT_WINDOW;
        public long ContextId { get; set; } = 0L;
        public int DocumentStartOffset { get; set; } = 0;
        public string OldText { get; set; } = string.Empty;
        public ImeTextRange Delta { get; set; } = new ImeTextRange();
        public string DeltaText { get; set; } = string.Empty;
        public ImeTextRange Selection { get; set; } = new ImeTextRange();
        public ImeTextRange Composition { get; set; } = new ImeTextRange();
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeTextModelState {
        public ImeTextModelMode Mode { get; set; } = ImeTextModelMode.DOCUMENT_WINDOW;
        public long ContextId { get; set; } = 0L;
        public int DocumentStartOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public ImeTextRange Selection { get; set; } = new ImeTextRange();
        public ImeTextRange Composition { get; set; } = new ImeTextRange();
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeTextRange {
        public int Start { get; set; } = 0;
        public int End { get; set; } = 0;
    }

    public sealed partial class ImeTextReplacement {
        public TextRange Range { get; set; } = new TextRange();
        public string Text { get; set; } = string.Empty;
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }
}
