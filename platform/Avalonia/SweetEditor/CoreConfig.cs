#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum AutoIndentMode {
        NONE = 0,
        KEEP_INDENT = 1
    }

    public enum CurrentLineRenderMode {
        BACKGROUND = 0,
        BORDER = 1,
        NONE = 2
    }

    public enum FoldArrowMode {
        AUTO = 0,
        ALWAYS = 1,
        HIDDEN = 2
    }

    public enum RangeEffectUnderlineStyle {
        NONE = 0,
        SOLID = 1,
        DASHED = 2,
        WAVY = 3
    }

    public enum ScrollbarMode {
        ALWAYS = 0,
        TRANSIENT = 1,
        NEVER = 2
    }

    public enum ScrollbarTrackTapMode {
        JUMP = 0,
        DISABLED = 1
    }

    public enum WrapMode {
        NONE = 0,
        CHAR_BREAK = 1,
        WORD_BREAK = 2
    }

    public sealed partial class EditorOptions {
        public float TouchSlop { get; set; } = 10f;
        public long DoubleTapTimeout { get; set; } = 300L;
        public long LongPressMs { get; set; } = 500L;
        public float FlingFriction { get; set; } = 3.5f;
        public float FlingMinVelocity { get; set; } = 50.0f;
        public float FlingMaxVelocity { get; set; } = 8000.0f;
        public long MaxUndoStackSize { get; set; } = 512L;
        public long KeyChordTimeoutMs { get; set; } = 2000L;
        public bool RevealSelectionEndOnSelectAll { get; set; } = false;
    }

    public sealed partial class EditorRangeEffectStyles {
        public RangeEffectStyle Selection { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle SearchMatch { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle SearchCurrent { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DocumentHighlightText { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DocumentHighlightRead { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DocumentHighlightWrite { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle LinkedEditingActive { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle LinkedEditingInactive { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle ImeComposition { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle BracketMatch { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DiagnosticError { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DiagnosticWarning { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DiagnosticInfo { get; set; } = new RangeEffectStyle();
        public RangeEffectStyle DiagnosticHint { get; set; } = new RangeEffectStyle();
    }

    public sealed partial class EditorRenderColors {
        public int TextForeground { get; set; } = 0;
        public int LinkForeground { get; set; } = 0;
        public int ActiveLinkForeground { get; set; } = 0;
        public int CodelensForeground { get; set; } = 0;
        public int ActiveCodelensForeground { get; set; } = 0;
    }

    public sealed partial class HandleConfig {
        public OffsetRect StartHitOffset { get; set; } = new OffsetRect();
        public OffsetRect EndHitOffset { get; set; } = new OffsetRect();
    }

    public sealed partial class RangeEffectStyle {
        public int ForegroundColor { get; set; } = 0;
        public int BackgroundColor { get; set; } = 0;
        public int BorderColor { get; set; } = 0;
        public int UnderlineColor { get; set; } = 0;
        public RangeEffectUnderlineStyle UnderlineStyle { get; set; } = RangeEffectUnderlineStyle.NONE;
    }

    public sealed partial class ScrollbarConfig {
        public float Thickness { get; set; } = 10.0f;
        public float MinThumb { get; set; } = 24.0f;
        public float ThumbHitPadding { get; set; } = 0.0f;
        public ScrollbarMode Mode { get; set; } = ScrollbarMode.ALWAYS;
        public bool ThumbDraggable { get; set; } = true;
        public ScrollbarTrackTapMode TrackTapMode { get; set; } = ScrollbarTrackTapMode.JUMP;
        public int FadeDelayMs { get; set; } = 700;
        public int FadeDurationMs { get; set; } = 300;
    }
}
