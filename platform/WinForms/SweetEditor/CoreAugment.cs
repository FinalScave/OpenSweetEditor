#nullable enable
using System;
using System.Collections.Generic;

namespace SweetEditor {

    public sealed partial class PointF {
        public PointF() { }

        public PointF(float x, float y) {
            X = x;
            Y = y;
        }
    }

    public sealed partial class Rect {
        public Rect() { }

        public Rect(PointF origin, float width, float height) {
            Origin = origin ?? new PointF();
            Width = width;
            Height = height;
        }

        public Rect(float x, float y, float width, float height)
            : this(new PointF(x, y), width, height) {
        }
    }

    public sealed partial class OffsetRect {
        public OffsetRect() { }

        public OffsetRect(float left, float top, float right, float bottom) {
            Left = left;
            Top = top;
            Right = right;
            Bottom = bottom;
        }
    }

    public sealed partial class IntRange {
        public IntRange() { }

        public IntRange(int start, int end) {
            Start = start;
            End = end;
        }

        public bool IsEmpty => End < Start;

        public bool Contains(int value) => !IsEmpty && value >= Start && value <= End;

        public int Length => IsEmpty ? 0 : End - Start + 1;

        public override string ToString() => "IntRange { Start = " + Start + ", End = " + End + " }";
    }

    public sealed partial class TextPosition {
        public static TextPosition NONE => new(-1, -1);

        public TextPosition() { }

        public TextPosition(int line, int column) {
            Line = line;
            Column = column;
        }

        public int CompareTo(TextPosition? other) {
            if (other == null) {
                return 1;
            }
            int lineCompare = Line.CompareTo(other.Line);
            return lineCompare != 0 ? lineCompare : Column.CompareTo(other.Column);
        }

        public bool IsBeforeOrEqual(TextPosition? other) => CompareTo(other) <= 0;

        public bool TryClampTo(Document? document, out TextPosition clamped) {
            clamped = new TextPosition();
            int lineCount = Math.Max(0, document?.GetLineCount() ?? 0);
            if (lineCount <= 0) {
                return false;
            }

            int line = Math.Clamp(Line, 0, lineCount - 1);
            string lineText = document?.GetLineText(line) ?? string.Empty;
            int column = Math.Clamp(Column, 0, lineText.Length);
            clamped = new TextPosition(line, column);
            return true;
        }

        public override string ToString() => "TextPosition { Line = " + Line + ", Column = " + Column + " }";
    }

    public sealed partial class TextRange {
        public TextRange() { }

        public TextRange(TextPosition start, TextPosition end) {
            Start = start ?? new TextPosition();
            End = end ?? new TextPosition();
        }

        public bool IsCollapsed => Start.Line == End.Line && Start.Column == End.Column;

        public TextRange Normalized() => Start.CompareTo(End) <= 0
            ? new TextRange(Start, End)
            : new TextRange(End, Start);

        public bool TryNormalize(Document? document, out TextRange normalized) {
            normalized = new TextRange();
            TextRange range = Normalized();
            if (!range.Start.TryClampTo(document, out TextPosition start) ||
                !range.End.TryClampTo(document, out TextPosition end)) {
                return false;
            }

            if (start.CompareTo(end) >= 0) {
                return false;
            }

            normalized = new TextRange(start, end);
            return true;
        }

        public bool OverlapsOrTouches(TextRange? other) {
            if (other == null) {
                return false;
            }

            TextRange left = Normalized();
            TextRange right = other.Normalized();
            return left.End.CompareTo(right.Start) >= 0 &&
                   right.End.CompareTo(left.Start) >= 0;
        }

        public override string ToString() => "TextRange { Start = " + Start + ", End = " + End + " }";
    }

    public sealed partial class TextChange {
        public TextChange() { }

        public TextChange(TextRange range, string? newText) {
            Range = range ?? new TextRange();
            NewText = newText ?? string.Empty;
        }

        public string Text {
            get => NewText;
            set => NewText = value ?? string.Empty;
        }
    }

    public sealed partial class TextEdit {
        public TextEdit() { }

        public TextEdit(TextRange range, string? newText) {
            Range = range ?? new TextRange();
            NewText = newText ?? string.Empty;
        }
    }

    public sealed partial class TextStyle {
        public const int NORMAL = 0;
        public const int BOLD = 1;
        public const int ITALIC = 2;
        public const int STRIKETHROUGH = 4;

        public TextStyle() { }

        public TextStyle(int color, int fontStyle)
            : this(color, 0, fontStyle) {
        }

        public TextStyle(int color, int backgroundColor, int fontStyle) {
            Color = color;
            BackgroundColor = backgroundColor;
            FontStyle = fontStyle;
        }
    }

    public sealed partial class StyleSpan {
        public StyleSpan() { }

        public StyleSpan(int column, int length, int styleId) {
            Column = column;
            Length = length;
            StyleId = styleId;
        }
    }

    public sealed partial class IndentGuide {
        public IndentGuide() { }

        public IndentGuide(TextPosition start, TextPosition end) {
            Start = start ?? new TextPosition();
            End = end ?? new TextPosition();
        }
    }

    public sealed partial class InlayHint {
        public InlayHint() { }

        public InlayHint(InlayType type, int column, string? text, int intValue) {
            Type = type;
            Column = column;
            Text = text ?? string.Empty;
            IntValue = intValue;
        }

        public static InlayHint TextHint(int column, string? text) => new(global::SweetEditor.InlayType.TEXT, column, text, 0);

        public static InlayHint IconHint(int column, int iconId) => new(global::SweetEditor.InlayType.ICON, column, string.Empty, iconId);

        public static InlayHint ColorHint(int column, int color) => new(global::SweetEditor.InlayType.COLOR, column, string.Empty, color);

        public int IconId => Type == global::SweetEditor.InlayType.ICON ? IntValue : 0;

        public int ColorValue => Type == global::SweetEditor.InlayType.COLOR ? IntValue : 0;

        public bool IsIcon => Type == global::SweetEditor.InlayType.ICON;
    }

    public sealed partial class PhantomText {
        public PhantomText() { }

        public PhantomText(int column, string? text) {
            Column = column;
            Text = text ?? string.Empty;
        }
    }

    public sealed partial class CodeLensItem {
        public CodeLensItem() { }

        public CodeLensItem(int column, string? text, int commandId = 0) {
            Column = column;
            Text = text ?? string.Empty;
            CommandId = commandId;
        }
    }

    public sealed partial class LinkSpan {
        public LinkSpan() { }

        public LinkSpan(int column, int length, string? target) {
            Column = column;
            Length = length;
            Target = target ?? string.Empty;
        }
    }

    public sealed partial class GutterIcon {
        public GutterIcon() { }

        public GutterIcon(int iconId) {
            IconId = iconId;
        }
    }

    public sealed partial class Diagnostic {
        public Diagnostic() { }

        public Diagnostic(int column, int length, int severity)
            : this(column, length, (DiagnosticSeverity)severity) {
        }

        public Diagnostic(int column, int length, DiagnosticSeverity severity) {
            Column = column;
            Length = length;
            Severity = severity;
        }
    }

    public sealed partial class FoldRegion {
        public FoldRegion() { }

        public FoldRegion(int startLine, int endLine)
            : this(startLine, endLine, false) {
        }

        public FoldRegion(int startLine, int endLine, bool collapsed) {
            StartLine = startLine;
            EndLine = endLine;
            Collapsed = collapsed;
        }
    }

    public sealed partial class SeparatorGuide {
        public SeparatorGuide() { }

        public SeparatorGuide(int line, int style, int count, int textEndColumn)
            : this(line, (SeparatorStyle)style, count, textEndColumn) {
        }

        public SeparatorGuide(int line, SeparatorStyle style, int count, int textEndColumn) {
            Line = line;
            Style = style;
            Count = count;
            TextEndColumn = textEndColumn;
        }
    }

    public sealed partial class KeyChord : IEquatable<KeyChord> {
        public static KeyChord Empty => new(global::SweetEditor.KeyModifier.NONE, global::SweetEditor.KeyCode.NONE);

        public static KeyChord EMPTY => Empty;

        public KeyChord() { }

        public KeyChord(int modifiers, int keyCode) {
            Modifiers = modifiers;
            KeyCode = keyCode;
        }

        public KeyChord(KeyModifier modifiers, KeyCode keyCode)
            : this((int)modifiers, (int)keyCode) {
        }

        public bool IsEmpty => KeyCode == (int)global::SweetEditor.KeyCode.NONE;

        public bool Equals(KeyChord? other) {
            return other != null && Modifiers == other.Modifiers && KeyCode == other.KeyCode;
        }

        public override bool Equals(object? obj) => obj is KeyChord other && Equals(other);

        public override int GetHashCode() => HashCode.Combine(Modifiers, KeyCode);

        public static bool operator ==(KeyChord? left, KeyChord? right) => EqualityComparer<KeyChord?>.Default.Equals(left, right);

        public static bool operator !=(KeyChord? left, KeyChord? right) => !(left == right);
    }

    public sealed partial class KeyBinding : IEquatable<KeyBinding> {
        public KeyBinding() { }

        public KeyBinding(KeyChord first, int command)
            : this(first, KeyChord.Empty, command) {
        }

        public KeyBinding(KeyChord first, EditorBuiltinCommand command)
            : this(first, KeyChord.Empty, (int)command) {
        }

        public KeyBinding(KeyChord first, KeyChord second, EditorBuiltinCommand command)
            : this(first, second, (int)command) {
        }

        public KeyBinding(KeyChord first, KeyChord second, int command) {
            First = first ?? KeyChord.Empty;
            Second = second ?? KeyChord.Empty;
            Command = command;
        }

        public KeyBinding(KeyModifier modifiers, KeyCode keyCode, int command)
            : this(new KeyChord(modifiers, keyCode), KeyChord.Empty, command) {
        }

        public KeyBinding(KeyModifier modifiers, KeyCode keyCode, EditorBuiltinCommand command)
            : this(modifiers, keyCode, (int)command) {
        }

        public KeyBinding(KeyModifier firstModifiers, KeyCode firstKeyCode, KeyModifier secondModifiers, KeyCode secondKeyCode, int command)
            : this(new KeyChord(firstModifiers, firstKeyCode), new KeyChord(secondModifiers, secondKeyCode), command) {
        }

        public bool IsChorded => Second != null && !Second.IsEmpty;

        public KeyBinding WithCommand(int command) => new(First, Second, command);

        public KeyBinding WithCommand(EditorBuiltinCommand command) => WithCommand((int)command);

        public KeyBinding WithCommandId(int command) => WithCommand(command);

        public bool Equals(KeyBinding? other) {
            return other != null
                && Command == other.Command
                && EqualityComparer<KeyChord>.Default.Equals(First, other.First)
                && EqualityComparer<KeyChord>.Default.Equals(Second, other.Second);
        }

        public override bool Equals(object? obj) => obj is KeyBinding other && Equals(other);

        public override int GetHashCode() => HashCode.Combine(First, Second, Command);

        public static bool operator ==(KeyBinding? left, KeyBinding? right) => EqualityComparer<KeyBinding?>.Default.Equals(left, right);

        public static bool operator !=(KeyBinding? left, KeyBinding? right) => !(left == right);
    }

    public sealed partial class LinkedEditingModel {
        public LinkedEditingModel AddGroup(int index, string? defaultText, params TextRange[] ranges) {
            Groups.Add(new TabStopGroup(index, defaultText, ranges));
            return this;
        }
    }

    public sealed partial class TabStopGroup {
        public TabStopGroup() { }

        public TabStopGroup(int index, string? defaultText, IEnumerable<TextRange>? ranges = null) {
            Index = index;
            DefaultText = defaultText ?? string.Empty;
            Ranges = ranges == null ? new List<TextRange>() : new List<TextRange>(ranges);
        }
    }

    public sealed partial class HandleConfig {
        public float StartLeft {
            get => StartHitOffset.Left;
            set => StartHitOffset.Left = value;
        }

        public float StartTop {
            get => StartHitOffset.Top;
            set => StartHitOffset.Top = value;
        }

        public float StartRight {
            get => StartHitOffset.Right;
            set => StartHitOffset.Right = value;
        }

        public float StartBottom {
            get => StartHitOffset.Bottom;
            set => StartHitOffset.Bottom = value;
        }

        public float EndLeft {
            get => EndHitOffset.Left;
            set => EndHitOffset.Left = value;
        }

        public float EndTop {
            get => EndHitOffset.Top;
            set => EndHitOffset.Top = value;
        }

        public float EndRight {
            get => EndHitOffset.Right;
            set => EndHitOffset.Right = value;
        }

        public float EndBottom {
            get => EndHitOffset.Bottom;
            set => EndHitOffset.Bottom = value;
        }
    }

    public sealed partial class EditorActionResult {
        public static EditorActionResult Empty => new();
    }
}
