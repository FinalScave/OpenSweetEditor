#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public sealed partial class IntRange {
        public int Start { get; set; } = 0;
        public int End { get; set; } = -1;
    }

    public sealed partial class OffsetRect {
        public float Left { get; set; } = 0f;
        public float Top { get; set; } = 0f;
        public float Right { get; set; } = 0f;
        public float Bottom { get; set; } = 0f;
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

    public sealed partial class TextChange {
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
