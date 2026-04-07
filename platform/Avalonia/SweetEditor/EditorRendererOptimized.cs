using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Media;

namespace SweetEditor {
	internal sealed partial class EditorRendererOptimized : IDisposable {
		private const float DefaultTextSizeDip = 15.0f;
		private const float InlayTextSizeRatio = 0.86f;
		private const float LineNumberTextSizeRatio = 0.85f;
		private const int MaxCacheableTextLength = 256;
		private const int MeasureColorArgb = unchecked((int)0xFF000000);
		private const int FontStyleBold = 1;
		private const int FontStyleItalic = 1 << 1;
		private const int FontStyleStrike = 1 << 2;
		private const float HandleLineWidth = 1.2f;
		private const float HandleDropRadius = 7.0f;
		private const float HandleCenterDistance = 16.0f;
		private const float HandleCurveKappa = 0.5522f;

		private readonly LruCache<int, ISolidColorBrush> _brushCache = new(4096);
		private readonly LruCacheLongKey<Pen> _penCache = new(2048);
		private readonly GlyphRunCache _glyphRunCache = new();
		private readonly LruCache<TextMetricsKey, TextMetrics> _textMetricsCache = new(8192);
		private readonly LruCache<LayoutMetricsKey, LayoutMetrics> _layoutMetricsCache = new(512);
		private readonly LruCache<AdvanceKey, float> _monospaceAdvanceCache = new(128);
		private readonly LruCache<int, string> _lineNumberTextCache = new(16384);
		private readonly LruCache<int, IImage?> _iconCache = new(256);
		private readonly LruCache<int, float> _iconWidthCache = new(256);
		private readonly FrameRateMonitor _frameRateMonitor = new();
		private readonly RenderOptimizer _renderOptimizer = new();
		private readonly MeasurePerfStats _measurePerfStats = new();
		private readonly PerfOverlay _perfOverlay = new();

		private EditorTheme _theme;
		private EditorIconProvider? _iconProvider;
		private string _fontFamily = "monospace";
		private float _textSizeDip = DefaultTextSizeDip;
		private float _scale = 1.0f;
		private float _platformDensity = 1.0f;

		private Typeface _regularTypeface = new("monospace");
		private Typeface _boldTypeface = new("monospace", FontStyle.Normal, FontWeight.Bold);
		private Typeface _italicTypeface = new("monospace", FontStyle.Italic, FontWeight.Normal);
		private Typeface _boldItalicTypeface = new("monospace", FontStyle.Italic, FontWeight.Bold);

		private int _cachedFontStyle = int.MinValue;
		private Typeface _cachedTypeface;

		private readonly record struct TextMetricsKey(string Text, int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct LayoutMetricsKey(int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct AdvanceKey(int FontStyle, int SizeKey, bool Inlay);

		private readonly record struct TextMetrics(float Width, float Baseline, float Height);

		private readonly record struct LayoutMetrics(float Baseline, float Height);

		public EditorRendererOptimized(EditorTheme theme) {
			_theme = theme;
			_cachedTypeface = _regularTypeface;
			UpdateTypefaces();
		}

		public EditorTheme Theme => _theme;
		public float EditorTextSize => _textSizeDip;
		public string FontFamily => _fontFamily;
		public FrameRateMonitor FrameRateMonitor => _frameRateMonitor;
		public RenderOptimizer RenderOptimizer => _renderOptimizer;

		public EditorCore.TextMeasurer CreateTextMeasurer() {
			return new EditorCore.TextMeasurer {
				MeasureTextWidth = OnMeasureText,
				MeasureInlayHintWidth = OnMeasureInlayText,
				MeasureIconWidth = OnMeasureIconWidth,
				GetFontMetrics = OnGetFontMetrics,
			};
		}

		public MeasurePerfStats GetMeasurePerfStats() => _measurePerfStats;
		public PerfOverlay GetPerfOverlay() => _perfOverlay;

		public void SetPerfOverlayEnabled(bool enabled) {
			_perfOverlay.SetEnabled(enabled);
		}

		public bool IsPerfOverlayEnabled() => _perfOverlay.IsEnabled();

		public void BeginFrameMeasureStats() {
			if (_perfOverlay.IsEnabled()) {
				_measurePerfStats.Reset();
			}
			_frameRateMonitor.BeginFrame();
		}

		public void RecordInputPerf(string tag, float inputMs) {
			if (_perfOverlay.IsEnabled()) {
				_perfOverlay.RecordInput(tag, inputMs);
			}
		}

		public void ApplyTheme(EditorTheme theme) {
			_theme = theme;
		}

		public void SetEditorIconProvider(EditorIconProvider? provider) {
			_iconProvider = provider;
			_iconCache.Clear();
			_iconWidthCache.Clear();
		}

		public void SetScale(float scale) {
			_scale = Math.Max(0.1f, scale);
			ClearTextCaches();
		}

		public void SetPlatformDensity(float density) {
			_platformDensity = Math.Max(0.5f, density);
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
			_textSizeDip = Math.Max(1f, sizeDip);
			ClearTextCaches();
		}

		public void SetFontFamily(string? family) {
			if (string.IsNullOrWhiteSpace(family)) {
				return;
			}
			_fontFamily = family.Trim();
			UpdateTypefaces();
		}

		public void Render(DrawingContext context, EditorRenderModel model, Size viewportSize, float buildMs) {
			PerfStepRecorder? drawPerf = _perfOverlay.IsEnabled() ? PerfStepRecorder.Start() : null;
			long drawStart = drawPerf != null ? Stopwatch.GetTimestamp() : 0;

			RenderBackground(context, viewportSize);
			drawPerf?.Mark(PerfStepRecorder.STEP_CLEAR);

			RenderCurrentLine(context, model, viewportSize.Width);
			drawPerf?.Mark(PerfStepRecorder.STEP_CURRENT);

			Rect contentClip = GetContentClipRect(model, viewportSize);
			using (context.PushClip(contentClip)) {
				RenderSelections(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_SELECTION);
				RenderVisualLines(context, model, contentClip);
				drawPerf?.Mark(PerfStepRecorder.STEP_LINES);
				RenderCursor(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_CURSOR);
			}

			RenderGutterOverlay(context, model, viewportSize.Height);
			RenderLineNumbers(context, model);
			drawPerf?.Mark(PerfStepRecorder.STEP_GUTTER);
			RenderSelectionHandles(context, model);

			RenderScrollbars(context, model);
			drawPerf?.Mark(PerfStepRecorder.STEP_SCROLLBARS);

			float drawMs = 0f;
			if (drawPerf != null) {
				drawMs = (float)((Stopwatch.GetTimestamp() - drawStart) * 1000.0 / Stopwatch.Frequency);
				drawPerf.Finish();
				float totalMs = Math.Max(0f, buildMs) + drawMs;
				_perfOverlay.RecordFrame(buildMs, drawMs, totalMs, drawPerf, _measurePerfStats);
				_perfOverlay.Render(context, viewportSize);
			}

			_frameRateMonitor.EndFrame(buildMs, drawMs);
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private void RenderBackground(DrawingContext context, Size viewportSize) {
			context.FillRectangle(GetBrush((int)_theme.BackgroundColor), new Rect(0, 0, viewportSize.Width, viewportSize.Height));
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private void RenderCurrentLine(DrawingContext context, EditorRenderModel model, double viewportWidth) {
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.NONE || model.CurrentLine.Y < 0 || viewportWidth <= 0) {
				return;
			}

			double lineHeight = model.Cursor.Height > 0 ? model.Cursor.Height : Math.Max(1f, EffectiveTextSize);
			var rect = new Rect(0, Snap(model.CurrentLine.Y), viewportWidth, Snap(lineHeight));

			if (model.CurrentLineRenderMode == CurrentLineRenderMode.BORDER) {
				context.DrawRectangle(null, GetPen(GetCurrentLineBorderColor(), 1), rect);
			} else {
				context.FillRectangle(GetBrush((int)_theme.CurrentLineColor), rect);
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private void RenderSelections(DrawingContext context, EditorRenderModel model) {
			if (model.SelectionRects == null) {
				return;
			}

			var brush = GetBrush((int)_theme.SelectionColor);
			foreach (var rect in model.SelectionRects) {
				context.FillRectangle(brush, new Rect(
					Snap(rect.Origin.X),
					Snap(rect.Origin.Y),
					Math.Max(0, Snap(rect.Width)),
					Math.Max(0, Snap(rect.Height))));
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private void RenderCursor(DrawingContext context, EditorRenderModel model) {
			if (!model.Cursor.Visible) {
				return;
			}

			var rect = new Rect(
				Snap(model.Cursor.Position.X),
				Snap(model.Cursor.Position.Y),
				1.5,
				Math.Max(1, Snap(model.Cursor.Height)));
			context.FillRectangle(GetBrush((int)_theme.CursorColor), rect);
		}

		private void RenderVisualLines(DrawingContext context, EditorRenderModel model, Rect contentClip) {
			if (model.VisualLines == null) {
				return;
			}

			float clipLeft = (float)contentClip.X;
			float clipRight = (float)(contentClip.X + contentClip.Width);
			bool monospaceFastPath = IsProbablyMonospace();

			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.VisualLines);

			for (int lineIndex = 0; lineIndex < lines.Length; lineIndex++) {
				List<VisualRun>? runsList = lines[lineIndex].Runs;
				if (runsList == null || runsList.Count == 0) {
					continue;
				}

				Span<VisualRun> runs = CollectionsMarshal.AsSpan(runsList);
				RenderVisualRuns(context, runs, clipLeft, clipRight, monospaceFastPath);
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveOptimization)]
		private void RenderVisualRuns(DrawingContext context, Span<VisualRun> runs, float clipLeft, float clipRight, bool monospaceFastPath) {
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
				bool needsLayout = hasBackground || hasStrike || isInlay;
				float textSize = run.Type == VisualRunType.INLAY_HINT ? EffectiveInlaySize : EffectiveTextSize;

				Typeface typeface = GetTypefaceCached(run.Style.FontStyle);
				bool canUseGlyphFastPath = drawWhitespaceText && !isInlay && CanUseGlyphFastPathCached(text);
				bool canUseHorizontalClip = canUseGlyphFastPath && monospaceFastPath;

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

				if (drawWhitespaceText && canUseHorizontalClip && !string.IsNullOrEmpty(text) && drawWidth > clipRight - clipLeft) {
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

				if (run.Type == VisualRunType.INLAY_HINT && run.IconId != 0 && TryGetIconImage(run.IconId, out IImage? iconBmp) && iconBmp != null) {
					var iconRect = new Rect(drawX, topY, drawWidth, Snap(lineHeight));
					context.DrawImage(iconBmp, new Rect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), iconRect);
					continue;
				}

				if (!drawWhitespaceText || text.Length == 0) {
					continue;
				}

				string drawText = clippedGlyphText ? text.Substring(clippedStartIndex, clippedLength) : text;

				if (canUseGlyphFastPath && _glyphRunCache.TryGetOrCreate(drawText, typeface, textSize, run.Style.FontStyle, out GlyphRun? glyphRun) && glyphRun != null) {
					glyphRun.BaselineOrigin = new Point(drawX, Snap(run.Y));
					context.DrawGlyphRun(GetBrush(textColor), glyphRun);
				} else {
					if (!needsLayout) {
						layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, inlay: false);
						topY = Snap(run.Y - layout.Baseline);
						lineHeight = layout.Height;
						needsLayout = true;
					}

					FormattedText? formatted = drawText.Length > 0
						? GetFormattedText(drawText, typeface, run.Style.FontStyle, textSize, textColor, isInlay)
						: null;

					if (formatted != null) {
						context.DrawText(formatted, new Point(drawX, topY));
					}
				}

				if (hasStrike && text.Length > 0) {
					if (!needsLayout) {
						layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, inlay: false);
					}
					float y = Snap(topY + layout.Baseline * 0.5f);
					context.DrawLine(GetPen(textColor, 1), new Point(drawX, y), new Point(drawX + drawWidth, y));
				}
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private Typeface GetTypefaceCached(int fontStyle) {
			if (_cachedFontStyle == fontStyle) {
				return _cachedTypeface;
			}
			_cachedFontStyle = fontStyle;
			_cachedTypeface = ResolveTypeface(fontStyle);
			return _cachedTypeface;
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private Typeface ResolveTypeface(int fontStyle) {
			bool bold = (fontStyle & FontStyleBold) != 0;
			bool italic = (fontStyle & FontStyleItalic) != 0;
			if (bold && italic) return _boldItalicTypeface;
			if (bold) return _boldTypeface;
			if (italic) return _italicTypeface;
			return _regularTypeface;
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private ISolidColorBrush GetBrush(int argb) {
			if (_brushCache.TryGet(argb, out ISolidColorBrush? brush)) {
				return brush!;
			}
			brush = new SolidColorBrush(Color.FromUInt32(unchecked((uint)argb)));
			_brushCache.Set(argb, brush);
			return brush;
		}

		private Pen GetPen(int argb, double thickness, PenLineCap lineCap = PenLineCap.Flat, PenLineJoin lineJoin = PenLineJoin.Miter) {
			long key = ((long)argb << 32) | ((long)QuantizeSize((float)thickness) << 8) | ((int)lineCap << 4) | (int)lineJoin;
			if (_penCache.TryGet(key, out Pen? pen)) {
				return pen!;
			}
			pen = new Pen(GetBrush(argb), thickness, lineCap: lineCap, lineJoin: lineJoin);
			_penCache.Set(key, pen);
			return pen;
		}

		private bool TryGetIconImage(int iconId, out IImage? image) {
			image = null;
			if (iconId == 0 || _iconProvider == null) {
				return false;
			}

			if (_iconCache.TryGet(iconId, out IImage? cached)) {
				image = cached;
				return cached != null;
			}

			image = _iconProvider.GetIcon(iconId) as IImage;
			_iconCache.Set(iconId, image);
			return image != null;
		}

		private float GetMonospaceAdvance(int fontStyle, float size, bool inlay) {
			var key = new AdvanceKey(fontStyle, QuantizeSize(size), inlay);
			if (_monospaceAdvanceCache.TryGet(key, out float advance)) {
				return advance;
			}

			Typeface typeface = ResolveTypeface(fontStyle);
			TextMetrics metrics = GetTextMetrics("M", typeface, fontStyle, size, inlay);
			advance = metrics.Width;
			_monospaceAdvanceCache.Set(key, advance);
			return advance;
		}

		private TextMetrics GetTextMetrics(string text, Typeface typeface, int fontStyle, float size, bool inlay) {
			string safeText = string.IsNullOrEmpty(text) ? "M" : text;
			bool shouldCache = safeText.Length <= MaxCacheableTextLength;
			var key = shouldCache ? new TextMetricsKey(safeText, fontStyle, QuantizeSize(size), inlay) : default;

			if (shouldCache && _textMetricsCache.TryGet(key, out TextMetrics metrics)) {
				return string.IsNullOrEmpty(text) ? metrics with { Width = 0f } : metrics;
			}

			var formatted = new FormattedText(
				safeText,
				System.Globalization.CultureInfo.CurrentCulture,
				FlowDirection.LeftToRight,
				typeface,
				size,
				GetBrush(MeasureColorArgb));

			metrics = new TextMetrics(
				(float)Math.Max(formatted.Width, formatted.WidthIncludingTrailingWhitespace),
				(float)formatted.Baseline,
				Math.Max(1f, (float)formatted.Height));

			if (shouldCache) {
				_textMetricsCache.Set(key, metrics);
			}

			return string.IsNullOrEmpty(text) ? metrics with { Width = 0f } : metrics;
		}

		private LayoutMetrics GetLayoutMetrics(Typeface typeface, int fontStyle, float size, bool inlay) {
			var key = new LayoutMetricsKey(fontStyle, QuantizeSize(size), inlay);
			if (_layoutMetricsCache.TryGet(key, out LayoutMetrics metrics)) {
				return metrics;
			}

			TextMetrics textMetrics = GetTextMetrics("M", typeface, fontStyle, size, inlay);
			metrics = new LayoutMetrics(textMetrics.Baseline, textMetrics.Height);
			_layoutMetricsCache.Set(key, metrics);
			return metrics;
		}

		private FormattedText GetFormattedText(string text, Typeface typeface, int fontStyle, float size, int argb, bool inlay) {
			return new FormattedText(
				text,
				System.Globalization.CultureInfo.CurrentCulture,
				FlowDirection.LeftToRight,
				typeface,
				size,
				GetBrush(argb));
		}

		private bool CanUseGlyphFastPathCached(string text) {
			if (string.IsNullOrEmpty(text)) {
				return false;
			}

			if (text.Length > MaxCacheableTextLength) {
				return CanUseGlyphFastPath(text.AsSpan());
			}

			return CanUseGlyphFastPath(text.AsSpan());
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private static bool CanUseGlyphFastPath(ReadOnlySpan<char> text) {
			for (int i = 0; i < text.Length; i++) {
				char ch = text[i];
				if (ch > 0x7F || ch == '\t' || ch == '\r' || ch == '\n') {
					return false;
				}
			}
			return true;
		}

		private void RenderGutterOverlay(DrawingContext context, EditorRenderModel model, double viewportHeight) {
			if (model.SplitX <= 0) {
				return;
			}

			context.FillRectangle(GetBrush((int)_theme.BackgroundColor), new Rect(0, 0, model.SplitX, viewportHeight));
			RenderCurrentLine(context, model, model.SplitX);
			if (model.SplitLineVisible) {
				RenderSplitLine(context, model, viewportHeight);
			}
		}

		private void RenderLineNumbers(DrawingContext context, EditorRenderModel model) {
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
			int normalLineNumberColor = (int)_theme.LineNumberColor;
			int activeLineNumberColor = GetActiveLineNumberColor();
			LayoutMetrics lineNumberMetrics = GetLayoutMetrics(_regularTypeface, 0, EffectiveLineNumberSize, inlay: false);

			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.VisualLines);
			for (int lineIndex = 0; lineIndex < lines.Length; lineIndex++) {
				ref readonly VisualLine line = ref lines[lineIndex];
				if (line.WrapIndex != 0 || line.IsPhantomLine) {
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
				bool hasIcons = iconEnd > iconStart && _iconProvider != null;

				if (overlayMode && hasIcons) {
					RenderGutterIconItem(context, gutterIcons![iconStart]);
				} else {
					string text = GetLineNumberText(logicalLine + 1);
					int lineNumberColor = isCurrentLine ? activeLineNumberColor : normalLineNumberColor;
					float drawX = Snap(line.LineNumberPosition.X);
					float baselineY = Snap(line.LineNumberPosition.Y);

					if (_glyphRunCache.TryGetOrCreate(text, _regularTypeface, EffectiveLineNumberSize, 0, out GlyphRun? glyphRun) && glyphRun != null) {
						glyphRun.BaselineOrigin = new Point(drawX, baselineY);
						context.DrawGlyphRun(GetBrush(lineNumberColor), glyphRun);
					} else {
						FormattedText formatted = GetFormattedText(text, _regularTypeface, 0, EffectiveLineNumberSize, lineNumberColor, inlay: false);
						float topY = Snap(line.LineNumberPosition.Y - lineNumberMetrics.Baseline);
						context.DrawText(formatted, new Point(drawX, topY));
					}

					if (hasIcons && !overlayMode) {
						for (int i = iconStart; i < iconEnd; i++) {
							RenderGutterIconItem(context, gutterIcons![i]);
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
					RenderFoldMarkerItem(context, foldMarker.Value, isCurrentLine ? activeLineNumberColor : normalLineNumberColor);
				}
			}
		}

		[MethodImpl(MethodImplOptions.AggressiveInlining)]
		private void RenderGutterIconItem(DrawingContext context, GutterIconRenderItem item) {
			if (item.Width <= 0f || item.Height <= 0f || !TryGetIconImage(item.IconId, out IImage? iconBmp) || iconBmp == null) {
				return;
			}

			var dst = new Rect(Snap(item.Origin.X), Snap(item.Origin.Y), Math.Max(0, Snap(item.Width)), Math.Max(0, Snap(item.Height)));
			if (dst.Width > 0 && dst.Height > 0) {
				context.DrawImage(iconBmp, new Rect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), dst);
			}
		}

		private void RenderFoldMarkerItem(DrawingContext context, FoldMarkerRenderItem item, int color) {
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

		private void RenderSplitLine(DrawingContext context, EditorRenderModel model, double viewportHeight) {
			if (!model.SplitLineVisible || model.SplitX <= 0) {
				return;
			}
			var pen = GetPen((int)_theme.SplitLineColor, 1);
			double splitX = Snap(model.SplitX);
			context.DrawLine(pen, new Point(splitX, 0), new Point(splitX, viewportHeight));
		}

		private void RenderScrollbars(DrawingContext context, EditorRenderModel model) {
			RenderScrollbar(context, model.VerticalScrollbar);
			RenderScrollbar(context, model.HorizontalScrollbar);
		}

		private void RenderScrollbar(DrawingContext context, ScrollbarModel model) {
			if (!model.Visible || model.Alpha <= 0) {
				return;
			}

			byte alpha = (byte)Math.Clamp(model.Alpha * 255, 0, 255);
			int trackColor = ((int)_theme.ScrollbarTrackColor & 0x00FFFFFF) | (alpha << 24);
			int thumbColor = ((int)(model.ThumbActive ? _theme.ScrollbarThumbActiveColor : _theme.ScrollbarThumbColor) & 0x00FFFFFF) | (alpha << 24);

			context.FillRectangle(GetBrush(trackColor), new Rect(Snap(model.Track.Origin.X), Snap(model.Track.Origin.Y), Snap(model.Track.Width), Snap(model.Track.Height)));
			context.FillRectangle(GetBrush(thumbColor), new Rect(Snap(model.Thumb.Origin.X), Snap(model.Thumb.Origin.Y), Snap(model.Thumb.Width), Snap(model.Thumb.Height)));
		}

		private void RenderSelectionHandles(DrawingContext context, EditorRenderModel model) {
			RenderSelectionHandle(context, model, model.SelectionStartHandle, isStart: true);
			RenderSelectionHandle(context, model, model.SelectionEndHandle, isStart: false);
		}

		private void RenderSelectionHandle(DrawingContext context, EditorRenderModel model, SelectionHandle handle, bool isStart) {
			if (!handle.Visible || handle.Height <= 0f) {
				return;
			}

			double drawScale = Math.Max(0.7f, _scale);
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

			var brush = GetBrush((int)_theme.CursorColor);
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

		private int ResolveRunTextColor(VisualRun run) {
			return run.Type == VisualRunType.INLAY_HINT
				? (int)_theme.InlayHintTextColor
				: run.Style.Color != 0
					? run.Style.Color
					: (int)_theme.TextColor;
		}

		private string GetLineNumberText(int logicalLineNumber) {
			if (_lineNumberTextCache.TryGet(logicalLineNumber, out string? cached)) {
				return cached!;
			}

			string value = logicalLineNumber.ToString(System.Globalization.CultureInfo.InvariantCulture);
			_lineNumberTextCache.Set(logicalLineNumber, value);
			return value;
		}

		private int GetActiveLineNumberColor() {
			int argb = (int)_theme.CurrentLineNumberColor;
			if (argb == 0) {
				argb = (int)_theme.LineNumberColor;
			}
			return (argb & 0x00FFFFFF) | unchecked((int)0xFF000000);
		}

		private int GetCurrentLineBorderColor() {
			int argb = (int)_theme.CurrentLineColor;
			if (argb == 0) {
				argb = (int)_theme.LineNumberColor;
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

		private float EffectiveTextSize => _textSizeDip * _scale;
		private float EffectiveInlaySize => EffectiveTextSize * InlayTextSizeRatio;
		private float EffectiveLineNumberSize => EffectiveTextSize * LineNumberTextSizeRatio;

		private static int QuantizeSize(float size) => (int)MathF.Round(size * 100f);

		private bool IsProbablyMonospace() => _fontFamily.Contains("mono", StringComparison.OrdinalIgnoreCase);

		private float Snap(float value) => MathF.Round(value * _scale) / _scale;
		private double Snap(double value) => Math.Round(value * _scale) / _scale;

		private void UpdateTypefaces() {
			_regularTypeface = new Typeface(_fontFamily, FontStyle.Normal, FontWeight.Normal);
			_boldTypeface = new Typeface(_fontFamily, FontStyle.Normal, FontWeight.Bold);
			_italicTypeface = new Typeface(_fontFamily, FontStyle.Italic, FontWeight.Normal);
			_boldItalicTypeface = new Typeface(_fontFamily, FontStyle.Italic, FontWeight.Bold);
			ClearTextCaches();
		}

		private void ClearTextCaches() {
			_textMetricsCache.Clear();
			_layoutMetricsCache.Clear();
			_monospaceAdvanceCache.Clear();
			_lineNumberTextCache.Clear();
			_glyphRunCache.Clear();
		}

		public void Dispose() {
			ClearTextCaches();
			_brushCache.Clear();
			_penCache.Clear();
			_iconCache.Clear();
			_iconWidthCache.Clear();
			_glyphRunCache.Dispose();
		}

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) {
				return 0f;
			}

			bool collect = _perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveTextSize;
				if (IsProbablyMonospace() && CanUseGlyphFastPath(text.AsSpan())) {
					return text.Length * GetMonospaceAdvance(fontStyle, textSize, inlay: false);
				}
				return GetTextMetrics(text, ResolveTypeface(fontStyle), fontStyle, textSize, inlay: false).Width;
			} catch {
				return text.Length * EffectiveTextSize * 0.6f;
			} finally {
				if (collect) {
					_measurePerfStats.RecordText(Stopwatch.GetTimestamp() - start, text.Length, fontStyle);
				}
			}
		}

		private float OnMeasureInlayText(string text) {
			string safe = string.IsNullOrEmpty(text) ? "M" : text;
			bool collect = _perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveInlaySize;
				if (IsProbablyMonospace() && CanUseGlyphFastPath(safe.AsSpan())) {
					return safe.Length * GetMonospaceAdvance(0, textSize, inlay: true);
				}
				return GetTextMetrics(safe, _regularTypeface, 0, textSize, inlay: true).Width;
			} catch {
				return safe.Length * EffectiveInlaySize * 0.6f;
			} finally {
				if (collect) {
					_measurePerfStats.RecordInlay(Stopwatch.GetTimestamp() - start, safe.Length);
				}
			}
		}

		private float OnMeasureIconWidth(int iconId) {
			bool collect = _perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				if (iconId == 0) {
					return EffectiveTextSize;
				}
				if (_iconWidthCache.TryGet(iconId, out float cachedWidth)) {
					return cachedWidth;
				}
				if (TryGetIconImage(iconId, out IImage? bmp) && bmp != null) {
					float width = (float)bmp.Size.Width;
					_iconWidthCache.Set(iconId, width);
					return width;
				}
				return EffectiveTextSize;
			} finally {
				if (collect) {
					_measurePerfStats.RecordIcon(Stopwatch.GetTimestamp() - start);
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
				TextMetrics metrics = GetTextMetrics("M", _regularTypeface, 0, EffectiveTextSize, inlay: false);
				ascent = metrics.Baseline;
				descent = Math.Max(0.1f, metrics.Height - metrics.Baseline);
			} catch {
				ascent = EffectiveTextSize * 0.8f;
				descent = EffectiveTextSize * 0.2f;
			}
			float[] metricValues = { -ascent, descent };
			Marshal.Copy(metricValues, 0, arrPtr, 2);
		}
	}
}
