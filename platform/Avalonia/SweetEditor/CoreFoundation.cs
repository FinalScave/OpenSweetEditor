#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum CaretAffinity {
        DOWNSTREAM = 0,
        UPSTREAM = 1
    }

    public sealed partial class IntRange {
        public int Start { get; set; } = 0;
        public int End { get; set; } = -1;
    }

    public sealed partial class PointF {
        public float X { get; set; } = 0f;
        public float Y { get; set; } = 0f;
    }

    public sealed partial class Rect {
        public PointF Origin { get; set; } = new PointF();
        public float Width { get; set; } = 0f;
        public float Height { get; set; } = 0f;
    }

    public sealed partial class Size {
        public float Width { get; set; } = 0f;
        public float Height { get; set; } = 0f;
    }

    public sealed partial class TabStopGroup {
        public int Index { get; set; } = 0;
        public List<TextRange> Ranges { get; set; } = new();
        public string DefaultText { get; set; } = string.Empty;
    }

    public sealed partial class TextChange {
        public TextRange Range { get; set; } = new TextRange();
        public string NewText { get; set; } = string.Empty;
    }

    public sealed partial class TextEdit {
        public TextRange Range { get; set; } = new TextRange();
        public string NewText { get; set; } = string.Empty;
    }

    public sealed partial class TextPosition {
        public int Line { get; set; } = 0;
        public int Column { get; set; } = 0;
    }

    public sealed partial class TextRange {
        public TextPosition Start { get; set; } = new TextPosition();
        public TextPosition End { get; set; } = new TextPosition();
    }
}
