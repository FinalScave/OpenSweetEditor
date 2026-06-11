#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum EditorActionSource {
        NONE = 0,
        SETUP = 1,
        PROGRAMMATIC = 2,
        KEYBOARD = 3,
        IME = 4,
        GESTURE = 5,
        ANIMATION = 6,
        DECORATION = 7,
        FOLDING = 8,
        SEARCH = 9,
        LINKED_EDITING = 10
    }

    public enum ScrollBehavior {
        GOTO_TOP = 0,
        GOTO_CENTER = 1,
        GOTO_BOTTOM = 2
    }

    public enum TextChangeKind {
        NONE = 0,
        INSERTION = 1,
        REPLACEMENT = 2,
        DELETION = 3,
        MOVE = 4,
        UNDO = 5,
        REDO = 6,
        MIXED = 7
    }

    public sealed partial class EditorActionResult {
        public bool Handled { get; set; } = false;
        public bool NeedsRedraw { get; set; } = false;
        public EditorActionSource Source { get; set; } = EditorActionSource.NONE;
        public TextChangeKind TextChangeKind { get; set; } = TextChangeKind.NONE;
        public bool ContentChanged { get; set; } = false;
        public bool CursorChanged { get; set; } = false;
        public bool SelectionChanged { get; set; } = false;
        public bool ScrollChanged { get; set; } = false;
        public bool ScaleChanged { get; set; } = false;
        public bool PointerCursorChanged { get; set; } = false;
        public bool CompositionChanged { get; set; } = false;
        public bool DecorationChanged { get; set; } = false;
        public bool NeedsImeSync { get; set; } = false;
        public bool NeedsEdgeScroll { get; set; } = false;
        public bool NeedsFling { get; set; } = false;
        public bool NeedsAnimation { get; set; } = false;
        public bool IsHandleDrag { get; set; } = false;
        public List<TextChange> Changes { get; set; } = new();
        public TextPosition CursorBefore { get; set; } = new TextPosition();
        public TextPosition CursorAfter { get; set; } = new TextPosition();
        public bool HasSelectionBefore { get; set; } = false;
        public bool HasSelectionAfter { get; set; } = false;
        public TextRange SelectionBefore { get; set; } = new TextRange();
        public TextRange SelectionAfter { get; set; } = new TextRange();
        public float ScrollXBefore { get; set; } = 0f;
        public float ScrollYBefore { get; set; } = 0f;
        public float ScrollXAfter { get; set; } = 0f;
        public float ScrollYAfter { get; set; } = 0f;
        public float ScaleBefore { get; set; } = 1f;
        public float ScaleAfter { get; set; } = 1f;
        public PointerCursorType PointerCursorBefore { get; set; } = PointerCursorType.TEXT;
        public PointerCursorType PointerCursorAfter { get; set; } = PointerCursorType.TEXT;
        public ImeSyncSnapshot ImeSync { get; set; } = new ImeSyncSnapshot();
        public GestureType GestureType { get; set; } = GestureType.UNDEFINED;
        public EventType GestureEventType { get; set; } = EventType.UNDEFINED;
        public PointF TapPoint { get; set; } = new PointF();
        public HitTarget HitTarget { get; set; } = new HitTarget();
        public int Modifiers { get; set; } = 0;
        public int Command { get; set; } = 0;
    }
}
