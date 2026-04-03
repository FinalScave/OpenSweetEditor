namespace SweetEditor {
	/// <summary>
	/// Centralized configuration for <see cref="SweetEditorControl"/>.
	/// <para>
	/// Obtain via <see cref="SweetEditorControl.Settings"/>. All setters take effect immediately.
	/// </para>
	/// </summary>
	public class EditorSettings {

		private readonly SweetEditorControl editor;

		private float scale = 1.0f;
		private FoldArrowMode foldArrowMode = FoldArrowMode.ALWAYS;
		private WrapMode wrapMode = WrapMode.NONE;
		private float lineSpacingAdd = 0f;
		private float lineSpacingMult = 1.0f;
		private float contentStartPadding = 0f;
		private bool showSplitLine = true;
		private bool gutterSticky = true;
		private bool gutterVisible = true;
		private CurrentLineRenderMode currentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
		private AutoIndentMode autoIndentMode = AutoIndentMode.NONE;
		private bool backspaceUnindent = true;
		private bool readOnly = false;
		private bool compositionEnabled = true;
		private int maxGutterIcons = 0;
		private int decorationScrollRefreshMinIntervalMs = 16;
		private float decorationOverscanViewportMultiplier = 1.5f;

		internal EditorSettings(SweetEditorControl editor) {
			this.editor = editor;
		}

		/// <summary>Sets editor scale.</summary>
		public void SetScale(float scale) {
			this.scale = scale;
			editor.EditorCoreInternal.SetScale(scale);
			editor.SyncPlatformScaleInternal(scale);
			editor.Flush();
		}

		/// <summary>Gets editor scale.</summary>
		public float GetScale() => scale;

		/// <summary>Sets fold arrow mode.</summary>
		public void SetFoldArrowMode(FoldArrowMode mode) {
			foldArrowMode = mode;
			editor.EditorCoreInternal.SetFoldArrowMode((int)mode);
		}

		/// <summary>Gets fold arrow mode.</summary>
		public FoldArrowMode GetFoldArrowMode() => foldArrowMode;

		/// <summary>Sets wrap mode.</summary>
		public void SetWrapMode(WrapMode mode) {
			wrapMode = mode;
			editor.EditorCoreInternal.SetWrapMode((int)mode);
			editor.Flush();
		}

		/// <summary>Gets wrap mode.</summary>
		public WrapMode GetWrapMode() => wrapMode;

		/// <summary>Sets line spacing.</summary>
		public void SetLineSpacing(float add, float mult) {
			lineSpacingAdd = add;
			lineSpacingMult = mult;
			editor.EditorCoreInternal.SetLineSpacing(add, mult);
			editor.Flush();
		}

		/// <summary>Gets line spacing add.</summary>
		public float GetLineSpacingAdd() => lineSpacingAdd;

		/// <summary>Gets line spacing multiplier.</summary>
		public float GetLineSpacingMult() => lineSpacingMult;

		/// <summary>Sets extra horizontal padding between gutter split and text content start.</summary>
		public void SetContentStartPadding(float padding) {
			contentStartPadding = System.Math.Max(0f, padding);
			editor.EditorCoreInternal.SetContentStartPadding(contentStartPadding);
			editor.Flush();
		}

		/// <summary>Gets content start padding.</summary>
		public float GetContentStartPadding() => contentStartPadding;

		/// <summary>Sets whether gutter split line should be rendered.</summary>
		public void SetShowSplitLine(bool show) {
			showSplitLine = show;
			editor.EditorCoreInternal.SetShowSplitLine(show);
			editor.Flush();
		}

		/// <summary>Gets whether gutter split line should be rendered.</summary>
		public bool IsShowSplitLine() => showSplitLine;

		/// <summary>Sets whether gutter stays fixed during horizontal scroll.</summary>
		public void SetGutterSticky(bool sticky) {
			gutterSticky = sticky;
			editor.EditorCoreInternal.SetGutterSticky(sticky);
			editor.Flush();
		}

		/// <summary>Gets whether gutter stays fixed during horizontal scroll.</summary>
		public bool IsGutterSticky() => gutterSticky;

		/// <summary>Sets whether gutter area is visible.</summary>
		public void SetGutterVisible(bool visible) {
			gutterVisible = visible;
			editor.EditorCoreInternal.SetGutterVisible(visible);
			editor.Flush();
		}

		/// <summary>Gets whether gutter area is visible.</summary>
		public bool IsGutterVisible() => gutterVisible;

		/// <summary>Sets current line render mode.</summary>
		public void SetCurrentLineRenderMode(CurrentLineRenderMode mode) {
			currentLineRenderMode = mode;
			editor.EditorCoreInternal.SetCurrentLineRenderMode(mode);
			editor.Flush();
		}

		/// <summary>Gets current line render mode.</summary>
		public CurrentLineRenderMode GetCurrentLineRenderMode() => currentLineRenderMode;

		/// <summary>Sets auto indent mode.</summary>
		public void SetAutoIndentMode(AutoIndentMode mode) {
			autoIndentMode = mode;
			editor.EditorCoreInternal.SetAutoIndentMode((int)mode);
		}

		/// <summary>Gets auto indent mode.</summary>
		public AutoIndentMode GetAutoIndentMode() => autoIndentMode;

		/// <summary>Sets backspace unindent behavior.</summary>
		public void SetBackspaceUnindent(bool enabled) {
			backspaceUnindent = enabled;
			editor.EditorCoreInternal.SetBackspaceUnindent(enabled);
		}

		/// <summary>Gets backspace unindent behavior.</summary>
		public bool IsBackspaceUnindent() => backspaceUnindent;

		/// <summary>Sets read-only mode.</summary>
		public void SetReadOnly(bool readOnly) {
			this.readOnly = readOnly;
			editor.EditorCoreInternal.SetReadOnly(readOnly);
		}

		/// <summary>Gets read-only mode.</summary>
		public bool IsReadOnly() => readOnly;

		/// <summary>Enables or disables IME composition.</summary>
		public void SetCompositionEnabled(bool enabled) {
			compositionEnabled = enabled;
			editor.EditorCoreInternal.SetCompositionEnabled(enabled);
			editor.Flush();
		}

		/// <summary>Gets whether IME composition is enabled.</summary>
		public bool IsCompositionEnabled() => compositionEnabled;

		/// <summary>Sets max gutter icons.</summary>
		public void SetMaxGutterIcons(int count) {
			maxGutterIcons = count;
			editor.EditorCoreInternal.SetMaxGutterIcons(count);
		}

		/// <summary>Gets max gutter icons.</summary>
		public int GetMaxGutterIcons() => maxGutterIcons;

		/// <summary>Sets minimum interval for scroll-triggered decoration refresh (milliseconds).</summary>
		public void SetDecorationScrollRefreshMinIntervalMs(int intervalMs) {
			decorationScrollRefreshMinIntervalMs = System.Math.Max(0, intervalMs);
			editor.RequestDecorationRefresh();
		}

		/// <summary>Gets minimum interval for scroll-triggered decoration refresh (milliseconds).</summary>
		public int GetDecorationScrollRefreshMinIntervalMs() => decorationScrollRefreshMinIntervalMs;

		/// <summary>Sets decoration overscan multiplier relative to viewport line count.</summary>
		public void SetDecorationOverscanViewportMultiplier(float multiplier) {
			decorationOverscanViewportMultiplier = System.Math.Max(0f, multiplier);
			editor.RequestDecorationRefresh();
		}

		/// <summary>Gets decoration overscan multiplier relative to viewport line count.</summary>
		public float GetDecorationOverscanViewportMultiplier() => decorationOverscanViewportMultiplier;
	}
}
