#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum EditorActionReason {
        NONE = 0,
        SETUP = 1,
        TEXT_EDIT = 2,
        KEY_INPUT = 3,
        IME = 4,
        GESTURE = 5,
        ANIMATION = 6,
        PROGRAMMATIC = 7,
        DECORATION = 8,
        FOLDING = 9,
        LINKED_EDITING = 10,
        TEXT_INSERT = 11,
        TEXT_REPLACE = 12,
        TEXT_DELETE = 13,
        TEXT_UNDO = 14,
        TEXT_REDO = 15
    }

    public enum ScrollBehavior {
        GOTO_TOP = 0,
        GOTO_CENTER = 1,
        GOTO_BOTTOM = 2
    }

    public sealed partial class EditorActionResult {
        public bool Handled { get; set; } = false;
        public bool NeedsRedraw { get; set; } = false;
        public EditorActionReason Reason { get; set; } = EditorActionReason.NONE;
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
