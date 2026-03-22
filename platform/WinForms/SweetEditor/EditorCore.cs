using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.Linq;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using static SweetEditor.EditorCore;

namespace SweetEditor {

	/// <summary>
	/// Document object that wraps the native document handle from the C++ side.
	/// </summary>
	public class Document {
		internal IntPtr nativeHandle;

		/// <summary>
		/// Creates a document from UTF-16 text.
		/// </summary>
		/// <param name="text">Initial document text content</param>
		public Document(string text) {
			nativeHandle = NativeMethods.CreateDocument(text);
		}

		/// <summary>
		/// Gets the text content of the specified line.
		/// </summary>
		/// <param name="line">Line number (0-based)</param>
		/// <returns>Text of the line; returns empty string when handle is invalid</returns>
		public string GetLineText(int line) {
			if (nativeHandle == IntPtr.Zero) return "";
			IntPtr ptr = NativeMethods.GetDocumentLineText(nativeHandle, (UIntPtr)line);
			if (ptr == IntPtr.Zero) return "";
			string text = Marshal.PtrToStringUni(ptr) ?? "";
			NativeMethods.FreeUtf16String(ptr);
			return text;
		}
	}

	/// <summary>
	/// 2D floating-point coordinate.
	/// </summary>
	public struct PointF {
		/// <summary>X coordinate.</summary>
		[JsonPropertyName("x")]
		public float X { get; set; }
		/// <summary>Y coordinate.</summary>
		[JsonPropertyName("y")]
		public float Y { get; set; }

		/// <summary>Creates point (0, 0).</summary>
		public PointF() {
			X = 0;
			Y = 0;
		}

		/// <summary>Creates a point with the specified coordinates.</summary>
		/// <param name="x">X coordinate</param>
		/// <param name="y">Y coordinate</param>
		public PointF(float x, float y) {
			X = x;
			Y = y;
		}
	}

	/// <summary>
	/// Input event type.
	/// </summary>
	public enum EventType {
		UNDEFINED = 0,
		TOUCH_DOWN = 1,
		TOUCH_POINTER_DOWN = 2,
		TOUCH_MOVE = 3,
		TOUCH_POINTER_UP = 4,
		TOUCH_UP = 5,
		TOUCH_CANCEL = 6,
		MOUSE_DOWN = 7,
		MOUSE_MOVE = 8,
		MOUSE_UP = 9,
		MOUSE_WHEEL = 10,
		MOUSE_RIGHT_DOWN = 11,
		DIRECT_SCALE = 12,
		DIRECT_SCROLL = 13
	}

	/// <summary>
	/// Keyboard modifier flags.
	/// </summary>
	[Flags]
	public enum Modifier : byte {
		NONE = 0,
		SHIFT = 1 << 0,
		CTRL = 1 << 1,
		ALT = 1 << 2,
		META = 1 << 3
	}

	/// <summary>
	/// Gesture input event.
	/// </summary>
	public struct GestureEvent {
		/// <summary>Event type.</summary>
		public EventType Type { get; set; }
		/// <summary>Touch point list.</summary>
		public List<PointF> Points { get; set; }
		/// <summary>Modifier key state.</summary>
		public Modifier Modifiers { get; set; }
		/// <summary>Mouse wheel horizontal delta.</summary>
		public float WheelDeltaX { get; set; }
		/// <summary>Mouse wheel vertical delta.</summary>
		public float WheelDeltaY { get; set; }
		/// <summary>Direct scale factor.</summary>
		public float DirectScale { get; set; }

		/// <summary>
		/// Converts the touch point list to an interleaved float array [x0, y0, x1, y1, ...].
		/// </summary>
		/// <returns>Interleaved coordinate array; returns an empty array when there are no touch points.</returns>
		public float[] GetPointsArray() {
			if (Points == null || Points.Count == 0) return Array.Empty<float>();
			float[] arr = new float[Points.Count * 2];
			for (int i = 0; i < Points.Count; i++) {
				arr[i * 2] = Points[i].X;
				arr[i * 2 + 1] = Points[i].Y;
			}
			return arr;
		}
	}

	/// <summary>
	/// Gesture recognition result type.
	/// </summary>
	public enum GestureType {
		UNDEFINED = 0,
		TAP = 1,
		DOUBLE_TAP = 2,
		LONG_PRESS = 3,
		SCALE = 4,
		SCROLL = 5,
		FAST_SCROLL = 6,
		DRAG_SELECT = 7,
		CONTEXT_MENU = 8
	}

	/// <summary>
	/// Fold arrow display mode.
	/// </summary>
	public enum FoldArrowMode {
		/// <summary>Auto: show when foldable regions exist, hide when none exist</summary>
		AUTO = 0,
		/// <summary>Always show (reserve space to avoid width jitter)</summary>
		ALWAYS = 1,
		/// <summary>Always hide (no reserved space, even when foldable regions exist)</summary>
		HIDDEN = 2,
	}

	/// <summary>
	/// Auto-wrap mode.
	/// </summary>
	public enum WrapMode {
		/// <summary>No auto-wrap</summary>
		NONE = 0,
		/// <summary>Wrap by character</summary>
		CHAR_BREAK = 1,
		/// <summary>Wrap by word</summary>
		WORD_BREAK = 2,
	}

	/// <summary>
	/// Auto-indent mode.
	/// </summary>
	public enum AutoIndentMode {
		/// <summary>No auto-indent; new lines start at column 0</summary>
		NONE = 0,
		/// <summary>Keeps previous line indentation (copies leading whitespace)</summary>
		KEEP_INDENT = 1,
	}

	/// <summary>
	/// Current line render mode.
	/// </summary>
	public enum CurrentLineRenderMode {
		/// <summary>Fill the entire current line background.</summary>
		BACKGROUND = 0,
		/// <summary>Draw a border around current line.</summary>
		BORDER = 1,
		/// <summary>Disable current line decoration.</summary>
		NONE = 2,
	}

	/// <summary>
	/// Selection handle appearance and touch configuration.
	/// </summary>
	public class HandleConfig {
		/// <summary>Water-drop circle radius (default 22.0)</summary>
		public float Radius { get; set; } = 22.0f;
		/// <summary>Distance from circle center to tip (default 56.0)</summary>
		public float CenterDist { get; set; } = 56.0f;
		/// <summary>Cursor vertical line width (default 3.0)</summary>
		public float LineWidth { get; set; } = 3.0f;
		/// <summary>Touch hot-zone expansion (default 10.0)</summary>
		public float TouchPadding { get; set; } = 10.0f;
		/// <summary>Vertical offset during drag (default 50.0)</summary>
		public float DragYOffset { get; set; } = 50.0f;
	}

	/// <summary>
	/// Scrollbar visibility mode.
	/// </summary>
	public enum ScrollbarMode {
		ALWAYS = 0,
		TRANSIENT = 1,
		NEVER = 2,
	}

	/// <summary>
	/// Scrollbar track tap behavior.
	/// </summary>
	public enum ScrollbarTrackTapMode {
		JUMP = 0,
		DISABLED = 1,
	}

	/// <summary>
	/// Scrollbar configuration (geometry + behavior).
	/// </summary>
	public class ScrollbarConfig {
		/// <summary>Scrollbar thickness in pixels (default 10.0)</summary>
		public float Thickness { get; set; } = 10.0f;
		/// <summary>Minimum scrollbar thumb length in pixels (default 24.0)</summary>
		public float MinThumb { get; set; } = 24.0f;
		/// <summary>Extra thumb hit-test padding in pixels.</summary>
		public float ThumbHitPadding { get; set; } = 0.0f;
		/// <summary>Visibility mode</summary>
		public ScrollbarMode Mode { get; set; } = ScrollbarMode.ALWAYS;
		/// <summary>Whether thumb dragging is enabled</summary>
		public bool ThumbDraggable { get; set; } = true;
		/// <summary>Track tap behavior</summary>
		public ScrollbarTrackTapMode TrackTapMode { get; set; } = ScrollbarTrackTapMode.JUMP;
		/// <summary>Delay before hide in TRANSIENT mode</summary>
		public int FadeDelayMs { get; set; } = 700;
		/// <summary>Fade duration in TRANSIENT mode (used for both fade-in and fade-out).</summary>
		public int FadeDurationMs { get; set; } = 300;
	}

	/// <summary>
	/// Construction-time immutable options for EditorCore.
	/// Fields mirror the C++ EditorOptions struct.
	/// Binary layout (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms, u64 max_undo_stack_size
	/// </summary>
	public class EditorOptions {
		/// <summary>Threshold to determine if a gesture is a move (default 10)</summary>
		public float TouchSlop { get; set; } = 10f;
		/// <summary>Double-tap time threshold in ms (default 300)</summary>
		public long DoubleTapTimeout { get; set; } = 300;
		/// <summary>Long press time threshold in ms (default 500)</summary>
		public long LongPressMs { get; set; } = 500;
		/// <summary>Max undo stack size, 0 = unlimited (default 512)</summary>
		public ulong MaxUndoStackSize { get; set; } = 512;
	}

	/// <summary>
	/// Screen-space rectangle for caret/text position (for floating panel positioning).
	/// Coordinates are relative to the top-left corner of the editor control.
	/// </summary>
	public struct CursorRect {
		/// <summary>X coordinate relative to the top-left corner of the editor control</summary>
		public float X;
		/// <summary>Y coordinate relative to the top-left corner of the editor control (line top).</summary>
		public float Y;
		/// <summary>Line height (matches caret height)</summary>
		public float Height;

		public override string ToString() => $"CursorRect(X={X}, Y={Y}, Height={Height})";
	}

	/// <summary>
	/// Scrollbar metrics (used by platform code to compute thumb size and position).
	/// </summary>
	[StructLayout(LayoutKind.Sequential)]
	public struct ScrollMetrics {
		public float Scale;
		public float ScrollX;
		public float ScrollY;
		public float MaxScrollX;
		public float MaxScrollY;
		public float ContentWidth;
		public float ContentHeight;
		public float ViewportWidth;
		public float ViewportHeight;
		public float TextAreaX;
		public float TextAreaWidth;
		public int CanScrollXInt;
		public int CanScrollYInt;

		public bool CanScrollX => CanScrollXInt != 0;
		public bool CanScrollY => CanScrollYInt != 0;
	}

	/// <summary>
	/// Linked editing model (pure data structure).
	/// Build with Builder, then pass into <c>EditorCore.StartLinkedEditing()</c> to enter linked editing mode.
	/// </summary>
	public class LinkedEditingModel {
		/// <summary>Tab stop group.</summary>
		public class TabStopGroup {
			/// <summary>Group index (0 = final caret position, 1+ = editing order).</summary>
			public int Index { get; set; }
			/// <summary>Default placeholder text</summary>
			public string? DefaultText { get; set; }
			/// <summary>All text ranges in this group</summary>
			public List<TabStopRange> Ranges { get; set; } = new();
		}

		/// <summary>Text range (linked editing location).</summary>
		public struct TabStopRange {
			public int StartLine;
			public int StartColumn;
			public int EndLine;
			public int EndColumn;

			public TabStopRange(int startLine, int startColumn, int endLine, int endColumn) {
				StartLine = startLine;
				StartColumn = startColumn;
				EndLine = endLine;
				EndColumn = endColumn;
			}
		}

		/// <summary>All tab stop groups.</summary>
		public List<TabStopGroup> Groups { get; set; } = new();

		/// <summary>Adds a tab stop group.</summary>
		public LinkedEditingModel AddGroup(int index, string? defaultText, params TabStopRange[] ranges) {
			var group = new TabStopGroup { Index = index, DefaultText = defaultText };
			group.Ranges.AddRange(ranges);
			Groups.Add(group);
			return this;
		}
	}

	/// <summary>
	/// Scroll behavior.
	/// </summary>
	public enum ScrollBehavior {
		/// <summary>Align target line to viewport top</summary>
		TOP = 0,
		/// <summary>Align target line to viewport center</summary>
		CENTER = 1,
		/// <summary>Align target line to viewport bottom</summary>
		BOTTOM = 2,
	}

	/// <summary>
	/// Separator style.
	/// </summary>
	public enum SeparatorStyle {
		/// <summary>Single line (---)</summary>
		SINGLE = 0,
		/// <summary>Double line (===)</summary>
		DOUBLE = 1,
	}

	/// <summary>
	/// Highlight layer.
	/// </summary>
	public enum SpanLayer : byte {
		/// <summary>Syntax highlight (base layer, full coverage).</summary>
		SYNTAX = 0,
		/// <summary>Semantic highlight (LSP semantic tokens, overrides syntax layer).</summary>
		SEMANTIC = 1,
	}

	#region Adornment model types (Adornment Models)

	/// <summary>Immutable value object describing a highlight span on a line.</summary>
	public sealed class StyleSpan {
		/// <summary>Start column (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Character length</summary>
		public int Length { get; }
		/// <summary>Style ID registered by registerTextStyle</summary>
		public int StyleId { get; }
		public StyleSpan(int column, int length, int styleId) { Column = column; Length = length; StyleId = styleId; }
	}

	/// <summary>InlayHint type enum.</summary>
	public enum InlayType {
		/// <summary>Text type</summary>
		Text = 0,
		/// <summary>Icon type</summary>
		Icon = 1,
		/// <summary>Color block type</summary>
		Color = 2,
	}

	/// <summary>Immutable value object describing an InlayHint on a line.</summary>
	public sealed class InlayHint {
		public InlayType Type { get; }
		public int Column { get; }
		public string? Text { get; }
		public int IntValue { get; }
		public InlayHint(InlayType type, int column, string? text, int intValue) { Type = type; Column = column; Text = text; IntValue = intValue; }
		public static InlayHint TextHint(int column, string text) => new(InlayType.Text, column, text, 0);
		public static InlayHint IconHint(int column, int iconId) => new(InlayType.Icon, column, null, iconId);
		public static InlayHint ColorHint(int column, int color) => new(InlayType.Color, column, null, color);
	}

	/// <summary>Immutable value object describing ghost text on a line.</summary>
	public sealed class PhantomText {
		/// <summary>Insert column (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Ghost text content</summary>
		public string Text { get; }
		public PhantomText(int column, string text) { Column = column; Text = text; }
	}

	/// <summary>Immutable value object describing a single gutter icon.</summary>
	public sealed class GutterIcon {
		/// <summary>Icon resource ID</summary>
		public int IconId { get; }
		public GutterIcon(int iconId) { IconId = iconId; }
	}

	/// <summary>Immutable value object describing a diagnostic entry on a line.</summary>
	public sealed class DiagnosticItem {
		/// <summary>Start column (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Character length</summary>
		public int Length { get; }
		/// <summary>Severity (0=error, 1=warning, 2=info, 3=hint)</summary>
		public int Severity { get; }
		/// <summary>Underline/marker color (ARGB)</summary>
		public int Color { get; }
		public DiagnosticItem(int column, int length, int severity, int color) { Column = column; Length = length; Severity = severity; Color = color; }
	}

	/// <summary>Immutable value object describing a foldable region.</summary>
	public sealed class FoldRegion {
		/// <summary>Start line (0-based, this line stays visible).</summary>
		public int StartLine { get; }
		/// <summary>End line (0-based, inclusive).</summary>
		public int EndLine { get; }
		public FoldRegion(int startLine, int endLine) { StartLine = startLine; EndLine = endLine; }
	}

	/// <summary>Immutable value object describing an indent guide line.</summary>
	public sealed class IndentGuide {
		public TextPosition Start { get; }
		public TextPosition End { get; }
		public IndentGuide(TextPosition start, TextPosition end) { Start = start; End = end; }
		public IndentGuide(int startLine, int startColumn, int endLine, int endColumn)
			: this(new TextPosition { Line = startLine, Column = startColumn },
				   new TextPosition { Line = endLine, Column = endColumn }) { }
	}

	/// <summary>Immutable value object describing a bracket branch line.</summary>
	public sealed class BracketGuide {
		public TextPosition Parent { get; }
		public TextPosition End { get; }
		public TextPosition[]? Children { get; }
		public BracketGuide(TextPosition parent, TextPosition end, TextPosition[]? children) { Parent = parent; End = end; Children = children; }
	}

	/// <summary>Immutable value object describing a control-flow back-edge arrow.</summary>
	public sealed class FlowGuide {
		public TextPosition Start { get; }
		public TextPosition End { get; }
		public FlowGuide(TextPosition start, TextPosition end) { Start = start; End = end; }
		public FlowGuide(int startLine, int startColumn, int endLine, int endColumn)
			: this(new TextPosition { Line = startLine, Column = startColumn },
				   new TextPosition { Line = endLine, Column = endColumn }) { }
	}

	/// <summary>Immutable value object describing a horizontal separator line.</summary>
	public sealed class SeparatorGuide {
		/// <summary>Line number (0-based)</summary>
		public int Line { get; }
		/// <summary>Separator style (0=Single line, 1=Double line)</summary>
		public int Style { get; }
		/// <summary>Symbol count</summary>
		public int Count { get; }
		/// <summary>Comment text end column</summary>
		public int TextEndColumn { get; }
		public SeparatorGuide(int line, int style, int count, int textEndColumn) { Line = line; Style = style; Count = count; TextEndColumn = textEndColumn; }
	}

	#endregion

	/// <summary>
	/// Tap hit target type.
	/// </summary>
	[JsonConverter(typeof(JsonStringEnumConverter))]
	public enum HitTargetType {
		/// <summary>No special target hit</summary>
		NONE = 0,
		/// <summary>Hit InlayHint (text type).</summary>
		INLAY_HINT_TEXT = 1,
		/// <summary>Hit InlayHint (icon type).</summary>
		INLAY_HINT_ICON = 2,
		/// <summary>Hit a gutter icon</summary>
		GUTTER_ICON = 3,
		/// <summary>Hit fold placeholder (click to expand folded region).</summary>
		FOLD_PLACEHOLDER = 4,
		/// <summary>Hit gutter fold arrow (click to toggle fold/unfold).</summary>
		FOLD_GUTTER = 5,
		/// <summary>Hit InlayHint (color block type).</summary>
		INLAY_HINT_COLOR = 6,
	}

	/// <summary>
	/// Tap hit target info (filled by the C++ layer during TAP gesture handling).
	/// </summary>
	public struct HitTarget {
		[JsonPropertyName("type")]
		public HitTargetType Type { get; set; }
		/// <summary>Hit logical line (0-based)</summary>
		[JsonPropertyName("line")]
		public int Line { get; set; }
		/// <summary>Hit column (0-based, meaningful only for InlayHint).</summary>
		[JsonPropertyName("column")]
		public int Column { get; set; }
		/// <summary>Icon ID (valid for INLAY_HINT_ICON / GUTTER_ICON).</summary>
		[JsonPropertyName("icon_id")]
		public int IconId { get; set; }
		/// <summary>Color value (ARGB, valid for INLAY_HINT_COLOR).</summary>
		[JsonPropertyName("color_value")]
		public int ColorValue { get; set; }
	}

	/// <summary>
	/// Gesture handling result.
	/// </summary>
	public struct GestureResult {
		/// <summary>Recognized gesture type.</summary>
		[JsonPropertyName("type")]
		public GestureType Type { get; set; }
		/// <summary>Tap position.</summary>
		[JsonPropertyName("tap_point")]
		public PointF? TapPoint { get; set; }
		/// <summary>Modifier key state (bit flags).</summary>
		[JsonPropertyName("modifiers")]
		public byte Modifiers { get; set; }

		/// <summary>Post-operation caret position.</summary>
		[JsonPropertyName("cursor_position")]
		public TextPosition CursorPosition { get; set; }
		/// <summary>Whether a selection exists after operation.</summary>
		[JsonPropertyName("has_selection")]
		public bool HasSelection { get; set; }
		/// <summary>Post-operation selection range.</summary>
		[JsonPropertyName("selection")]
		public TextRange Selection { get; set; }
		/// <summary>Post-operation horizontal scroll offset.</summary>
		[JsonPropertyName("view_scroll_x")]
		public float ViewScrollX { get; set; }
		/// <summary>Post-operation vertical scroll offset.</summary>
		[JsonPropertyName("view_scroll_y")]
		public float ViewScrollY { get; set; }
		/// <summary>Post-operation scale factor.</summary>
		[JsonPropertyName("view_scale")]
		public float ViewScale { get; set; }

		/// <summary>Tap hit target info (filled by C++ on TAP).</summary>
		[JsonPropertyName("hit_target")]
		public HitTarget HitTarget { get; set; }

		/// <summary>Whether the platform should start/continue an edge-scroll timer.</summary>
		[JsonPropertyName("needs_edge_scroll")]
		public bool NeedsEdgeScroll { get; set; }

		/// <summary>Creates the default gesture result.</summary>
		public GestureResult() {
			Type = GestureType.UNDEFINED;
			TapPoint = new PointF();
		}

		/// <summary>Creates a gesture result with the specified type and position.</summary>
		/// <param name="type">Gesture type</param>
		/// <param name="position">Tap screen position</param>
		public GestureResult(GestureType type, PointF position) {
			Type = type;
			TapPoint = position;
		}

	}

	/// <summary>
	/// Enum for visual render segment kinds.
	/// </summary>
	public enum VisualRunType {
		/// <summary>Plain text</summary>
		TEXT,
		/// <summary>Space</summary>
		WHITESPACE,
		/// <summary>Line break</summary>
		NEWLINE,
		/// <summary>Inline content (text or icon).</summary>
		INLAY_HINT,
		/// <summary>Ghost text (used for Copilot code suggestions).</summary>
		PHANTOM_TEXT,
		/// <summary>Fold placeholder (" ... " at the end of the first line of a folded region).</summary>
		FOLD_PLACEHOLDER
	}

	/// <summary>
	/// Structure for each visually rendered text segment.
	/// </summary>
	public struct VisualRun {
		/// <summary>Segment type</summary>
		[JsonPropertyName("type")]
		public VisualRunType Type { get; set; }
		/// <summary>Draw start X coordinate.</summary>
		[JsonPropertyName("x")]
		public float X { get; set; }
		/// <summary>Draw start Y coordinate.</summary>
		[JsonPropertyName("y")]
		public float Y { get; set; }
		/// <summary>Segment text content (only present for TEXT, INLAY_HINT(TEXT), and PHANTOM_TEXT).</summary>
		[JsonPropertyName("text")]
		public string Text { get; set; }
		/// <summary>Style (color + background color + font style).</summary>
		[JsonPropertyName("style")]
		public TextStyle Style { get; set; }
		/// <summary>Precomputed width (filled during C++ layout).</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Horizontal background padding (INLAY_HINT only, one per side).</summary>
		[JsonPropertyName("padding")]
		public float Padding { get; set; }
		/// <summary>Horizontal outer margin to adjacent runs (INLAY_HINT only, one per side).</summary>
		[JsonPropertyName("margin")]
		public float Margin { get; set; }
		/// <summary>Icon resource ID (used only for INLAY_HINT(ICON)).</summary>
		[JsonPropertyName("icon_id")]
		public int IconId { get; set; }
		/// <summary>Color value (ARGB, used only for INLAY_HINT(COLOR)).</summary>
		[JsonPropertyName("color_value")]
		public int ColorValue { get; set; }
	}

	/// <summary>
	/// Fold state enum (maps to C++ FoldState).
	/// </summary>
	[JsonConverter(typeof(JsonStringEnumConverter))]
	public enum FoldState {
		/// <summary>First line of non-folded region</summary>
		NONE,
		/// <summary>Foldable (expanded; click to fold).</summary>
		EXPANDED,
		/// <summary>Folded (click to expand).</summary>
		COLLAPSED,
	}

	/// <summary>
	/// Visual render row data.
	/// </summary>
	public struct VisualLine {
		/// <summary>Logical line index</summary>
		[JsonPropertyName("logical_line")]
		public int LogicalLine { get; set; }
		/// <summary>Wrap row index under auto-wrap (0 = first row, 1,2,... = continuation rows).</summary>
		[JsonPropertyName("wrap_index")]
		public int WrapIndex { get; set; }
		/// <summary>Line number position</summary>
		[JsonPropertyName("line_number_position")]
		public PointF LineNumberPosition { get; set; }
		/// <summary>Text segments in this visual row</summary>
		[JsonPropertyName("runs")]
		public List<VisualRun> Runs { get; set; }
		/// <summary>Whether this is a ghost-text continuation row (2nd, 3rd, ... rows of multi-line phantom text).</summary>
		[JsonPropertyName("is_phantom_line")]
		public bool IsPhantomLine { get; set; }
		/// <summary>Fold state</summary>
		[JsonPropertyName("fold_state")]
		public FoldState FoldState { get; set; }
	}

	/// <summary>
	/// Gutter icon render item with fully resolved geometry.
	/// </summary>
	public struct GutterIconRenderItem {
		/// <summary>Logical line index.</summary>
		[JsonPropertyName("logical_line")]
		public int LogicalLine { get; set; }
		/// <summary>Icon resource ID.</summary>
		[JsonPropertyName("icon_id")]
		public int IconId { get; set; }
		/// <summary>Icon top-left corner.</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Icon width.</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Icon height.</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Fold marker render item with fully resolved geometry.
	/// </summary>
	public struct FoldMarkerRenderItem {
		/// <summary>Logical line index.</summary>
		[JsonPropertyName("logical_line")]
		public int LogicalLine { get; set; }
		/// <summary>Fold state on this line.</summary>
		[JsonPropertyName("fold_state")]
		public FoldState FoldState { get; set; }
		/// <summary>Marker top-left corner.</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Marker width.</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Marker height.</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Text position (line + column, both 0-based).
	/// </summary>
	public struct TextPosition {
		/// <summary>Line</summary>
		[JsonPropertyName("line")]
		public int Line { get; set; }
		/// <summary>Column</summary>
		[JsonPropertyName("column")]
		public int Column { get; set; }
	}

	/// <summary>
	/// Text range composed of start and end <see cref="TextPosition"/> values.
	/// </summary>
	public struct TextRange {
		[JsonPropertyName("start")]
		public TextPosition Start { get; set; }
		[JsonPropertyName("end")]
		public TextPosition End { get; set; }
	}

	#region Editor event system

	/// <summary>
	/// Editor event type.
	/// </summary>
	public enum EditorEventType {
		/// <summary>Content changed</summary>
		TextChanged,
		/// <summary>Caret position changed</summary>
		CursorChanged,
		/// <summary>Selection changed</summary>
		SelectionChanged,
		/// <summary>Scroll position changed</summary>
		ScrollChanged,
		/// <summary>Zoom changed</summary>
		ScaleChanged,
		/// <summary>Long press</summary>
		LongPress,
		/// <summary>Double-click select</summary>
		DoubleTap,
		/// <summary>Right click/context menu</summary>
		ContextMenu,
		/// <summary>GutterIcon Click</summary>
		GutterIconClick,
		/// <summary>InlayHint Click</summary>
		InlayHintClick,
		/// <summary>Fold region click.</summary>
		FoldToggle,
	}

	/// <summary>
	/// Base class for editor event args.
	/// </summary>
	public class EditorEventArgs : EventArgs {
		public EditorEventType EventType { get; }
		public EditorEventArgs(EditorEventType type) { EventType = type; }
	}

	/// <summary>
	/// Text change operation type enum.
	/// </summary>
	public enum TextChangeAction {
		Insert,
		Delete,
		Key,
		Composition,
		Undo,
		Redo
	}

	/// <summary>
	/// Single text change (precise change info for one edit location).
	/// </summary>
	public class TextChange {
		/// <summary>Replaced/deleted text range (pre-operation coordinates).</summary>
		[JsonPropertyName("range")]
		public TextRange? Range { get; set; }
		/// <summary>New text after change (inserted/replaced content).</summary>
		[JsonPropertyName("new_text")]
		public string? NewText { get; set; }
	}

	/// <summary>
	/// Result of a text edit operation with precise changed ranges and text.
	/// </summary>
	public class TextEditResult {
		/// <summary>List of all changes</summary>
		[JsonPropertyName("changes")]
		public List<TextChange>? Changes { get; set; }

		/// <summary>Empty result (no changes).</summary>
		public static readonly TextEditResult Empty = new TextEditResult();
	}

	/// <summary>
	/// Text change event args.
	/// </summary>
	public class TextChangedEventArgs : EditorEventArgs {
		/// <summary>Operation type</summary>
		public TextChangeAction Action { get; }
		/// <summary>Replaced/deleted text range (pre-operation coordinates); null means unavailable.</summary>
		public TextRange? ChangeRange { get; }
		/// <summary>New text after change (inserted/replaced content); null means unavailable, and empty string means pure deletion.</summary>
		public string? Text { get; }
		public TextChangedEventArgs(TextChangeAction action, TextRange? changeRange = null, string? text = null)
			: base(EditorEventType.TextChanged) {
			Action = action;
			ChangeRange = changeRange;
			Text = text;
		}
	}

	/// <summary>
	/// Caret change event args.
	/// </summary>
	public class CursorChangedEventArgs : EditorEventArgs {
		public TextPosition CursorPosition { get; }
		public CursorChangedEventArgs(TextPosition cursor) : base(EditorEventType.CursorChanged) { CursorPosition = cursor; }
	}

	/// <summary>
	/// Selection changed event args.
	/// </summary>
	public class SelectionChangedEventArgs : EditorEventArgs {
		public bool HasSelection { get; }
		public TextRange Selection { get; }
		public TextPosition CursorPosition { get; }
		public SelectionChangedEventArgs(bool has, TextRange sel, TextPosition cursor)
			: base(EditorEventType.SelectionChanged) { HasSelection = has; Selection = sel; CursorPosition = cursor; }
	}

	/// <summary>
	/// Scroll change event args.
	/// </summary>
	public class ScrollChangedEventArgs : EditorEventArgs {
		public float ScrollX { get; }
		public float ScrollY { get; }
		public ScrollChangedEventArgs(float x, float y) : base(EditorEventType.ScrollChanged) { ScrollX = x; ScrollY = y; }
	}

	/// <summary>
	/// Zoom changed event args.
	/// </summary>
	public class ScaleChangedEventArgs : EditorEventArgs {
		public float Scale { get; }
		public ScaleChangedEventArgs(float scale) : base(EditorEventType.ScaleChanged) { Scale = scale; }
	}

	/// <summary>
	/// Long-press event args.
	/// </summary>
	public class LongPressEventArgs : EditorEventArgs {
		public TextPosition CursorPosition { get; }
		public PointF ScreenPoint { get; }
		public LongPressEventArgs(TextPosition cursor, PointF point)
			: base(EditorEventType.LongPress) { CursorPosition = cursor; ScreenPoint = point; }
	}

	/// <summary>
	/// Double-click selection event args.
	/// </summary>
	public class DoubleTapEventArgs : EditorEventArgs {
		public TextPosition CursorPosition { get; }
		public bool HasSelection { get; }
		public TextRange Selection { get; }
		public PointF ScreenPoint { get; }
		public DoubleTapEventArgs(TextPosition cursor, bool has, TextRange sel, PointF point)
			: base(EditorEventType.DoubleTap) { CursorPosition = cursor; HasSelection = has; Selection = sel; ScreenPoint = point; }
	}

	/// <summary>
	/// Context-menu event args.
	/// </summary>
	public class ContextMenuEventArgs : EditorEventArgs {
		public TextPosition CursorPosition { get; }
		public PointF ScreenPoint { get; }
		public ContextMenuEventArgs(TextPosition cursor, PointF point)
			: base(EditorEventType.ContextMenu) { CursorPosition = cursor; ScreenPoint = point; }
	}

	/// <summary>
	/// InlayHint click event args.
	/// </summary>
	public class InlayHintClickEventArgs : EditorEventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Hit column (0-based)</summary>
		public int Column { get; }
		/// <summary>Icon ID (valid only for icon-type InlayHint).</summary>
		public int IconId { get; }
		/// <summary>Color value (valid only for color-block InlayHint).</summary>
		public int ColorValue { get; }
		/// <summary>Whether the hit InlayHint is icon type.</summary>
		public bool IsIcon { get; }
		/// <summary>Tap screen position</summary>
		public PointF ScreenPoint { get; }
		public InlayHintClickEventArgs(int line, int column, int iconId, int colorValue, bool isIcon, PointF point)
			: base(EditorEventType.InlayHintClick) {
			Line = line; Column = column; IconId = iconId; ColorValue = colorValue; IsIcon = isIcon; ScreenPoint = point;
		}
	}

	/// <summary>
	/// GutterIcon click event args.
	/// </summary>
	public class GutterIconClickEventArgs : EditorEventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Icon ID</summary>
		public int IconId { get; }
		/// <summary>Tap screen position</summary>
		public PointF ScreenPoint { get; }
		public GutterIconClickEventArgs(int line, int iconId, PointF point)
			: base(EditorEventType.GutterIconClick) {
			Line = line; IconId = iconId; ScreenPoint = point;
		}
	}

	/// <summary>
	/// Fold region click event args (toggleFold is already executed by the C++ layer).
	/// </summary>
	public class FoldToggleEventArgs : EditorEventArgs {
		/// <summary>Line index of the fold region (0-based).</summary>
		public int Line { get; }
		/// <summary>Whether the click hit the gutter fold arrow (false means the fold placeholder was clicked).</summary>
		public bool IsGutter { get; }
		/// <summary>Tap screen position</summary>
		public PointF ScreenPoint { get; }
		public FoldToggleEventArgs(int line, bool isGutter, PointF point)
			: base(EditorEventType.FoldToggle) {
			Line = line; IsGutter = isGutter; ScreenPoint = point;
		}
	}

	#endregion

	/// <summary>
	/// Caret data.
	/// </summary>
	public struct Cursor {
		/// <summary>Logical caret position in text</summary>
		[JsonPropertyName("text_position")]
		public TextPosition TextPosition { get; set; }
		/// <summary>Caret screen position</summary>
		[JsonPropertyName("position")]
		public PointF Position { get; set; }
		/// <summary>Caret height</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
		/// <summary>Whether caret is visible</summary>
		[JsonPropertyName("visible")]
		public bool Visible { get; set; }
		/// <summary>Whether drag caret is visible</summary>
		[JsonPropertyName("show_dragger")]
		public bool ShowDragger { get; set; }
	}

	/// <summary>
	/// Single-line selection highlight rectangle.
	/// </summary>
	public struct SelectionRect {
		/// <summary>Rectangle top-left corner</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Rectangle width</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Rectangle height</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Code guide line direction.
	/// </summary>
	public enum GuideDirection {
		/// <summary>Horizontal direction.</summary>
		HORIZONTAL,
		/// <summary>Vertical direction.</summary>
		VERTICAL
	}

	/// <summary>
	/// Code guide line type.
	/// </summary>
	public enum GuideType {
		/// <summary>Indent line.</summary>
		INDENT,
		/// <summary>Bracket match line.</summary>
		BRACKET,
		/// <summary>Control flow line.</summary>
		FLOW,
		/// <summary>Separator line.</summary>
		SEPARATOR
	}

	/// <summary>
	/// Code guide line style.
	/// </summary>
	public enum GuideStyle {
		/// <summary>Solid.</summary>
		SOLID,
		/// <summary>Dashed.</summary>
		DASHED,
		/// <summary>Double.</summary>
		DOUBLE
	}

	/// <summary>
	/// Render data for a code guide line segment.
	/// </summary>
	public struct GuideSegment {
		/// <summary>Segment direction.</summary>
		[JsonPropertyName("direction")]
		public GuideDirection Direction { get; set; }
		/// <summary>Segment type.</summary>
		[JsonPropertyName("type")]
		public GuideType Type { get; set; }
		/// <summary>Segment style.</summary>
		[JsonPropertyName("style")]
		public GuideStyle Style { get; set; }
		/// <summary>Segment start point.</summary>
		[JsonPropertyName("start")]
		public PointF Start { get; set; }
		/// <summary>Segment end point.</summary>
		[JsonPropertyName("end")]
		public PointF End { get; set; }
		/// <summary>Whether the end point has an arrowhead.</summary>
		[JsonPropertyName("arrow_end")]
		public bool ArrowEnd { get; set; }
	}

	/// <summary>
	/// Editor render model.
	/// </summary>
	public struct EditorRenderModel {
		/// <summary>Line-number divider position.</summary>
		[JsonPropertyName("split_x")]
		public float SplitX { get; set; }
		/// <summary>Whether split line should be rendered.</summary>
		[JsonPropertyName("split_line_visible")]
		public bool SplitLineVisible { get; set; }
		/// <summary>Current horizontal scroll offset</summary>
		[JsonPropertyName("scroll_x")]
		public float ScrollX { get; set; }
		/// <summary>Current vertical scroll offset</summary>
		[JsonPropertyName("scroll_y")]
		public float ScrollY { get; set; }
		/// <summary>Viewport width</summary>
		[JsonPropertyName("viewport_width")]
		public float ViewportWidth { get; set; }
		/// <summary>Viewport height</summary>
		[JsonPropertyName("viewport_height")]
		public float ViewportHeight { get; set; }
		/// <summary>Current-line background position</summary>
		[JsonPropertyName("current_line")]
		public PointF CurrentLine { get; set; }
		/// <summary>Current line render mode.</summary>
		[JsonPropertyName("current_line_render_mode")]
		public CurrentLineRenderMode CurrentLineRenderMode { get; set; }
			/// <summary>Visually rendered text rows (visible area only).</summary>
			[JsonPropertyName("lines")]
			public List<VisualLine> VisualLines { get; set; }
			/// <summary>Gutter icon render list (fully resolved geometry, visible area only).</summary>
			[JsonPropertyName("gutter_icons")]
			public List<GutterIconRenderItem> GutterIcons { get; set; }
			/// <summary>Fold marker render list (fully resolved geometry, visible area only).</summary>
			[JsonPropertyName("fold_markers")]
			public List<FoldMarkerRenderItem> FoldMarkers { get; set; }
			/// <summary>Caret</summary>
			[JsonPropertyName("cursor")]
			public Cursor Cursor { get; set; }
		/// <summary>Selection highlight rectangles</summary>
		[JsonPropertyName("selection_rects")]
		public List<SelectionRect> SelectionRects { get; set; }
		/// <summary>Selection start drag handle</summary>
		[JsonPropertyName("selection_start_handle")]
		public SelectionHandle SelectionStartHandle { get; set; }
		/// <summary>Selection end drag handle</summary>
		[JsonPropertyName("selection_end_handle")]
		public SelectionHandle SelectionEndHandle { get; set; }
		/// <summary>Composition decoration (underlined region during IME composition).</summary>
		[JsonPropertyName("composition_decoration")]
		public CompositionDecoration CompositionDecoration { get; set; }
		/// <summary>Code guide lines</summary>
		[JsonPropertyName("guide_segments")]
		public List<GuideSegment> GuideSegments { get; set; }
		/// <summary>Diagnostic decorations (squiggle/underline).</summary>
		[JsonPropertyName("diagnostic_decorations")]
		public List<DiagnosticDecoration> DiagnosticDecorations { get; set; }
		/// <summary>Maximum number of gutter icons shown in the line-number gutter (0 = overlay mode).</summary>
		[JsonPropertyName("max_gutter_icons")]
		public int MaxGutterIcons { get; set; }
		/// <summary>Linked-edit highlight rectangles (tab stop placeholders).</summary>
		[JsonPropertyName("linked_editing_rects")]
		public List<LinkedEditingRect> LinkedEditingRects { get; set; }
		/// <summary>Bracket-match highlight rectangles (bracket near caret + matching bracket).</summary>
		[JsonPropertyName("bracket_highlight_rects")]
		public List<BracketHighlightRect> BracketHighlightRects { get; set; }
		/// <summary>Vertical scrollbar render model.</summary>
		[JsonPropertyName("vertical_scrollbar")]
		public ScrollbarModel VerticalScrollbar { get; set; }
		/// <summary>Horizontal scrollbar render model.</summary>
		[JsonPropertyName("horizontal_scrollbar")]
		public ScrollbarModel HorizontalScrollbar { get; set; }
	}

	/// <summary>
	/// Render decoration for composition area (underline).
	/// </summary>
	public struct CompositionDecoration {
		/// <summary>Whether composition decoration needs to be rendered.</summary>
		[JsonPropertyName("active")]
		public bool Active { get; set; }
		/// <summary>Start screen position of composition text area</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Width of composition text area</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Line height</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Selection drag handle.
	/// </summary>
	public struct SelectionHandle {
		/// <summary>Handle position.</summary>
		[JsonPropertyName("position")]
		public PointF Position { get; set; }
		/// <summary>Handle height.</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
		/// <summary>Whether visible.</summary>
		[JsonPropertyName("visible")]
		public bool Visible { get; set; }
	}

	/// <summary>
	/// Diagnostic decoration render primitive (squiggle/underline).
	/// </summary>
	public struct DiagnosticDecoration {
		/// <summary>Start screen position of the squiggle area (below baseline).</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Squiggle width</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Line height (used to position baseline offset).</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
		/// <summary>Severity level (0=ERROR, 1=WARNING, 2=INFO, 3=HINT)</summary>
		[JsonPropertyName("severity")]
		public int Severity { get; set; }
		/// <summary>Color value (ARGB), 0 means use the default color for this severity.</summary>
		[JsonPropertyName("color")]
		public int Color { get; set; }
	}

	/// <summary>
	/// Linked-edit highlight rectangle (visual marker for a tab stop placeholder).
	/// </summary>
	public struct LinkedEditingRect {
		/// <summary>Rectangle top-left corner</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Rectangle width</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Rectangle height</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
		/// <summary>Whether this is the active tab stop</summary>
		[JsonPropertyName("is_active")]
		public bool IsActive { get; set; }
	}

	/// <summary>
	/// Bracket-match highlight rectangle (visual marker for bracket near caret + matching bracket).
	/// </summary>
	public struct BracketHighlightRect {
		/// <summary>Rectangle top-left corner</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Rectangle width</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Rectangle height</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Scrollbar rectangle geometry (track/thumb).
	/// </summary>
	public struct ScrollbarRect {
		/// <summary>Rectangle top-left corner.</summary>
		[JsonPropertyName("origin")]
		public PointF Origin { get; set; }
		/// <summary>Rectangle width.</summary>
		[JsonPropertyName("width")]
		public float Width { get; set; }
		/// <summary>Rectangle height.</summary>
		[JsonPropertyName("height")]
		public float Height { get; set; }
	}

	/// <summary>
	/// Scrollbar render model for one axis.
	/// </summary>
	public struct ScrollbarModel {
		/// <summary>Whether scrollbar is visible.</summary>
		[JsonPropertyName("visible")]
		public bool Visible { get; set; }
		/// <summary>Scrollbar alpha in [0, 1].</summary>
		[JsonPropertyName("alpha")]
		public float Alpha { get; set; }
		/// <summary>Track rectangle.</summary>
		[JsonPropertyName("track")]
		public ScrollbarRect Track { get; set; }
		/// <summary>Thumb rectangle.</summary>
		[JsonPropertyName("thumb")]
		public ScrollbarRect Thumb { get; set; }
	}

	/// <summary>
	/// Keyboard event handling result.
	/// </summary>
	public struct KeyEventResult {
		/// <summary>Whether the event was handled</summary>
		[JsonPropertyName("handled")]
		public bool Handled { get; set; }
		/// <summary>Whether content changed</summary>
		[JsonPropertyName("content_changed")]
		public bool ContentChanged { get; set; }
		/// <summary>Whether the caret changed.</summary>
		[JsonPropertyName("cursor_changed")]
		public bool CursorChanged { get; set; }
		/// <summary>Whether selection changed</summary>
		[JsonPropertyName("selection_changed")]
		public bool SelectionChanged { get; set; }
		/// <summary>Precise text change info (valid when content_changed is true).</summary>
		[JsonPropertyName("edit_result")]
		public TextEditResult? EditResult { get; set; }
	}

	/// <summary>
	/// Native method entry points for the WinForms platform, centralized management of all P/Invoke declarations.
	/// </summary>
	internal static class NativeMethods {
		private const string LibraryName = "sweeteditor.dll";

		[DllImport(LibraryName, EntryPoint = "create_document_from_utf16", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CreateDocument(string text);

		[DllImport(LibraryName, EntryPoint = "get_document_line_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetDocumentLineText(IntPtr documentHandle, UIntPtr line);

		[DllImport(LibraryName, EntryPoint = "init_unhandled_exception_handler", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void InitUnhandledExceptionHandler();

		[DllImport(LibraryName, EntryPoint = "create_editor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CreateEditor(EditorCore.TextMeasurer measurer, byte[] optionsData, UIntPtr optionsSize);

		[DllImport(LibraryName, EntryPoint = "set_editor_document", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetEditorDocument(IntPtr handle, IntPtr documentHandle);

		[DllImport(LibraryName, EntryPoint = "set_editor_viewport", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetViewport(IntPtr handle, int width, int height);

		[DllImport(LibraryName, EntryPoint = "reset_editor_text_measurer", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ResetEditorTextMeasurer(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_fold_arrow_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetFoldArrowMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_set_wrap_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetWrapMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_set_scale", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetScale(IntPtr handle, float scale);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spacing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineSpacing(IntPtr handle, float add, float mult);

		[DllImport(LibraryName, EntryPoint = "editor_set_content_start_padding", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetContentStartPadding(IntPtr handle, float padding);

		[DllImport(LibraryName, EntryPoint = "editor_set_show_split_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetShowSplitLine(IntPtr handle, int show);

		[DllImport(LibraryName, EntryPoint = "editor_set_current_line_render_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetCurrentLineRenderMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "build_editor_render_model", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr BuildRenderModel(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "handle_editor_gesture_event_ex", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr HandleGestureEventEx(IntPtr handle, uint type, uint pointerCount, float[] points,
			byte modifiers, float wheelDeltaX, float wheelDeltaY, float directScale, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_edge_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickEdgeScroll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "handle_editor_key_event", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr HandleKeyEvent(IntPtr handle, ushort keyCode, [MarshalAs(UnmanagedType.LPUTF8Str)] string? text, byte modifiers, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_insert_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr InsertText(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_replace_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ReplaceText(IntPtr handle,
			int startLine, int startColumn,
			int endLine, int endColumn,
			[MarshalAs(UnmanagedType.LPUTF8Str)] string text,
			out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_delete_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr DeleteText(IntPtr handle,
			int startLine, int startColumn,
			int endLine, int endColumn,
			out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_backspace", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr Backspace(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_delete_forward", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr DeleteForward(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_line_up", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveLineUp(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_line_down", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveLineDown(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_copy_line_up", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CopyLineUp(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_copy_line_down", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CopyLineDown(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_delete_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr DeleteLine(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_insert_line_above", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr InsertLineAbove(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_insert_line_below", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr InsertLineBelow(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_selected_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetSelectedText(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_undo", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr Undo(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_redo", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr Redo(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_can_undo", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int CanUndo(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_can_redo", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int CanRedo(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_cursor_position", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetCursorPosition(IntPtr handle, nuint line, nuint column);

		[DllImport(LibraryName, EntryPoint = "editor_get_cursor_position", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetCursorPosition(IntPtr handle, ref nuint outLine, ref nuint outColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_word_range_at_cursor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetWordRangeAtCursor(IntPtr handle, ref nuint outStartLine, ref nuint outStartColumn, ref nuint outEndLine, ref nuint outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_word_at_cursor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetWordAtCursor(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_selection", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetSelection(IntPtr handle, int startLine, int startColumn, int endLine, int endColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_selection", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int GetSelection(IntPtr handle, ref nuint outStartLine, ref nuint outStartColumn, ref nuint outEndLine, ref nuint outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_select_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SelectAll(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_left", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorLeft(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_right", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorRight(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_up", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorUp(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_down", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorDown(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_to_line_start", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorToLineStart(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_to_line_end", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void MoveCursorToLineEnd(IntPtr handle, int extendSelection);

		[DllImport(LibraryName, EntryPoint = "editor_composition_start", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void CompositionStart(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_composition_update", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void CompositionUpdate(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text);

		[DllImport(LibraryName, EntryPoint = "editor_composition_end", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CompositionEnd(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_composition_cancel", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void CompositionCancel(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_is_composing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsComposing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetReadOnly(IntPtr handle, int readOnly);

		[DllImport(LibraryName, EntryPoint = "editor_is_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsReadOnly(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetAutoIndentMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_get_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int GetAutoIndentMode(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_handle_config", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetHandleConfig(IntPtr handle, float radius, float centerDist, float lineWidth, float touchPadding, float dragYOffset);

		[DllImport(LibraryName, EntryPoint = "editor_set_scrollbar_config", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetScrollbarConfig(IntPtr handle,
			float thickness, float minThumb, float thumbHitPadding,
			int mode, int thumbDraggable, int trackTapMode,
			int fadeDelayMs, int fadeDurationMs);

		[DllImport(LibraryName, EntryPoint = "editor_get_position_rect", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetPositionRect(IntPtr handle, nuint line, nuint column, ref float outX, ref float outY, ref float outHeight);

		[DllImport(LibraryName, EntryPoint = "editor_get_cursor_rect", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetCursorRect(IntPtr handle, ref float outX, ref float outY, ref float outHeight);

		[DllImport(LibraryName, EntryPoint = "editor_scroll_to_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ScrollToLine(IntPtr handle, int line, byte behavior);

		[DllImport(LibraryName, EntryPoint = "editor_goto_position", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GotoPosition(IntPtr handle, int line, int column);

		[DllImport(LibraryName, EntryPoint = "editor_set_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetScroll(IntPtr handle, float scrollX, float scrollY);

		[DllImport(LibraryName, EntryPoint = "editor_get_scroll_metrics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetScrollMetrics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_register_text_style", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void registerTextStyle(IntPtr handle, uint styleId, int color, int backgroundColor, int fontStyle);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineSpans(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineInlayHints(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLinePhantomTexts(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineGutterIcons(IntPtr handle, byte[] data, nuint size);

		// ===================== Batch APIs =====================

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineSpans(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineInlayHints(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLinePhantomTexts(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineGutterIcons(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineDiagnostics(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearGutterIcons(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_max_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetMaxGutterIcons(IntPtr handle, uint count);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineDiagnostics(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearDiagnostics(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_indent_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetIndentGuides(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_bracket_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBracketGuides(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_flow_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetFlowGuides(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_separator_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetSeparatorGuides(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearGuides(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_fold_regions", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetFoldRegions(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_toggle_fold", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int ToggleFold(IntPtr handle, nuint line);

		[DllImport(LibraryName, EntryPoint = "editor_fold_at", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int FoldAt(IntPtr handle, nuint line);

		[DllImport(LibraryName, EntryPoint = "editor_unfold_at", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int UnfoldAt(IntPtr handle, nuint line);

		[DllImport(LibraryName, EntryPoint = "editor_fold_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FoldAll(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_unfold_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void UnfoldAll(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_is_line_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsLineVisible(IntPtr handle, nuint line);

		[DllImport(LibraryName, EntryPoint = "editor_clear_highlights", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearHighlights(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_clear_highlights_layer", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearHighlightsLayer(IntPtr handle, byte layer);

		[DllImport(LibraryName, EntryPoint = "editor_clear_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearInlayHints(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_clear_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearPhantomTexts(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_clear_all_decorations", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearAllDecorations(IntPtr handle);

		// ===================== BracketHighlight =====================

		[DllImport(LibraryName, EntryPoint = "editor_set_bracket_pairs", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBracketPairs(IntPtr handle, int[] openChars, int[] closeChars, nuint count);

		[DllImport(LibraryName, EntryPoint = "editor_set_matched_brackets", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetMatchedBrackets(IntPtr handle, nuint openLine, nuint openCol, nuint closeLine, nuint closeCol);

		[DllImport(LibraryName, EntryPoint = "editor_clear_matched_brackets", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearMatchedBrackets(IntPtr handle);

		// ===================== LinkedEditing =====================

		[DllImport(LibraryName, EntryPoint = "editor_insert_snippet", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr InsertSnippet(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string snippetTemplate, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_start_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void StartLinkedEditing(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_is_in_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsInLinkedEditing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_linked_editing_next", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int LinkedEditingNext(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_linked_editing_prev", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int LinkedEditingPrev(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_cancel_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void CancelLinkedEditing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "free_binary_data", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeBinaryData(IntPtr ptr);

		[DllImport(LibraryName, EntryPoint = "free_u16_string", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeUtf16String(IntPtr cstringPtr);
	}

	/// <summary>
	/// Editor core that wraps high-level calls to the native C++ editor engine.
	/// </summary>
	public class EditorCore : IDisposable {
		private static bool exceptionHandlerInitialized = false;
		private readonly IntPtr nativeHandle;
		private TextMeasurer measurer;
		private HandleConfig _handleConfig = new HandleConfig();
		private ScrollbarConfig _scrollbarConfig = new ScrollbarConfig();
		private GCHandle textMeasurerGCHandle;
		private GCHandle inlayHintMeasurerGCHandle;
		private GCHandle iconMeasurerGCHandle;
		private GCHandle fontMetricsGCHandle;
		private Document? currentDocument;

		#region Delegate/callback types

		/// <summary>Text width measurement callback delegate.</summary>
		[UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Unicode)]
		public delegate float MeasureTextWidthDelegate([MarshalAs(UnmanagedType.LPWStr)] string text, int fontStyle);

		/// <summary>InlayHint text width measurement callback delegate.</summary>
		[UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet = CharSet.Unicode)]
		public delegate float MeasureInlayHintWidthDelegate([MarshalAs(UnmanagedType.LPWStr)] string text);

		/// <summary>Icon width measurement callback delegate.</summary>
		[UnmanagedFunctionPointer(CallingConvention.StdCall)]
		public delegate float MeasureIconWidthDelegate(int iconId);

		/// <summary>Font metrics callback delegate.</summary>
		[UnmanagedFunctionPointer(CallingConvention.StdCall)]
		public delegate void GetFontMetricsDelegate(IntPtr arrPtr, UIntPtr length);

		/// <summary>
		/// Text measurement callback set, corresponding to the C++ side text_measurer_t.
		/// </summary>
		[StructLayout(LayoutKind.Sequential)]
		public struct TextMeasurer {
			public MeasureTextWidthDelegate MeasureTextWidth;
			public MeasureInlayHintWidthDelegate MeasureInlayHintWidth;
			public MeasureIconWidthDelegate MeasureIconWidth;
			public GetFontMetricsDelegate GetFontMetrics;
		}

		#endregion

		#region Construction/initialization/lifecycle

		/// <summary>
		/// Creates an editor core instance.
		/// </summary>
		/// <param name="textMeasurer">Text measurement callback set</param>
		/// <param name="options">Editor construction options</param>
		public EditorCore(TextMeasurer textMeasurer, EditorOptions options) {
			if (!exceptionHandlerInitialized) {
				NativeMethods.InitUnhandledExceptionHandler();
				exceptionHandlerInitialized = true;
			}
			measurer = textMeasurer;
			textMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureTextWidth);
			inlayHintMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureInlayHintWidth);
			iconMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureIconWidth);
			fontMetricsGCHandle = GCHandle.Alloc(measurer.GetFontMetrics);
			byte[] optionsData = ProtocolEncoder.PackEditorOptions(options);
			nativeHandle = NativeMethods.CreateEditor(measurer, optionsData, (UIntPtr)optionsData.Length);
		}

		/// <summary>Loads a document into the editor.</summary>
		/// <param name="document">Document object to load.</param>
		public void LoadDocument(Document document) {
			currentDocument = document;
			NativeMethods.SetEditorDocument(nativeHandle, document.nativeHandle);
		}

		/// <summary>Gets the currently loaded document instance.</summary>
		public Document? GetDocument() => currentDocument;

		/// <summary>Releases unmanaged resources.</summary>
		public void Dispose() {
			if (textMeasurerGCHandle.IsAllocated) {
				textMeasurerGCHandle.Free();
			}
			if (inlayHintMeasurerGCHandle.IsAllocated) {
				inlayHintMeasurerGCHandle.Free();
			}
			if (iconMeasurerGCHandle.IsAllocated) {
				iconMeasurerGCHandle.Free();
			}
			if (fontMetricsGCHandle.IsAllocated) {
				fontMetricsGCHandle.Free();
			}
		}

		#endregion

		#region Viewport/font/appearance configuration

		/// <summary>Sets editor viewport size.</summary>
		/// <param name="width">Viewport width (pixels).</param>
		/// <param name="height">Viewport height (pixels).</param>
		public void SetViewport(int width, int height) {
			NativeMethods.SetViewport(nativeHandle, width, height);
		}

		/// <summary>Resets the text measurement cache (call after font/DPI changes so the next BuildRenderModel re-measures text).</summary>
		public void ResetMeasurer() {
			NativeMethods.ResetEditorTextMeasurer(nativeHandle);
		}

		/// <summary>Sets fold-arrow display mode.</summary>
		/// <param name="mode">Mode value (0=AUTO, 1=ALWAYS, 2=HIDDEN)</param>
		public void SetFoldArrowMode(int mode) {
			NativeMethods.SetFoldArrowMode(nativeHandle, mode);
		}

		/// <summary>Sets auto-wrap mode.</summary>
		/// <param name="mode">Mode value (0=NONE, 1=CHAR_BREAK, 2=WORD_BREAK)</param>
		public void SetWrapMode(int mode) {
			NativeMethods.SetWrapMode(nativeHandle, mode);
		}

		/// <summary>Sets editor scale factor.</summary>
		/// <param name="scale">Scale factor (1.0 = 100%).</param>
		public void SetScale(float scale) {
			NativeMethods.SetScale(nativeHandle, scale);
		}

		/// <summary>Sets line spacing.</summary>
		/// <param name="add">Additional line spacing (pixels).</param>
		/// <param name="mult">Line spacing multiplier</param>
		public void SetLineSpacing(float add, float mult) {
			NativeMethods.SetLineSpacing(nativeHandle, add, mult);
		}

		/// <summary>Sets extra horizontal padding between gutter split and text content start.</summary>
		/// <param name="padding">Padding in pixels (clamped to &gt;= 0 on native side).</param>
		public void SetContentStartPadding(float padding) {
			NativeMethods.SetContentStartPadding(nativeHandle, padding);
		}

		/// <summary>Sets whether gutter split line should be rendered.</summary>
		/// <param name="show">true=show, false=hide.</param>
		public void SetShowSplitLine(bool show) {
			NativeMethods.SetShowSplitLine(nativeHandle, show ? 1 : 0);
		}

		/// <summary>Sets current line render mode.</summary>
		/// <param name="mode">BACKGROUND(fill), BORDER(stroke), or NONE(disabled).</param>
		public void SetCurrentLineRenderMode(CurrentLineRenderMode mode) {
			NativeMethods.SetCurrentLineRenderMode(nativeHandle, (int)mode);
		}

		#endregion

		#region Rendering

		/// <summary>
		/// Builds the render model (calls the C++ layout engine and returns visual data for the visible area).
		/// </summary>
		/// <returns>Editor render model.</returns>
		public EditorRenderModel BuildRenderModel() {
			IntPtr payloadPtr = NativeMethods.BuildRenderModel(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseRenderModel(payloadPtr, payloadSize);
		}

		#endregion

		#region Gesture/keyboard event handling

		/// <summary>Handles gesture events (touch/mouse/wheel, etc.).</summary>
		/// <param name="gestureEvent">Gesture event data.</param>
		/// <returns>Gesture recognition result.</returns>
		public GestureResult HandleGestureEvent(GestureEvent gestureEvent) {
			float[] pointsArr = gestureEvent.GetPointsArray();
			IntPtr payloadPtr = NativeMethods.HandleGestureEventEx(nativeHandle, (uint)gestureEvent.Type,
				(uint)(gestureEvent.Points?.Count ?? 0), pointsArr,
				(byte)gestureEvent.Modifiers, gestureEvent.WheelDeltaX, gestureEvent.WheelDeltaY, gestureEvent.DirectScale,
				out UIntPtr payloadSize);
			return ProtocolDecoder.ParseGestureResult(payloadPtr, payloadSize);
		}

		/// <summary>Advances edge-scroll by one tick and returns an updated gesture result.</summary>
		public GestureResult TickEdgeScroll() {
			IntPtr payloadPtr = NativeMethods.TickEdgeScroll(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseGestureResult(payloadPtr, payloadSize);
		}

		/// <summary>
		/// Handles keyboard events.
		/// </summary>
		/// <param name="keyCode">Virtual key code</param>
		/// <param name="text">Text mapped to the key (nullable).</param>
		/// <param name="modifiers">Modifier key flags</param>
		/// <returns>Keyboard event handling result.</returns>
		public KeyEventResult HandleKeyEvent(ushort keyCode, string? text, byte modifiers) {
			IntPtr payloadPtr = NativeMethods.HandleKeyEvent(nativeHandle, keyCode, text, modifiers, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseKeyEventResult(payloadPtr, payloadSize);
		}

		#endregion

		#region Text editing

		/// <summary>Inserts text at the caret position.</summary>
		/// <param name="text">Text to insert</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public TextEditResult InsertText(string text) {
			IntPtr payloadPtr = NativeMethods.InsertText(nativeHandle, text, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Replaces text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to replace.</param>
		/// <param name="newText">New replacement text</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public TextEditResult ReplaceText(TextRange range, string newText) {
			IntPtr payloadPtr = NativeMethods.ReplaceText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, newText, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to delete.</param>
		/// <returns>Edit result.</returns>
		public TextEditResult DeleteText(TextRange range) {
			IntPtr payloadPtr = NativeMethods.DeleteText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character backward (Backspace).</summary>
		/// <returns>Edit result.</returns>
		public TextEditResult Backspace() {
			IntPtr payloadPtr = NativeMethods.Backspace(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character forward (Delete key).</summary>
		/// <returns>Edit result.</returns>
		public TextEditResult DeleteForward() {
			IntPtr payloadPtr = NativeMethods.DeleteForward(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) up by one line.</summary>
		public TextEditResult MoveLineUp() {
			IntPtr payloadPtr = NativeMethods.MoveLineUp(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) down by one line.</summary>
		public TextEditResult MoveLineDown() {
			IntPtr payloadPtr = NativeMethods.MoveLineDown(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) upward.</summary>
		public TextEditResult CopyLineUp() {
			IntPtr payloadPtr = NativeMethods.CopyLineUp(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) downward.</summary>
		public TextEditResult CopyLineDown() {
			IntPtr payloadPtr = NativeMethods.CopyLineDown(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes the current line (or all selected lines).</summary>
		public TextEditResult DeleteLine() {
			IntPtr payloadPtr = NativeMethods.DeleteLine(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line above the current line.</summary>
		public TextEditResult InsertLineAbove() {
			IntPtr payloadPtr = NativeMethods.InsertLineAbove(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line below the current line.</summary>
		public TextEditResult InsertLineBelow() {
			IntPtr payloadPtr = NativeMethods.InsertLineBelow(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Gets the currently selected text.</summary>
		/// <returns>Selected text; returns empty string when there is no selection.</returns>
		public string GetSelectedText() {
			IntPtr ptr = NativeMethods.GetSelectedText(nativeHandle);
			string text = Marshal.PtrToStringAnsi(ptr) ?? "";
			return text;
		}

		#endregion

		#region Undo/redo

		/// <summary>Performs undo.</summary>
		/// <returns>Edit result; null means there is nothing to undo.</returns>
		public TextEditResult? Undo() {
			IntPtr payloadPtr = NativeMethods.Undo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Performs redo.</summary>
		/// <returns>Edit result; null means there is nothing to redo.</returns>
		public TextEditResult? Redo() {
			IntPtr payloadPtr = NativeMethods.Redo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Whether undo is available.</summary>
		/// <returns>Returns <c>true</c> if undo is available.</returns>
		public bool CanUndo() {
			return NativeMethods.CanUndo(nativeHandle) != 0;
		}

		/// <summary>Whether redo is available.</summary>
		/// <returns>Returns <c>true</c> if redo is available.</returns>
		public bool CanRedo() {
			return NativeMethods.CanRedo(nativeHandle) != 0;
		}

		#endregion

		#region Caret/Selection Management

		/// <summary>Sets caret position (without scrolling viewport).</summary>
		/// <param name="position">Target position</param>
		public void SetCursorPosition(TextPosition position) {
			NativeMethods.SetCursorPosition(nativeHandle, (nuint)position.Line, (nuint)position.Column);
		}

		/// <summary>Gets current caret position.</summary>
		/// <returns>Caret line/column position.</returns>
		public TextPosition GetCursorPosition() {
			nuint line = 0, column = 0;
			NativeMethods.GetCursorPosition(nativeHandle, ref line, ref column);
			return new TextPosition { Line = (int)line, Column = (int)column };
		}

		/// <summary>Gets the text range of the word at the caret.</summary>
		/// <returns>Word line/column range.</returns>
		public TextRange GetWordRangeAtCursor() {
			nuint sl = 0, sc = 0, el = 0, ec = 0;
			NativeMethods.GetWordRangeAtCursor(nativeHandle, ref sl, ref sc, ref el, ref ec);
			return new TextRange {
				Start = new TextPosition { Line = (int)sl, Column = (int)sc },
				End = new TextPosition { Line = (int)el, Column = (int)ec }
			};
		}

		/// <summary>Gets the text content of the word at the caret.</summary>
		/// <returns>Word text; returns an empty string when the caret is not on a word.</returns>
		public string GetWordAtCursor() {
			IntPtr ptr = NativeMethods.GetWordAtCursor(nativeHandle);
			if (ptr == IntPtr.Zero) return "";
			return Marshal.PtrToStringUTF8(ptr) ?? "";
		}

		/// <summary>Sets text selection.</summary>
		/// <param name="startLine">Selection start line (0-based).</param>
		/// <param name="startColumn">Selection start column (0-based).</param>
		/// <param name="endLine">Selection end line (0-based).</param>
		/// <param name="endColumn">Selection end column (0-based).</param>
		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			NativeMethods.SetSelection(nativeHandle, startLine, startColumn, endLine, endColumn);
		}

		/// <summary>Gets current selection range.</summary>
		/// <returns>Tuple: whether selection exists and the selection range.</returns>
		public (bool hasSelection, TextRange range) GetSelection() {
			nuint sl = 0, sc = 0, el = 0, ec = 0;
			int has = NativeMethods.GetSelection(nativeHandle, ref sl, ref sc, ref el, ref ec);
			var range = new TextRange {
				Start = new TextPosition { Line = (int)sl, Column = (int)sc },
				End = new TextPosition { Line = (int)el, Column = (int)ec }
			};
			return (has != 0, range);
		}

		/// <summary>Selects all document content.</summary>
		public void SelectAll() {
			NativeMethods.SelectAll(nativeHandle);
		}

		#endregion

		#region Caret Movement

		/// <summary>Moves caret left.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorLeft(bool extendSelection = false) {
			NativeMethods.MoveCursorLeft(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret right.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorRight(bool extendSelection = false) {
			NativeMethods.MoveCursorRight(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret up.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorUp(bool extendSelection = false) {
			NativeMethods.MoveCursorUp(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret down.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorDown(bool extendSelection = false) {
			NativeMethods.MoveCursorDown(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret to line start.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorToLineStart(bool extendSelection = false) {
			NativeMethods.MoveCursorToLineStart(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret to line end.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorToLineEnd(bool extendSelection = false) {
			NativeMethods.MoveCursorToLineEnd(nativeHandle, extendSelection ? 1 : 0);
		}

		#endregion

		#region IME composition

		/// <summary>Notifies the editor that IME composition has started.</summary>
		public void CompositionStart() {
			NativeMethods.CompositionStart(nativeHandle);
		}

		/// <summary>Updates IME composition text.</summary>
		/// <param name="text">Current composition text</param>
		public void CompositionUpdate(string text) {
			NativeMethods.CompositionUpdate(nativeHandle, text);
		}

		/// <summary>Ends IME composition and commits the text.</summary>
		/// <param name="committedText">Final committed text</param>
		/// <returns>Edit result.</returns>
		public TextEditResult CompositionEnd(string committedText) {
			IntPtr payloadPtr = NativeMethods.CompositionEnd(nativeHandle, committedText, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Cancels IME composition.</summary>
		public void CompositionCancel() {
			NativeMethods.CompositionCancel(nativeHandle);
		}

		/// <summary>Whether IME composition is currently active.</summary>
		/// <returns>Returns <c>true</c> when IME composition is active.</returns>
		public bool IsComposing() {
			return NativeMethods.IsComposing(nativeHandle) != 0;
		}

		#endregion

		#region Read-only mode

		/// <summary>Sets read-only mode.</summary>
		/// <param name="readOnly">Whether read-only</param>
		public void SetReadOnly(bool readOnly) {
			NativeMethods.SetReadOnly(nativeHandle, readOnly ? 1 : 0);
		}

		/// <summary>Checks whether the editor is in read-only mode.</summary>
		/// <returns>Returns <c>true</c> when read-only.</returns>
		public bool IsReadOnly() {
			return NativeMethods.IsReadOnly(nativeHandle) != 0;
		}

		#endregion

		#region Auto Indent

		/// <summary>Sets auto-indent mode.</summary>
		/// <param name="mode">Auto-indent mode</param>
		public void SetAutoIndentMode(int mode) {
			NativeMethods.SetAutoIndentMode(nativeHandle, mode);
		}

		/// <summary>Gets current auto-indent mode.</summary>
		/// <returns>Auto-indent mode value (0=NONE, 1=KEEP_INDENT).</returns>
		public int GetAutoIndentMode() {
			return NativeMethods.GetAutoIndentMode(nativeHandle);
		}

		#endregion

		#region Handle Config

		/// <summary>Sets the selection handle appearance and touch configuration.</summary>
		/// <param name="config">HandleConfig instance</param>
		public void SetHandleConfig(HandleConfig config) {
			_handleConfig = config;
			NativeMethods.SetHandleConfig(nativeHandle, config.Radius, config.CenterDist, config.LineWidth, config.TouchPadding, config.DragYOffset);
		}

		/// <summary>Gets the current handle configuration.</summary>
		public HandleConfig GetHandleConfig() {
			return _handleConfig;
		}

		#endregion

		#region Scrollbar Config

		/// <summary>Sets scrollbar geometry configuration.</summary>
		/// <param name="config">ScrollbarConfig instance</param>
		public void SetScrollbarConfig(ScrollbarConfig config) {
			_scrollbarConfig = config;
			NativeMethods.SetScrollbarConfig(
				nativeHandle,
				config.Thickness,
				config.MinThumb,
				config.ThumbHitPadding,
				(int)config.Mode,
				config.ThumbDraggable ? 1 : 0,
				(int)config.TrackTapMode,
				config.FadeDelayMs,
				config.FadeDurationMs);
		}

		/// <summary>Gets the current scrollbar geometry configuration.</summary>
		public ScrollbarConfig GetScrollbarConfig() {
			return _scrollbarConfig;
		}

		#endregion

		#region Position coordinate queries

		/// <summary>Gets the screen-space rectangle for any text position (for floating panel positioning).</summary>
		/// <param name="line">Line (0-based)</param>
		/// <param name="column">Column (0-based)</param>
		/// <returns>CursorRect; coordinates are relative to the top-left corner of the editor control.</returns>
		public CursorRect GetPositionRect(int line, int column) {
			float x = 0, y = 0, h = 0;
			NativeMethods.GetPositionRect(nativeHandle, (nuint)line, (nuint)column, ref x, ref y, ref h);
			return new CursorRect { X = x, Y = y, Height = h };
		}

		/// <summary>Gets the screen-space rectangle for the current caret position (shortcut method).</summary>
		/// <returns>CursorRect; coordinates are relative to the top-left corner of the editor control.</returns>
		public CursorRect GetCursorRect() {
			float x = 0, y = 0, h = 0;
			NativeMethods.GetCursorRect(nativeHandle, ref x, ref y, ref h);
			return new CursorRect { X = x, Y = y, Height = h };
		}

		#endregion

		#region Scrolling/navigation

		/// <summary>Jumps to the specified line and column.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="column">Target column (0-based).</param>
		public void GotoPosition(int line, int column) {
			NativeMethods.GotoPosition(nativeHandle, line, column);
		}

		/// <summary>Scrolls to the specified line.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="behavior">Scroll alignment behavior (see <see cref="ScrollBehavior"/>).</param>
		public void ScrollToLine(int line, int behavior = (int)ScrollBehavior.CENTER) {
			NativeMethods.ScrollToLine(nativeHandle, line, (byte)behavior);
		}

		/// <summary>Manually sets scroll position (automatically clamped to valid range).</summary>
		/// <param name="scrollX">Horizontal scroll offset</param>
		/// <param name="scrollY">Vertical scroll offset</param>
		public void SetScroll(float scrollX, float scrollY) {
			NativeMethods.SetScroll(nativeHandle, scrollX, scrollY);
		}

		/// <summary>Gets scrollbar metrics (used by platform-side scrollbar rendering).</summary>
		public ScrollMetrics GetScrollMetrics() {
			IntPtr payloadPtr = NativeMethods.GetScrollMetrics(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseScrollMetrics(payloadPtr, payloadSize);
		}
		#endregion

		#region Style Registration + Highlight Spans

		/// <summary>Registers a highlight style (with background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="backgroundColor">Background color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public void registerTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) {
			NativeMethods.registerTextStyle(nativeHandle, styleId, color, backgroundColor, fontStyle);
		}

		/// <summary>Registers a highlight style (without background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public void registerTextStyle(uint styleId, int color, int fontStyle) {
			NativeMethods.registerTextStyle(nativeHandle, styleId, color, 0, fontStyle);
		}

		/// <summary>Sets highlight spans for the specified line (model overload).</summary>
		public void SetLineSpans(int line, int layer, IList<StyleSpan> spans) {
			if (spans == null) return;
			byte[] payload = ProtocolEncoder.PackLineSpans(line, layer, spans);
			NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets highlight spans for the specified line (buffer overload, accepts pre-encoded data).</summary>
		public void SetLineSpans(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets highlight spans for multiple lines (model overload).</summary>
		public void SetBatchLineSpans(int layer, Dictionary<int, IList<StyleSpan>> spansByLine) {
			if (spansByLine == null || spansByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineSpans(layer, spansByLine);
			NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets highlight spans for multiple lines (buffer overload, accepts pre-encoded data).</summary>
		public void SetBatchLineSpans(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		#endregion

		#region InlayHint / PhantomText

		/// <summary>Sets Inlay Hints for the specified line (model overload, replaces whole line).</summary>
		public void SetLineInlayHints(int line, IList<InlayHint> hints) {
			if (hints == null) return;
			byte[] payload = ProtocolEncoder.PackLineInlayHints(line, hints);
			NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets Inlay Hints for the specified line (buffer overload).</summary>
		public void SetLineInlayHints(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (model overload).</summary>
		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) {
			if (hintsByLine == null || hintsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineInlayHints(hintsByLine);
			NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (buffer overload).</summary>
		public void SetBatchLineInlayHints(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets ghost text for the specified line (model overload, replaces whole line).</summary>
		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) {
			if (phantoms == null) return;
			byte[] payload = ProtocolEncoder.PackLinePhantomTexts(line, phantoms);
			NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets ghost text for the specified line (buffer overload).</summary>
		public void SetLinePhantomTexts(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets ghost text for multiple lines (model overload).</summary>
		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) {
			if (phantomsByLine == null || phantomsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLinePhantomTexts(phantomsByLine);
			NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets ghost text for multiple lines (buffer overload).</summary>
		public void SetBatchLinePhantomTexts(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		#endregion

		#region Gutter icons

		/// <summary>Sets gutter icons for the specified line (model overload, replaces whole line).</summary>
		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) {
			if (icons == null) return;
			byte[] payload = ProtocolEncoder.PackLineGutterIcons(line, icons);
			NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets gutter icons for the specified line (buffer overload).</summary>
		public void SetLineGutterIcons(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets gutter icons for multiple lines (model overload).</summary>
		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) {
			if (iconsByLine == null || iconsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineGutterIcons(iconsByLine);
			NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets gutter icons for multiple lines (buffer overload).</summary>
		public void SetBatchLineGutterIcons(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all gutter icons.</summary>
		public void ClearGutterIcons() {
			NativeMethods.ClearGutterIcons(nativeHandle);
		}

		/// <summary>Sets maximum icon count shown in the gutter.</summary>
		public void SetMaxGutterIcons(int count) {
			NativeMethods.SetMaxGutterIcons(nativeHandle, (uint)count);
		}

		#endregion

		#region Diagnostic decorations

		/// <summary>Sets diagnostic decorations for the specified line (model overload).</summary>
		public void SetLineDiagnostics(int line, IList<DiagnosticItem> items) {
			if (items == null) return;
			byte[] payload = ProtocolEncoder.PackLineDiagnostics(line, items);
			NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets diagnostic decorations for the specified line (buffer overload).</summary>
		public void SetLineDiagnostics(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (model overload).</summary>
		public void SetBatchLineDiagnostics(Dictionary<int, IList<DiagnosticItem>> diagsByLine) {
			if (diagsByLine == null || diagsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineDiagnostics(diagsByLine);
			NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (buffer overload).</summary>
		public void SetBatchLineDiagnostics(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all diagnostic decorations.</summary>
		public void ClearDiagnostics() {
			NativeMethods.ClearDiagnostics(nativeHandle);
		}

		#endregion

		#region Guide Lines

		/// <summary>Sets indent guide list (global replace, model overload).</summary>
		public void SetIndentGuides(IList<IndentGuide> guides) {
			if (guides == null) return;
			byte[] payload = ProtocolEncoder.PackIndentGuides(guides);
			NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets indent guide list (buffer overload).</summary>
		public void SetIndentGuides(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets bracket branch guide list (global replace, model overload).</summary>
		public void SetBracketGuides(IList<BracketGuide> guides) {
			if (guides == null) return;
			byte[] payload = ProtocolEncoder.PackBracketGuides(guides);
			NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets bracket branch guide list (buffer overload).</summary>
		public void SetBracketGuides(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets control-flow back-edge arrow list (global replace, model overload).</summary>
		public void SetFlowGuides(IList<FlowGuide> guides) {
			if (guides == null) return;
			byte[] payload = ProtocolEncoder.PackFlowGuides(guides);
			NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets control-flow back-edge arrow list (buffer overload).</summary>
		public void SetFlowGuides(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets horizontal separator list (global replace, model overload).</summary>
		public void SetSeparatorGuides(IList<SeparatorGuide> guides) {
			if (guides == null) return;
			byte[] payload = ProtocolEncoder.PackSeparatorGuides(guides);
			NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets horizontal separator list (buffer overload).</summary>
		public void SetSeparatorGuides(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all code guide lines.</summary>
		public void ClearGuides() {
			NativeMethods.ClearGuides(nativeHandle);
		}

		#endregion

		#region Code folding

		/// <summary>Sets foldable region list (model overload).</summary>
		public void SetFoldRegions(IList<FoldRegion> regions) {
			if (regions == null) return;
			byte[] payload = ProtocolEncoder.PackFoldRegions(regions);
			NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets foldable region list (buffer overload).</summary>
		public void SetFoldRegions(byte[] payload) {
			if (payload == null) return;
			NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Toggles fold/unfold state of the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means a region was found and toggled.</returns>
		public bool ToggleFold(int line) {
			return NativeMethods.ToggleFold(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Folds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means folding succeeded.</returns>
		public bool FoldAt(int line) {
			return NativeMethods.FoldAt(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Unfolds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means unfolding succeeded.</returns>
		public bool UnfoldAt(int line) {
			return NativeMethods.UnfoldAt(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Folds all regions.</summary>
		public void FoldAll() {
			NativeMethods.FoldAll(nativeHandle);
		}

		/// <summary>Unfolds all regions.</summary>
		public void UnfoldAll() {
			NativeMethods.UnfoldAll(nativeHandle);
		}

		/// <summary>Checks whether the specified line is visible (not hidden by folding).</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means visible.</returns>
		public bool IsLineVisible(int line) {
			return NativeMethods.IsLineVisible(nativeHandle, (nuint)line) != 0;
		}

		#endregion

		#region Clear operations

		/// <summary>Clears all highlight spans.</summary>
		public void ClearHighlights() {
			NativeMethods.ClearHighlights(nativeHandle);
		}

		/// <summary>Clears highlight spans in the specified layer.</summary>
		/// <param name="layer">Target layer (see <see cref="SpanLayer"/>).</param>
		public void ClearHighlights(int layer) {
			NativeMethods.ClearHighlightsLayer(nativeHandle, (byte)layer);
		}

		/// <summary>Clears all Inlay Hints.</summary>
		public void ClearInlayHints() {
			NativeMethods.ClearInlayHints(nativeHandle);
		}

		/// <summary>Clears all ghost text.</summary>
		public void ClearPhantomTexts() {
			NativeMethods.ClearPhantomTexts(nativeHandle);
		}

		/// <summary>Clears all decoration data (highlights, Inlay Hints, ghost text, icons, and guide lines).</summary>
		public void ClearAllDecorations() {
			NativeMethods.ClearAllDecorations(nativeHandle);
		}

		#endregion

		#region LinkedEditing

		/// <summary>Inserts a VSCode snippet template and enters linked editing mode.</summary>
		public TextEditResult InsertSnippet(string snippetTemplate) {
			IntPtr payloadPtr = NativeMethods.InsertSnippet(nativeHandle, snippetTemplate, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Starts linked editing mode with a generic LinkedEditingModel.</summary>
		public void StartLinkedEditing(LinkedEditingModel model) {
			byte[] payload = ProtocolEncoder.PackLinkedEditingPayload(model);
			NativeMethods.StartLinkedEditing(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Whether linked editing mode is active.</summary>
		public bool IsInLinkedEditing() {
			return NativeMethods.IsInLinkedEditing(nativeHandle) != 0;
		}

		/// <summary>Linked editing: jump to next tab stop.</summary>
		public bool LinkedEditingNext() {
			return NativeMethods.LinkedEditingNext(nativeHandle) != 0;
		}

		/// <summary>Linked editing: jump to previous tab stop.</summary>
		public bool LinkedEditingPrev() {
			return NativeMethods.LinkedEditingPrev(nativeHandle) != 0;
		}

		/// <summary>Cancels linked editing mode.</summary>
		public void CancelLinkedEditing() {
			NativeMethods.CancelLinkedEditing(nativeHandle);
		}

		#endregion

		#region Bracket highlight APIs

		/// <summary>Sets custom bracket pair list.</summary>
		public void SetBracketPairs(int[] openChars, int[] closeChars) {
			if (openChars.Length != closeChars.Length) throw new ArgumentException("open/close arrays must have same length");
			NativeMethods.SetBracketPairs(nativeHandle, openChars, closeChars, (nuint)openChars.Length);
		}

		/// <summary>Sets externally computed exact bracket pair positions (takes priority over built-in scanning).</summary>
		public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) {
			NativeMethods.SetMatchedBrackets(nativeHandle, (nuint)openLine, (nuint)openColumn, (nuint)closeLine, (nuint)closeColumn);
		}

		/// <summary>Clears externally supplied bracket match results (falls back to built-in scanning).</summary>
		public void ClearMatchedBrackets() {
			NativeMethods.ClearMatchedBrackets(nativeHandle);
		}

		#endregion

	}
}

