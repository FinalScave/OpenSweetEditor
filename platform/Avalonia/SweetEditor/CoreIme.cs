#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum ImeCommandKind {
        SET_SELECTION = 0,
        SET_PREEDIT_TEXT = 1,
        COMMIT_TEXT = 2,
        FINISH_PREEDIT = 3,
        CANCEL_PREEDIT = 4,
        SET_MARKED_RANGE = 5,
        CLEAR_MARKED_RANGE = 6,
        REPLACE_TEXT = 7,
        DELETE_SURROUNDING_TEXT = 8,
        SET_KEYBOARD_SCRIPT = 9
    }

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

    public enum ImeMarkedRangeRole {
        NONE = 0,
        PREEDIT = 1,
        SYSTEM_MARK = 2
    }

    public enum ImePreeditStorage {
        NONE = 0,
        VISIBLE_DOCUMENT_PREEDIT = 1,
        SHADOW_ONLY = 2
    }

    public enum ImeScriptClass {
        UNKNOWN = 0,
        LATIN = 1,
        CJK = 2,
        KANA = 3,
        HANGUL = 4
    }

    public enum ImeTextUnit {
        GRAPHEME = 0,
        CODE_POINT = 1
    }

    public enum ImeTextUpdateKind {
        SNAPSHOT = 0,
        PATCH = 1
    }

    public enum ImeTextUpdateScope {
        DOCUMENT_WINDOW = 0,
        TRANSIENT_INPUT = 1
    }

    public sealed partial class ImeCommandMessage {
        public ImeCommandKind Kind { get; set; } = ImeCommandKind.SET_SELECTION;
        public long ContextId { get; set; } = 0L;
        public int ContextRevision { get; set; } = 0;
        public int DocumentStartOffset { get; set; } = 0;
        public ImeOffsetRange Range { get; set; } = new ImeOffsetRange();
        public ImeOffsetRange Selection { get; set; } = new ImeOffsetRange();
        public string Text { get; set; } = string.Empty;
        public int CursorOffset { get; set; } = 1;
        public int DeleteBefore { get; set; } = 0;
        public int DeleteAfter { get; set; } = 0;
        public ImeTextUnit TextUnit { get; set; } = ImeTextUnit.GRAPHEME;
        public ImeMarkedRangeRole MarkedRole { get; set; } = ImeMarkedRangeRole.NONE;
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }

    public sealed partial class ImeInputContext {
        public long Id { get; set; } = 0L;
        public int Revision { get; set; } = 0;
        public int DocumentStartOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public ImeOffsetRange Selection { get; set; } = new ImeOffsetRange();
        public bool HasComposition { get; set; } = false;
        public ImeOffsetRange Composition { get; set; } = new ImeOffsetRange();
        public bool HasSystemMarkRange { get; set; } = false;
        public ImeOffsetRange SystemMarkRange { get; set; } = new ImeOffsetRange();
        public ImeInputContextKind Kind { get; set; } = ImeInputContextKind.NONE;
    }

    public sealed partial class ImeMarkedRange {
        public ImeMarkedRangeRole Role { get; set; } = ImeMarkedRangeRole.NONE;
        public ImeOffsetRange Range { get; set; } = new ImeOffsetRange();
    }

    public sealed partial class ImeOffsetRange {
        public int Start { get; set; } = 0;
        public int End { get; set; } = 0;
    }

    public sealed partial class ImeSyncSnapshot {
        public TextPosition Cursor { get; set; } = new TextPosition();
        public TextRange Selection { get; set; } = new TextRange();
        public bool HasSelection { get; set; } = false;
        public bool HasComposingSession { get; set; } = false;
        public bool HasVisibleCompositionRange { get; set; } = false;
        public TextRange VisibleCompositionRange { get; set; } = new TextRange();
        public bool HasSystemMarkRange { get; set; } = false;
        public TextRange SystemMarkRange { get; set; } = new TextRange();
        public ImePreeditStorage PreeditStorage { get; set; } = ImePreeditStorage.NONE;
        public ImeContextPolicy ContextPolicy { get; set; } = ImeContextPolicy.NONE;
        public bool ClearSystemMark { get; set; } = false;
    }

    public sealed partial class ImeTextPatch {
        public ImeOffsetRange Range { get; set; } = new ImeOffsetRange();
        public string Text { get; set; } = string.Empty;
    }

    public sealed partial class ImeTextUpdateMessage {
        public ImeTextUpdateKind Kind { get; set; } = ImeTextUpdateKind.SNAPSHOT;
        public ImeTextUpdateScope Scope { get; set; } = ImeTextUpdateScope.DOCUMENT_WINDOW;
        public long ContextId { get; set; } = 0L;
        public int ContextRevision { get; set; } = 0;
        public int DocumentStartOffset { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
        public ImeTextPatch Patch { get; set; } = new ImeTextPatch();
        public ImeOffsetRange Selection { get; set; } = new ImeOffsetRange();
        public ImeMarkedRange MarkedRange { get; set; } = new ImeMarkedRange();
        public ImeScriptClass ScriptClass { get; set; } = ImeScriptClass.UNKNOWN;
    }
}
