using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
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
	public class Document : IDisposable {
		internal IntPtr nativeHandle;
		private bool disposed;

		/// <summary>
		/// Creates a document from UTF-16 text.
		/// </summary>
		/// <param name="text">Initial document text content</param>
		public Document(string text) {
			nativeHandle = NativeMethods.CreateDocument(text);
		}

		/// <summary>
		/// Creates a document from a local file.
		/// </summary>
		/// <param name="file">Source file</param>
		public Document(FileInfo? file) : this(ReadTextFromFile(file)) {
		}

		/// <summary>
		/// Creates a document from a local file path.
		/// </summary>
		/// <param name="path">Source file path</param>
		public static Document FromPath(string path) {
			return new Document(ReadTextFromFile(path));
		}

		/// <summary>
		/// Gets the number of logical lines in the document.
		/// </summary>
		public int GetLineCount() {
			if (nativeHandle == IntPtr.Zero) return 0;
			return checked((int)NativeMethods.GetDocumentLineCount(nativeHandle));
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

		/// <summary>
		/// Gets the complete document text.
		/// </summary>
		public string GetText() {
			if (nativeHandle == IntPtr.Zero) return "";
			IntPtr ptr = NativeMethods.GetDocumentText(nativeHandle);
			if (ptr == IntPtr.Zero) return "";
			string text = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return text;
		}

		private static string ReadTextFromFile(FileInfo? file) {
			return ReadTextFromFile(file?.FullName);
		}

		private static string ReadTextFromFile(string? path) {
			if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) return "";
			return File.ReadAllText(path);
		}

		~Document() {
			Dispose(false);
		}

		public void Dispose() {
			Dispose(true);
			GC.SuppressFinalize(this);
		}

		private void Dispose(bool disposing) {
			if (disposed) return;
			disposed = true;
			if (nativeHandle != IntPtr.Zero) {
				NativeMethods.FreeDocument(nativeHandle);
				nativeHandle = IntPtr.Zero;
			}
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
	/// Keyboard key code constants matching the C++ KeyCode enum.
	/// </summary>
	public enum KeyCode : ushort {
		NONE = 0,
		BACKSPACE = 8,
		TAB = 9,
		ENTER = 13,
		ESCAPE = 27,
		SPACE = 32,
		PAGE_UP = 33,
		PAGE_DOWN = 34,
		END = 35,
		HOME = 36,
		LEFT = 37,
		UP = 38,
		RIGHT = 39,
		DOWN = 40,
		DELETE_KEY = 46,
		A = 65,
		C = 67,
		D = 68,
		K = 75,
		V = 86,
		X = 88,
		Y = 89,
		Z = 90,
	}

	/// <summary>
	/// Modifier flag constants matching the C++ KeyModifier enum.
	/// </summary>
	[Flags]
	public enum KeyModifier : byte {
		NONE = 0,
		SHIFT = 1 << 0,
		CTRL = 1 << 1,
		ALT = 1 << 2,
		META = 1 << 3,
	}

	/// <summary>
	/// Built-in editor command ids matching the C++ EditorCommand enum.
	/// </summary>
	public enum EditorCommand : uint {
		NONE = 0,
		CURSOR_LEFT = 1,
		CURSOR_RIGHT = 2,
		CURSOR_UP = 3,
		CURSOR_DOWN = 4,
		CURSOR_LINE_START = 5,
		CURSOR_LINE_END = 6,
		CURSOR_PAGE_UP = 7,
		CURSOR_PAGE_DOWN = 8,
		SELECT_LEFT = 9,
		SELECT_RIGHT = 10,
		SELECT_UP = 11,
		SELECT_DOWN = 12,
		SELECT_LINE_START = 13,
		SELECT_LINE_END = 14,
		SELECT_PAGE_UP = 15,
		SELECT_PAGE_DOWN = 16,
		SELECT_ALL = 17,
		BACKSPACE = 18,
		DELETE_FORWARD = 19,
		INSERT_TAB = 20,
		INSERT_NEWLINE = 21,
		INSERT_LINE_ABOVE = 22,
		INSERT_LINE_BELOW = 23,
		UNDO = 24,
		REDO = 25,
		MOVE_LINE_UP = 26,
		MOVE_LINE_DOWN = 27,
		COPY_LINE_UP = 28,
		COPY_LINE_DOWN = 29,
		DELETE_LINE = 30,
		COPY = 31,
		PASTE = 32,
		CUT = 33,
		TRIGGER_COMPLETION = 34,
	}

	/// <summary>
	/// A single key chord: one key press with optional modifiers.
	/// </summary>
	public readonly struct KeyChord : IEquatable<KeyChord> {
		public static readonly KeyChord EMPTY = new(KeyModifier.NONE, KeyCode.NONE);

		public KeyModifier Modifiers { get; }
		public KeyCode KeyCode { get; }

		public KeyChord(KeyModifier modifiers, KeyCode keyCode) {
			Modifiers = modifiers;
			KeyCode = keyCode;
		}

		public bool IsEmpty => KeyCode == KeyCode.NONE;

		public bool Equals(KeyChord other) => Modifiers == other.Modifiers && KeyCode == other.KeyCode;

		public override bool Equals(object? obj) => obj is KeyChord other && Equals(other);

		public override int GetHashCode() => HashCode.Combine((byte)Modifiers, (ushort)KeyCode);
	}

	/// <summary>
	/// A key binding entry: one or two chords mapped to a command id.
	/// </summary>
	public sealed class KeyBinding : IEquatable<KeyBinding> {
		public KeyChord First { get; }
		public KeyChord Second { get; }
		public int Command { get; }

		public KeyBinding(KeyChord first, int command) : this(first, KeyChord.EMPTY, command) { }

		public KeyBinding(KeyChord first, KeyChord second, int command) {
			First = first;
			Second = second;
			Command = command;
		}

		public KeyBinding(KeyModifier modifiers, KeyCode keyCode, int command)
			: this(new KeyChord(modifiers, keyCode), KeyChord.EMPTY, command) { }

		public KeyBinding(KeyModifier firstModifiers, KeyCode firstKeyCode,
						  KeyModifier secondModifiers, KeyCode secondKeyCode, int command)
			: this(new KeyChord(firstModifiers, firstKeyCode), new KeyChord(secondModifiers, secondKeyCode), command) { }

		public KeyBinding WithCommand(int command) => new KeyBinding(First, Second, command);

		public bool Equals(KeyBinding? other) {
			if (other is null) return false;
			return First.Equals(other.First) && Second.Equals(other.Second);
		}

		public override bool Equals(object? obj) => Equals(obj as KeyBinding);

		public override int GetHashCode() => HashCode.Combine(First, Second);
	}

	/// <summary>
	/// Pure data container for keyboard shortcut bindings.
	/// </summary>
	public class KeyMap {
		private readonly Dictionary<KeyBinding, int> bindings = new();

		public void AddBinding(KeyBinding binding) {
			bindings[binding] = binding.Command;
		}

		public void RemoveBinding(KeyBinding binding) {
			bindings.Remove(binding);
		}

		public IReadOnlyDictionary<KeyBinding, int> GetBindings() {
			return bindings;
		}
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
		public KeyModifier Modifiers { get; set; }
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
	/// Selection handle hit-test configuration.
	/// </summary>
	public class HandleConfig {
		/// <summary>Start handle hit area offset from the cursor bottom anchor (left)</summary>
		public float StartLeft { get; set; } = -32.1f;
		/// <summary>Start handle hit area offset from the cursor bottom anchor (top)</summary>
		public float StartTop { get; set; } = -8.0f;
		/// <summary>Start handle hit area offset from the cursor bottom anchor (right)</summary>
		public float StartRight { get; set; } = 8.0f;
		/// <summary>Start handle hit area offset from the cursor bottom anchor (bottom)</summary>
		public float StartBottom { get; set; } = 32.1f;
		/// <summary>End handle hit area offset from the cursor bottom anchor (left)</summary>
		public float EndLeft { get; set; } = -8.0f;
		/// <summary>End handle hit area offset from the cursor bottom anchor (top)</summary>
		public float EndTop { get; set; } = -8.0f;
		/// <summary>End handle hit area offset from the cursor bottom anchor (right)</summary>
		public float EndRight { get; set; } = 32.1f;
		/// <summary>End handle hit area offset from the cursor bottom anchor (bottom)</summary>
		public float EndBottom { get; set; } = 32.1f;
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
	/// Binary layout (LE): f32 touch_slop, i64 double_tap_timeout, i64 long_press_ms, f32 fling_friction, f32 fling_min_velocity, f32 fling_max_velocity, u64 max_undo_stack_size, i64 key_chord_timeout_ms, u8 reveal_selection_end_on_select_all
	/// </summary>
	public class EditorOptions {
		/// <summary>Threshold to determine if a gesture is a move (default 10)</summary>
		public float TouchSlop { get; set; } = 10f;
		/// <summary>Double-tap time threshold in ms (default 300)</summary>
		public long DoubleTapTimeout { get; set; } = 300;
		/// <summary>Long press time threshold in ms (default 500)</summary>
		public long LongPressMs { get; set; } = 500;
		/// <summary>Fling friction coefficient, higher = faster deceleration (default 2.0)</summary>
		public float FlingFriction { get; set; } = 2.0f;
		/// <summary>Minimum fling velocity threshold in px/s (default 30)</summary>
		public float FlingMinVelocity { get; set; } = 30f;
		/// <summary>Maximum fling velocity cap in px/s (default 12000)</summary>
		public float FlingMaxVelocity { get; set; } = 12000f;
		/// <summary>Max undo stack size, 0 = unlimited (default 512)</summary>
		public ulong MaxUndoStackSize { get; set; } = 512;
		/// <summary>Key chord pending timeout in ms (default 2000)</summary>
		public long KeyChordTimeoutMs { get; set; } = 2000;
		/// <summary>Whether selectAll() should reveal the selection end after selecting the full document.</summary>
		public bool RevealSelectionEndOnSelectAll { get; set; } = false;
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
	/// Editor layout metrics exposed by the native layout engine.
	/// </summary>
	public struct LayoutMetrics {
		public float FontHeight;
		public float FontAscent;
		public float LineSpacingAdd;
		public float LineSpacingMult;
		public float LineNumberMargin;
		public float LineNumberWidth;
		public int MaxGutterIcons;
		public float InlayHintPadding;
		public float InlayHintMargin;
		public FoldArrowMode FoldArrowMode;
		public bool HasFoldRegions;
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

	/// <summary>Immutable value object representing a single CodeLens item.</summary>
	public sealed class CodeLensItem {
		/// <summary>Column anchor within the logical line (0-based, UTF-16 offset).</summary>
		public int Column { get; }
		/// <summary>Display text (e.g. "3 references")</summary>
		public string Text { get; }
		/// <summary>Command ID (platform-defined, passed back on click)</summary>
		public int CommandId { get; }
		public CodeLensItem(int column, string text, int commandId) { Column = column; Text = text; CommandId = commandId; }
	}

	/// <summary>Immutable value object representing a clickable link span on a line.</summary>
	public sealed class LinkSpan {
		/// <summary>Start column within the logical line (0-based, UTF-16 offset).</summary>
		public int Column { get; }
		/// <summary>Character length of the link span.</summary>
		public int Length { get; }
		/// <summary>Link target string returned on click.</summary>
		public string Target { get; }
		public LinkSpan(int column, int length, string target) {
			Column = column;
			Length = length;
			Target = target ?? string.Empty;
		}
	}

	/// <summary>Immutable value object describing a single gutter icon.</summary>
	public sealed class GutterIcon {
		/// <summary>Icon resource ID</summary>
		public int IconId { get; }
		public GutterIcon(int iconId) { IconId = iconId; }
	}

	/// <summary>Immutable value object describing a diagnostic entry on a line.</summary>
	public sealed class Diagnostic {
		/// <summary>Start column (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Character length</summary>
		public int Length { get; }
		/// <summary>Severity (0=error, 1=warning, 2=info, 3=hint)</summary>
		public int Severity { get; }
		public Diagnostic(int column, int length, int severity) { Column = column; Length = length; Severity = severity; }
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
		public IReadOnlyList<TextPosition> Children { get; }
		public BracketGuide(TextPosition parent, TextPosition end, IReadOnlyList<TextPosition> children) {
			Parent = parent;
			End = end;
			Children = children ?? Array.Empty<TextPosition>();
		}
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
		/// <summary>Separator style.</summary>
		public SeparatorStyle Style { get; }
		/// <summary>Symbol count</summary>
		public int Count { get; }
		/// <summary>Comment text end column</summary>
		public int TextEndColumn { get; }
		public SeparatorGuide(int line, SeparatorStyle style, int count, int textEndColumn) {
			Line = line;
			Style = style;
			Count = count;
			TextEndColumn = textEndColumn;
		}
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
		/// <summary>Hit a CodeLens item.</summary>
		CODELENS = 7,
		/// <summary>Hit a clickable document link.</summary>
		LINK = 8,
	}

	/// <summary>
	/// Pointer cursor type hint returned by the core.
	/// </summary>
	[JsonConverter(typeof(JsonStringEnumConverter))]
	public enum PointerCursorType {
		DEFAULT = 0,
		TEXT = 1,
		HAND = 2,
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
		/// <summary>Hit column (0-based, meaningful for InlayHint, CodeLens, and Link).</summary>
		[JsonPropertyName("column")]
		public int Column { get; set; }
		/// <summary>Icon ID (valid for INLAY_HINT_ICON / GUTTER_ICON, or command ID for CODELENS).</summary>
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

		/// <summary>Whether the platform should start/continue a fling animation callback.</summary>
		[JsonPropertyName("needs_fling")]
		public bool NeedsFling { get; set; }

		/// <summary>Whether any animation is still active; platform can use a single callback.</summary>
		[JsonPropertyName("needs_animation")]
		public bool NeedsAnimation { get; set; }

		/// <summary>Pointer cursor type hint for the current mouse location.</summary>
		[JsonPropertyName("pointer_cursor_type")]
		public PointerCursorType PointerCursorType { get; set; }

		/// <summary>Creates the default gesture result.</summary>
		public GestureResult() {
			Type = GestureType.UNDEFINED;
			TapPoint = new PointF();
			PointerCursorType = global::SweetEditor.PointerCursorType.TEXT;
		}

		/// <summary>Creates a gesture result with the specified type and position.</summary>
		/// <param name="type">Gesture type</param>
		/// <param name="position">Tap screen position</param>
		public GestureResult(GestureType type, PointF position) {
			Type = type;
			TapPoint = position;
			PointerCursorType = global::SweetEditor.PointerCursorType.TEXT;
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
		FOLD_PLACEHOLDER,
		/// <summary>Tab character (width computed by core based on tab_size and column position).</summary>
		TAB,
		/// <summary>CodeLens clickable label (above code line).</summary>
		CODELENS,
		/// <summary>Clickable document link embedded in code text.</summary>
		LINK
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
		/// <summary>Segment text content (used by TEXT, INLAY_HINT(TEXT), PHANTOM_TEXT, and LINK).</summary>
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
		/// <summary>Whether this run is in active state (hovered/pressed).</summary>
		[JsonPropertyName("active")]
		public bool Active { get; set; }
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

	public enum VisualLineKind {
		CONTENT = 0,
		PHANTOM = 1,
		CODELENS = 2,
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
		/// <summary>Semantic kind of this visual row.</summary>
		[JsonPropertyName("kind")]
		public VisualLineKind Kind { get; set; }
		/// <summary>Whether this visual row owns gutter semantics (line number, gutter icon, fold marker).</summary>
		[JsonPropertyName("owns_gutter_semantics")]
		public bool OwnsGutterSemantics { get; set; }
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

	/// <summary>
	/// Inclusive integer range.
	/// </summary>
	public struct IntRange {
		[JsonPropertyName("start")]
		public int Start { get; set; }
		[JsonPropertyName("end")]
		public int End { get; set; }

		public bool IsEmpty => End < Start;

		public IntRange(int start, int end) {
			Start = start;
			End = end;
		}

		public override string ToString() => $"IntRange(Start={Start}, End={End})";
	}

	#region Editor event system

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
	public sealed class TextChange {
		/// <summary>Replaced/deleted text range (pre-operation coordinates).</summary>
		[JsonPropertyName("range")]
		public TextRange Range { get; }
		/// <summary>New text after change (inserted/replaced content).</summary>
		[JsonPropertyName("new_text")]
		public string NewText { get; }

		public TextChange(TextRange range, string newText) {
			Range = range;
			NewText = newText ?? string.Empty;
		}
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
	/// Text unit used by IME deletion requests.
	/// </summary>
	public enum ImeTextUnit {
		UTF16_CODE_UNIT = 0,
		CODE_POINT = 1
	}

	/// <summary>
	/// Script class reported by a platform IME.
	/// </summary>
	public enum ImeScriptClass {
		UNKNOWN = 0,
		LATIN = 1,
		CJK = 2,
		KANA = 3,
		HANGUL = 4
	}

	/// <summary>
	/// Storage used for the active IME preedit.
	/// </summary>
	public enum ImePreeditStorage {
		NONE = 0,
		VISIBLE_DOCUMENT_COMPOSITION = 1,
		SHADOW_ONLY = 2
	}

	/// <summary>
	/// Surrounding context policy exposed to platform IME APIs.
	/// </summary>
	public enum ImeContextPolicy {
		NONE = 0,
		LIMITED_FOR_CANDIDATES = 1
	}

	/// <summary>
	/// Snapshot used by platform layers to synchronize IME selection and marked ranges.
	/// </summary>
	public sealed class ImeSyncSnapshot {
		[JsonPropertyName("cursor")]
		public TextPosition Cursor { get; set; }
		[JsonPropertyName("selection")]
		public TextRange? Selection { get; set; }
		[JsonPropertyName("has_composing_session")]
		public bool HasComposingSession { get; set; }
		[JsonPropertyName("visible_composition_range")]
		public TextRange? VisibleCompositionRange { get; set; }
		[JsonPropertyName("platform_marked_range")]
		public TextRange? PlatformMarkedRange { get; set; }
		[JsonPropertyName("platform_text_window_text")]
		public string PlatformTextWindowText { get; set; } = string.Empty;
		[JsonPropertyName("platform_text_window_start_offset")]
		public int PlatformTextWindowStartOffset { get; set; }
		[JsonPropertyName("platform_text_window_selection_offsets")]
		public IntRange PlatformTextWindowSelectionOffsets { get; set; } = new IntRange(0, 0);
		[JsonPropertyName("platform_text_window_composing_offsets")]
		public IntRange PlatformTextWindowComposingOffsets { get; set; } = new IntRange(-1, -1);
		[JsonPropertyName("preedit_storage")]
		public ImePreeditStorage PreeditStorage { get; set; } = ImePreeditStorage.NONE;
		[JsonPropertyName("context_policy")]
		public ImeContextPolicy ContextPolicy { get; set; } = ImeContextPolicy.NONE;
		[JsonPropertyName("clear_platform_preedit")]
		public bool ClearPlatformPreedit { get; set; }
	}

	/// <summary>
	/// Result of a semantic IME action handled by the core.
	/// </summary>
	public sealed class ImeActionResult {
		[JsonPropertyName("handled")]
		public bool Handled { get; set; }
		[JsonPropertyName("content_changed")]
		public bool ContentChanged { get; set; }
		[JsonPropertyName("cursor_changed")]
		public bool CursorChanged { get; set; }
		[JsonPropertyName("selection_changed")]
		public bool SelectionChanged { get; set; }
		[JsonPropertyName("edit_result")]
		public TextEditResult EditResult { get; set; } = TextEditResult.Empty;
		[JsonPropertyName("sync")]
		public ImeSyncSnapshot Sync { get; set; } = new ImeSyncSnapshot();
	}

	/// <summary>
	/// Text change event args.
	/// </summary>
	public class TextChangedEventArgs : EventArgs {
		/// <summary>Operation type</summary>
		public TextChangeAction Action { get; }
		/// <summary>Incremental text changes for the current edit cycle.</summary>
		public IReadOnlyList<TextChange> Changes { get; }
		public TextChangedEventArgs(TextChangeAction action, IReadOnlyList<TextChange>? changes = null) {
			Action = action;
			Changes = changes ?? Array.Empty<TextChange>();
		}
	}

	/// <summary>
	/// Caret change event args.
	/// </summary>
	public class CursorChangedEventArgs : EventArgs {
		public TextPosition CursorPosition { get; }
		public CursorChangedEventArgs(TextPosition cursor) { CursorPosition = cursor; }
	}

	/// <summary>
	/// Selection changed event args.
	/// </summary>
	public class SelectionChangedEventArgs : EventArgs {
		public bool HasSelection { get; }
		public TextRange? Selection { get; }
		public TextPosition CursorPosition { get; }
		public SelectionChangedEventArgs(bool has, TextRange? sel, TextPosition cursor) {
			HasSelection = has;
			Selection = sel;
			CursorPosition = cursor;
		}
	}

	/// <summary>
	/// Scroll change event args.
	/// </summary>
	public class ScrollChangedEventArgs : EventArgs {
		public float ScrollX { get; }
		public float ScrollY { get; }
		public ScrollChangedEventArgs(float x, float y) { ScrollX = x; ScrollY = y; }
	}

	/// <summary>
	/// Zoom changed event args.
	/// </summary>
	public class ScaleChangedEventArgs : EventArgs {
		public float Scale { get; }
		public ScaleChangedEventArgs(float scale) { Scale = scale; }
	}

	/// <summary>
	/// Document loaded event args.
	/// </summary>
	public class DocumentLoadedEventArgs : EventArgs { }

	/// <summary>
	/// Long-press event args.
	/// </summary>
	public class LongPressEventArgs : EventArgs {
		public TextPosition CursorPosition { get; }
		public PointF LocationInEditor { get; }
		public LongPressEventArgs(TextPosition cursor, PointF point) { CursorPosition = cursor; LocationInEditor = point; }
	}

	/// <summary>
	/// Double-click selection event args.
	/// </summary>
	public class DoubleTapEventArgs : EventArgs {
		public TextPosition CursorPosition { get; }
		public bool HasSelection { get; }
		public TextRange? Selection { get; }
		public PointF LocationInEditor { get; }
		public DoubleTapEventArgs(TextPosition cursor, bool has, TextRange? sel, PointF point) {
			CursorPosition = cursor;
			HasSelection = has;
			Selection = sel;
			LocationInEditor = point;
		}
	}

	/// <summary>
	/// Context-menu event args.
	/// </summary>
	public class ContextMenuEventArgs : EventArgs {
		public TextPosition CursorPosition { get; }
		public PointF LocationInEditor { get; }
		public ContextMenuEventArgs(TextPosition cursor, PointF point) { CursorPosition = cursor; LocationInEditor = point; }
	}

	/// <summary>
	/// InlayHint click event args.
	/// </summary>
	public class InlayHintClickEventArgs : EventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Hit column (0-based)</summary>
		public int Column { get; }
		/// <summary>Inlay type.</summary>
		public InlayType Type { get; }
		/// <summary>Type-specific integer payload. Icon uses icon id, color uses ARGB, text uses 0.</summary>
		public int IntValue { get; }
		/// <summary>Pointer location in editor coordinates.</summary>
		public PointF LocationInEditor { get; }
		public InlayHintClickEventArgs(int line, int column, InlayType type, int intValue, PointF point) {
			Line = line;
			Column = column;
			Type = type;
			IntValue = intValue;
			LocationInEditor = point;
		}
	}

	/// <summary>
	/// GutterIcon click event args.
	/// </summary>
	public class GutterIconClickEventArgs : EventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Icon ID</summary>
		public int IconId { get; }
		/// <summary>Pointer location in editor coordinates.</summary>
		public PointF LocationInEditor { get; }
		public GutterIconClickEventArgs(int line, int iconId, PointF point) {
			Line = line;
			IconId = iconId;
			LocationInEditor = point;
		}
	}

	/// <summary>
	/// Fold region click event args (toggleFold is already executed by the C++ layer).
	/// </summary>
	public class FoldToggleEventArgs : EventArgs {
		/// <summary>Line index of the fold region (0-based).</summary>
		public int Line { get; }
		/// <summary>Whether the click hit the gutter fold arrow (false means the fold placeholder was clicked).</summary>
		public bool IsGutter { get; }
		/// <summary>Pointer location in editor coordinates.</summary>
		public PointF LocationInEditor { get; }
		public FoldToggleEventArgs(int line, bool isGutter, PointF point) {
			Line = line;
			IsGutter = isGutter;
			LocationInEditor = point;
		}
	}

	/// <summary>
	/// CodeLens click event args.
	/// </summary>
	public class CodeLensClickEventArgs : EventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Column anchor of the clicked CodeLens (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Command ID (from CodeLensItem)</summary>
		public int CommandId { get; }
		/// <summary>Pointer location in editor coordinates.</summary>
		public PointF LocationInEditor { get; }
		public CodeLensClickEventArgs(int line, int column, int commandId, PointF point) {
			Line = line;
			Column = column;
			CommandId = commandId;
			LocationInEditor = point;
		}
	}

	/// <summary>
	/// Link click event args.
	/// </summary>
	public class LinkClickEventArgs : EventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Column anchor of the clicked link (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Link target string resolved by the native core.</summary>
		public string Target { get; }
		/// <summary>Pointer location in editor coordinates.</summary>
		public PointF LocationInEditor { get; }
		public LinkClickEventArgs(int line, int column, string target, PointF point) {
			Line = line;
			Column = column;
			Target = target ?? string.Empty;
			LocationInEditor = point;
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
		/// <summary>Whether gutter stays fixed during horizontal scroll.</summary>
		[JsonPropertyName("gutter_sticky")]
		public bool GutterSticky { get; set; }
		/// <summary>Whether gutter area is visible.</summary>
		[JsonPropertyName("gutter_visible")]
		public bool GutterVisible { get; set; }
		/// <summary>Pointer cursor type hint for the current mouse location.</summary>
		[JsonPropertyName("pointer_cursor_type")]
		public PointerCursorType PointerCursorType { get; set; }
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
		/// <summary>Whether the thumb is currently being dragged.</summary>
		[JsonPropertyName("thumb_active")]
		public bool ThumbActive { get; set; }
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
		/// <summary>Resolved keymap command id.</summary>
		[JsonPropertyName("command")]
		public int Command { get; set; }
	}

	/// <summary>
	/// Native method entry points for the WinForms platform, centralized management of all P/Invoke declarations.
	/// </summary>
	internal static class NativeMethods {
		private const string LibraryName = "sweeteditor.dll";

		[DllImport(LibraryName, EntryPoint = "create_document_from_utf16", CharSet = CharSet.Unicode, CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CreateDocument(string text);

		[DllImport(LibraryName, EntryPoint = "free_document", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeDocument(IntPtr documentHandle);

		[DllImport(LibraryName, EntryPoint = "get_document_line_utf16", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetDocumentLineText(IntPtr documentHandle, UIntPtr line);

		[DllImport(LibraryName, EntryPoint = "get_document_utf8", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetDocumentText(IntPtr documentHandle);

		[DllImport(LibraryName, EntryPoint = "get_document_line_count", CallingConvention = CallingConvention.Cdecl)]
		internal static extern UIntPtr GetDocumentLineCount(IntPtr documentHandle);

		[DllImport(LibraryName, EntryPoint = "init_unhandled_exception_handler", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void InitUnhandledExceptionHandler();

		[DllImport(LibraryName, EntryPoint = "create_editor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CreateEditor(EditorCore.TextMeasurer measurer, byte[] optionsData, UIntPtr optionsSize);

		[DllImport(LibraryName, EntryPoint = "free_editor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeEditor(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "set_editor_document", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetEditorDocument(IntPtr handle, IntPtr documentHandle);

		[DllImport(LibraryName, EntryPoint = "set_editor_viewport", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetViewport(IntPtr handle, int width, int height);

		[DllImport(LibraryName, EntryPoint = "editor_on_font_metrics_changed", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void OnFontMetricsChanged(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_fold_arrow_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetFoldArrowMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_set_wrap_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetWrapMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_set_tab_size", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetTabSize(IntPtr handle, int tabSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_insert_spaces", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetInsertSpaces(IntPtr handle, int enabled);

		[DllImport(LibraryName, EntryPoint = "editor_set_scale", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetScale(IntPtr handle, float scale);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spacing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineSpacing(IntPtr handle, float add, float mult);

		[DllImport(LibraryName, EntryPoint = "editor_set_content_start_padding", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetContentStartPadding(IntPtr handle, float padding);

		[DllImport(LibraryName, EntryPoint = "editor_set_show_split_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetShowSplitLine(IntPtr handle, int show);

		[DllImport(LibraryName, EntryPoint = "editor_set_gutter_sticky", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetGutterSticky(IntPtr handle, int sticky);

		[DllImport(LibraryName, EntryPoint = "editor_set_gutter_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetGutterVisible(IntPtr handle, int visible);

		[DllImport(LibraryName, EntryPoint = "editor_set_current_line_render_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetCurrentLineRenderMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "build_editor_render_model", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr BuildRenderModel(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "get_layout_metrics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetLayoutMetrics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "handle_editor_gesture_event_ex", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr HandleGestureEventEx(IntPtr handle, uint type, uint pointerCount, float[] points,
			byte modifiers, float wheelDeltaX, float wheelDeltaY, float directScale, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_edge_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickEdgeScroll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_fling", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickFling(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_animations", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickAnimations(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "handle_editor_key_event", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr HandleKeyEvent(IntPtr handle, ushort keyCode, [MarshalAs(UnmanagedType.LPUTF8Str)] string? text, byte modifiers, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_keymap", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetKeyMap(IntPtr handle, byte[] data, UIntPtr size);

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

		[DllImport(LibraryName, EntryPoint = "editor_is_composing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsComposing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_get_composing_range", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetComposingRange(IntPtr handle, ref int outStartLine, ref int outStartColumn, ref int outEndLine, ref int outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_composing_session_range", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetComposingSessionRange(IntPtr handle, ref int outStartLine, ref int outStartColumn, ref int outEndLine, ref int outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_ime_update_preedit", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeUpdatePreedit(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, int scriptHint, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_commit_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeCommitText(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, int scriptHint, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_finish_preedit", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeFinishPreedit(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_cancel_preedit", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeCancelPreedit(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_mark_document_range", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeMarkDocumentRange(IntPtr handle, nuint startLine, nuint startColumn, nuint endLine, nuint endColumn, int scriptHint, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_replace_text", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeReplaceText(IntPtr handle, nuint startLine, nuint startColumn, nuint endLine, nuint endColumn, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, int scriptHint, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_delete_backward", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeDeleteBackward(IntPtr handle, nuint beforeLength, int textUnit, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_delete_forward", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeDeleteForward(IntPtr handle, nuint afterLength, int textUnit, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_delete_surrounding", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeDeleteSurrounding(IntPtr handle, nuint beforeLength, nuint afterLength, int textUnit, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_notify_selection_changed", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeNotifySelectionChanged(IntPtr handle, nuint startLine, nuint startColumn, nuint endLine, nuint endColumn, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_notify_cursor_changed", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeNotifyCursorChanged(IntPtr handle, nuint cursorLine, nuint cursorColumn, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_set_keyboard_script_class", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ImeSetKeyboardScriptClass(IntPtr handle, int scriptClass);

		[DllImport(LibraryName, EntryPoint = "editor_ime_get_keyboard_script_class", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int ImeGetKeyboardScriptClass(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_get_ime_sync_snapshot", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetImeSyncSnapshot(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetReadOnly(IntPtr handle, int readOnly);

		[DllImport(LibraryName, EntryPoint = "editor_is_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsReadOnly(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetAutoIndentMode(IntPtr handle, int mode);

		[DllImport(LibraryName, EntryPoint = "editor_get_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int GetAutoIndentMode(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_backspace_unindent", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBackspaceUnindent(IntPtr handle, int enabled);

		[DllImport(LibraryName, EntryPoint = "editor_set_handle_config", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetHandleConfig(IntPtr handle,
			float startLeft, float startTop, float startRight, float startBottom,
			float endLeft, float endTop, float endRight, float endBottom);

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

		[DllImport(LibraryName, EntryPoint = "editor_ensure_cursor_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void EnsureCursorVisible(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetScroll(IntPtr handle, float scrollX, float scrollY);

		[DllImport(LibraryName, EntryPoint = "editor_get_scroll_metrics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetScrollMetrics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_register_text_style", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void registerTextStyle(IntPtr handle, uint styleId, int color, int backgroundColor, int fontStyle);

		[DllImport(LibraryName, EntryPoint = "editor_register_batch_text_styles", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void registerBatchTextStyles(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineSpans(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearLineSpans(IntPtr handle, nuint line, byte layer);

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

		[DllImport(LibraryName, EntryPoint = "editor_set_line_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineCodeLens(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineCodeLens(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearCodeLens(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_links", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetLineLinks(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_links", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetBatchLineLinks(IntPtr handle, byte[] data, nuint size);

		[DllImport(LibraryName, EntryPoint = "editor_clear_links", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void ClearLinks(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_get_link_target_at", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetLinkTargetAt(IntPtr handle, nuint line, nuint column);

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

		[DllImport(LibraryName, EntryPoint = "editor_get_visible_line_range", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetVisibleLineRange(IntPtr handle, out int outStartLine, out int outEndLine);

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

		[DllImport(LibraryName, EntryPoint = "editor_set_auto_closing_pairs", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void SetAutoClosingPairs(IntPtr handle, int[] openChars, int[] closeChars, nuint count);

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

		[DllImport(LibraryName, EntryPoint = "free_u8_string", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeUtf8String(IntPtr cstringPtr);
	}

	/// <summary>
	/// Editor core that wraps high-level calls to the native C++ editor engine.
	/// Public methods on this wrapper are UI-thread-affine unless explicitly documented otherwise.
	/// </summary>
	public class EditorCore : IDisposable {
		private static bool exceptionHandlerInitialized = false;
		private IntPtr nativeHandle;
		private TextMeasurer measurer;
		private HandleConfig _handleConfig = new HandleConfig();
		private ScrollbarConfig _scrollbarConfig = new ScrollbarConfig();
		private bool _backspaceUnindent = true;
		private GCHandle textMeasurerGCHandle;
		private GCHandle inlayHintMeasurerGCHandle;
		private GCHandle iconMeasurerGCHandle;
		private GCHandle fontMetricsGCHandle;
		private Document? currentDocument;
		private bool disposed;
		private bool IsReleased => disposed || nativeHandle == IntPtr.Zero;

		private static void LogIgnoredCall(string method, string reason) {
			Debug.WriteLine($"[SweetEditor] Ignored {method}: {reason}.");
		}

		#region Lifecycle

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
			if (IsReleased) return;
			if (document == null) {
				LogIgnoredCall(nameof(LoadDocument), "document is null");
				return;
			}
			if (document.nativeHandle == IntPtr.Zero) {
				LogIgnoredCall(nameof(LoadDocument), "document handle is invalid");
				return;
			}
			currentDocument = document;
			NativeMethods.SetEditorDocument(nativeHandle, document.nativeHandle);
		}

		/// <summary>Gets the currently loaded document instance.</summary>
		public Document? GetDocument() => IsReleased ? null : currentDocument;

		/// <summary>Releases unmanaged resources.</summary>
		~EditorCore() {
			Dispose(false);
		}

		public void Dispose() {
			Dispose(true);
			GC.SuppressFinalize(this);
		}

		private void Dispose(bool disposing) {
			if (disposed) return;
			disposed = true;
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
			if (nativeHandle != IntPtr.Zero) {
				NativeMethods.FreeEditor(nativeHandle);
				nativeHandle = IntPtr.Zero;
			}
			currentDocument = null;
		}

		#endregion

		#region View And Rendering

		/// <summary>Sets editor viewport size.</summary>
		/// <param name="width">Viewport width (pixels).</param>
		/// <param name="height">Viewport height (pixels).</param>
		public void SetViewport(int width, int height) {
			if (IsReleased) return;
			NativeMethods.SetViewport(nativeHandle, width, height);
		}

		/// <summary>Notifies the editor that font metrics have changed (call after font/scale/DPI changes).</summary>
		public void OnFontMetricsChanged() {
			if (IsReleased) return;
			NativeMethods.OnFontMetricsChanged(nativeHandle);
		}

		/// <summary>Sets fold-arrow display mode.</summary>
		/// <param name="mode">Mode value (0=AUTO, 1=ALWAYS, 2=HIDDEN)</param>
		public void SetFoldArrowMode(int mode) {
			if (IsReleased) return;
			NativeMethods.SetFoldArrowMode(nativeHandle, mode);
		}

		/// <summary>Sets auto-wrap mode.</summary>
		/// <param name="mode">Mode value (0=NONE, 1=CHAR_BREAK, 2=WORD_BREAK)</param>
		public void SetWrapMode(int mode) {
			if (IsReleased) return;
			NativeMethods.SetWrapMode(nativeHandle, mode);
		}

		/// <summary>Sets tab size (number of spaces per tab stop).</summary>
		/// <param name="tabSize">Tab size (default 4, minimum 1).</param>
		public void SetTabSize(int tabSize) {
			if (IsReleased) return;
			NativeMethods.SetTabSize(nativeHandle, tabSize);
		}

		/// <summary>Sets whether pressing Tab inserts spaces instead of a tab character.</summary>
		public void SetInsertSpaces(bool enabled) {
			if (IsReleased) return;
			NativeMethods.SetInsertSpaces(nativeHandle, enabled ? 1 : 0);
		}

		/// <summary>Sets editor scale factor.</summary>
		/// <param name="scale">Scale factor (1.0 = 100%).</param>
		public void SetScale(float scale) {
			if (IsReleased) return;
			NativeMethods.SetScale(nativeHandle, scale);
		}

		/// <summary>Sets line spacing.</summary>
		/// <param name="add">Additional line spacing (pixels).</param>
		/// <param name="mult">Line spacing multiplier</param>
		public void SetLineSpacing(float add, float mult) {
			if (IsReleased) return;
			NativeMethods.SetLineSpacing(nativeHandle, add, mult);
		}

		/// <summary>Sets extra horizontal padding between gutter split and text content start.</summary>
		/// <param name="padding">Padding in pixels (clamped to &gt;= 0 on native side).</param>
		public void SetContentStartPadding(float padding) {
			if (IsReleased) return;
			NativeMethods.SetContentStartPadding(nativeHandle, padding);
		}

		/// <summary>Sets whether gutter split line should be rendered.</summary>
		/// <param name="show">true=show, false=hide.</param>
		public void SetShowSplitLine(bool show) {
			if (IsReleased) return;
			NativeMethods.SetShowSplitLine(nativeHandle, show ? 1 : 0);
		}

		/// <summary>Sets whether gutter stays fixed during horizontal scroll.</summary>
		/// <param name="sticky">true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style).</param>
		public void SetGutterSticky(bool sticky) {
			if (IsReleased) return;
			NativeMethods.SetGutterSticky(nativeHandle, sticky ? 1 : 0);
		}

		/// <summary>Sets whether gutter area is visible.</summary>
		/// <param name="visible">true=show gutter, false=hide entire gutter.</param>
		public void SetGutterVisible(bool visible) {
			if (IsReleased) return;
			NativeMethods.SetGutterVisible(nativeHandle, visible ? 1 : 0);
		}

		/// <summary>Sets current line render mode.</summary>
		/// <param name="mode">BACKGROUND(fill), BORDER(stroke), or NONE(disabled).</param>
		public void SetCurrentLineRenderMode(CurrentLineRenderMode mode) {
			if (IsReleased) return;
			NativeMethods.SetCurrentLineRenderMode(nativeHandle, (int)mode);
		}

		/// <summary>
		/// Builds the render model (calls the C++ layout engine and returns visual data for the visible area).
		/// </summary>
		/// <returns>Editor render model.</returns>
		public EditorRenderModel BuildRenderModel() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.BuildRenderModel(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseRenderModel(payloadPtr, payloadSize);
		}

		/// <summary>Gets layout metrics from the native layout engine.</summary>
		public LayoutMetrics GetLayoutMetrics() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.GetLayoutMetrics(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseLayoutMetrics(payloadPtr, payloadSize);
		}

		#endregion

		#region Input

		/// <summary>Handles gesture events (touch/mouse/wheel, etc.).</summary>
		/// <param name="gestureEvent">Gesture event data.</param>
		/// <returns>Gesture recognition result.</returns>
		public GestureResult HandleGestureEvent(GestureEvent gestureEvent) {
			return HandleGestureEventEx(gestureEvent);
		}

		/// <summary>Handles gesture events using the extended gesture protocol entry point.</summary>
		/// <param name="gestureEvent">Gesture event data.</param>
		/// <returns>Gesture recognition result.</returns>
		public GestureResult HandleGestureEventEx(GestureEvent gestureEvent) {
			if (IsReleased) return default;
			float[] pointsArr = gestureEvent.GetPointsArray();
			IntPtr payloadPtr = NativeMethods.HandleGestureEventEx(nativeHandle, (uint)gestureEvent.Type,
				(uint)(gestureEvent.Points?.Count ?? 0), pointsArr,
				(byte)gestureEvent.Modifiers, gestureEvent.WheelDeltaX, gestureEvent.WheelDeltaY, gestureEvent.DirectScale,
				out UIntPtr payloadSize);
			return ProtocolDecoder.ParseGestureResult(payloadPtr, payloadSize);
		}

		/// <summary>Advances edge-scroll by one tick and returns an updated gesture result.</summary>
		public GestureResult TickEdgeScroll() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.TickEdgeScroll(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseGestureResult(payloadPtr, payloadSize);
		}

		/// <summary>Advances fling animation by one tick and returns an updated gesture result.</summary>
		public GestureResult TickFling() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.TickFling(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseGestureResult(payloadPtr, payloadSize);
		}

		/// <summary>Unified animation tick: advances all active animations (edge-scroll, fling).</summary>
		public GestureResult TickAnimations() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.TickAnimations(nativeHandle, out UIntPtr payloadSize);
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
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.HandleKeyEvent(nativeHandle, keyCode, text, modifiers, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseKeyEventResult(payloadPtr, payloadSize);
		}

		/// <summary>Replaces the current keymap with the provided binding table.</summary>
		public void SetKeyMap(KeyMap keyMap) {
			if (nativeHandle == IntPtr.Zero) return;
			if (keyMap == null) {
				LogIgnoredCall(nameof(SetKeyMap), "keyMap is null");
				return;
			}
			byte[] payload = PackKeyMap(keyMap);
			NativeMethods.SetKeyMap(nativeHandle, payload, (UIntPtr)payload.Length);
		}

		#endregion

		#region Editing And Navigation

		/// <summary>Inserts text at the caret position.</summary>
		/// <param name="text">Text to insert</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public TextEditResult InsertText(string text) {
			if (IsReleased || text == null) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.InsertText(nativeHandle, text, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Replaces text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to replace.</param>
		/// <param name="newText">New replacement text</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public TextEditResult ReplaceText(TextRange range, string newText) {
			if (IsReleased || newText == null) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.ReplaceText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, newText, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to delete.</param>
		/// <returns>Edit result.</returns>
		public TextEditResult DeleteText(TextRange range) {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.DeleteText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character backward (Backspace).</summary>
		/// <returns>Edit result.</returns>
		public TextEditResult Backspace() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.Backspace(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character forward (Delete key).</summary>
		/// <returns>Edit result.</returns>
		public TextEditResult DeleteForward() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.DeleteForward(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) up by one line.</summary>
		public TextEditResult MoveLineUp() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.MoveLineUp(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) down by one line.</summary>
		public TextEditResult MoveLineDown() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.MoveLineDown(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) upward.</summary>
		public TextEditResult CopyLineUp() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.CopyLineUp(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) downward.</summary>
		public TextEditResult CopyLineDown() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.CopyLineDown(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes the current line (or all selected lines).</summary>
		public TextEditResult DeleteLine() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.DeleteLine(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line above the current line.</summary>
		public TextEditResult InsertLineAbove() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.InsertLineAbove(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line below the current line.</summary>
		public TextEditResult InsertLineBelow() {
			if (IsReleased) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.InsertLineBelow(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Gets the currently selected text.</summary>
		/// <returns>Selected text; returns empty string when there is no selection.</returns>
		public string GetSelectedText() {
			if (IsReleased) return "";
			IntPtr ptr = NativeMethods.GetSelectedText(nativeHandle);
			if (ptr == IntPtr.Zero) return "";
			string text = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return text;
		}

		/// <summary>Performs undo.</summary>
		/// <returns>Edit result; null means there is nothing to undo.</returns>
		public TextEditResult? Undo() {
			if (IsReleased) return null;
			IntPtr payloadPtr = NativeMethods.Undo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Performs redo.</summary>
		/// <returns>Edit result; null means there is nothing to redo.</returns>
		public TextEditResult? Redo() {
			if (IsReleased) return null;
			IntPtr payloadPtr = NativeMethods.Redo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Whether undo is available.</summary>
		/// <returns>Returns <c>true</c> if undo is available.</returns>
		public bool CanUndo() {
			if (IsReleased) return false;
			return NativeMethods.CanUndo(nativeHandle) != 0;
		}

		/// <summary>Whether redo is available.</summary>
		/// <returns>Returns <c>true</c> if redo is available.</returns>
		public bool CanRedo() {
			if (IsReleased) return false;
			return NativeMethods.CanRedo(nativeHandle) != 0;
		}

		/// <summary>Sets caret position (without scrolling viewport).</summary>
		/// <param name="position">Target position</param>
		public void SetCursorPosition(TextPosition position) {
			if (IsReleased) return;
			NativeMethods.SetCursorPosition(nativeHandle, (nuint)position.Line, (nuint)position.Column);
		}

		/// <summary>Gets current caret position.</summary>
		/// <returns>Caret line/column position.</returns>
		public TextPosition GetCursorPosition() {
			if (IsReleased) return default;
			nuint line = 0, column = 0;
			NativeMethods.GetCursorPosition(nativeHandle, ref line, ref column);
			return new TextPosition { Line = (int)line, Column = (int)column };
		}

		/// <summary>Gets the text range of the word at the caret.</summary>
		/// <returns>Word line/column range.</returns>
		public TextRange GetWordRangeAtCursor() {
			if (IsReleased) return default;
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
			if (IsReleased) return "";
			IntPtr ptr = NativeMethods.GetWordAtCursor(nativeHandle);
			if (ptr == IntPtr.Zero) return "";
			string text = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return text;
		}

		/// <summary>Sets text selection.</summary>
		/// <param name="startLine">Selection start line (0-based).</param>
		/// <param name="startColumn">Selection start column (0-based).</param>
		/// <param name="endLine">Selection end line (0-based).</param>
		/// <param name="endColumn">Selection end column (0-based).</param>
		public void SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			if (IsReleased) return;
			NativeMethods.SetSelection(nativeHandle, startLine, startColumn, endLine, endColumn);
		}

		/// <summary>Gets current selection range.</summary>
		/// <returns>Tuple: whether selection exists and the selection range.</returns>
		public (bool hasSelection, TextRange range) GetSelection() {
			if (IsReleased) return (false, default);
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
			if (IsReleased) return;
			NativeMethods.SelectAll(nativeHandle);
		}

		/// <summary>Moves caret left.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorLeft(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorLeft(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret right.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorRight(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorRight(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret up.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorUp(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorUp(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret down.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorDown(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorDown(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret to line start.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorToLineStart(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorToLineStart(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Moves caret to line end.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public void MoveCursorToLineEnd(bool extendSelection = false) {
			if (IsReleased) return;
			NativeMethods.MoveCursorToLineEnd(nativeHandle, extendSelection ? 1 : 0);
		}

		/// <summary>Whether visible IME composition is currently active.</summary>
		/// <returns>Returns <c>true</c> when IME composition is active.</returns>
		public bool IsComposing() {
			if (IsReleased) return false;
			return NativeMethods.IsComposing(nativeHandle) != 0;
		}

		/// <summary>Gets the visible IME composition range.</summary>
		public TextRange? GetComposingRange() {
			if (IsReleased) return null;
			int startLine = -1;
			int startColumn = -1;
			int endLine = -1;
			int endColumn = -1;
			NativeMethods.GetComposingRange(nativeHandle, ref startLine, ref startColumn, ref endLine, ref endColumn);
			return CreateOptionalRange(startLine, startColumn, endLine, endColumn);
		}

		/// <summary>Gets the active IME composition session range.</summary>
		public TextRange? GetComposingSessionRange() {
			if (IsReleased) return null;
			int startLine = -1;
			int startColumn = -1;
			int endLine = -1;
			int endColumn = -1;
			NativeMethods.GetComposingSessionRange(nativeHandle, ref startLine, ref startColumn, ref endLine, ref endColumn);
			return CreateOptionalRange(startLine, startColumn, endLine, endColumn);
		}

		/// <summary>Updates platform IME preedit text.</summary>
		public ImeActionResult UpdateImePreedit(string? text, ImeScriptClass scriptHint = ImeScriptClass.UNKNOWN) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeUpdatePreedit(nativeHandle, text ?? string.Empty, (int)scriptHint, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Commits platform IME text.</summary>
		public ImeActionResult CommitImeText(string? text, ImeScriptClass scriptHint = ImeScriptClass.UNKNOWN) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeCommitText(nativeHandle, text ?? string.Empty, (int)scriptHint, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Finishes the current platform IME preedit.</summary>
		public ImeActionResult FinishImePreedit() {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeFinishPreedit(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Cancels the current platform IME preedit.</summary>
		public ImeActionResult CancelImePreedit() {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeCancelPreedit(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Marks a document range explicitly reported by the platform IME.</summary>
		public ImeActionResult MarkImeDocumentRange(TextRange range, ImeScriptClass scriptHint = ImeScriptClass.UNKNOWN) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeMarkDocumentRange(nativeHandle,
				ToNativeSize(range.Start.Line), ToNativeSize(range.Start.Column),
				ToNativeSize(range.End.Line), ToNativeSize(range.End.Column),
				(int)scriptHint, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Replaces text through an explicit platform IME replacement request.</summary>
		public ImeActionResult ReplaceImeText(TextRange range, string? text, ImeScriptClass scriptHint = ImeScriptClass.UNKNOWN) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeReplaceText(nativeHandle,
				ToNativeSize(range.Start.Line), ToNativeSize(range.Start.Column),
				ToNativeSize(range.End.Line), ToNativeSize(range.End.Column),
				text ?? string.Empty, (int)scriptHint, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes text before the caret through IME semantics.</summary>
		public ImeActionResult DeleteImeBackward(int beforeLength = 1, ImeTextUnit textUnit = ImeTextUnit.UTF16_CODE_UNIT) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeDeleteBackward(nativeHandle, ToNativeSize(beforeLength), (int)textUnit, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes text after the caret through IME semantics.</summary>
		public ImeActionResult DeleteImeForward(int afterLength = 1, ImeTextUnit textUnit = ImeTextUnit.UTF16_CODE_UNIT) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeDeleteForward(nativeHandle, ToNativeSize(afterLength), (int)textUnit, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Deletes surrounding text through IME semantics.</summary>
		public ImeActionResult DeleteImeSurrounding(int beforeLength, int afterLength, ImeTextUnit textUnit = ImeTextUnit.UTF16_CODE_UNIT) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeDeleteSurrounding(nativeHandle, ToNativeSize(beforeLength), ToNativeSize(afterLength), (int)textUnit, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Notifies core about an IME-driven selection change.</summary>
		public ImeActionResult NotifyImeSelectionChanged(TextRange range) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeNotifySelectionChanged(nativeHandle,
				ToNativeSize(range.Start.Line), ToNativeSize(range.Start.Column),
				ToNativeSize(range.End.Line), ToNativeSize(range.End.Column),
				out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Notifies core about an IME-driven cursor change.</summary>
		public ImeActionResult NotifyImeCursorChanged(TextPosition cursor) {
			if (IsReleased) return new ImeActionResult();
			IntPtr payloadPtr = NativeMethods.ImeNotifyCursorChanged(nativeHandle,
				ToNativeSize(cursor.Line), ToNativeSize(cursor.Column), out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeActionResult(payloadPtr, payloadSize);
		}

		/// <summary>Sets the current IME keyboard script class.</summary>
		public void SetImeKeyboardScriptClass(ImeScriptClass scriptClass) {
			if (IsReleased) return;
			NativeMethods.ImeSetKeyboardScriptClass(nativeHandle, (int)scriptClass);
		}

		/// <summary>Gets the current IME keyboard script class.</summary>
		public ImeScriptClass GetImeKeyboardScriptClass() {
			if (IsReleased) return ImeScriptClass.UNKNOWN;
			int value = NativeMethods.ImeGetKeyboardScriptClass(nativeHandle);
			return Enum.IsDefined(typeof(ImeScriptClass), value) ? (ImeScriptClass)value : ImeScriptClass.UNKNOWN;
		}

		/// <summary>Gets the current IME synchronization snapshot.</summary>
		public ImeSyncSnapshot GetImeSyncSnapshot() {
			if (IsReleased) return new ImeSyncSnapshot();
			IntPtr payloadPtr = NativeMethods.GetImeSyncSnapshot(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseImeSyncSnapshot(payloadPtr, payloadSize);
		}

		private static TextRange? CreateOptionalRange(int startLine, int startColumn, int endLine, int endColumn) {
			if (startLine < 0 || startColumn < 0 || endLine < 0 || endColumn < 0) return null;
			return new TextRange {
				Start = new TextPosition { Line = startLine, Column = startColumn },
				End = new TextPosition { Line = endLine, Column = endColumn }
			};
		}

		private static nuint ToNativeSize(int value) {
			return (nuint)Math.Max(0, value);
		}

		/// <summary>Sets read-only mode.</summary>
		/// <param name="readOnly">Whether read-only</param>
		public void SetReadOnly(bool readOnly) {
			if (IsReleased) return;
			NativeMethods.SetReadOnly(nativeHandle, readOnly ? 1 : 0);
		}

		/// <summary>Checks whether the editor is in read-only mode.</summary>
		/// <returns>Returns <c>true</c> when read-only.</returns>
		public bool IsReadOnly() {
			if (IsReleased) return false;
			return NativeMethods.IsReadOnly(nativeHandle) != 0;
		}

		/// <summary>Sets auto-indent mode.</summary>
		/// <param name="mode">Auto-indent mode</param>
		public void SetAutoIndentMode(int mode) {
			if (IsReleased) return;
			NativeMethods.SetAutoIndentMode(nativeHandle, mode);
		}

		/// <summary>Gets current auto-indent mode.</summary>
		/// <returns>Auto-indent mode value (0=NONE, 1=KEEP_INDENT).</returns>
		public int GetAutoIndentMode() {
			if (IsReleased) return 0;
			return NativeMethods.GetAutoIndentMode(nativeHandle);
		}

		/// <summary>Sets backspace unindent behavior.</summary>
		public void SetBackspaceUnindent(bool enabled) {
			if (IsReleased) return;
			_backspaceUnindent = enabled;
			NativeMethods.SetBackspaceUnindent(nativeHandle, enabled ? 1 : 0);
		}

		/// <summary>Returns whether backspace unindent is enabled.</summary>
		public bool IsBackspaceUnindent() {
			return IsReleased ? false : _backspaceUnindent;
		}

		/// <summary>Sets the selection handle hit-test configuration.</summary>
		/// <param name="config">HandleConfig instance</param>
		public void SetHandleConfig(HandleConfig config) {
			if (IsReleased) return;
			if (config == null) {
				LogIgnoredCall(nameof(SetHandleConfig), "config is null");
				return;
			}
			_handleConfig = config;
			NativeMethods.SetHandleConfig(nativeHandle,
				config.StartLeft, config.StartTop, config.StartRight, config.StartBottom,
				config.EndLeft, config.EndTop, config.EndRight, config.EndBottom);
		}

		/// <summary>Gets the current handle configuration.</summary>
		public HandleConfig GetHandleConfig() {
			return IsReleased ? new HandleConfig() : _handleConfig;
		}

		/// <summary>Sets scrollbar geometry configuration.</summary>
		/// <param name="config">ScrollbarConfig instance</param>
		public void SetScrollbarConfig(ScrollbarConfig config) {
			if (IsReleased) return;
			if (config == null) {
				LogIgnoredCall(nameof(SetScrollbarConfig), "config is null");
				return;
			}
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
			return IsReleased ? new ScrollbarConfig() : _scrollbarConfig;
		}

		/// <summary>Gets the screen-space rectangle for any text position (for floating panel positioning).</summary>
		/// <param name="line">Line (0-based)</param>
		/// <param name="column">Column (0-based)</param>
		/// <returns>CursorRect; coordinates are relative to the top-left corner of the editor control.</returns>
		public CursorRect GetPositionRect(int line, int column) {
			if (IsReleased) return default;
			float x = 0, y = 0, h = 0;
			NativeMethods.GetPositionRect(nativeHandle, (nuint)line, (nuint)column, ref x, ref y, ref h);
			return new CursorRect { X = x, Y = y, Height = h };
		}

		/// <summary>Gets the screen-space rectangle for the current caret position (shortcut method).</summary>
		/// <returns>CursorRect; coordinates are relative to the top-left corner of the editor control.</returns>
		public CursorRect GetCursorRect() {
			if (IsReleased) return default;
			float x = 0, y = 0, h = 0;
			NativeMethods.GetCursorRect(nativeHandle, ref x, ref y, ref h);
			return new CursorRect { X = x, Y = y, Height = h };
		}

		/// <summary>Jumps to the specified line and column.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="column">Target column (0-based).</param>
		public void GotoPosition(int line, int column) {
			if (IsReleased) return;
			NativeMethods.GotoPosition(nativeHandle, line, column);
		}

		/// <summary>Scrolls minimally to keep the current caret visible inside the viewport.</summary>
		public void EnsureCursorVisible() {
			if (IsReleased) return;
			NativeMethods.EnsureCursorVisible(nativeHandle);
		}

		/// <summary>Scrolls to the specified line.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="behavior">Scroll alignment behavior (see <see cref="ScrollBehavior"/>).</param>
		public void ScrollToLine(int line, int behavior = (int)ScrollBehavior.CENTER) {
			if (IsReleased) return;
			NativeMethods.ScrollToLine(nativeHandle, line, (byte)behavior);
		}

		/// <summary>Manually sets scroll position (automatically clamped to valid range).</summary>
		/// <param name="scrollX">Horizontal scroll offset</param>
		/// <param name="scrollY">Vertical scroll offset</param>
		public void SetScroll(float scrollX, float scrollY) {
			if (IsReleased) return;
			NativeMethods.SetScroll(nativeHandle, scrollX, scrollY);
		}

		/// <summary>Gets scrollbar metrics (used by platform-side scrollbar rendering).</summary>
		public ScrollMetrics GetScrollMetrics() {
			if (IsReleased) return default;
			IntPtr payloadPtr = NativeMethods.GetScrollMetrics(nativeHandle, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseScrollMetrics(payloadPtr, payloadSize);
		}

		/// <summary>Gets the visible logical line range from the last completed layout pass.</summary>
		public IntRange GetVisibleLineRange() {
			if (IsReleased) return new IntRange(0, -1);
			NativeMethods.GetVisibleLineRange(nativeHandle, out int startLine, out int endLine);
			return new IntRange(startLine, endLine);
		}
		#endregion

		#region Decorations And Folding

		/// <summary>Registers a highlight style (with background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="backgroundColor">Background color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public void registerTextStyle(int styleId, int color, int backgroundColor, int fontStyle) {
			if (IsReleased) return;
			NativeMethods.registerTextStyle(nativeHandle, unchecked((uint)styleId), color, backgroundColor, fontStyle);
		}

		/// <summary>Registers a highlight style (without background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public void registerTextStyle(int styleId, int color, int fontStyle) {
			if (IsReleased) return;
			NativeMethods.registerTextStyle(nativeHandle, unchecked((uint)styleId), color, 0, fontStyle);
		}

		/// <summary>Registers multiple highlight styles in one native call.</summary>
		/// <param name="stylesById">Style definitions keyed by style ID.</param>
		public void registerBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById) {
			if (IsReleased || stylesById == null || stylesById.Count == 0) {
				return;
			}

			byte[] payload = ProtocolEncoder.PackBatchTextStyles(stylesById);
			if (payload.Length == 0) {
				return;
			}

			NativeMethods.registerBatchTextStyles(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets highlight spans for the specified line (model overload).</summary>
		public void SetLineSpans(int line, int layer, IList<StyleSpan> spans) {
			if (IsReleased || spans == null) return;
			byte[] payload = ProtocolEncoder.PackLineSpans(line, layer, spans);
			NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets highlight spans for the specified line (buffer overload, accepts pre-encoded data).</summary>
		public void SetLineSpans(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets highlight spans for multiple lines (model overload).</summary>
		public void SetBatchLineSpans(int layer, Dictionary<int, IList<StyleSpan>> spansByLine) {
			if (IsReleased || spansByLine == null || spansByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineSpans(layer, spansByLine);
			NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets highlight spans for multiple lines (buffer overload, accepts pre-encoded data).</summary>
		public void SetBatchLineSpans(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears highlight spans for the specified line and layer.</summary>
		public void ClearLineSpans(int line, int layer) {
			if (IsReleased) return;
			NativeMethods.ClearLineSpans(nativeHandle, (nuint)line, (byte)layer);
		}

		/// <summary>Sets Inlay Hints for the specified line (model overload, replaces whole line).</summary>
		public void SetLineInlayHints(int line, IList<InlayHint> hints) {
			if (IsReleased || hints == null) return;
			byte[] payload = ProtocolEncoder.PackLineInlayHints(line, hints);
			NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets Inlay Hints for the specified line (buffer overload).</summary>
		public void SetLineInlayHints(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (model overload).</summary>
		public void SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) {
			if (IsReleased || hintsByLine == null || hintsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineInlayHints(hintsByLine);
			NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (buffer overload).</summary>
		public void SetBatchLineInlayHints(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets ghost text for the specified line (model overload, replaces whole line).</summary>
		public void SetLinePhantomTexts(int line, IList<PhantomText> phantoms) {
			if (IsReleased || phantoms == null) return;
			byte[] payload = ProtocolEncoder.PackLinePhantomTexts(line, phantoms);
			NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets ghost text for the specified line (buffer overload).</summary>
		public void SetLinePhantomTexts(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets ghost text for multiple lines (model overload).</summary>
		public void SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) {
			if (IsReleased || phantomsByLine == null || phantomsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLinePhantomTexts(phantomsByLine);
			NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets ghost text for multiple lines (buffer overload).</summary>
		public void SetBatchLinePhantomTexts(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets gutter icons for the specified line (model overload, replaces whole line).</summary>
		public void SetLineGutterIcons(int line, IList<GutterIcon> icons) {
			if (IsReleased || icons == null) return;
			byte[] payload = ProtocolEncoder.PackLineGutterIcons(line, icons);
			NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets gutter icons for the specified line (buffer overload).</summary>
		public void SetLineGutterIcons(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets gutter icons for multiple lines (model overload).</summary>
		public void SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) {
			if (IsReleased || iconsByLine == null || iconsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineGutterIcons(iconsByLine);
			NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets gutter icons for multiple lines (buffer overload).</summary>
		public void SetBatchLineGutterIcons(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all gutter icons.</summary>
		public void ClearGutterIcons() {
			if (IsReleased) return;
			NativeMethods.ClearGutterIcons(nativeHandle);
		}

		/// <summary>Sets maximum icon count shown in the gutter.</summary>
		public void SetMaxGutterIcons(int count) {
			if (IsReleased) return;
			NativeMethods.SetMaxGutterIcons(nativeHandle, (uint)count);
		}

		/// <summary>Sets CodeLens items for the specified line (model overload).</summary>
		public void SetLineCodeLens(int line, IList<CodeLensItem> items) {
			if (IsReleased || items == null) return;
			byte[] payload = ProtocolEncoder.PackLineCodeLens(line, items);
			NativeMethods.SetLineCodeLens(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets CodeLens items for the specified line (buffer overload).</summary>
		public void SetLineCodeLens(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineCodeLens(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets CodeLens items for multiple lines (model overload).</summary>
		public void SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) {
			if (IsReleased || itemsByLine == null || itemsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineCodeLens(itemsByLine);
			NativeMethods.SetBatchLineCodeLens(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets CodeLens items for multiple lines (buffer overload).</summary>
		public void SetBatchLineCodeLens(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineCodeLens(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all CodeLens items.</summary>
		public void ClearCodeLens() {
			if (IsReleased) return;
			NativeMethods.ClearCodeLens(nativeHandle);
		}

		/// <summary>Sets link spans for the specified line (model overload).</summary>
		public void SetLineLinks(int line, IList<LinkSpan> links) {
			if (IsReleased || links == null) return;
			byte[] payload = ProtocolEncoder.PackLineLinks(line, links);
			NativeMethods.SetLineLinks(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets link spans for the specified line (buffer overload).</summary>
		public void SetLineLinks(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineLinks(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets link spans for multiple lines (model overload).</summary>
		public void SetBatchLineLinks(Dictionary<int, IList<LinkSpan>> linksByLine) {
			if (IsReleased || linksByLine == null || linksByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineLinks(linksByLine);
			NativeMethods.SetBatchLineLinks(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets link spans for multiple lines (buffer overload).</summary>
		public void SetBatchLineLinks(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineLinks(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all link spans.</summary>
		public void ClearLinks() {
			if (IsReleased) return;
			NativeMethods.ClearLinks(nativeHandle);
		}

		/// <summary>Gets the link target at the specified line and column.</summary>
		public string GetLinkTargetAt(int line, int column) {
			if (IsReleased) return "";
			IntPtr ptr = NativeMethods.GetLinkTargetAt(nativeHandle, (nuint)line, (nuint)column);
			if (ptr == IntPtr.Zero) return "";
			string target = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return target;
		}

		/// <summary>Sets diagnostic decorations for the specified line (model overload).</summary>
		public void SetLineDiagnostics(int line, IList<Diagnostic> items) {
			if (IsReleased || items == null) return;
			byte[] payload = ProtocolEncoder.PackLineDiagnostics(line, items);
			NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets diagnostic decorations for the specified line (buffer overload).</summary>
		public void SetLineDiagnostics(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (model overload).</summary>
		public void SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine) {
			if (IsReleased || diagsByLine == null || diagsByLine.Count == 0) return;
			byte[] payload = ProtocolEncoder.PackBatchLineDiagnostics(diagsByLine);
			NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (buffer overload).</summary>
		public void SetBatchLineDiagnostics(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all diagnostic decorations.</summary>
		public void ClearDiagnostics() {
			if (IsReleased) return;
			NativeMethods.ClearDiagnostics(nativeHandle);
		}

		/// <summary>Sets indent guide list (global replace, model overload).</summary>
		public void SetIndentGuides(IList<IndentGuide> guides) {
			if (IsReleased || guides == null) return;
			byte[] payload = ProtocolEncoder.PackIndentGuides(guides);
			NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets indent guide list (buffer overload).</summary>
		public void SetIndentGuides(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets bracket branch guide list (global replace, model overload).</summary>
		public void SetBracketGuides(IList<BracketGuide> guides) {
			if (IsReleased || guides == null) return;
			byte[] payload = ProtocolEncoder.PackBracketGuides(guides);
			NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets bracket branch guide list (buffer overload).</summary>
		public void SetBracketGuides(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets control-flow back-edge arrow list (global replace, model overload).</summary>
		public void SetFlowGuides(IList<FlowGuide> guides) {
			if (IsReleased || guides == null) return;
			byte[] payload = ProtocolEncoder.PackFlowGuides(guides);
			NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets control-flow back-edge arrow list (buffer overload).</summary>
		public void SetFlowGuides(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets horizontal separator list (global replace, model overload).</summary>
		public void SetSeparatorGuides(IList<SeparatorGuide> guides) {
			if (IsReleased || guides == null) return;
			byte[] payload = ProtocolEncoder.PackSeparatorGuides(guides);
			NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets horizontal separator list (buffer overload).</summary>
		public void SetSeparatorGuides(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Clears all code guide lines.</summary>
		public void ClearGuides() {
			if (IsReleased) return;
			NativeMethods.ClearGuides(nativeHandle);
		}

		/// <summary>Sets foldable region list (model overload).</summary>
		public void SetFoldRegions(IList<FoldRegion> regions) {
			if (IsReleased || regions == null) return;
			byte[] payload = ProtocolEncoder.PackFoldRegions(regions);
			NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Sets foldable region list (buffer overload).</summary>
		public void SetFoldRegions(byte[] payload) {
			if (IsReleased || payload == null) return;
			NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Toggles fold/unfold state of the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means a region was found and toggled.</returns>
		public bool ToggleFold(int line) {
			if (IsReleased) return false;
			return NativeMethods.ToggleFold(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Folds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means folding succeeded.</returns>
		public bool FoldAt(int line) {
			if (IsReleased) return false;
			return NativeMethods.FoldAt(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Unfolds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means unfolding succeeded.</returns>
		public bool UnfoldAt(int line) {
			if (IsReleased) return false;
			return NativeMethods.UnfoldAt(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Folds all regions.</summary>
		public void FoldAll() {
			if (IsReleased) return;
			NativeMethods.FoldAll(nativeHandle);
		}

		/// <summary>Unfolds all regions.</summary>
		public void UnfoldAll() {
			if (IsReleased) return;
			NativeMethods.UnfoldAll(nativeHandle);
		}

		/// <summary>Checks whether the specified line is visible (not hidden by folding).</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means visible.</returns>
		public bool IsLineVisible(int line) {
			if (IsReleased) return false;
			return NativeMethods.IsLineVisible(nativeHandle, (nuint)line) != 0;
		}

		/// <summary>Clears all highlight spans.</summary>
		public void ClearHighlights() {
			if (IsReleased) return;
			NativeMethods.ClearHighlights(nativeHandle);
		}

		/// <summary>Clears highlight spans in the specified layer.</summary>
		/// <param name="layer">Target layer (see <see cref="SpanLayer"/>).</param>
		public void ClearHighlights(int layer) {
			if (IsReleased) return;
			NativeMethods.ClearHighlightsLayer(nativeHandle, (byte)layer);
		}

		/// <summary>Clears all Inlay Hints.</summary>
		public void ClearInlayHints() {
			if (IsReleased) return;
			NativeMethods.ClearInlayHints(nativeHandle);
		}

		/// <summary>Clears all ghost text.</summary>
		public void ClearPhantomTexts() {
			if (IsReleased) return;
			NativeMethods.ClearPhantomTexts(nativeHandle);
		}

		/// <summary>Clears all decoration data (highlights, Inlay Hints, ghost text, icons, and guide lines).</summary>
		public void ClearAllDecorations() {
			if (IsReleased) return;
			NativeMethods.ClearAllDecorations(nativeHandle);
		}

		#endregion

		#region Linked Editing And Brackets

		/// <summary>Inserts a VSCode snippet template and enters linked editing mode.</summary>
		public TextEditResult InsertSnippet(string snippetTemplate) {
			if (IsReleased || snippetTemplate == null) return TextEditResult.Empty;
			IntPtr payloadPtr = NativeMethods.InsertSnippet(nativeHandle, snippetTemplate, out UIntPtr payloadSize);
			return ProtocolDecoder.ParseTextEditResult(payloadPtr, payloadSize);
		}

		/// <summary>Starts linked editing mode with a generic LinkedEditingModel.</summary>
		public void StartLinkedEditing(LinkedEditingModel model) {
			if (IsReleased || model == null) return;
			byte[] payload = ProtocolEncoder.PackLinkedEditingPayload(model);
			NativeMethods.StartLinkedEditing(nativeHandle, payload, (nuint)payload.Length);
		}

		/// <summary>Whether linked editing mode is active.</summary>
		public bool IsInLinkedEditing() {
			if (IsReleased) return false;
			return NativeMethods.IsInLinkedEditing(nativeHandle) != 0;
		}

		/// <summary>Linked editing: jump to next tab stop.</summary>
		public bool LinkedEditingNext() {
			if (IsReleased) return false;
			return NativeMethods.LinkedEditingNext(nativeHandle) != 0;
		}

		/// <summary>Linked editing: jump to previous tab stop.</summary>
		public bool LinkedEditingPrev() {
			if (IsReleased) return false;
			return NativeMethods.LinkedEditingPrev(nativeHandle) != 0;
		}

		/// <summary>Cancels linked editing mode.</summary>
		public void CancelLinkedEditing() {
			if (IsReleased) return;
			NativeMethods.CancelLinkedEditing(nativeHandle);
		}

		/// <summary>Sets custom bracket pair list.</summary>
		public void SetBracketPairs(int[] openChars, int[] closeChars) {
			if (IsReleased) return;
			if (openChars == null || closeChars == null) {
				LogIgnoredCall(nameof(SetBracketPairs), "openChars or closeChars is null");
				return;
			}
			if (openChars.Length != closeChars.Length) {
				LogIgnoredCall(nameof(SetBracketPairs), "openChars and closeChars length mismatch");
				return;
			}
			NativeMethods.SetBracketPairs(nativeHandle, openChars, closeChars, (nuint)openChars.Length);
		}

		/// <summary>Sets auto-closing pairs for automatic bracket completion.</summary>
		public void SetAutoClosingPairs(int[] openChars, int[] closeChars) {
			if (IsReleased) return;
			if (openChars == null || closeChars == null) {
				LogIgnoredCall(nameof(SetAutoClosingPairs), "openChars or closeChars is null");
				return;
			}
			if (openChars.Length != closeChars.Length) {
				LogIgnoredCall(nameof(SetAutoClosingPairs), "openChars and closeChars length mismatch");
				return;
			}
			NativeMethods.SetAutoClosingPairs(nativeHandle, openChars, closeChars, (nuint)openChars.Length);
		}

		/// <summary>Sets externally computed exact bracket pair positions (takes priority over built-in scanning).</summary>
		public void SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) {
			if (IsReleased) return;
			NativeMethods.SetMatchedBrackets(nativeHandle, (nuint)openLine, (nuint)openColumn, (nuint)closeLine, (nuint)closeColumn);
		}

		/// <summary>Clears externally supplied bracket match results (falls back to built-in scanning).</summary>
		public void ClearMatchedBrackets() {
			if (IsReleased) return;
			NativeMethods.ClearMatchedBrackets(nativeHandle);
		}

		private static byte[] PackKeyMap(KeyMap keyMap) {
			var bindings = keyMap.GetBindings();
			using var stream = new MemoryStream(4 + bindings.Count * 10);
			using var writer = new BinaryWriter(stream);
			writer.Write(bindings.Count);
			foreach (var entry in bindings) {
				KeyBinding binding = entry.Key;
				writer.Write((byte)binding.First.Modifiers);
				writer.Write((ushort)binding.First.KeyCode);
				writer.Write((byte)binding.Second.Modifiers);
				writer.Write((ushort)binding.Second.KeyCode);
				writer.Write(entry.Value);
			}
			writer.Flush();
			return stream.ToArray();
		}

		#endregion

	}
}
