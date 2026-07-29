#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    [Flags]
    public enum AnimationFlag {
        NONE = 0,
        EDGE_SCROLL = 1,
        FLING = 2,
        TRANSIENT_SCROLLBAR = 4
    }

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

    [Flags]
    public enum InteractionFlag {
        NONE = 0,
        PRIMARY_POINTER = 1,
        SELECTION_DRAG = 2,
        VIEWPORT_GESTURE = 4
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
        public bool CursorChanged { get; set; } = false;
        public bool SelectionChanged { get; set; } = false;
        public bool ScrollChanged { get; set; } = false;
        public bool ScaleChanged { get; set; } = false;
        public bool PointerCursorChanged { get; set; } = false;
        public bool CompositionChanged { get; set; } = false;
        public bool DecorationChanged { get; set; } = false;
        public int AnimationFlags { get; set; } = 0;
        public int NextAnimationDelayMs { get; set; } = 0;
        public int InteractionFlags { get; set; } = 0;
        public List<TextChange> TextChanges { get; set; } = new();
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
        public ImeHostAction ImeHostAction { get; set; } = ImeHostAction.NONE;
        public ImeState ImeState { get; set; } = new ImeState();
        public GestureType GestureType { get; set; } = GestureType.UNDEFINED;
        public EventType GestureEventType { get; set; } = EventType.UNDEFINED;
        public PointF TapPoint { get; set; } = new PointF();
        public HitTarget HitTarget { get; set; } = new HitTarget();
        public int Modifiers { get; set; } = 0;
        public int Command { get; set; } = 0;
    }
}
