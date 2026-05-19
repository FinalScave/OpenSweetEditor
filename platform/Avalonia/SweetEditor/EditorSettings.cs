namespace SweetEditor {
	public sealed class EditorSettings {
		private readonly SweetEditorControl editor;

		private float editorTextSize;
		private string fontFamily;
		private float scale = 1.0f;
		private FoldArrowMode foldArrowMode = FoldArrowMode.ALWAYS;
		private WrapMode wrapMode = WrapMode.NONE;
		private bool compositionEnabled;
		private float lineSpacingAdd;
		private float lineSpacingMult = 1.0f;
		private float contentStartPadding;
		private bool showSplitLine = true;
		private bool gutterSticky = true;
		private bool gutterVisible = true;
		private CurrentLineRenderMode currentLineRenderMode = CurrentLineRenderMode.BACKGROUND;
		private AutoIndentMode autoIndentMode = AutoIndentMode.KEEP_INDENT;
		private bool backspaceUnindent;
		private bool readOnly;
		private int maxGutterIcons;
		private long decorationScrollRefreshMinIntervalMs = 16L;
		private float decorationOverscanViewportMultiplier = 1.5f;

		internal EditorSettings(SweetEditorControl editor) {
			this.editor = editor;
			editorTextSize = editor.RendererInternal.EditorTextSize;
			fontFamily = editor.RendererInternal.FontFamily;
			compositionEnabled = editor.EditorCoreInternal.IsCompositionEnabled();
			backspaceUnindent = editor.EditorCoreInternal.IsBackspaceUnindent();
			readOnly = editor.EditorCoreInternal.IsReadOnly();
		}

		public void SetEditorTextSize(float size) {
			editorTextSize = size > 0 ? size : editorTextSize;
			editor.RendererInternal.SetEditorTextSize(editorTextSize);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.OnFontMetricsChanged());
		}

		public float GetEditorTextSize() => editorTextSize;

		public void SetFontFamily(string family) {
			if (string.IsNullOrWhiteSpace(family)) {
				return;
			}
			fontFamily = family.Trim();
			editor.RendererInternal.SetFontFamily(fontFamily);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.OnFontMetricsChanged());
		}

		public string GetFontFamily() => fontFamily;

		public void SetTypeface(string typeface) => SetFontFamily(typeface);

		public string GetTypeface() => GetFontFamily();

		public void SetScale(float scale) {
			this.scale = scale > 0 ? scale : 1.0f;
			EditorActionResult scaleResult = editor.EditorCoreInternal.SetScale(this.scale);
			editor.RendererInternal.SetScale(this.scale);
			editor.DispatchEditorActionResult(scaleResult);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.OnFontMetricsChanged());
		}

		public float GetScale() => scale;

		public void SetFoldArrowMode(FoldArrowMode mode) {
			foldArrowMode = NormalizeFoldArrowMode(mode);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetFoldArrowMode((int)foldArrowMode));
		}

		public FoldArrowMode GetFoldArrowMode() => foldArrowMode;

		public void SetWrapMode(WrapMode mode) {
			wrapMode = NormalizeWrapMode(mode);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetWrapMode((int)wrapMode));
		}

		public WrapMode GetWrapMode() => wrapMode;

		public void SetCompositionEnabled(bool enabled) {
			if (compositionEnabled == enabled) {
				return;
			}

			if (!enabled && editor.EditorCoreInternal.IsComposing()) {
				editor.DispatchEditorActionResult(editor.EditorCoreInternal.CancelImePreedit());
			}

			compositionEnabled = enabled;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetCompositionEnabled(enabled));
		}

		public bool IsCompositionEnabled() => compositionEnabled;

		public void SetLineSpacing(float add, float mult) {
			lineSpacingAdd = add;
			lineSpacingMult = mult <= 0 ? 1.0f : mult;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetLineSpacing(lineSpacingAdd, lineSpacingMult));
		}

		public float GetLineSpacingAdd() => lineSpacingAdd;

		public float GetLineSpacingMult() => lineSpacingMult;

		public void SetContentStartPadding(float padding) {
			contentStartPadding = padding < 0 ? 0 : padding;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetContentStartPadding(contentStartPadding));
		}

		public float GetContentStartPadding() => contentStartPadding;

		public void SetShowSplitLine(bool show) {
			showSplitLine = show;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetShowSplitLine(show));
		}

		public bool IsShowSplitLine() => showSplitLine;

		public void SetGutterSticky(bool sticky) {
			gutterSticky = sticky;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetGutterSticky(sticky));
		}

		internal void SetGutterStickyCoreOnly(bool sticky) {
			gutterSticky = sticky;
			editor.EditorCoreInternal.SetGutterSticky(sticky);
		}

		public bool IsGutterSticky() => gutterSticky;

		public void SetGutterVisible(bool visible) {
			gutterVisible = visible;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetGutterVisible(visible));
		}

		public bool IsGutterVisible() => gutterVisible;

		public void SetCurrentLineRenderMode(CurrentLineRenderMode mode) {
			currentLineRenderMode = NormalizeCurrentLineRenderMode(mode);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetCurrentLineRenderMode(currentLineRenderMode));
		}

		public CurrentLineRenderMode GetCurrentLineRenderMode() => currentLineRenderMode;

		public void SetAutoIndentMode(AutoIndentMode mode) {
			autoIndentMode = NormalizeAutoIndentMode(mode);
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetAutoIndentMode((int)autoIndentMode));
		}

		public AutoIndentMode GetAutoIndentMode() => autoIndentMode;

		public void SetBackspaceUnindent(bool enabled) {
			backspaceUnindent = enabled;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetBackspaceUnindent(enabled));
		}

		public bool IsBackspaceUnindent() => backspaceUnindent;

		public void SetReadOnly(bool readOnly) {
			this.readOnly = readOnly;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetReadOnly(readOnly));
		}

		public bool IsReadOnly() => readOnly;

		public void SetMaxGutterIcons(int count) {
			maxGutterIcons = count < 0 ? 0 : count;
			editor.DispatchEditorActionResult(editor.EditorCoreInternal.SetMaxGutterIcons(maxGutterIcons));
		}

		public int GetMaxGutterIcons() => maxGutterIcons;

		public void SetDecorationScrollRefreshMinIntervalMs(long ms) {
			decorationScrollRefreshMinIntervalMs = ms < 0 ? 0L : ms;
			editor.RequestDecorationRefresh();
		}

		public long GetDecorationScrollRefreshMinIntervalMs() => decorationScrollRefreshMinIntervalMs;

		public void SetDecorationOverscanViewportMultiplier(float multiplier) {
			decorationOverscanViewportMultiplier = multiplier < 0 ? 0 : multiplier;
			editor.RequestDecorationRefresh();
		}

		public float GetDecorationOverscanViewportMultiplier() => decorationOverscanViewportMultiplier;

		private static FoldArrowMode NormalizeFoldArrowMode(FoldArrowMode mode) {
			return mode is FoldArrowMode.AUTO or FoldArrowMode.ALWAYS or FoldArrowMode.HIDDEN
				? mode
				: FoldArrowMode.ALWAYS;
		}

		private static WrapMode NormalizeWrapMode(WrapMode mode) {
			return mode is WrapMode.NONE or WrapMode.CHAR_BREAK or WrapMode.WORD_BREAK
				? mode
				: WrapMode.NONE;
		}

		private static CurrentLineRenderMode NormalizeCurrentLineRenderMode(CurrentLineRenderMode mode) {
			return mode is CurrentLineRenderMode.BACKGROUND or CurrentLineRenderMode.BORDER or CurrentLineRenderMode.NONE
				? mode
				: CurrentLineRenderMode.BACKGROUND;
		}

		private static AutoIndentMode NormalizeAutoIndentMode(AutoIndentMode mode) {
			return mode is AutoIndentMode.NONE or AutoIndentMode.KEEP_INDENT
				? mode
				: AutoIndentMode.KEEP_INDENT;
		}
	}
}
