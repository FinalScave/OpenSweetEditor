#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public enum DiagnosticSeverity {
        DIAG_ERROR = 0,
        DIAG_WARNING = 1,
        DIAG_INFO = 2,
        DIAG_HINT = 3
    }

    public enum DocumentHighlightKind {
        TEXT = 0,
        READ = 1,
        WRITE = 2
    }

    public enum InlayType {
        TEXT = 0,
        ICON = 1,
        COLOR = 2
    }

    public enum SeparatorStyle {
        SINGLE = 0,
        DOUBLE = 1
    }

    public enum SpanLayer {
        SYNTAX = 0,
        SEMANTIC = 1,
        OVERLAY = 2
    }

    public sealed partial class BracketGuide {
        public TextPosition Parent { get; set; } = new TextPosition();
        public TextPosition End { get; set; } = new TextPosition();
        public List<TextPosition> Children { get; set; } = new();
    }

    public sealed partial class CodeLensItem {
        public int Column { get; set; } = 0;
        public int CommandId { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
    }

    public sealed partial class Diagnostic {
        public int Column { get; set; } = 0;
        public int Length { get; set; } = 0;
        public DiagnosticSeverity Severity { get; set; } = DiagnosticSeverity.DIAG_ERROR;
    }

    public sealed partial class DocumentHighlight {
        public int Column { get; set; } = 0;
        public int Length { get; set; } = 0;
        public DocumentHighlightKind Kind { get; set; } = DocumentHighlightKind.TEXT;
    }

    public sealed partial class FlowGuide {
        public TextPosition Start { get; set; } = new TextPosition();
        public TextPosition End { get; set; } = new TextPosition();
    }

    public sealed partial class FoldRegion {
        public int StartLine { get; set; } = 0;
        public int EndLine { get; set; } = 0;
        public bool Collapsed { get; set; } = false;
    }

    public sealed partial class GutterIcon {
        public int IconId { get; set; } = 0;
    }

    public sealed partial class IndentGuide {
        public TextPosition Start { get; set; } = new TextPosition();
        public TextPosition End { get; set; } = new TextPosition();
    }

    public sealed partial class InlayHint {
        public InlayType Type { get; set; } = InlayType.TEXT;
        public int Column { get; set; } = 0;
        public int IntValue { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
    }

    public sealed partial class LinkSpan {
        public int Column { get; set; } = 0;
        public int Length { get; set; } = 0;
        public string Target { get; set; } = string.Empty;
    }

    public sealed partial class PhantomText {
        public int Column { get; set; } = 0;
        public string Text { get; set; } = string.Empty;
    }

    public sealed partial class SeparatorGuide {
        public int Line { get; set; } = 0;
        public SeparatorStyle Style { get; set; } = SeparatorStyle.SINGLE;
        public int Count { get; set; } = 0;
        public int TextEndColumn { get; set; } = 0;
    }

    public sealed partial class StyleSpan {
        public int Column { get; set; } = 0;
        public int Length { get; set; } = 0;
        public int StyleId { get; set; } = 0;
    }

    public sealed partial class TextStyle {
        public int Color { get; set; } = 0;
        public int BackgroundColor { get; set; } = 0;
        public int FontStyle { get; set; } = 0;
    }
}
