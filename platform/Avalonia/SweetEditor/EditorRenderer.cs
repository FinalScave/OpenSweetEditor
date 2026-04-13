using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Media;

namespace SweetEditor {
	internal sealed class EditorRenderer : IDisposable {
		private const float DefaultTextSizeDip = 15.0f;
		private const float InlayTextSizeRatio = 0.86f;
		private const float LineNumberTextSizeRatio = 0.85f;
		private const int MaxFormattedTextCacheEntries = 4096;
		private const int MaxTextMetricsCacheEntries = 4096;
		private const int MaxAdvanceCacheEntries = 32;
		private const int MaxGlyphRunCacheEntries = 8192;
		private const int MaxCacheableTextLength = 192;
		private const int MaxGlyphFastPathCacheEntries = 8192;
		private const int MaxLineNumberTextCacheEntries = 8192;
		private const int MeasureColorArgb = unchecked((int)0xFF000000);
		private const int FontStyleBold = 1;
		private const int FontStyleItalic = 1 << 1;
		private const int FontStyleStrike = 1 << 2;
		private const float HandleLineWidth = 1.2f;
		private const float HandleDropRadius = 7.0f;
		private const float HandleCenterDistance = 16.0f;
		private const float HandleCurveKappa = 0.5522f;

		private readonly Dictionary<int, ISolidColorBrush> brushCache = new();
		private readonly Dictionary<PenKey, Pen> penCache = new();
		private readonly Dictionary<FormattedTextKey, FormattedText> formattedTextCache = new();
		private readonly Dictionary<GlyphRunKey, GlyphRun> glyphRunCache = new();
		private readonly Dictionary<TextMetricsKey, TextMetrics> textMetricsCache = new();
		private readonly Dictionary<LayoutMetricsKey, LayoutMetrics> layoutMetricsCache = new();
		private readonly Dictionary<AdvanceKey, float> monospaceAdvanceCache = new();
		private readonly Dictionary<int, string> lineNumberTextCache = new();
		private readonly Dictionary<string, bool> glyphFastPathCache = new(StringComparer.Ordinal);
		private readonly Dictionary<int, IImage?> iconCache = new();
		private readonly Dictionary<int, float> iconWidthCache = new();
		private readonly MeasurePerfStats measurePerfStats = new();
		private readonly PerfOverlay perfOverlay = new();

		private EditorTheme theme;
		private EditorIconProvider? iconProvider;
		private string fontFamily = "monospace";
		private float textSizeDip = DefaultTextSizeDip;
		private float scale = 1.0f;
		private float platformDensity = 1.0f;

		private Typeface regularTypeface = new("monospace");
		private Typeface boldTypeface = new("monospace", FontStyle.Normal, FontWeight.Bold);
		private Typeface italicTypeface = new("monospace", FontStyle.Italic, FontWeight.Normal);
		private Typeface boldItalicTypeface = new("monospace", FontStyle.Italic, FontWeight.Bold);

		private readonly record struct FormattedTextKey(string Text, int FontStyle, int SizeKey, int Argb, bool Inlay);

		private readonly record struct GlyphRunKey(string Text, int Start, int Length, int FontStyle, int SizeKey);

		private readonly record struct TextMetricsKey(string Text, int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct LayoutMetricsKey(int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct AdvanceKey(int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct PenKey(int Argb, int ThicknessKey, PenLineCap LineCap, PenLineJoin LineJoin);

		private readonly record struct TextMetrics(float Width, float Baseline, float Height);

		private readonly record struct LayoutMetrics(float Baseline, float Height);

		public EditorRenderer(EditorTheme theme) {
			this.theme = theme;
			UpdateTypefaces();
		}

		public EditorTheme Theme => theme;

		public float EditorTextSize => textSizeDip;

		public string FontFamily => fontFamily;

		public EditorCore.TextMeasurer CreateTextMeasurer() {
			return new EditorCore.TextMeasurer {
				MeasureTextWidth = OnMeasureText,
				MeasureInlayHintWidth = OnMeasureInlayText,
				MeasureIconWidth = OnMeasureIconWidth,
				GetFontMetrics = OnGetFontMetrics,
			};
		}

		public MeasurePerfStats GetMeasurePerfStats() => measurePerfStats;

		public PerfOverlay GetPerfOverlay() => perfOverlay;

		public void SetPerfOverlayEnabled(bool enabled) {
			perfOverlay.SetEnabled(enabled);
		}

		public bool IsPerfOverlayEnabled() => perfOverlay.IsEnabled();

		public void BeginFrameMeasureStats() {
			if (perfOverlay.IsEnabled()) {
				measurePerfStats.Reset();
			}
		}

		public void RecordInputPerf(string tag, float inputMs) {
			if (perfOverlay.IsEnabled()) {
				perfOverlay.RecordInput(tag, inputMs);
			}
		}

		public void ApplyTheme(EditorTheme theme) {
			this.theme = theme;
			formattedTextCache.Clear();
		}

		public void SetEditorIconProvider(EditorIconProvider? provider) {
			iconProvider = provider;
			iconCache.Clear();
			iconWidthCache.Clear();
		}

		public void SetScale(float scale) {
			this.scale = Math.Max(0.1f, scale);
			ClearTextCaches();
		}

		public void SetPlatformDensity(float density) {
			platformDensity = Math.Max(0.5f, density);
		}

		public static HandleConfig ComputeHandleHitConfig(float density) {
			float d = Math.Max(0.5f, density);
			double angle = Math.PI / 4.0;
			double cos = Math.Cos(angle);
			double sin = Math.Sin(angle);
			double r = HandleDropRadius;
			double c = HandleCenterDistance;

			var points = new (double x, double y)[] {
				(0, 0),
				(-r, c),
				(r, c),
				(0, c + r),
				(0, c - r * 0.8),
			};

			double minX = double.MaxValue;
			double minY = double.MaxValue;
			double maxX = double.MinValue;
			double maxY = double.MinValue;
			foreach (var p in points) {
				double rx = p.x * cos - p.y * sin;
				double ry = p.x * sin + p.y * cos;
				minX = Math.Min(minX, rx);
				minY = Math.Min(minY, ry);
				maxX = Math.Max(maxX, rx);
				maxY = Math.Max(maxY, ry);
			}

			double pad = 1.0;
			return new HandleConfig {
				StartLeft = (float)((minX - pad) * d),
				StartTop = (float)((minY - pad) * d),
				StartRight = (float)((maxX + pad) * d),
				StartBottom = (float)((maxY + pad) * d),
				EndLeft = (float)((-maxX - pad) * d),
				EndTop = (float)((minY - pad) * d),
				EndRight = (float)((-minX + pad) * d),
				EndBottom = (float)((maxY + pad) * d),
			};
		}

		public void SetEditorTextSize(float sizeDip) {
			textSizeDip = Math.Max(1f, sizeDip);
			ClearTextCaches();
		}

		public void SetFontFamily(string? family) {
			if (string.IsNullOrWhiteSpace(family)) {
				return;
			}
			fontFamily = family.Trim();
			UpdateTypefaces();
		}

		public void Render(DrawingContext context, EditorRenderModel model, Size viewportSize, float buildMs) {
			PerfStepRecorder? drawPerf = perfOverlay.IsEnabled() ? PerfStepRecorder.Start() : null;
			long drawStart = drawPerf != null ? Stopwatch.GetTimestamp() : 0;

			context.FillRectangle(GetBrush((int)theme.BackgroundColor), new Rect(0, 0, viewportSize.Width, viewportSize.Height));
			drawPerf?.Mark(PerfStepRecorder.STEP_CLEAR);

			DrawCurrentLine(context, model, viewportSize.Width);
			drawPerf?.Mark(PerfStepRecorder.STEP_CURRENT);

			Rect contentClip = GetContentClipRect(model, viewportSize);
			using (context.PushClip(contentClip)) {
				DrawSelections(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_SELECTION);
				DrawVisualLines(context, model, contentClip);
				drawPerf?.Mark(PerfStepRecorder.STEP_LINES);
				DrawCursor(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_CURSOR);
			}

			DrawGutterOverlay(context, model, viewportSize.Height);
			DrawLineNumbers(context, model);
			drawPerf?.Mark(PerfStepRecorder.STEP_GUTTER);
			DrawSelectionHandles(context, model);

			DrawScrollbars(context, model);
			drawPerf?.Mark(PerfStepRecorder.STEP_SCROLLBARS);

			if (drawPerf != null) {
				float drawMs = (float)((Stopwatch.GetTimestamp() - drawStart) * 1000.0 / Stopwatch.Frequency);
				drawPerf.Finish();
				float totalMs = Math.Max(0f, buildMs) + drawMs;
				perfOverlay.RecordFrame(buildMs, drawMs, totalMs, drawPerf, measurePerfStats);
				perfOverlay.Render(context, viewportSize);
			}
		}

		public void Dispose() {
			ClearTextCaches();
			brushCache.Clear();
			penCache.Clear();
			iconCache.Clear();
			iconWidthCache.Clear();
		}

		private void UpdateTypefaces() {
			regularTypeface = new Typeface(fontFamily, FontStyle.Normal, FontWeight.Normal);
			boldTypeface = new Typeface(fontFamily, FontStyle.Normal, FontWeight.Bold);
			italicTypeface = new Typeface(fontFamily, FontStyle.Italic, FontWeight.Normal);
			boldItalicTypeface = new Typeface(fontFamily, FontStyle.Italic, FontWeight.Bold);
			ClearTextCaches();
		}

		private float EffectiveTextSize => textSizeDip * scale;

		private float EffectiveInlaySize => EffectiveTextSize * InlayTextSizeRatio;

		private float EffectiveLineNumberSize => EffectiveTextSize * LineNumberTextSizeRatio;

		private void ClearTextCaches() {
			formattedTextCache.Clear();
			glyphRunCache.Clear();
			textMetricsCache.Clear();
			layoutMetricsCache.Clear();
			monospaceAdvanceCache.Clear();
			lineNumberTextCache.Clear();
			glyphFastPathCache.Clear();
		}

		private static int QuantizeSize(float size) => (int)MathF.Round(size * 100f);

		private bool IsProbablyMonospace() => fontFamily.Contains("mono", StringComparison.OrdinalIgnoreCase);

		private static bool CanUseGlyphFastPath(string text) {
			return !string.IsNullOrEmpty(text) && CanUseGlyphFastPath(text.AsSpan());
		}

		private bool CanUseGlyphFastPathCached(string text) {
			if (string.IsNullOrEmpty(text)) {
				return false;
			}

			if (text.Length > MaxCacheableTextLength) {
				return CanUseGlyphFastPath(text.AsSpan());
			}

			if (glyphFastPathCache.TryGetValue(text, out bool cached)) {
				return cached;
			}

			if (glyphFastPathCache.Count >= MaxGlyphFastPathCacheEntries) {
				glyphFastPathCache.Clear();
			}

			bool canUse = CanUseGlyphFastPath(text.AsSpan());
			glyphFastPathCache[text] = canUse;
			return canUse;
		}

		private static bool CanUseGlyphFastPath(ReadOnlySpan<char> text) {
			if (text.IsEmpty) {
				return false;
			}
			for (int i = 0; i < text.Length; i++) {
				char ch = text[i];
				if (ch > 0x7F || ch == '\t' || ch == '\r' || ch == '\n') {
					return false;
				}
			}
			return true;
		}

		private bool CanUseMonospaceFastPath(string text) => CanUseGlyphFastPathCached(text);

		private float GetMonospaceAdvance(int fontStyle, float size, bool inlay) {
			var key = new AdvanceKey(fontStyle, QuantizeSize(size), inlay);
			if (monospaceAdvanceCache.TryGetValue(key, out float advance)) {
				return advance;
			}

			if (monospaceAdvanceCache.Count >= MaxAdvanceCacheEntries) {
				monospaceAdvanceCache.Clear();
			}

			Typeface typeface = ResolveTypeface(fontStyle);
			TextMetrics metrics = GetTextMetrics("M", typeface, fontStyle, size, inlay);
			advance = metrics.Width;
			monospaceAdvanceCache[key] = advance;
			return advance;
		}

		private bool TryGetGlyphRun(string text, Typeface typeface, int fontStyle, float size, out GlyphRun glyphRun) {
			if (!CanUseGlyphFastPathCached(text)) {
				glyphRun = default!;
				return false;
			}
			return TryGetGlyphRun(text, 0, text.Length, typeface, fontStyle, size, allowCache: true, skipFastPathValidation: true, out glyphRun);
		}

		private bool TryGetGlyphRun(
			string text,
			int start,
			int length,
			Typeface typeface,
			int fontStyle,
			float size,
			bool allowCache,
			bool skipFastPathValidation,
			out GlyphRun glyphRun) {
			glyphRun = default!;
			if (string.IsNullOrEmpty(text) || length <= 0 || start < 0 || start + length > text.Length) {
				return false;
			}

			ReadOnlySpan<char> slice = text.AsSpan(start, length);
			if (!skipFastPathValidation && !CanUseGlyphFastPath(slice)) {
				return false;
			}

			if (typeface.GlyphTypeface is not IGlyphTypeface glyphTypeface) {
				return false;
			}

			bool shouldCache = allowCache && length <= MaxCacheableTextLength;
			var key = shouldCache ? new GlyphRunKey(text, start, length, fontStyle, QuantizeSize(size)) : default;
			if (shouldCache && glyphRunCache.TryGetValue(key, out GlyphRun? cached)) {
				glyphRun = cached;
				return true;
			}

			if (shouldCache && glyphRunCache.Count >= MaxGlyphRunCacheEntries) {
				glyphRunCache.Clear();
			}

			ushort[] glyphIndices = new ushort[length];
			for (int i = 0; i < length; i++) {
				glyphIndices[i] = glyphTypeface.GetGlyph(slice[i]);
			}

			glyphRun = new GlyphRun(glyphTypeface, size, text.AsMemory(start, length), glyphIndices, new Point(0, 0), 0);
			if (shouldCache) {
				glyphRunCache[key] = glyphRun;
			}
			return true;
		}

		private TextMetrics GetTextMetrics(string text, Typeface typeface, int fontStyle, float size, bool inlay) {
			string safeText = string.IsNullOrEmpty(text) ? "M" : text;
			bool shouldCache = safeText.Length <= MaxCacheableTextLength;
			var key = shouldCache ? new TextMetricsKey(safeText, fontStyle, QuantizeSize(size), inlay) : default;
			if (shouldCache && textMetricsCache.TryGetValue(key, out TextMetrics metrics)) {
				return string.IsNullOrEmpty(text) ? metrics with { Width = 0f } : metrics;
			}

			if (shouldCache && textMetricsCache.Count >= MaxTextMetricsCacheEntries) {
				textMetricsCache.Clear();
			}

			var formatted = new FormattedText(
				safeText,
				CultureInfo.CurrentCulture,
				FlowDirection.LeftToRight,
				typeface,
				size,
				GetBrush(MeasureColorArgb));
			metrics = new TextMetrics(
				(float)Math.Max(formatted.Width, formatted.WidthIncludingTrailingWhitespace),
				(float)formatted.Baseline,
				Math.Max(1f, (float)formatted.Height));
			if (shouldCache) {
				textMetricsCache[key] = metrics;
			}
			return string.IsNullOrEmpty(text) ? metrics with { Width = 0f } : metrics;
		}

		private FormattedText GetFormattedText(string text, Typeface typeface, int fontStyle, float size, int argb, bool inlay) {
			bool shouldCache = text.Length <= MaxCacheableTextLength;
			var key = shouldCache ? new FormattedTextKey(text, fontStyle, QuantizeSize(size), argb, inlay) : default;
			if (shouldCache && formattedTextCache.TryGetValue(key, out FormattedText? cachedFormatted)) {
				return cachedFormatted;
			}

			if (shouldCache && formattedTextCache.Count >= MaxFormattedTextCacheEntries) {
				formattedTextCache.Clear();
			}

			FormattedText formatted = new FormattedText(
				text,
				CultureInfo.CurrentCulture,
				FlowDirection.LeftToRight,
				typeface,
				size,
				GetBrush(argb));
			if (shouldCache) {
				formattedTextCache[key] = formatted;
			}
			return formatted;
		}

		private LayoutMetrics GetLayoutMetrics(Typeface typeface, int fontStyle, float size, bool inlay) {
			var key = new LayoutMetricsKey(fontStyle, QuantizeSize(size), inlay);
			if (layoutMetricsCache.TryGetValue(key, out LayoutMetrics metrics)) {
				return metrics;
			}

			if (layoutMetricsCache.Count >= MaxAdvanceCacheEntries * 4) {
				layoutMetricsCache.Clear();
			}

			TextMetrics textMetrics = GetTextMetrics("M", typeface, fontStyle, size, inlay);
			metrics = new LayoutMetrics(textMetrics.Baseline, textMetrics.Height);
			layoutMetricsCache[key] = metrics;
			return metrics;
		}

		private float Snap(float value) => MathF.Round(value * scale) / scale;

		private double Snap(double value) => Math.Round(value * scale) / scale;

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) {
				return 0f;
			}

			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveTextSize;
				if (IsProbablyMonospace() && CanUseMonospaceFastPath(text)) {
					return text.Length * GetMonospaceAdvance(fontStyle, textSize, inlay: false);
				}
				return GetTextMetrics(text, ResolveTypeface(fontStyle), fontStyle, textSize, inlay: false).Width;
			} catch {
				return text.Length * EffectiveTextSize * 0.6f;
			} finally {
				if (collect) {
					measurePerfStats.RecordText(Stopwatch.GetTimestamp() - start, text.Length, fontStyle);
				}
			}
		}

		private float OnMeasureInlayText(string text) {
			string safe = string.IsNullOrEmpty(text) ? "M" : text;
			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveInlaySize;
				if (IsProbablyMonospace() && CanUseMonospaceFastPath(safe)) {
					return safe.Length * GetMonospaceAdvance(0, textSize, inlay: true);
				}
				return GetTextMetrics(safe, regularTypeface, 0, textSize, inlay: true).Width;
			} catch {
				return safe.Length * EffectiveInlaySize * 0.6f;
			} finally {
				if (collect) {
					measurePerfStats.RecordInlay(Stopwatch.GetTimestamp() - start, safe.Length);
				}
			}
		}

		private float OnMeasureIconWidth(int iconId) {
			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				if (iconId == 0) {
					return EffectiveTextSize;
				}
				if (iconWidthCache.TryGetValue(iconId, out float cachedWidth)) {
					return cachedWidth;
				}
				if (TryGetIconImage(iconId, out IImage? bmp) && bmp != null) {
					float width = (float)bmp.Size.Width;
					iconWidthCache[iconId] = width;
					return width;
				}
				return EffectiveTextSize;
			} finally {
				if (collect) {
					measurePerfStats.RecordIcon(Stopwatch.GetTimestamp() - start);
				}
			}
		}

		private void OnGetFontMetrics(IntPtr arrPtr, UIntPtr length) {
			if (arrPtr == IntPtr.Zero || length.ToUInt64() < 2) {
				return;
			}
			float ascent;
			float descent;
			try {
				TextMetrics metrics = GetTextMetrics("M", regularTypeface, 0, EffectiveTextSize, inlay: false);
				ascent = metrics.Baseline;
				descent = Math.Max(0.1f, metrics.Height - metrics.Baseline);
			} catch {
				ascent = EffectiveTextSize * 0.8f;
				descent = EffectiveTextSize * 0.2f;
			}
			float[] metricValues = { -ascent, descent };
			System.Runtime.InteropServices.Marshal.Copy(metricValues, 0, arrPtr, 2);
		}

		private Typeface ResolveTypeface(int fontStyle) {
			bool bold = (fontStyle & FontStyleBold) != 0;
			bool italic = (fontStyle & FontStyleItalic) != 0;
			if (bold && italic) {
				return boldItalicTypeface;
			}
			if (bold) {
				return boldTypeface;
			}
			if (italic) {
				return italicTypeface;
			}
			return regularTypeface;
		}

		private ISolidColorBrush GetBrush(int argb) {
			if (!brushCache.TryGetValue(argb, out var brush)) {
				brush = new SolidColorBrush(Color.FromUInt32(unchecked((uint)argb)));
				brushCache[argb] = brush;
			}
			return brush;
		}

		private bool TryGetIconImage(int iconId, out IImage? image) {
			image = null;
			if (iconId == 0 || iconProvider == null) {
				return false;
			}

			if (iconCache.TryGetValue(iconId, out IImage? cached)) {
				image = cached;
				return cached != null;
			}

			if (iconCache.Count >= 128) {
				iconCache.Clear();
				iconWidthCache.Clear();
			}

			image = iconProvider.GetIcon(iconId) as IImage;
			iconCache[iconId] = image;
			return image != null;
		}

		private void DrawCurrentLine(DrawingContext context, EditorRenderModel model, double viewportWidth) {
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.NONE) {
				return;
			}
			if (model.CurrentLine.Y < 0 || viewportWidth <= 0) {
				return;
			}
			double lineHeight = model.Cursor.Height > 0 ? model.Cursor.Height : Math.Max(1f, EffectiveTextSize);
			var rect = new Rect(0, Snap(model.CurrentLine.Y), viewportWidth, Snap(lineHeight));
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.BORDER) {
				context.DrawRectangle(null, GetPen(GetCurrentLineBorderColor(), 1), rect);
				return;
			}
			context.FillRectangle(GetBrush((int)theme.CurrentLineColor), rect);
		}

		private void DrawSelections(DrawingContext context, EditorRenderModel model) {
			if (model.SelectionRects == null) {
				return;
			}
			var brush = GetBrush((int)theme.SelectionColor);
			foreach (var rect in model.SelectionRects) {
				context.FillRectangle(brush, new Rect(Snap(rect.Origin.X), Snap(rect.Origin.Y), Math.Max(0, Snap(rect.Width)), Math.Max(0, Snap(rect.Height))));
			}
		}

		private void DrawSelectionHandles(DrawingContext context, EditorRenderModel model) {
			DrawSelectionHandle(context, model, model.SelectionStartHandle, isStart: true);
			DrawSelectionHandle(context, model, model.SelectionEndHandle, isStart: false);
		}

		private void DrawSelectionHandle(DrawingContext context, EditorRenderModel model, SelectionHandle handle, bool isStart) {
			if (!handle.Visible || handle.Height <= 0f) {
				return;
			}

			double drawScale = Math.Max(0.7f, scale);
			double lineWidth = Snap(HandleLineWidth * drawScale);
			double dropRadius = Snap(HandleDropRadius * drawScale);
			double centerDistance = Snap(HandleCenterDistance * drawScale);
			double x = Snap(handle.Position.X);
			if (model.GutterVisible) {
				double gutterRight = Math.Max(0, Snap(model.SplitX));
				double handleGap = Snap(Math.Max(2.0, drawScale * 1.4));
				x = Math.Max(x, gutterRight + handleGap);
			}
			double y = Snap(handle.Position.Y);
			double height = Math.Max(1, Snap(handle.Height));
			double tipX = x;
			double tipY = y + height;

			var brush = GetBrush((int)theme.CursorColor);
			context.FillRectangle(brush, new Rect(tipX - lineWidth * 0.5, y, lineWidth, height));

			double angleRad = isStart ? Math.PI / 4.0 : -Math.PI / 4.0;
			double cos = Math.Cos(angleRad);
			double sin = Math.Sin(angleRad);

			double cx = tipX;
			double cy = tipY + centerDistance;
			double k = dropRadius * HandleCurveKappa;

			Point Rotate(double px, double py) {
				double dx = px - tipX;
				double dy = py - tipY;
				return new Point(tipX + dx * cos - dy * sin, tipY + dx * sin + dy * cos);
			}

			var path = new StreamGeometry();
			using (var geo = path.Open()) {
				Point tip = new Point(tipX, tipY);
				geo.BeginFigure(tip, true);
				geo.CubicBezierTo(
					Rotate(tipX, tipY + centerDistance * 0.4),
					Rotate(cx - dropRadius, cy - dropRadius * 0.8),
					Rotate(cx - dropRadius, cy));
				geo.CubicBezierTo(
					Rotate(cx - dropRadius, cy + k),
					Rotate(cx - k, cy + dropRadius),
					Rotate(cx, cy + dropRadius));
				geo.CubicBezierTo(
					Rotate(cx + k, cy + dropRadius),
					Rotate(cx + dropRadius, cy + k),
					Rotate(cx + dropRadius, cy));
				geo.CubicBezierTo(
					Rotate(cx + dropRadius, cy - dropRadius * 0.8),
					Rotate(tipX, tipY + centerDistance * 0.4),
					tip);
				geo.EndFigure(true);
			}
			context.DrawGeometry(brush, null, path);
		}

		private void DrawVisualLines(DrawingContext context, EditorRenderModel model, Rect contentClip) {
			if (model.VisualLines == null) {
				return;
			}
			float clipLeft = (float)contentClip.X;
			float clipRight = (float)(contentClip.X + contentClip.Width);
			bool monospaceFastPath = IsProbablyMonospace();
			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.VisualLines);
			int cachedFontStyle = int.MinValue;
			Typeface cachedTypeface = regularTypeface;

			for (int lineIndex = 0; lineIndex < lines.Length; lineIndex++) {
				List<VisualRun>? runsList = lines[lineIndex].Runs;
				if (runsList == null || runsList.Count == 0) {
					continue;
				}
				Span<VisualRun> runs = CollectionsMarshal.AsSpan(runsList);
				for (int i = 0; i < runs.Length; i++) {
					ref readonly VisualRun run = ref runs[i];
					if (run.Type == VisualRunType.NEWLINE) {
						continue;
					}
					string text = run.Text ?? string.Empty;
					int textColor = ResolveRunTextColor(run);
					float drawX = Snap(run.X);
					float drawWidth = Math.Max(1f, Snap(run.Width));

					if (drawX >= clipRight || drawX + drawWidth <= clipLeft) {
						continue;
					}

					bool isInlay = run.Type == VisualRunType.INLAY_HINT;
					bool drawWhitespaceText = run.Type is not (VisualRunType.WHITESPACE or VisualRunType.TAB);
					bool hasBackground = run.Style.BackgroundColor != 0;
					bool hasStrike = (run.Style.FontStyle & FontStyleStrike) != 0;
					bool isActiveCodeLens = run.Type == VisualRunType.CODELENS && run.Active;
					bool needsLayout = hasBackground || hasStrike || isInlay || isActiveCodeLens;
					float textSize = run.Type == VisualRunType.INLAY_HINT ? EffectiveInlaySize : EffectiveTextSize;
					Typeface typeface = default!;
					bool hasTypeface = false;
					bool canUseGlyphFastPath = false;
					bool canUseHorizontalClip = false;
					if (drawWhitespaceText || needsLayout) {
						if (cachedFontStyle == run.Style.FontStyle) {
							typeface = cachedTypeface;
						} else {
							typeface = ResolveTypeface(run.Style.FontStyle);
							cachedFontStyle = run.Style.FontStyle;
							cachedTypeface = typeface;
						}
						hasTypeface = true;
						canUseGlyphFastPath =
							drawWhitespaceText &&
							!isInlay &&
							CanUseGlyphFastPathCached(text);
						canUseHorizontalClip = canUseGlyphFastPath && monospaceFastPath;
					}

					int clippedStartIndex = 0;
					int clippedLength = text.Length;
					bool clippedGlyphText = false;
					LayoutMetrics layout = default;
					float topY = Snap(run.Y);
					float lineHeight = Math.Max(1f, textSize);
					if (needsLayout) {
						layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, run.Type == VisualRunType.INLAY_HINT);
						topY = Snap(run.Y - layout.Baseline);
						lineHeight = layout.Height;
					}

						if (drawWhitespaceText &&
							canUseHorizontalClip &&
							!string.IsNullOrEmpty(text) &&
							drawWidth > clipRight - clipLeft) {
							float advance = GetMonospaceAdvance(run.Style.FontStyle, textSize, inlay: false);
							if (advance > 0f) {
								int startIndex = Math.Max(0, (int)MathF.Floor((clipLeft - drawX) / advance));
								int endIndex = Math.Min(text.Length, (int)MathF.Ceiling((clipRight - drawX) / advance));
								if (endIndex <= startIndex) {
									continue;
								}

								if (startIndex > 0 || endIndex < text.Length) {
									clippedStartIndex = startIndex;
									clippedLength = endIndex - startIndex;
									clippedGlyphText = true;
									drawX = Snap(drawX + startIndex * advance);
									drawWidth = Math.Max(1f, Snap(clippedLength * advance));
								}
							}
						}

					if (hasBackground) {
						float backgroundX = Math.Max(drawX, clipLeft);
						float backgroundRight = Math.Min(drawX + drawWidth, clipRight);
						context.FillRectangle(
							GetBrush(run.Style.BackgroundColor),
							new Rect(backgroundX, topY, Math.Max(0f, backgroundRight - backgroundX), Snap(lineHeight)));
					}

					if (run.Type == VisualRunType.INLAY_HINT &&
						run.IconId != 0 &&
						TryGetIconImage(run.IconId, out IImage? iconBmp) &&
						iconBmp != null) {
						var iconRect = new Rect(drawX, topY, drawWidth, Snap(lineHeight));
						context.DrawImage(iconBmp, new Rect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), iconRect);
						continue;
					}

						if (!drawWhitespaceText || text.Length == 0) {
							continue;
						}

						GlyphRun glyphRun = default!;
						bool usedGlyphRun = canUseGlyphFastPath &&
							TryGetGlyphRun(
								text,
								clippedStartIndex,
								clippedLength,
								typeface,
								run.Style.FontStyle,
								textSize,
								allowCache: !clippedGlyphText,
								skipFastPathValidation: canUseGlyphFastPath,
								out glyphRun);
						if (!usedGlyphRun) {
							if (!hasTypeface) {
								typeface = ResolveTypeface(run.Style.FontStyle);
								hasTypeface = true;
						}
						if (!needsLayout) {
							layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, inlay: false);
							topY = Snap(run.Y - layout.Baseline);
								lineHeight = layout.Height;
								needsLayout = true;
							}
							string drawText = clippedGlyphText
								? text.Substring(clippedStartIndex, clippedLength)
								: text;
							FormattedText? formatted = drawText.Length > 0
								? GetFormattedText(drawText, typeface, run.Style.FontStyle, textSize, textColor, isInlay)
								: null;
							if (formatted == null) {
								continue;
							}
							context.DrawText(formatted, new Point(drawX, topY));
						} else {
							glyphRun.BaselineOrigin = new Point(drawX, Snap(run.Y));
							context.DrawGlyphRun(GetBrush(textColor), glyphRun);
						}

					if (text.Length == 0) {
						continue;
					}

					if (hasStrike) {
						if (!needsLayout) {
							layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, inlay: false);
						}
						float y = Snap(topY + layout.Baseline * 0.5f);
						context.DrawLine(GetPen(textColor, 1), new Point(drawX, y), new Point(drawX + drawWidth, y));
					}

					if (isActiveCodeLens) {
						float underlineY = ComputeCodeLensUnderlineY(topY, layout);
						context.DrawLine(GetPen(textColor, 1), new Point(drawX, underlineY), new Point(drawX + drawWidth, underlineY));
					}
				}
			}
		}

		private float ComputeCodeLensUnderlineY(float topY, LayoutMetrics layout) {
			float gap = Math.Clamp(layout.Height * 0.14f, 2.0f, 3.0f);
			return Snap(topY + layout.Height + gap);
		}

		private void DrawCursor(DrawingContext context, EditorRenderModel model) {
			if (!model.Cursor.Visible) {
				return;
			}
			var rect = new Rect(Snap(model.Cursor.Position.X), Snap(model.Cursor.Position.Y), 1.5, Math.Max(1, Snap(model.Cursor.Height)));
			context.FillRectangle(GetBrush((int)theme.CursorColor), rect);
		}

		private void DrawGutterOverlay(DrawingContext context, EditorRenderModel model, double viewportHeight) {
			if (model.SplitX <= 0) {
				return;
			}

			context.FillRectangle(GetBrush((int)theme.BackgroundColor), new Rect(0, 0, model.SplitX, viewportHeight));
			DrawCurrentLine(context, model, model.SplitX);
			if (model.SplitLineVisible) {
				DrawSplitLine(context, model, viewportHeight);
			}
		}

		private void DrawLineNumbers(DrawingContext context, EditorRenderModel model) {
			if (!model.GutterVisible || model.VisualLines == null) {
				return;
			}
			var gutterIcons = model.GutterIcons;
			var foldMarkers = model.FoldMarkers;
			int iconCount = gutterIcons?.Count ?? 0;
			int markerCount = foldMarkers?.Count ?? 0;
			int iconCursor = 0;
			int markerCursor = 0;
			bool overlayMode = model.MaxGutterIcons == 0;
			int activeLogicalLine = model.Cursor.TextPosition.Line;
			int normalLineNumberColor = (int)theme.LineNumberColor;
			int activeLineNumberColor = GetActiveLineNumberColor();
			LayoutMetrics lineNumberMetrics = GetLayoutMetrics(regularTypeface, 0, EffectiveLineNumberSize, inlay: false);
			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.VisualLines);
			for (int lineIndex = 0; lineIndex < lines.Length; lineIndex++) {
				ref readonly VisualLine line = ref lines[lineIndex];
				if (!line.OwnsGutterSemantics) {
					continue;
				}
				int logicalLine = line.LogicalLine;
				bool isCurrentLine = logicalLine == activeLogicalLine;

				while (iconCursor < iconCount && gutterIcons![iconCursor].LogicalLine < logicalLine) {
					iconCursor++;
				}
				int iconStart = iconCursor;
				while (iconCursor < iconCount && gutterIcons![iconCursor].LogicalLine == logicalLine) {
					iconCursor++;
				}
				int iconEnd = iconCursor;
				bool hasIcons = iconEnd > iconStart && iconProvider != null;

				if (overlayMode && hasIcons) {
					DrawGutterIconItem(context, gutterIcons![iconStart]);
				} else {
					string text = GetLineNumberText(logicalLine + 1);
					int lineNumberColor = isCurrentLine ? activeLineNumberColor : normalLineNumberColor;
					float drawX = Snap(line.LineNumberPosition.X);
					float baselineY = Snap(line.LineNumberPosition.Y);
					if (TryGetGlyphRun(text, regularTypeface, 0, EffectiveLineNumberSize, out GlyphRun glyphRun)) {
						glyphRun.BaselineOrigin = new Point(drawX, baselineY);
						context.DrawGlyphRun(GetBrush(lineNumberColor), glyphRun);
					} else {
						FormattedText formatted = GetFormattedText(text, regularTypeface, 0, EffectiveLineNumberSize, lineNumberColor, inlay: false);
						float topY = Snap(line.LineNumberPosition.Y - lineNumberMetrics.Baseline);
						context.DrawText(formatted, new Point(drawX, topY));
					}

					if (hasIcons && !overlayMode) {
						for (int i = iconStart; i < iconEnd; i++) {
							DrawGutterIconItem(context, gutterIcons![i]);
						}
					}
				}

				while (markerCursor < markerCount && foldMarkers![markerCursor].LogicalLine < logicalLine) {
					markerCursor++;
				}
				FoldMarkerRenderItem? foldMarker = null;
				while (markerCursor < markerCount && foldMarkers![markerCursor].LogicalLine == logicalLine) {
					if (foldMarker == null) {
						foldMarker = foldMarkers[markerCursor];
					}
					markerCursor++;
				}
				if (foldMarker != null) {
					DrawFoldMarkerItem(context, foldMarker.Value, isCurrentLine ? activeLineNumberColor : normalLineNumberColor);
				}
			}
		}

		private void DrawGutterIconItem(DrawingContext context, GutterIconRenderItem item) {
			if (item.Width <= 0f || item.Height <= 0f) {
				return;
			}
			if (!TryGetIconImage(item.IconId, out IImage? iconBmp) || iconBmp == null) {
				return;
			}

			var dst = new Rect(Snap(item.Origin.X), Snap(item.Origin.Y), Math.Max(0, Snap(item.Width)), Math.Max(0, Snap(item.Height)));
			if (dst.Width <= 0 || dst.Height <= 0) {
				return;
			}
			context.DrawImage(iconBmp, new Rect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), dst);
		}

		private void DrawFoldMarkerItem(DrawingContext context, FoldMarkerRenderItem item, int color) {
			if (item.Width <= 0f || item.Height <= 0f || item.FoldState == FoldState.NONE) {
				return;
			}

			float centerX = item.Origin.X + item.Width * 0.5f;
			float centerY = item.Origin.Y + item.Height * 0.5f;
			float halfSize = Math.Min(item.Width, item.Height) * 0.28f;
			float strokeWidth = Math.Max(1f, item.Height * 0.1f);
			var pen = GetPen(color, strokeWidth, PenLineCap.Round, PenLineJoin.Round);

			Point p1;
			Point p2;
			Point p3;
			if (item.FoldState == FoldState.COLLAPSED) {
				p1 = new Point(Snap(centerX - halfSize * 0.5f), Snap(centerY - halfSize));
				p2 = new Point(Snap(centerX + halfSize * 0.5f), Snap(centerY));
				p3 = new Point(Snap(centerX - halfSize * 0.5f), Snap(centerY + halfSize));
			} else {
				p1 = new Point(Snap(centerX - halfSize), Snap(centerY - halfSize * 0.5f));
				p2 = new Point(Snap(centerX), Snap(centerY + halfSize * 0.5f));
				p3 = new Point(Snap(centerX + halfSize), Snap(centerY - halfSize * 0.5f));
			}
			context.DrawLine(pen, p1, p2);
			context.DrawLine(pen, p2, p3);
		}

		private void DrawSplitLine(DrawingContext context, EditorRenderModel model, double viewportHeight) {
			if (!model.SplitLineVisible || model.SplitX <= 0) {
				return;
			}
			var pen = GetPen((int)theme.SplitLineColor, 1);
			double splitX = Snap(model.SplitX);
			context.DrawLine(pen, new Point(splitX, 0), new Point(splitX, viewportHeight));
		}

		private void DrawScrollbars(DrawingContext context, EditorRenderModel model) {
			DrawScrollbar(context, model.VerticalScrollbar);
			DrawScrollbar(context, model.HorizontalScrollbar);
		}

		private void DrawScrollbar(DrawingContext context, ScrollbarModel model) {
			if (!model.Visible || model.Alpha <= 0) {
				return;
			}

			byte alpha = (byte)Math.Clamp(model.Alpha * 255, 0, 255);
			int trackColor = ((int)theme.ScrollbarTrackColor & 0x00FFFFFF) | (alpha << 24);
			int thumbColor = ((int)(model.ThumbActive ? theme.ScrollbarThumbActiveColor : theme.ScrollbarThumbColor) & 0x00FFFFFF) | (alpha << 24);

			context.FillRectangle(GetBrush(trackColor), new Rect(Snap(model.Track.Origin.X), Snap(model.Track.Origin.Y), Snap(model.Track.Width), Snap(model.Track.Height)));
			context.FillRectangle(GetBrush(thumbColor), new Rect(Snap(model.Thumb.Origin.X), Snap(model.Thumb.Origin.Y), Snap(model.Thumb.Width), Snap(model.Thumb.Height)));
		}

		private int GetActiveLineNumberColor() {
			int argb = (int)theme.CurrentLineNumberColor;
			if (argb == 0) {
				argb = (int)theme.LineNumberColor;
			}
			return (argb & 0x00FFFFFF) | unchecked((int)0xFF000000);
		}

		private int ResolveRunTextColor(VisualRun run) {
			if (run.Type == VisualRunType.INLAY_HINT) {
				return (int)theme.InlayHintTextColor;
			}
			if (run.Type == VisualRunType.CODELENS) {
				return run.Active ? GetActiveLineNumberColor() : (int)theme.InlayHintTextColor;
			}
			return run.Style.Color != 0
				? run.Style.Color
				: (int)theme.TextColor;
		}

		private string GetLineNumberText(int logicalLineNumber) {
			if (lineNumberTextCache.TryGetValue(logicalLineNumber, out string? cached)) {
				return cached;
			}

			if (lineNumberTextCache.Count >= MaxLineNumberTextCacheEntries) {
				lineNumberTextCache.Clear();
			}

			string value = logicalLineNumber.ToString(CultureInfo.InvariantCulture);
			lineNumberTextCache[logicalLineNumber] = value;
			return value;
		}

		private int GetCurrentLineBorderColor() {
			int argb = (int)theme.CurrentLineColor;
			if (argb == 0) {
				argb = (int)theme.LineNumberColor;
			}
			int alpha = (argb >> 24) & 0xFF;
			if (alpha < 0xA0) {
				argb = (argb & 0x00FFFFFF) | unchecked((int)0xA0000000);
			}
			return argb;
		}

		private static Rect GetContentClipRect(EditorRenderModel model, Size viewportSize) {
			double left = model.GutterVisible && model.GutterSticky
				? Math.Max(0, model.SplitX)
				: 0;
			double width = Math.Max(0, viewportSize.Width - left);
			return new Rect(left, 0, width, Math.Max(0, viewportSize.Height));
		}

		private Pen GetPen(int argb, double thickness, PenLineCap lineCap = PenLineCap.Flat, PenLineJoin lineJoin = PenLineJoin.Miter) {
			int thicknessKey = QuantizeSize((float)thickness);
			var key = new PenKey(argb, thicknessKey, lineCap, lineJoin);
			if (penCache.TryGetValue(key, out Pen? pen)) {
				return pen;
			}

			pen = new Pen(GetBrush(argb), thickness, lineCap: lineCap, lineJoin: lineJoin);
			penCache[key] = pen;
			return pen;
		}
	}
}
