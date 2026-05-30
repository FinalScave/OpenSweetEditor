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
		/// <param name="file">Source file.</param>
		public Document(FileInfo? file) : this(ReadTextFromFile(file)) {
		}

		/// <summary>
		/// Creates a document from a local file path.
		/// </summary>
		/// <param name="path">Source file path.</param>
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
			int lineCount = GetLineCount();
			if (lineCount <= 0) return "";
			int safeLine = Math.Clamp(line, 0, lineCount - 1);
			IntPtr ptr = NativeMethods.GetDocumentLineText(nativeHandle, (UIntPtr)safeLine);
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
			if (string.IsNullOrWhiteSpace(path) || !File.Exists(path)) {
				return "";
			}
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
			if (disposed) {
				return;
			}
			disposed = true;
			if (nativeHandle != IntPtr.Zero) {
				NativeMethods.FreeDocument(nativeHandle);
				nativeHandle = IntPtr.Zero;
			}
		}
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
		/// <summary>Document loaded.</summary>
		DocumentLoaded,
		/// <summary>Long press</summary>
		LongPress,
		/// <summary>Double-click select</summary>
		DoubleTap,
		/// <summary>Right click/context menu</summary>
		ContextMenu,
		/// <summary>GutterIcon Click</summary>
		GutterIconClick,
		/// <summary>CodeLens Click</summary>
		CodeLensClick,
		/// <summary>InlayHint Click</summary>
		InlayHintClick,
		/// <summary>Fold region click.</summary>
		FoldToggle,
		/// <summary>Custom selection menu item clicked.</summary>
		SelectionMenuItemClick,
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
	/// Text change event args.
	/// </summary>
	public class TextChangedEventArgs : EditorEventArgs {
		/// <summary>Operation type hint.</summary>
		public TextChangeAction Action { get; }
		/// <summary>Precise list of document changes.</summary>
		public IReadOnlyList<TextChange> Changes { get; }
		/// <summary>Compatibility alias: first change range when available.</summary>
		public TextRange? ChangeRange { get; }
		/// <summary>Compatibility alias: first change text when available.</summary>
		public string? Text { get; }

		public TextChangedEventArgs(TextChangeAction action, IReadOnlyList<TextChange>? changes = null)
			: base(EditorEventType.TextChanged) {
			Action = action;
			Changes = changes ?? Array.Empty<TextChange>();
			TextChange? first = Changes.Count > 0 ? Changes[0] : null;
			ChangeRange = first?.Range;
			Text = first?.Text;
		}

		public TextChangedEventArgs(TextChangeAction action, TextRange? changeRange, string? text)
			: this(action, changeRange == null && text == null
				? null
				: new[] { new TextChange { Range = changeRange, Text = text } }) {
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
		public TextRange? Selection { get; }
		public TextPosition CursorPosition { get; }
		public SelectionChangedEventArgs(bool has, TextRange? sel, TextPosition cursor)
			: base(EditorEventType.SelectionChanged) { HasSelection = has; Selection = has ? sel : null; CursorPosition = cursor; }
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
		public TextRange? Selection { get; }
		public PointF ScreenPoint { get; }
		public DoubleTapEventArgs(TextPosition cursor, bool has, TextRange? sel, PointF point)
			: base(EditorEventType.DoubleTap) { CursorPosition = cursor; HasSelection = has; Selection = has ? sel : null; ScreenPoint = point; }
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
		/// <summary>Inlay hint payload type.</summary>
		public InlayType Type { get; }
		/// <summary>Integer payload (icon id or color value, depending on <see cref="Type"/>).</summary>
		public int IntValue { get; }
		/// <summary>Optional text payload.</summary>
		public string? Text { get; }
		/// <summary>Compatibility alias for icon-type inlays.</summary>
		public int IconId => Type == InlayType.ICON ? IntValue : 0;
		/// <summary>Compatibility alias for color-type inlays.</summary>
		public int ColorValue => Type == InlayType.COLOR ? IntValue : 0;
		/// <summary>Compatibility alias.</summary>
		public bool IsIcon => Type == InlayType.ICON;
		/// <summary>Tap screen position</summary>
		public PointF ScreenPoint { get; }
		public InlayHintClickEventArgs(int line, int column, InlayType type, int intValue, string? text, PointF point)
			: base(EditorEventType.InlayHintClick) {
			Line = line; Column = column; Type = type; IntValue = intValue; Text = text; ScreenPoint = point;
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

	/// <summary>
	/// CodeLens click event args.
	/// </summary>
	public class CodeLensClickEventArgs : EditorEventArgs {
		/// <summary>Hit logical line (0-based)</summary>
		public int Line { get; }
		/// <summary>Column anchor of the clicked CodeLens (0-based, UTF-16 offset)</summary>
		public int Column { get; }
		/// <summary>Command ID (from <see cref="CodeLensItem"/>)</summary>
		public int CommandId { get; }
		/// <summary>Tap screen position</summary>
		public PointF ScreenPoint { get; }
		public CodeLensClickEventArgs(int line, int column, int commandId, PointF point)
			: base(EditorEventType.CodeLensClick) {
			Line = line; Column = column; CommandId = commandId; ScreenPoint = point;
		}
	}

	#endregion

	/// <summary>
	/// Native method entry points for the WinForms platform, centralized management of all P/Invoke declarations.
	/// </summary>
	internal static class NativeMethods {
		private const string LibraryName = "sweeteditor";

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

		[DllImport(LibraryName, EntryPoint = "editor_set_document", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetEditorDocument(IntPtr handle, IntPtr documentHandle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_viewport", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetViewport(IntPtr handle, int width, int height, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_on_font_metrics_changed", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr OnFontMetricsChanged(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_fold_arrow_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetFoldArrowMode(IntPtr handle, int mode, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_wrap_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetWrapMode(IntPtr handle, int mode, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_tab_size", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetTabSize(IntPtr handle, int tabSize, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_insert_spaces", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetInsertSpaces(IntPtr handle, int enabled, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_scale", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetScale(IntPtr handle, float scale, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spacing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineSpacing(IntPtr handle, float add, float mult, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_content_start_padding", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetContentStartPadding(IntPtr handle, float padding, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_show_split_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetShowSplitLine(IntPtr handle, int show, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_gutter_sticky", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetGutterSticky(IntPtr handle, int sticky, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_gutter_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetGutterVisible(IntPtr handle, int visible, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_current_line_render_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetCurrentLineRenderMode(IntPtr handle, int mode, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_keymap", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetKeyMap(IntPtr handle, byte[] payload, UIntPtr payloadSize, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_build_render_model", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr BuildRenderModel(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_handle_gesture_event", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr HandleGestureEvent(IntPtr handle, byte[] data, UIntPtr size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_update_pointer_modifiers", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr UpdatePointerModifiers(IntPtr handle, byte modifiers, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_edge_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickEdgeScroll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_fling", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickFling(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_tick_animations", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr TickAnimations(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_handle_key_event", CallingConvention = CallingConvention.Cdecl)]
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
		internal static extern IntPtr SetCursorPosition(IntPtr handle, nuint line, nuint column, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_cursor_position", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetCursorPosition(IntPtr handle, ref nuint outLine, ref nuint outColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_word_range_at_cursor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetWordRangeAtCursor(IntPtr handle, ref nuint outStartLine, ref nuint outStartColumn, ref nuint outEndLine, ref nuint outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_get_word_at_cursor", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetWordAtCursor(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_selection", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetSelection(IntPtr handle, int startLine, int startColumn, int endLine, int endColumn, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_selection", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int GetSelection(IntPtr handle, ref nuint outStartLine, ref nuint outStartColumn, ref nuint outEndLine, ref nuint outEndColumn);

		[DllImport(LibraryName, EntryPoint = "editor_select_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SelectAll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_left", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorLeft(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_right", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorRight(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_up", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorUp(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_down", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorDown(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_to_line_start", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorToLineStart(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_move_cursor_to_line_end", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr MoveCursorToLineEnd(IntPtr handle, int extendSelection, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_update_preedit", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeUpdatePreedit(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string text, int scriptHint, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ime_cancel_preedit", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ImeCancelPreedit(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_is_composing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsComposing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetReadOnly(IntPtr handle, int readOnly, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_is_read_only", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsReadOnly(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetAutoIndentMode(IntPtr handle, int mode, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_auto_indent_mode", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int GetAutoIndentMode(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_set_backspace_unindent", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBackspaceUnindent(IntPtr handle, int enabled, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_handle_config", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetHandleConfig(IntPtr handle, byte[] data, UIntPtr size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_scrollbar_config", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetScrollbarConfig(IntPtr handle, byte[] data, UIntPtr size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_position_rect", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetPositionRect(IntPtr handle, nuint line, nuint column, ref float outX, ref float outY, ref float outHeight);

		[DllImport(LibraryName, EntryPoint = "editor_get_cursor_rect", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void GetCursorRect(IntPtr handle, ref float outX, ref float outY, ref float outHeight);

		[DllImport(LibraryName, EntryPoint = "editor_scroll_to_line", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ScrollToLine(IntPtr handle, int line, byte behavior, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_goto_position", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GotoPosition(IntPtr handle, int line, int column, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_ensure_cursor_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr EnsureCursorVisible(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_scroll", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetScroll(IntPtr handle, float scrollX, float scrollY, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_scroll_metrics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetScrollMetrics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_get_layout_metrics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr GetLayoutMetrics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_register_text_style", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr registerTextStyle(IntPtr handle, uint styleId, int color, int backgroundColor, int fontStyle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_register_batch_text_styles", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr registerBatchTextStyles(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineSpans(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineInlayHints(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLinePhantomTexts(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineGutterIcons(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		// ===================== Batch APIs =====================

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLineSpans(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_line_spans", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearLineSpans(IntPtr handle, nuint line, byte layer, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLineInlayHints(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLinePhantomTexts(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLineGutterIcons(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineCodeLens(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLineCodeLens(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_codelens", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearCodeLens(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_batch_line_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBatchLineDiagnostics(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearGutterIcons(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_max_gutter_icons", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetMaxGutterIcons(IntPtr handle, uint count, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_line_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetLineDiagnostics(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_diagnostics", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearDiagnostics(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_indent_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetIndentGuides(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_bracket_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBracketGuides(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_flow_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetFlowGuides(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_separator_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetSeparatorGuides(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_guides", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearGuides(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_fold_regions", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetFoldRegions(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_toggle_fold", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ToggleFold(IntPtr handle, nuint line, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_fold_at", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr FoldAt(IntPtr handle, nuint line, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_unfold_at", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr UnfoldAt(IntPtr handle, nuint line, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_fold_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr FoldAll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_unfold_all", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr UnfoldAll(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_is_line_visible", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsLineVisible(IntPtr handle, nuint line);

		[DllImport(LibraryName, EntryPoint = "editor_clear_highlights", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearHighlights(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_highlights_layer", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearHighlightsLayer(IntPtr handle, byte layer, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_inlay_hints", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearInlayHints(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_phantom_texts", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearPhantomTexts(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_all_decorations", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearAllDecorations(IntPtr handle, out UIntPtr outSize);

		// ===================== BracketHighlight =====================

		[DllImport(LibraryName, EntryPoint = "editor_set_bracket_pairs", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetBracketPairs(IntPtr handle, int[] openChars, int[] closeChars, nuint count, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_set_matched_brackets", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr SetMatchedBrackets(IntPtr handle, nuint openLine, nuint openCol, nuint closeLine, nuint closeCol, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_clear_matched_brackets", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr ClearMatchedBrackets(IntPtr handle, out UIntPtr outSize);

		// ===================== LinkedEditing =====================

		[DllImport(LibraryName, EntryPoint = "editor_insert_snippet", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr InsertSnippet(IntPtr handle, [MarshalAs(UnmanagedType.LPUTF8Str)] string snippetTemplate, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_start_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr StartLinkedEditing(IntPtr handle, byte[] data, nuint size, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_is_in_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern int IsInLinkedEditing(IntPtr handle);

		[DllImport(LibraryName, EntryPoint = "editor_linked_editing_next", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr LinkedEditingNext(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_linked_editing_prev", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr LinkedEditingPrev(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "editor_cancel_linked_editing", CallingConvention = CallingConvention.Cdecl)]
		internal static extern IntPtr CancelLinkedEditing(IntPtr handle, out UIntPtr outSize);

		[DllImport(LibraryName, EntryPoint = "free_binary_data", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeBinaryData(IntPtr ptr);

		[DllImport(LibraryName, EntryPoint = "free_u16_string", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeUtf16String(IntPtr cstringPtr);

		[DllImport(LibraryName, EntryPoint = "free_u8_string", CallingConvention = CallingConvention.Cdecl)]
		internal static extern void FreeUtf8String(IntPtr cstringPtr);
	}

	/// <summary>
	/// Editor core that wraps high-level calls to the native C++ editor engine.
	/// </summary>
	public class EditorCore : IDisposable {
		private static bool exceptionHandlerInitialized = false;
		private static bool exceptionHandlerInitAttempted = false;
		private static readonly object exceptionHandlerInitLock = new object();
		private IntPtr nativeHandleValue;
		private IntPtr nativeHandle {
			get {
				if (disposed || nativeHandleValue == IntPtr.Zero) {
					throw new ObjectDisposedException(nameof(EditorCore));
				}
				return nativeHandleValue;
			}
			set => nativeHandleValue = value;
		}
		private TextMeasurer measurer;
		private HandleConfig _handleConfig = new HandleConfig();
		private ScrollbarConfig _scrollbarConfig = new ScrollbarConfig();
		private GCHandle textMeasurerGCHandle;
		private GCHandle inlayHintMeasurerGCHandle;
		private GCHandle iconMeasurerGCHandle;
		private GCHandle fontMetricsGCHandle;
		private Document? currentDocument;
		private bool insertSpaces;
		private bool backspaceUnindent;
		private bool compositionEnabled = true;
		private bool disposed;
		private IReadOnlyList<BracketPair> autoClosingPairs = Array.Empty<BracketPair>();

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
			EnsureExceptionHandlerInitialized();
			measurer = textMeasurer;
			textMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureTextWidth);
			inlayHintMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureInlayHintWidth);
			iconMeasurerGCHandle = GCHandle.Alloc(measurer.MeasureIconWidth);
			fontMetricsGCHandle = GCHandle.Alloc(measurer.GetFontMetrics);
			byte[] optionsData = CoreProtocol.EncodeEditorOptions(options);
			nativeHandle = NativeMethods.CreateEditor(measurer, optionsData, (UIntPtr)optionsData.Length);
			SetKeyMap(EditorKeyMap.DefaultKeyMap().Bindings);
		}


		private static void EnsureExceptionHandlerInitialized() {
			if (exceptionHandlerInitialized || exceptionHandlerInitAttempted) {
				return;
			}

			lock (exceptionHandlerInitLock) {
				if (exceptionHandlerInitialized || exceptionHandlerInitAttempted) {
					return;
				}

				try {
					NativeMethods.InitUnhandledExceptionHandler();
					exceptionHandlerInitialized = true;
				} catch (EntryPointNotFoundException) {
					// Older native builds may not expose this optional hook.
					exceptionHandlerInitialized = false;
				} finally {
					exceptionHandlerInitAttempted = true;
				}
			}
		}

		private delegate T NativePayloadDecoder<T>(ReadOnlySpan<byte> data);

		private static unsafe T DecodePayload<T>(IntPtr payloadPtr, UIntPtr payloadSize, NativePayloadDecoder<T> decoder, T emptyValue) {
			if (payloadPtr == IntPtr.Zero) {
				return emptyValue;
			}
			try {
				ulong length = payloadSize.ToUInt64();
				if (length > int.MaxValue) {
					throw new InvalidOperationException("Native payload is too large.");
				}
				ReadOnlySpan<byte> data = new(payloadPtr.ToPointer(), (int)length);
				return decoder(data);
			} finally {
				NativeMethods.FreeBinaryData(payloadPtr);
			}
		}

		private static EditorActionResult DecodeAction(IntPtr payloadPtr, UIntPtr payloadSize) {
			return DecodePayload(payloadPtr, payloadSize, CoreProtocol.DecodeEditorActionResult, EditorActionResult.Empty);
		}
		private static IReadOnlyList<T> ToReadOnlyList<T>(IEnumerable<T> values) {
			return values as IReadOnlyList<T> ?? values.ToArray();
		}

		private static IReadOnlyDictionary<int, IReadOnlyList<T>> ToReadOnlyLineMap<T>(IEnumerable<KeyValuePair<int, IList<T>>> values) {
			var map = new Dictionary<int, IReadOnlyList<T>>();
			foreach (KeyValuePair<int, IList<T>> entry in values) {
				map[entry.Key] = ToReadOnlyList(entry.Value);
			}
			return map;
		}

		private static IReadOnlyDictionary<int, IReadOnlyList<T>> ToReadOnlyLineMap<T>(IEnumerable<KeyValuePair<int, List<T>>> values) {
			var map = new Dictionary<int, IReadOnlyList<T>>();
			foreach (KeyValuePair<int, List<T>> entry in values) {
				map[entry.Key] = entry.Value;
			}
			return map;
		}


		/// <summary>Loads a document into the editor.</summary>
		/// <param name="document">Document object to load.</param>
		public EditorActionResult LoadDocument(Document document) {
			currentDocument = document;
			IntPtr payloadPtr = NativeMethods.SetEditorDocument(nativeHandle, document.nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Gets the currently loaded document instance.</summary>
		public Document? GetDocument() => currentDocument;

		private int ClampLineForNative(int line) {
			int lineCount = currentDocument?.GetLineCount() ?? 0;
			if (lineCount <= 0) {
				return 0;
			}
			return Math.Clamp(line, 0, lineCount - 1);
		}

		private (int Line, int Column) ClampPositionForNative(int line, int column) {
			int safeLine = ClampLineForNative(line);
			if (column <= 0) {
				return (safeLine, 0);
			}
			string lineText = currentDocument?.GetLineText(safeLine) ?? string.Empty;
			return (safeLine, Math.Min(column, lineText.Length));
		}

		/// <summary>Releases unmanaged resources.</summary>
		public void Dispose() {
			Dispose(true);
			GC.SuppressFinalize(this);
		}

		~EditorCore() {
			Dispose(false);
		}

		private void Dispose(bool disposing) {
			if (disposed) {
				return;
			}

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
			if (nativeHandleValue != IntPtr.Zero) {
				NativeMethods.FreeEditor(nativeHandleValue);
				nativeHandleValue = IntPtr.Zero;
			}
			currentDocument = null;
		}

		#endregion

		#region Viewport/font/appearance configuration

		/// <summary>Sets editor viewport size.</summary>
		/// <param name="width">Viewport width (pixels).</param>
		/// <param name="height">Viewport height (pixels).</param>
		public EditorActionResult SetViewport(int width, int height) {
			IntPtr payloadPtr = NativeMethods.SetViewport(nativeHandle, width, height, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Notifies the editor that font metrics have changed (call after font/scale/DPI changes).</summary>
		public EditorActionResult OnFontMetricsChanged() {
			IntPtr payloadPtr = NativeMethods.OnFontMetricsChanged(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets fold-arrow display mode.</summary>
		/// <param name="mode">Mode value (0=AUTO, 1=ALWAYS, 2=HIDDEN)</param>
		public EditorActionResult SetFoldArrowMode(int mode) {
			IntPtr payloadPtr = NativeMethods.SetFoldArrowMode(nativeHandle, mode, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets auto-wrap mode.</summary>
		/// <param name="mode">Mode value (0=NONE, 1=CHAR_BREAK, 2=WORD_BREAK)</param>
		public EditorActionResult SetWrapMode(int mode) {
			IntPtr payloadPtr = NativeMethods.SetWrapMode(nativeHandle, mode, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets tab size (number of spaces per tab stop).</summary>
		/// <param name="tabSize">Tab size (default 4, minimum 1).</param>
		public EditorActionResult SetTabSize(int tabSize) {
			IntPtr payloadPtr = NativeMethods.SetTabSize(nativeHandle, tabSize, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Controls whether indentation should insert spaces instead of a tab character.</summary>
		public EditorActionResult SetInsertSpaces(bool enabled) {
			insertSpaces = enabled;
			IntPtr payloadPtr = NativeMethods.SetInsertSpaces(nativeHandle, enabled ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public bool IsInsertSpaces() => insertSpaces;

		/// <summary>Sets the active auto-closing bracket pairs.</summary>
		public void SetAutoClosingPairs(IReadOnlyList<BracketPair>? pairs) {
			autoClosingPairs = pairs?.Where(p => p != null && !string.IsNullOrEmpty(p.Open) && !string.IsNullOrEmpty(p.Close)).ToArray() ?? Array.Empty<BracketPair>();
		}

		public IReadOnlyList<BracketPair> GetAutoClosingPairs() => autoClosingPairs;

		/// <summary>Controls whether backspace at indentation boundaries should unindent by one indent unit.</summary>
		public EditorActionResult SetBackspaceUnindent(bool enabled) {
			backspaceUnindent = enabled;
			IntPtr payloadPtr = NativeMethods.SetBackspaceUnindent(nativeHandle, enabled ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public bool IsBackspaceUnindent() => backspaceUnindent;

		/// <summary>Sets editor scale factor.</summary>
		/// <param name="scale">Scale factor (1.0 = 100%).</param>
		public EditorActionResult SetScale(float scale) {
			IntPtr payloadPtr = NativeMethods.SetScale(nativeHandle, scale, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets line spacing.</summary>
		/// <param name="add">Additional line spacing (pixels).</param>
		/// <param name="mult">Line spacing multiplier</param>
		public EditorActionResult SetLineSpacing(float add, float mult) {
			IntPtr payloadPtr = NativeMethods.SetLineSpacing(nativeHandle, add, mult, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets extra horizontal padding between gutter split and text content start.</summary>
		/// <param name="padding">Padding in pixels (clamped to &gt;= 0 on native side).</param>
		public EditorActionResult SetContentStartPadding(float padding) {
			IntPtr payloadPtr = NativeMethods.SetContentStartPadding(nativeHandle, padding, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets whether gutter split line should be rendered.</summary>
		/// <param name="show">true=show, false=hide.</param>
		public EditorActionResult SetShowSplitLine(bool show) {
			IntPtr payloadPtr = NativeMethods.SetShowSplitLine(nativeHandle, show ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets whether gutter stays fixed during horizontal scroll.</summary>
		/// <param name="sticky">true=gutter fixed (desktop style), false=gutter scrolls with content (mobile style).</param>
		public EditorActionResult SetGutterSticky(bool sticky) {
			IntPtr payloadPtr = NativeMethods.SetGutterSticky(nativeHandle, sticky ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets whether gutter area is visible.</summary>
		/// <param name="visible">true=show gutter, false=hide entire gutter.</param>
		public EditorActionResult SetGutterVisible(bool visible) {
			IntPtr payloadPtr = NativeMethods.SetGutterVisible(nativeHandle, visible ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets current line render mode.</summary>
		/// <param name="mode">BACKGROUND(fill), BORDER(stroke), or NONE(disabled).</param>
		public EditorActionResult SetCurrentLineRenderMode(CurrentLineRenderMode mode) {
			IntPtr payloadPtr = NativeMethods.SetCurrentLineRenderMode(nativeHandle, (int)mode, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Rendering

		/// <summary>
		/// Builds the render model (calls the C++ layout engine and returns visual data for the visible area).
		/// </summary>
		/// <returns>Editor render model.</returns>
		public EditorRenderModel BuildRenderModel() {
			IntPtr payloadPtr = NativeMethods.BuildRenderModel(nativeHandle, out UIntPtr payloadSize);
			return DecodePayload(payloadPtr, payloadSize, CoreProtocol.DecodeEditorRenderModel, new EditorRenderModel());
		}

		#endregion

		#region Gesture/keyboard event handling

		/// <summary>Handles gesture events (touch/mouse/wheel, etc.).</summary>
		/// <param name="gestureEvent">Gesture event data.</param>
		/// <returns>Gesture recognition result.</returns>
		public EditorActionResult HandleGestureEvent(GestureEvent gestureEvent) {
			byte[] payload = CoreProtocol.EncodeGestureEvent(gestureEvent);
			IntPtr payloadPtr = NativeMethods.HandleGestureEvent(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Refreshes pointer presentation after modifier keys change.</summary>
		public EditorActionResult UpdatePointerModifiers(byte modifiers) {
			IntPtr payloadPtr = NativeMethods.UpdatePointerModifiers(nativeHandle, modifiers, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Advances edge-scroll by one tick and returns an updated gesture result.</summary>
		public EditorActionResult TickEdgeScroll() {
			IntPtr payloadPtr = NativeMethods.TickEdgeScroll(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Advances fling by one tick and returns an updated gesture result.</summary>
		public EditorActionResult TickFling() {
			IntPtr payloadPtr = NativeMethods.TickFling(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Unified animation tick: advances all active animations (edge-scroll, fling).</summary>
		public EditorActionResult TickAnimations() {
			IntPtr payloadPtr = NativeMethods.TickAnimations(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>
		/// Handles keyboard events.
		/// </summary>
		/// <param name="keyCode">Virtual key code</param>
		/// <param name="text">Text mapped to the key (nullable).</param>
		/// <param name="modifiers">Modifier key flags</param>
		/// <returns>Keyboard event handling result.</returns>
		public EditorActionResult HandleKeyEvent(ushort keyCode, string? text, byte modifiers) {
			IntPtr payloadPtr = NativeMethods.HandleKeyEvent(nativeHandle, keyCode, text, modifiers, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>
		/// Replaces the current keymap and synchronizes the complete binding table to the native core.
		/// </summary>
		/// <param name="bindings">Key binding data.</param>
		public EditorActionResult SetKeyMap(IReadOnlyList<KeyBinding> bindings) {
			if (bindings == null) {
				throw new ArgumentNullException(nameof(bindings));
			}
			return SyncKeyMapToNative(bindings);
		}

		private EditorActionResult SyncKeyMapToNative(IReadOnlyList<KeyBinding> bindings) {
			byte[] payload = CoreProtocol.EncodeSetKeyMapPayload(bindings);
			IntPtr payloadPtr = NativeMethods.SetKeyMap(nativeHandle, payload, (UIntPtr)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Text editing

		/// <summary>Inserts text at the caret position.</summary>
		/// <param name="text">Text to insert</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public EditorActionResult InsertText(string text) {
			IntPtr payloadPtr = NativeMethods.InsertText(nativeHandle, text, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Replaces text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to replace.</param>
		/// <param name="newText">New replacement text</param>
		/// <returns>Edit result containing changed ranges and new text.</returns>
		public EditorActionResult ReplaceText(TextRange range, string newText) {
			IntPtr payloadPtr = NativeMethods.ReplaceText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, newText, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Deletes text in the specified range (atomic operation).</summary>
		/// <param name="range">Text range to delete.</param>
		/// <returns>Edit result.</returns>
		public EditorActionResult DeleteText(TextRange range) {
			IntPtr payloadPtr = NativeMethods.DeleteText(nativeHandle,
				range.Start.Line, range.Start.Column,
				range.End.Line, range.End.Column, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character backward (Backspace).</summary>
		/// <returns>Edit result.</returns>
		public EditorActionResult Backspace() {
			IntPtr payloadPtr = NativeMethods.Backspace(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Deletes one character forward (Delete key).</summary>
		/// <returns>Edit result.</returns>
		public EditorActionResult DeleteForward() {
			IntPtr payloadPtr = NativeMethods.DeleteForward(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) up by one line.</summary>
		public EditorActionResult MoveLineUp() {
			IntPtr payloadPtr = NativeMethods.MoveLineUp(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves the current line (or selected lines) down by one line.</summary>
		public EditorActionResult MoveLineDown() {
			IntPtr payloadPtr = NativeMethods.MoveLineDown(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) upward.</summary>
		public EditorActionResult CopyLineUp() {
			IntPtr payloadPtr = NativeMethods.CopyLineUp(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Duplicates the current line (or selected lines) downward.</summary>
		public EditorActionResult CopyLineDown() {
			IntPtr payloadPtr = NativeMethods.CopyLineDown(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Deletes the current line (or all selected lines).</summary>
		public EditorActionResult DeleteLine() {
			IntPtr payloadPtr = NativeMethods.DeleteLine(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line above the current line.</summary>
		public EditorActionResult InsertLineAbove() {
			IntPtr payloadPtr = NativeMethods.InsertLineAbove(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Inserts an empty line below the current line.</summary>
		public EditorActionResult InsertLineBelow() {
			IntPtr payloadPtr = NativeMethods.InsertLineBelow(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Gets the currently selected text.</summary>
		/// <returns>Selected text; returns empty string when there is no selection.</returns>
		public string GetSelectedText() {
			IntPtr ptr = NativeMethods.GetSelectedText(nativeHandle);
			if (ptr == IntPtr.Zero) return "";
			string text = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return text;
		}

		#endregion

		#region Undo/redo

		/// <summary>Performs undo.</summary>
		/// <returns>Edit result; null means there is nothing to undo.</returns>
		public EditorActionResult? Undo() {
			IntPtr payloadPtr = NativeMethods.Undo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Performs redo.</summary>
		/// <returns>Edit result; null means there is nothing to redo.</returns>
		public EditorActionResult? Redo() {
			IntPtr payloadPtr = NativeMethods.Redo(nativeHandle, out UIntPtr payloadSize);
			if (payloadPtr == IntPtr.Zero) return null;
			return DecodeAction(payloadPtr, payloadSize);
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
		public EditorActionResult SetCursorPosition(TextPosition position) {
			IntPtr payloadPtr = NativeMethods.SetCursorPosition(nativeHandle, (nuint)position.Line, (nuint)position.Column, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
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
			string text = Marshal.PtrToStringUTF8(ptr) ?? "";
			NativeMethods.FreeUtf8String(ptr);
			return text;
		}

		/// <summary>Sets text selection.</summary>
		/// <param name="startLine">Selection start line (0-based).</param>
		/// <param name="startColumn">Selection start column (0-based).</param>
		/// <param name="endLine">Selection end line (0-based).</param>
		/// <param name="endColumn">Selection end column (0-based).</param>
		public EditorActionResult SetSelection(int startLine, int startColumn, int endLine, int endColumn) {
			IntPtr payloadPtr = NativeMethods.SetSelection(nativeHandle, startLine, startColumn, endLine, endColumn, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
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
		public EditorActionResult SelectAll() {
			IntPtr payloadPtr = NativeMethods.SelectAll(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Caret Movement

		/// <summary>Moves caret left.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorLeft(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorLeft(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves caret right.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorRight(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorRight(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves caret up.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorUp(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorUp(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves caret down.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorDown(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorDown(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves caret to line start.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorToLineStart(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorToLineStart(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Moves caret to line end.</summary>
		/// <param name="extendSelection">Whether to extend selection</param>
		public EditorActionResult MoveCursorToLineEnd(bool extendSelection = false) {
			IntPtr payloadPtr = NativeMethods.MoveCursorToLineEnd(nativeHandle, extendSelection ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region IME composition

		/// <summary>Updates IME composition text.</summary>
		/// <param name="text">Current composition text</param>
		public EditorActionResult UpdateImePreedit(string? text) {
			IntPtr payloadPtr = NativeMethods.ImeUpdatePreedit(nativeHandle, text ?? string.Empty, 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Cancels IME composition.</summary>
		public EditorActionResult CancelImePreedit() {
			IntPtr payloadPtr = NativeMethods.ImeCancelPreedit(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Whether IME composition is currently active.</summary>
		/// <returns>Returns <c>true</c> when IME composition is active.</returns>
		public bool IsComposing() {
			return NativeMethods.IsComposing(nativeHandle) != 0;
		}

		/// <summary>Enables or disables IME composition handling.</summary>
		/// <param name="enabled"><c>true</c> to enable composition; otherwise <c>false</c>.</param>
		public EditorActionResult SetCompositionEnabled(bool enabled) {
			compositionEnabled = enabled;
			if (!enabled && IsComposing()) {
				return CancelImePreedit();
			}
			return EditorActionResult.Empty;
		}

		/// <summary>Gets whether IME composition handling is enabled.</summary>
		/// <returns><c>true</c> when composition is enabled.</returns>
		public bool IsCompositionEnabled() {
			return compositionEnabled;
		}

		#endregion

		#region Read-only mode

		/// <summary>Sets read-only mode.</summary>
		/// <param name="readOnly">Whether read-only</param>
		public EditorActionResult SetReadOnly(bool readOnly) {
			IntPtr payloadPtr = NativeMethods.SetReadOnly(nativeHandle, readOnly ? 1 : 0, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
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
		public EditorActionResult SetAutoIndentMode(int mode) {
			IntPtr payloadPtr = NativeMethods.SetAutoIndentMode(nativeHandle, mode, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Gets current auto-indent mode.</summary>
		/// <returns>Auto-indent mode value (0=NONE, 1=KEEP_INDENT).</returns>
		public int GetAutoIndentMode() {
			return NativeMethods.GetAutoIndentMode(nativeHandle);
		}

		#endregion

		#region Handle Config

		/// <summary>Sets the selection handle hit-test configuration.</summary>
		/// <param name="config">HandleConfig instance</param>
		public EditorActionResult SetHandleConfig(HandleConfig config) {
			_handleConfig = config;
			byte[] payload = CoreProtocol.EncodeHandleConfig(config);
			IntPtr payloadPtr = NativeMethods.SetHandleConfig(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Gets the current handle configuration.</summary>
		public HandleConfig GetHandleConfig() {
			return _handleConfig;
		}

		#endregion

		#region Scrollbar Config

		/// <summary>Sets scrollbar geometry configuration.</summary>
		/// <param name="config">ScrollbarConfig instance</param>
		public EditorActionResult SetScrollbarConfig(ScrollbarConfig config) {
			_scrollbarConfig = config;
			byte[] payload = CoreProtocol.EncodeScrollbarConfig(config);
			IntPtr payloadPtr = NativeMethods.SetScrollbarConfig(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
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
			(int safeLine, int safeColumn) = ClampPositionForNative(line, column);
			float x = 0, y = 0, h = 0;
			NativeMethods.GetPositionRect(nativeHandle, (nuint)safeLine, (nuint)safeColumn, ref x, ref y, ref h);
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
		public EditorActionResult GotoPosition(int line, int column) {
			IntPtr payloadPtr = NativeMethods.GotoPosition(nativeHandle, line, column, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Scrolls minimally to keep the current caret visible inside the viewport.</summary>
		public EditorActionResult EnsureCursorVisible() {
			IntPtr payloadPtr = NativeMethods.EnsureCursorVisible(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Scrolls to the specified line.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="behavior">Scroll alignment behavior (see <see cref="ScrollBehavior"/>).</param>
		public EditorActionResult ScrollToLine(int line, int behavior = (int)ScrollBehavior.GOTO_CENTER) {
			IntPtr payloadPtr = NativeMethods.ScrollToLine(nativeHandle, line, (byte)behavior, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Manually sets scroll position (automatically clamped to valid range).</summary>
		/// <param name="scrollX">Horizontal scroll offset</param>
		/// <param name="scrollY">Vertical scroll offset</param>
		public EditorActionResult SetScroll(float scrollX, float scrollY) {
			IntPtr payloadPtr = NativeMethods.SetScroll(nativeHandle, scrollX, scrollY, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Gets scrollbar metrics (used by platform-side scrollbar rendering).</summary>
		public ScrollMetrics GetScrollMetrics() {
			IntPtr payloadPtr = NativeMethods.GetScrollMetrics(nativeHandle, out UIntPtr payloadSize);
			return DecodePayload(payloadPtr, payloadSize, CoreProtocol.DecodeScrollMetrics, new ScrollMetrics());
		}

		/// <summary>Gets a layout metrics snapshot for widget/layout code.</summary>
		public LayoutMetrics GetLayoutMetrics() {
			IntPtr payloadPtr = NativeMethods.GetLayoutMetrics(nativeHandle, out UIntPtr payloadSize);
			return DecodePayload(payloadPtr, payloadSize, CoreProtocol.DecodeLayoutMetrics, new LayoutMetrics());
		}
		#endregion

		#region Style Registration + Highlight Spans

		/// <summary>Registers a highlight style (with background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="backgroundColor">Background color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public EditorActionResult RegisterTextStyle(uint styleId, int color, int backgroundColor, int fontStyle) {
			IntPtr payloadPtr = NativeMethods.registerTextStyle(nativeHandle, styleId, color, backgroundColor, fontStyle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Registers a highlight style (without background color).</summary>
		/// <param name="styleId">Style ID</param>
		/// <param name="color">Text color (ARGB)</param>
		/// <param name="fontStyle">Font style (bit flags: BOLD | ITALIC | STRIKETHROUGH).</param>
		public EditorActionResult RegisterTextStyle(uint styleId, int color, int fontStyle) {
			IntPtr payloadPtr = NativeMethods.registerTextStyle(nativeHandle, styleId, color, 0, fontStyle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Registers multiple highlight styles in one native call.</summary>
		/// <param name="stylesById">Style definitions keyed by style ID.</param>
		public EditorActionResult RegisterBatchTextStyles(IReadOnlyDictionary<int, TextStyle> stylesById) {
			if (stylesById == null || stylesById.Count == 0) {
				return EditorActionResult.Empty;
			}

			byte[] payload = CoreProtocol.EncodeRegisterBatchTextStylesPayload(stylesById);
			if (payload.Length == 0) {
				return EditorActionResult.Empty;
			}

			IntPtr payloadPtr = NativeMethods.registerBatchTextStyles(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets highlight spans for the specified line (model overload).</summary>
		public EditorActionResult SetLineSpans(int line, int layer, IList<StyleSpan> spans) {
			if (spans == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLineSpansPayload(line, (SpanLayer)layer, ToReadOnlyList(spans));
			IntPtr payloadPtr = NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets highlight spans for the specified line (buffer overload, accepts pre-encoded data).</summary>
		public EditorActionResult SetLineSpans(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLineSpans(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets highlight spans for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLineSpans(int layer, Dictionary<int, IList<StyleSpan>> spansByLine) {
			if (spansByLine == null || spansByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineSpansPayload((SpanLayer)layer, ToReadOnlyLineMap(spansByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public EditorActionResult SetBatchLineSpans(int layer, Dictionary<int, List<StyleSpan>> spansByLine) {
			if (spansByLine == null || spansByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineSpansPayload((SpanLayer)layer, ToReadOnlyLineMap(spansByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets highlight spans for multiple lines (buffer overload, accepts pre-encoded data).</summary>
		public EditorActionResult SetBatchLineSpans(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLineSpans(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears highlight spans for a single line and layer.</summary>
		/// <param name="line">Target line (0-based).</param>
		/// <param name="layer">Target layer (see <see cref="SpanLayer"/>).</param>
		public EditorActionResult ClearLineSpans(int line, int layer) {
			IntPtr payloadPtr = NativeMethods.ClearLineSpans(nativeHandle, (nuint)ClampLineForNative(line), (byte)layer, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region InlayHint / PhantomText

		/// <summary>Sets Inlay Hints for the specified line (model overload, replaces whole line).</summary>
		public EditorActionResult SetLineInlayHints(int line, IList<InlayHint> hints) {
			if (hints == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLineInlayHintsPayload(line, ToReadOnlyList(hints));
			IntPtr payloadPtr = NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets Inlay Hints for the specified line (buffer overload).</summary>
		public EditorActionResult SetLineInlayHints(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLineInlayHints(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLineInlayHints(Dictionary<int, IList<InlayHint>> hintsByLine) {
			if (hintsByLine == null || hintsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineInlayHintsPayload(ToReadOnlyLineMap(hintsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public EditorActionResult SetBatchLineInlayHints(Dictionary<int, List<InlayHint>> hintsByLine) {
			if (hintsByLine == null || hintsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineInlayHintsPayload(ToReadOnlyLineMap(hintsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets Inlay Hints for multiple lines (buffer overload).</summary>
		public EditorActionResult SetBatchLineInlayHints(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLineInlayHints(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets ghost text for the specified line (model overload, replaces whole line).</summary>
		public EditorActionResult SetLinePhantomTexts(int line, IList<PhantomText> phantoms) {
			if (phantoms == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLinePhantomTextsPayload(line, ToReadOnlyList(phantoms));
			IntPtr payloadPtr = NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets ghost text for the specified line (buffer overload).</summary>
		public EditorActionResult SetLinePhantomTexts(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets ghost text for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLinePhantomTexts(Dictionary<int, IList<PhantomText>> phantomsByLine) {
			if (phantomsByLine == null || phantomsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLinePhantomTextsPayload(ToReadOnlyLineMap(phantomsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public EditorActionResult SetBatchLinePhantomTexts(Dictionary<int, List<PhantomText>> phantomsByLine) {
			if (phantomsByLine == null || phantomsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLinePhantomTextsPayload(ToReadOnlyLineMap(phantomsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets ghost text for multiple lines (buffer overload).</summary>
		public EditorActionResult SetBatchLinePhantomTexts(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLinePhantomTexts(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Gutter icons

		/// <summary>Sets gutter icons for the specified line (model overload, replaces whole line).</summary>
		public EditorActionResult SetLineGutterIcons(int line, IList<GutterIcon> icons) {
			if (icons == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLineGutterIconsPayload(line, ToReadOnlyList(icons));
			IntPtr payloadPtr = NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets gutter icons for the specified line (buffer overload).</summary>
		public EditorActionResult SetLineGutterIcons(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLineGutterIcons(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets gutter icons for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLineGutterIcons(Dictionary<int, IList<GutterIcon>> iconsByLine) {
			if (iconsByLine == null || iconsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineGutterIconsPayload(ToReadOnlyLineMap(iconsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public EditorActionResult SetBatchLineGutterIcons(Dictionary<int, List<GutterIcon>> iconsByLine) {
			if (iconsByLine == null || iconsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineGutterIconsPayload(ToReadOnlyLineMap(iconsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets gutter icons for multiple lines (buffer overload).</summary>
		public EditorActionResult SetBatchLineGutterIcons(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLineGutterIcons(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all gutter icons.</summary>
		public EditorActionResult ClearGutterIcons() {
			IntPtr payloadPtr = NativeMethods.ClearGutterIcons(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets maximum icon count shown in the gutter.</summary>
		public EditorActionResult SetMaxGutterIcons(int count) {
			IntPtr payloadPtr = NativeMethods.SetMaxGutterIcons(nativeHandle, (uint)Math.Max(0, count), out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region CodeLens

		/// <summary>Sets CodeLens items for the specified line (model overload).</summary>
		public EditorActionResult SetLineCodeLens(int line, IList<CodeLensItem> items) {
			if (items == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLineCodeLensPayload(line, ToReadOnlyList(items));
			IntPtr payloadPtr = NativeMethods.SetLineCodeLens(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets CodeLens items for the specified line (buffer overload).</summary>
		public EditorActionResult SetLineCodeLens(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLineCodeLens(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets CodeLens items for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLineCodeLens(Dictionary<int, IList<CodeLensItem>> itemsByLine) {
			if (itemsByLine == null || itemsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineCodeLensPayload(ToReadOnlyLineMap(itemsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineCodeLens(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets CodeLens items for multiple lines (list overload).</summary>
		public EditorActionResult SetBatchLineCodeLens(Dictionary<int, List<CodeLensItem>> itemsByLine) {
			if (itemsByLine == null || itemsByLine.Count == 0) return EditorActionResult.Empty;
			var normalized = new Dictionary<int, IList<CodeLensItem>>(itemsByLine.Count);
			foreach (var kv in itemsByLine) {
				normalized[kv.Key] = kv.Value;
			}
			byte[] payload = CoreProtocol.EncodeSetBatchLineCodeLensPayload(ToReadOnlyLineMap(normalized));
			IntPtr payloadPtr = NativeMethods.SetBatchLineCodeLens(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets CodeLens items for multiple lines (buffer overload).</summary>
		public EditorActionResult SetBatchLineCodeLens(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLineCodeLens(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all CodeLens items.</summary>
		public EditorActionResult ClearCodeLens() {
			IntPtr payloadPtr = NativeMethods.ClearCodeLens(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Diagnostic decorations

		/// <summary>Sets diagnostic decorations for the specified line (model overload).</summary>
		public EditorActionResult SetLineDiagnostics(int line, IList<Diagnostic> items) {
			if (items == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetLineDiagnosticsPayload(line, ToReadOnlyList(items));
			IntPtr payloadPtr = NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets diagnostic decorations for the specified line (buffer overload).</summary>
		public EditorActionResult SetLineDiagnostics(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetLineDiagnostics(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (model overload).</summary>
		public EditorActionResult SetBatchLineDiagnostics(Dictionary<int, IList<Diagnostic>> diagsByLine) {
			if (diagsByLine == null || diagsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineDiagnosticsPayload(ToReadOnlyLineMap(diagsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		public EditorActionResult SetBatchLineDiagnostics(Dictionary<int, List<Diagnostic>> diagsByLine) {
			if (diagsByLine == null || diagsByLine.Count == 0) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBatchLineDiagnosticsPayload(ToReadOnlyLineMap(diagsByLine));
			IntPtr payloadPtr = NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Batch sets diagnostic decorations for multiple lines (buffer overload).</summary>
		public EditorActionResult SetBatchLineDiagnostics(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBatchLineDiagnostics(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all diagnostic decorations.</summary>
		public EditorActionResult ClearDiagnostics() {
			IntPtr payloadPtr = NativeMethods.ClearDiagnostics(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Guide Lines

		/// <summary>Sets indent guide list (global replace, model overload).</summary>
		public EditorActionResult SetIndentGuides(IList<IndentGuide> guides) {
			if (guides == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetIndentGuidesPayload(ToReadOnlyList(guides));
			IntPtr payloadPtr = NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets indent guide list (buffer overload).</summary>
		public EditorActionResult SetIndentGuides(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetIndentGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets bracket branch guide list (global replace, model overload).</summary>
		public EditorActionResult SetBracketGuides(IList<BracketGuide> guides) {
			if (guides == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetBracketGuidesPayload(ToReadOnlyList(guides));
			IntPtr payloadPtr = NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets bracket branch guide list (buffer overload).</summary>
		public EditorActionResult SetBracketGuides(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetBracketGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets control-flow back-edge arrow list (global replace, model overload).</summary>
		public EditorActionResult SetFlowGuides(IList<FlowGuide> guides) {
			if (guides == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetFlowGuidesPayload(ToReadOnlyList(guides));
			IntPtr payloadPtr = NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets control-flow back-edge arrow list (buffer overload).</summary>
		public EditorActionResult SetFlowGuides(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetFlowGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets horizontal separator list (global replace, model overload).</summary>
		public EditorActionResult SetSeparatorGuides(IList<SeparatorGuide> guides) {
			if (guides == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetSeparatorGuidesPayload(ToReadOnlyList(guides));
			IntPtr payloadPtr = NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets horizontal separator list (buffer overload).</summary>
		public EditorActionResult SetSeparatorGuides(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetSeparatorGuides(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all code guide lines.</summary>
		public EditorActionResult ClearGuides() {
			IntPtr payloadPtr = NativeMethods.ClearGuides(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Code folding

		/// <summary>Sets foldable region list (model overload).</summary>
		public EditorActionResult SetFoldRegions(IList<FoldRegion> regions) {
			if (regions == null) return EditorActionResult.Empty;
			byte[] payload = CoreProtocol.EncodeSetFoldRegionsPayload(ToReadOnlyList(regions));
			IntPtr payloadPtr = NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets foldable region list (buffer overload).</summary>
		public EditorActionResult SetFoldRegions(byte[] payload) {
			if (payload == null) return EditorActionResult.Empty;
			IntPtr payloadPtr = NativeMethods.SetFoldRegions(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Toggles fold/unfold state of the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means a region was found and toggled.</returns>
		public EditorActionResult ToggleFold(int line) {
			IntPtr payloadPtr = NativeMethods.ToggleFold(nativeHandle, (nuint)ClampLineForNative(line), out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Folds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means folding succeeded.</returns>
		public EditorActionResult FoldAt(int line) {
			IntPtr payloadPtr = NativeMethods.FoldAt(nativeHandle, (nuint)ClampLineForNative(line), out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Unfolds the region containing the specified line.</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means unfolding succeeded.</returns>
		public EditorActionResult UnfoldAt(int line) {
			IntPtr payloadPtr = NativeMethods.UnfoldAt(nativeHandle, (nuint)ClampLineForNative(line), out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Folds all regions.</summary>
		public EditorActionResult FoldAll() {
			IntPtr payloadPtr = NativeMethods.FoldAll(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Unfolds all regions.</summary>
		public EditorActionResult UnfoldAll() {
			IntPtr payloadPtr = NativeMethods.UnfoldAll(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Checks whether the specified line is visible (not hidden by folding).</summary>
		/// <param name="line">Line (0-based)</param>
		/// <returns><c>true</c> means visible.</returns>
		public bool IsLineVisible(int line) {
			return NativeMethods.IsLineVisible(nativeHandle, (nuint)ClampLineForNative(line)) != 0;
		}

		#endregion

		#region Clear operations

		/// <summary>Clears all highlight spans.</summary>
		public EditorActionResult ClearHighlights() {
			IntPtr payloadPtr = NativeMethods.ClearHighlights(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears highlight spans in the specified layer.</summary>
		/// <param name="layer">Target layer (see <see cref="SpanLayer"/>).</param>
		public EditorActionResult ClearHighlights(int layer) {
			IntPtr payloadPtr = NativeMethods.ClearHighlightsLayer(nativeHandle, (byte)layer, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all Inlay Hints.</summary>
		public EditorActionResult ClearInlayHints() {
			IntPtr payloadPtr = NativeMethods.ClearInlayHints(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all ghost text.</summary>
		public EditorActionResult ClearPhantomTexts() {
			IntPtr payloadPtr = NativeMethods.ClearPhantomTexts(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears all decoration data (highlights, Inlay Hints, ghost text, icons, and guide lines).</summary>
		public EditorActionResult ClearAllDecorations() {
			IntPtr payloadPtr = NativeMethods.ClearAllDecorations(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region LinkedEditing

		/// <summary>Inserts a VSCode snippet template and enters linked editing mode.</summary>
		public EditorActionResult InsertSnippet(string snippetTemplate) {
			IntPtr payloadPtr = NativeMethods.InsertSnippet(nativeHandle, snippetTemplate, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Starts linked editing mode with a generic LinkedEditingModel.</summary>
		public EditorActionResult StartLinkedEditing(LinkedEditingModel model) {
			byte[] payload = CoreProtocol.EncodeStartLinkedEditingPayload(model);
			IntPtr payloadPtr = NativeMethods.StartLinkedEditing(nativeHandle, payload, (nuint)payload.Length, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Whether linked editing mode is active.</summary>
		public bool IsInLinkedEditing() {
			return NativeMethods.IsInLinkedEditing(nativeHandle) != 0;
		}

		/// <summary>Linked editing: jump to next tab stop.</summary>
		public EditorActionResult LinkedEditingNext() {
			IntPtr payloadPtr = NativeMethods.LinkedEditingNext(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Linked editing: jump to previous tab stop.</summary>
		public EditorActionResult LinkedEditingPrev() {
			IntPtr payloadPtr = NativeMethods.LinkedEditingPrev(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Cancels linked editing mode.</summary>
		public EditorActionResult CancelLinkedEditing() {
			IntPtr payloadPtr = NativeMethods.CancelLinkedEditing(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

		#region Bracket highlight APIs

		/// <summary>Sets custom bracket pair list.</summary>
		public EditorActionResult SetBracketPairs(int[]? openChars, int[]? closeChars) {
			if (openChars == null || closeChars == null) {
				return EditorActionResult.Empty;
			}
			int count = Math.Min(openChars.Length, closeChars.Length);
			if (count != openChars.Length || count != closeChars.Length) {
				openChars = openChars.Take(count).ToArray();
				closeChars = closeChars.Take(count).ToArray();
			}
			if (count == 0) {
				openChars = Array.Empty<int>();
				closeChars = Array.Empty<int>();
			}
			IntPtr payloadPtr = NativeMethods.SetBracketPairs(nativeHandle, openChars, closeChars, (nuint)count, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Sets externally computed exact bracket pair positions (takes priority over built-in scanning).</summary>
		public EditorActionResult SetMatchedBrackets(int openLine, int openColumn, int closeLine, int closeColumn) {
			(int safeOpenLine, int safeOpenColumn) = ClampPositionForNative(openLine, openColumn);
			(int safeCloseLine, int safeCloseColumn) = ClampPositionForNative(closeLine, closeColumn);
			IntPtr payloadPtr = NativeMethods.SetMatchedBrackets(nativeHandle, (nuint)safeOpenLine, (nuint)safeOpenColumn, (nuint)safeCloseLine, (nuint)safeCloseColumn, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		/// <summary>Clears externally supplied bracket match results (falls back to built-in scanning).</summary>
		public EditorActionResult ClearMatchedBrackets() {
			IntPtr payloadPtr = NativeMethods.ClearMatchedBrackets(nativeHandle, out UIntPtr payloadSize);
			return DecodeAction(payloadPtr, payloadSize);
		}

		#endregion

	}
}
