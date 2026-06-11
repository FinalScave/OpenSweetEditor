using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using Avalonia;
using Avalonia.Media;
using Avalonia.Media.TextFormatting;
using AvaloniaRect = Avalonia.Rect;

namespace SweetEditor {
	internal sealed class EditorRenderer : IDisposable {
		private const float DefaultTextSizeDip = 15.0f;
		private const float InlayTextSizeRatio = 0.86f;
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
		private readonly Dictionary<int, string> lineNumberTextCache = new();
		private readonly Dictionary<int, IImage?> iconCache = new();
		private readonly Dictionary<int, float> iconWidthCache = new();
		private readonly MeasurePerfStats measurePerfStats = new();
		private readonly PerfOverlay perfOverlay = new();
		private static readonly IntPtr measureTextWidthCallback = CreateMeasureTextWidthCallback();
		private static readonly IntPtr measureInlayHintWidthCallback = CreateMeasureInlayHintWidthCallback();
		private static readonly IntPtr measureIconWidthCallback = CreateMeasureIconWidthCallback();
		private static readonly IntPtr getFontMetricsCallback = CreateGetFontMetricsCallback();
		private static EditorRenderer? activeMeasureTarget;

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

		private readonly record struct PenKey
		(int Argb, int ThicknessKey, PenLineCap LineCap, PenLineJoin LineJoin);

		private readonly record struct TextMetrics
		(float Width, float Baseline, float Height);

		private readonly record struct LayoutMetrics
		(float Baseline, float Height);

		public EditorRenderer(EditorTheme theme) {
			this.theme = theme;
			UpdateTypefaces();
		}

		public EditorTheme Theme => theme;

		public float EditorTextSize => textSizeDip;

		public string FontFamily => fontFamily;

		public EditorCore.TextMeasurer CreateTextMeasurer() {
			activeMeasureTarget = this;
			return new EditorCore.TextMeasurer {
				MeasureTextWidth = measureTextWidthCallback,
				MeasureInlayHintWidth = measureInlayHintWidthCallback,
				MeasureIconWidth = measureIconWidthCallback,
				GetFontMetrics = getFontMetricsCallback,
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
		}

		public void SetEditorIconProvider(EditorIconProvider? provider) {
			iconProvider = provider;
			iconCache.Clear();
			iconWidthCache.Clear();
		}

		public void SetScale(float scale) {
			this.scale = Math.Max(0.1f, scale);
			ClearFontDependentCaches();
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

			var points = new(double x, double y)[] {
				(0, 0), (-r, c), (r, c), (0, c + r), (0, c - r * 0.8),
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
				StartLeft = (float)((minX - pad) * d),	StartTop = (float)((minY - pad) * d),
				StartRight = (float)((maxX + pad) * d), StartBottom = (float)((maxY + pad) * d),
				EndLeft = (float)((-maxX - pad) * d),	EndTop = (float)((minY - pad) * d),
				EndRight = (float)((-minX + pad) * d),	EndBottom = (float)((maxY + pad) * d),
			};
		}

		public void SetEditorTextSize(float sizeDip) {
			textSizeDip = Math.Max(1f, sizeDip);
			ClearFontDependentCaches();
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

			context.FillRectangle(GetBrush((int)theme.BackgroundColor),
								  new AvaloniaRect(0, 0, viewportSize.Width, viewportSize.Height));
			drawPerf?.Mark(PerfStepRecorder.STEP_CLEAR);

			DrawCurrentLine(context, model, viewportSize.Width);
			drawPerf?.Mark(PerfStepRecorder.STEP_CURRENT);

			AvaloniaRect contentClip = GetContentClipRect(model, viewportSize);
			using (context.PushClip(contentClip)) {
				DrawRangeEffectBackgrounds(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_RANGE_EFFECT_BACKGROUNDS);
				DrawVisualLines(context, model, contentClip);
				drawPerf?.Mark(PerfStepRecorder.STEP_LINES);
				DrawGuideSegments(context, model);
				DrawRangeEffectOverlays(context, model);
				drawPerf?.Mark(PerfStepRecorder.STEP_RANGE_EFFECT_OVERLAYS);
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
			lineNumberTextCache.Clear();
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
			ClearFontDependentCaches();
		}

		private float EffectiveTextSize => textSizeDip * scale;

		private float EffectiveInlaySize => EffectiveTextSize * InlayTextSizeRatio;

		private void ClearFontDependentCaches() {
			iconWidthCache.Clear();
		}

		private static int QuantizeSize(float size) => (int)MathF.Round(size * 100f);

		private bool IsProbablyMonospace() => fontFamily.Contains("mono", StringComparison.OrdinalIgnoreCase);

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

		private static double GlyphScale(IGlyphTypeface glyphTypeface, float size) {
			double designEmHeight = Math.Max(1.0, glyphTypeface.Metrics.DesignEmHeight);
			return size / designEmHeight;
		}

		private static bool TryGetGlyphAdvance(IGlyphTypeface glyphTypeface, uint codepoint, float size,
											   out ushort glyphIndex, out float advance) {
			glyphIndex = glyphTypeface.GetGlyph(codepoint);
			if (glyphIndex == 0) {
				advance = 0f;
				return false;
			}

			advance = (float)(glyphTypeface.GetGlyphAdvance(glyphIndex) * GlyphScale(glyphTypeface, size));
			return advance > 0f;
		}

		private bool TryGetFixedGlyphAdvance(Typeface typeface, float size, out float advance) {
			advance = 0f;
			if (typeface.GlyphTypeface is not IGlyphTypeface glyphTypeface) {
				return false;
			}
			if (!glyphTypeface.Metrics.IsFixedPitch && !IsProbablyMonospace()) {
				return false;
			}
			return TryGetGlyphAdvance(glyphTypeface, 'M', size, out _, out advance);
		}

		private bool TryMeasureGlyphText(string text, Typeface typeface, float size, out float width) {
			width = 0f;
			if (string.IsNullOrEmpty(text) || !CanUseGlyphFastPath(text.AsSpan())) {
				return false;
			}
			if (typeface.GlyphTypeface is not IGlyphTypeface glyphTypeface) {
				return false;
			}

			double scaleValue = GlyphScale(glyphTypeface, size);
			double measured = 0;
			ReadOnlySpan<char> chars = text.AsSpan();
			for (int i = 0; i < chars.Length; i++) {
				ushort glyphIndex = glyphTypeface.GetGlyph(chars[i]);
				if (glyphIndex == 0) {
					return false;
				}
				measured += glyphTypeface.GetGlyphAdvance(glyphIndex) * scaleValue;
			}

			width = (float)measured;
			return true;
		}

		private bool TryCreateGlyphRun(string text, int start, int length, Typeface typeface, float size,
									   Point baselineOrigin, out GlyphRun glyphRun, out float width) {
			glyphRun = default!;
			width = 0f;
			if (string.IsNullOrEmpty(text) || length <= 0 || start < 0 || start + length > text.Length) {
				return false;
			}

			ReadOnlySpan<char> slice = text.AsSpan(start, length);
			if (!CanUseGlyphFastPath(slice)) {
				return false;
			}

			if (typeface.GlyphTypeface is not IGlyphTypeface glyphTypeface) {
				return false;
			}

			double scaleValue = GlyphScale(glyphTypeface, size);
			var glyphInfos = new GlyphInfo[length];
			double measured = 0;
			for (int i = 0; i < length; i++) {
				ushort glyphIndex = glyphTypeface.GetGlyph(slice[i]);
				if (glyphIndex == 0) {
					return false;
				}
				double advance = glyphTypeface.GetGlyphAdvance(glyphIndex) * scaleValue;
				if (advance <= 0) {
					return false;
				}
				glyphInfos[i] = new GlyphInfo(glyphIndex, i, advance, default);
				measured += advance;
			}

			width = (float)measured;
			glyphRun = new GlyphRun(glyphTypeface, size, text.AsMemory(start, length), glyphInfos, baselineOrigin, 0);
			return true;
		}

		private TextMetrics GetTextMetrics(string text, Typeface typeface, int fontStyle, float size, bool inlay) {
			string safeText = string.IsNullOrEmpty(text) ? "M" : text;
			var formatted = new FormattedText(safeText, CultureInfo.CurrentCulture, FlowDirection.LeftToRight, typeface,
											  size, GetBrush(MeasureColorArgb));
			var metrics = new TextMetrics((float)Math.Max(formatted.Width, formatted.WidthIncludingTrailingWhitespace),
										  (float)formatted.Baseline, Math.Max(1f, (float)formatted.Height));
			return string.IsNullOrEmpty(text) ? metrics with { Width = 0f } : metrics;
		}

		private FormattedText GetFormattedText(string text, Typeface typeface, int fontStyle, float size, int argb,
											   bool inlay) {
			return new FormattedText(text, CultureInfo.CurrentCulture, FlowDirection.LeftToRight, typeface, size,
									 GetBrush(argb));
		}

		private LayoutMetrics GetLayoutMetrics(Typeface typeface, int fontStyle, float size, bool inlay) {
			if (typeface.GlyphTypeface is IGlyphTypeface glyphTypeface) {
				double scaleValue = GlyphScale(glyphTypeface, size);
				FontMetrics fontMetrics = glyphTypeface.Metrics;
				float ascent = Math.Max(0.1f, (float)Math.Abs(fontMetrics.Ascent * scaleValue));
				float descent = Math.Max(0.1f, (float)Math.Abs(fontMetrics.Descent * scaleValue));
				return new LayoutMetrics(ascent, Math.Max(1f, ascent + descent));
			}

			TextMetrics textMetrics = GetTextMetrics("M", typeface, fontStyle, size, inlay);
			return new LayoutMetrics(textMetrics.Baseline, textMetrics.Height);
		}

		private float Snap(float value) => MathF.Round(value * scale) / scale;

		private double Snap(double value) => Math.Round(value * scale) / scale;

		private static unsafe IntPtr CreateMeasureTextWidthCallback() {
			return (IntPtr)(delegate * unmanaged<ushort *, int, float>)&StaticMeasureText;
		}

		private static unsafe IntPtr CreateMeasureInlayHintWidthCallback() {
			return (IntPtr)(delegate * unmanaged<ushort *, float>)&StaticMeasureInlayText;
		}

		private static unsafe IntPtr CreateMeasureIconWidthCallback() {
			return (IntPtr)(delegate * unmanaged<int, float>)&StaticMeasureIconWidth;
		}

		private static unsafe IntPtr CreateGetFontMetricsCallback() {
			return (IntPtr)(delegate * unmanaged<IntPtr, UIntPtr, void>)&StaticGetFontMetrics;
		}

		[UnmanagedCallersOnly]
		private static unsafe float StaticMeasureText(ushort *textPtr, int fontStyle) {
			try {
				EditorRenderer? target = activeMeasureTarget;
				if (target == null) {
					return 0f;
				}
				string text = StringFromUtf16(textPtr);
				if (string.IsNullOrEmpty(text)) {
					return 0f;
				}
				return target.OnMeasureText(text, fontStyle);
			} catch {
				return 0f;
			}
		}

		[UnmanagedCallersOnly]
		private static unsafe float StaticMeasureInlayText(ushort *textPtr) {
			try {
				EditorRenderer? target = activeMeasureTarget;
				if (target == null) {
					return 0f;
				}
				string text = StringFromUtf16(textPtr);
				if (string.IsNullOrEmpty(text)) {
					return 0f;
				}
				return target.OnMeasureInlayText(text);
			} catch {
				return 0f;
			}
		}

		[UnmanagedCallersOnly]
		private static float StaticMeasureIconWidth(int iconId) {
			try {
				EditorRenderer? target = activeMeasureTarget;
				return target?.OnMeasureIconWidth(iconId) ?? DefaultTextSizeDip;
			} catch {
				return DefaultTextSizeDip;
			}
		}

		[UnmanagedCallersOnly]
		private static void StaticGetFontMetrics(IntPtr arrPtr, UIntPtr length) {
			try {
				activeMeasureTarget?.OnGetFontMetrics(arrPtr, length);
			} catch {
			}
		}

		private static unsafe string StringFromUtf16(ushort *textPtr) {
			if (textPtr == null) {
				return string.Empty;
			}

			int length = 0;
			while (textPtr[length] != 0) {
				length++;
			}
			return length == 0 ? string.Empty : new string((char *)textPtr, 0, length);
		}

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) {
				return 0f;
			}

			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveTextSize;
				Typeface typeface = ResolveTypeface(fontStyle);
				if (TryMeasureGlyphText(text, typeface, textSize, out float glyphWidth)) {
					return glyphWidth;
				}
				return GetTextMetrics(text, typeface, fontStyle, textSize, inlay: false).Width;
			} catch {
				return text.Length * EffectiveTextSize * 0.6f;
			} finally {
				if (collect) {
					measurePerfStats.RecordText(Stopwatch.GetTimestamp() - start, text.Length, fontStyle);
				}
			}
		}

		private float OnMeasureInlayText(string text) {
			if (string.IsNullOrEmpty(text)) {
				return 0f;
			}
			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				float textSize = EffectiveInlaySize;
				return GetTextMetrics(text, regularTypeface, 0, textSize, inlay: true).Width;
			} catch {
				return text.Length * EffectiveInlaySize * 0.6f;
			} finally {
				if (collect) {
					measurePerfStats.RecordInlay(Stopwatch.GetTimestamp() - start, text.Length);
				}
			}
		}

		private float OnMeasureIconWidth(int iconId) {
			bool collect = perfOverlay.IsEnabled();
			long start = collect ? Stopwatch.GetTimestamp() : 0;
			try {
				if (iconId != 0 && iconWidthCache.TryGetValue(iconId, out float cachedWidth)) {
					return cachedWidth;
				}

				float width = GetLayoutMetrics(regularTypeface, 0, EffectiveTextSize, inlay: false).Height;
				if (iconId != 0) {
					iconWidthCache[iconId] = width;
				}
				return width;
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
				LayoutMetrics metrics = GetLayoutMetrics(regularTypeface, 0, EffectiveTextSize, inlay: false);
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

			if (iconCache.TryGetValue(iconId, out IImage? cached))
            {
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
			var rect = new AvaloniaRect(0, Snap(model.CurrentLine.Y), viewportWidth, Snap(lineHeight));
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.BORDER) {
				context.DrawRectangle(null, GetPen(GetCurrentLineBorderColor(), 1), rect);
				return;
			}
			context.FillRectangle(GetBrush((int)theme.CurrentLineColor), rect);
		}

		private void DrawRangeEffectBackgrounds(DrawingContext context, EditorRenderModel model) {
			if (model.RangeEffects == null || model.RangeEffects.Count == 0) {
				return;
			}
			foreach (var effect in model.RangeEffects) {
				if (effect.Style.BackgroundColor == 0) {
					continue;
				}
				context.FillRectangle(GetBrush(effect.Style.BackgroundColor), ToAvaloniaRect(effect.Rect));
			}
		}

		private void DrawRangeEffectOverlays(DrawingContext context, EditorRenderModel model) {
			if (model.RangeEffects == null || model.RangeEffects.Count == 0) {
				return;
			}
			foreach (var effect in model.RangeEffects) {
				if (effect.Style.BorderColor != 0) {
					context.DrawRectangle(null, GetPen(effect.Style.BorderColor, BorderStrokeWidth(effect.Kind)),
										  ToAvaloniaRect(effect.Rect));
				}
				if (effect.Style.UnderlineColor != 0 && effect.Style.UnderlineStyle != RangeEffectUnderlineStyle.NONE) {
					DrawRangeEffectUnderline(context, effect.Rect, effect.Style);
				}
			}
		}

		private void DrawGuideSegments(DrawingContext context, EditorRenderModel model) {
			if (model.GuideSegments == null || model.GuideSegments.Count == 0) {
				return;
			}

			foreach (var guide in model.GuideSegments) {
				double startX = Snap(guide.Start.X);
				double startY = Snap(guide.Start.Y);
				double endX = Snap(guide.End.X);
				double endY = Snap(guide.End.Y);
				double dx = endX - startX;
				double dy = endY - startY;
				double length = Math.Sqrt(dx * dx + dy * dy);
				if (length <= 0.5) {
					continue;
				}

				var start = new Point(startX, startY);
				var end = new Point(endX, endY);
				var pen = GetPen(ResolveGuideColor(guide), 1, PenLineCap.Round, PenLineJoin.Round);
				if (guide.Style == GuideStyle.DOUBLE) {
					DrawDoubleGuideSegment(context, pen, start, end, dx, dy, length);
				} else if (guide.Style == GuideStyle.DASHED) {
					DrawDashedGuideSegment(context, pen, startX, startY, dx, dy, length);
				} else {
					context.DrawLine(pen, start, end);
				}

				if (guide.ArrowEnd) {
					DrawGuideArrow(context, pen, endX, endY, dx / length, dy / length);
				}
			}
		}

		private void DrawDoubleGuideSegment(DrawingContext context, Pen pen, Point start, Point end, double dx,
											double dy, double length) {
			double offsetX = -dy / length * 2.0;
			double offsetY = dx / length * 2.0;
			context.DrawLine(pen, new Point(Snap(start.X + offsetX), Snap(start.Y + offsetY)),
							 new Point(Snap(end.X + offsetX), Snap(end.Y + offsetY)));
			context.DrawLine(pen, new Point(Snap(start.X - offsetX), Snap(start.Y - offsetY)),
							 new Point(Snap(end.X - offsetX), Snap(end.Y - offsetY)));
		}

		private void DrawDashedGuideSegment(DrawingContext context, Pen pen, double startX, double startY, double dx,
											double dy, double length) {
			const double dash = 6.0;
			const double gap = 4.0;
			double ux = dx / length;
			double uy = dy / length;
			for (double distance = 0; distance < length; distance += dash + gap) {
				double next = Math.Min(distance + dash, length);
				context.DrawLine(pen, new Point(Snap(startX + ux * distance), Snap(startY + uy * distance)),
								 new Point(Snap(startX + ux * next), Snap(startY + uy * next)));
			}
		}

		private void DrawGuideArrow(DrawingContext context, Pen pen, double endX, double endY, double ux, double uy) {
			const double arrowSize = 7.0;
			const double wing = 0.55;
			double px = -uy;
			double py = ux;
			var end = new Point(Snap(endX), Snap(endY));
			var left = new Point(Snap(endX - ux * arrowSize + px * arrowSize * wing),
								 Snap(endY - uy * arrowSize + py * arrowSize * wing));
			var right = new Point(Snap(endX - ux * arrowSize - px * arrowSize * wing),
								  Snap(endY - uy * arrowSize - py * arrowSize * wing));
			context.DrawLine(pen, end, left);
			context.DrawLine(pen, end, right);
		}

		private int ResolveGuideColor(GuideSegment guide) {
			uint color = guide.Type == GuideType.SEPARATOR ? theme.SeparatorLineColor : theme.GuideColor;
			if (color == 0) {
				color = theme.LineNumberColor;
			}
			return (int)color;
		}

		private static double BorderStrokeWidth(RangeEffectKind kind) {
			return kind == RangeEffectKind.LINKED_EDITING_ACTIVE ? 2.0 : 1.5;
		}

		private void DrawRangeEffectUnderline(DrawingContext context, Rect rect, RangeEffectStyle style) {
			double startX = Snap(rect.Origin.X);
			double endX = Snap(rect.Origin.X + rect.Width);
			double baseY = Snap(rect.Origin.Y + rect.Height - 1f);
			var pen = GetPen(style.UnderlineColor, style.UnderlineStyle == RangeEffectUnderlineStyle.WAVY ? 3.0 : 2.0,
							 PenLineCap.Round, PenLineJoin.Round);

			if (style.UnderlineStyle == RangeEffectUnderlineStyle.DASHED) {
				DrawDashedUnderline(context, pen, startX, endX, baseY);
				return;
			}

			if (style.UnderlineStyle == RangeEffectUnderlineStyle.SOLID) {
				context.DrawLine(pen, new Point(startX, baseY), new Point(endX, baseY));
				return;
			}

			var path = new StreamGeometry();
			using (var geometry = path.Open()) {
				double halfWave = 7.0;
				double amplitude = 3.5;
				double x = startX;
				int step = 0;
				geometry.BeginFigure(new Point(startX, baseY), false);
				while (x < endX) {
					double nextX = Math.Min(x + halfWave, endX);
					double midX = (x + nextX) * 0.5;
					double peakY = step % 2 == 0 ? baseY - amplitude : baseY + amplitude;
					geometry.CubicBezierTo(
						new Point(x + 2.0 / 3.0 * (midX - x), baseY + 2.0 / 3.0 * (peakY - baseY)),
						new Point(nextX + 2.0 / 3.0 * (midX - nextX), baseY + 2.0 / 3.0 * (peakY - baseY)),
						new Point(nextX, baseY));
					x = nextX;
					step++;
				}
			}
			context.DrawGeometry(null, pen, path);
		}

		private static void DrawDashedUnderline(DrawingContext context, Pen pen, double startX, double endX, double y) {
			const double dash = 3.0;
			const double gap = 2.0;
			for (double x = startX; x < endX; x += dash + gap) {
				double nextX = Math.Min(x + dash, endX);
				context.DrawLine(pen, new Point(x, y), new Point(nextX, y));
			}
		}

		private void DrawSelectionHandles(DrawingContext context, EditorRenderModel model) {
			DrawSelectionHandle(context, model, model.SelectionStartHandle, isStart: true);
			DrawSelectionHandle(context, model, model.SelectionEndHandle, isStart: false);
		}

		private void DrawSelectionHandle(DrawingContext context, EditorRenderModel model, SelectionHandle handle,
										 bool isStart) {
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
			context.FillRectangle(brush, new AvaloniaRect(tipX - lineWidth * 0.5, y, lineWidth, height));

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
				geo.CubicBezierTo(Rotate(tipX, tipY + centerDistance * 0.4),
								  Rotate(cx - dropRadius, cy - dropRadius * 0.8), Rotate(cx - dropRadius, cy));
				geo.CubicBezierTo(Rotate(cx - dropRadius, cy + k), Rotate(cx - k, cy + dropRadius),
								  Rotate(cx, cy + dropRadius));
				geo.CubicBezierTo(Rotate(cx + k, cy + dropRadius), Rotate(cx + dropRadius, cy + k),
								  Rotate(cx + dropRadius, cy));
				geo.CubicBezierTo(Rotate(cx + dropRadius, cy - dropRadius * 0.8),
								  Rotate(tipX, tipY + centerDistance * 0.4), tip);
				geo.EndFigure(true);
			}
			context.DrawGeometry(brush, null, path);
		}

		private void DrawVisualLines(DrawingContext context, EditorRenderModel model, AvaloniaRect contentClip) {
			if (model.Lines == null) {
				return;
			}
			float clipLeft = (float)contentClip.X;
			float clipRight = (float)(contentClip.X + contentClip.Width);
			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.Lines);
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
					string text = run.Text ?? string.Empty;
					int textColor = ResolveRunTextColor(run);
					float drawX = Snap(run.X);
					float drawWidth = Math.Max(1f, Snap(run.Width));

					if (drawX >= clipRight || drawX + drawWidth <= clipLeft) {
						continue;
					}

					if (DrawInvisibleCharacterRun(context, run, drawX, drawWidth, contentClip)) {
						continue;
					}

					bool isInlay = run.Type == VisualRunType.INLAY_HINT;
					bool isFoldPlaceholder = run.Type == VisualRunType.FOLD_PLACEHOLDER;
					bool drawWhitespaceText = run.Type is not(VisualRunType.WHITESPACE or VisualRunType.TAB);
					bool hasBackground = run.Style.BackgroundColor != 0;
					bool hasStrike = (run.Style.FontStyle & FontStyleStrike) != 0;
					bool isActiveCodeLens = run.Type == VisualRunType.CODELENS && run.Active;
					bool needsLayout = hasBackground || hasStrike || isInlay || isFoldPlaceholder || isActiveCodeLens;
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
						canUseGlyphFastPath = drawWhitespaceText && !isInlay && CanUseGlyphFastPath(text.AsSpan());
						canUseHorizontalClip =
							canUseGlyphFastPath && TryGetFixedGlyphAdvance(typeface, textSize, out _);
					}

					int clippedStartIndex = 0;
					int clippedLength = text.Length;
					bool clippedGlyphText = false;
					LayoutMetrics layout = default;
					float topY = Snap(run.Y);
					float lineHeight = Math.Max(1f, textSize);
					if (needsLayout) {
						layout = GetLayoutMetrics(typeface, run.Style.FontStyle, textSize, isInlay);
						topY = Snap(run.Y - layout.Baseline);
						lineHeight = layout.Height;
					}

					if (drawWhitespaceText && canUseHorizontalClip && !string.IsNullOrEmpty(text) &&
						drawWidth > clipRight - clipLeft &&
						TryGetFixedGlyphAdvance(typeface, textSize, out float advance)) {
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

					if (hasBackground) {
						float backgroundX = Math.Max(drawX, clipLeft);
						float backgroundRight = Math.Min(drawX + drawWidth, clipRight);
						context.FillRectangle(GetBrush(run.Style.BackgroundColor),
											  new AvaloniaRect(backgroundX, topY,
															   Math.Max(0f, backgroundRight - backgroundX),
															   Snap(lineHeight)));
					}

					if (isFoldPlaceholder) {
						DrawFoldPlaceholderRun(context, run, text, textColor, drawX, topY, drawWidth, lineHeight,
											   typeface, textSize);
						continue;
					}

					if (isInlay) {
						DrawInlayHintRun(context, run, text, textColor, drawX, topY, drawWidth, lineHeight, typeface,
										 textSize);
						continue;
					}

					if (!drawWhitespaceText || text.Length == 0) {
						continue;
					}

					GlyphRun glyphRun = default!;
					bool usedGlyphRun = canUseGlyphFastPath &&
										TryCreateGlyphRun(text, clippedStartIndex, clippedLength, typeface, textSize,
														  new Point(drawX, Snap(run.Y)), out glyphRun, out _);
					if (!usedGlyphRun) {
						if (!hasTypeface) {
							typeface = ResolveTypeface(run.Style.FontStyle);
							hasTypeface = true;
						}
						string drawText = clippedGlyphText ? text.Substring(clippedStartIndex, clippedLength) : text;
						FormattedText? formatted = drawText.Length > 0
													   ? GetFormattedText(drawText, typeface, run.Style.FontStyle,
																		  textSize, textColor, isInlay)
													   : null;
						if (formatted == null) {
							continue;
						}
						layout = LayoutMetricsFromFormattedText(formatted);
						topY = Snap(run.Y - layout.Baseline);
						lineHeight = layout.Height;
						needsLayout = true;
						context.DrawText(formatted, new Point(drawX, topY));
					} else {
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
						float underlineY = ComputeCodeLensUnderlineY(run.Y, layout);
						context.DrawLine(GetPen(textColor, 1), new Point(drawX, underlineY),
										 new Point(drawX + drawWidth, underlineY));
					}
				}
			}
		}

		private bool DrawInvisibleCharacterRun(DrawingContext context, VisualRun run, float drawX, float drawWidth,
											   AvaloniaRect contentClip) {
			if (run.Type == VisualRunType.WHITESPACE) {
				DrawRunBackground(context, run, drawX, drawWidth, contentClip);
				DrawWhitespaceMarkerRun(context, run, drawX, drawWidth);
				return true;
			}
			if (run.Type == VisualRunType.TAB) {
				DrawRunBackground(context, run, drawX, drawWidth, contentClip);
				DrawTabMarkerRun(context, run, drawX, drawWidth);
				return true;
			}
			if (run.Type == VisualRunType.NEWLINE) {
				DrawRunBackground(context, run, drawX, drawWidth, contentClip);
				DrawLineBreakMarkerRun(context, run, drawX);
				return true;
			}
			return false;
		}

		private void DrawRunBackground(DrawingContext context, VisualRun run, float drawX, float drawWidth,
									   AvaloniaRect contentClip) {
			if (run.Style.BackgroundColor == 0 || drawWidth <= 0f) {
				return;
			}

			Typeface typeface = ResolveTypeface(run.Style.FontStyle);
			LayoutMetrics layout = GetLayoutMetrics(typeface, run.Style.FontStyle, EffectiveTextSize, inlay: false);
			float topY = Snap(run.Y - layout.Baseline);
			float clipLeft = (float)contentClip.X;
			float clipRight = (float)(contentClip.X + contentClip.Width);
			float backgroundX = Math.Max(drawX, clipLeft);
			float backgroundRight = Math.Min(drawX + drawWidth, clipRight);
			context.FillRectangle(GetBrush(run.Style.BackgroundColor),
								  new AvaloniaRect(backgroundX, topY,
												   Math.Max(0f, backgroundRight - backgroundX),
												   Snap(layout.Height)));
		}

		private void DrawWhitespaceMarkerRun(DrawingContext context, VisualRun run, float drawX, float drawWidth) {
			string text = run.Text ?? string.Empty;
			int markerCount = text.Length;
			if (markerCount <= 0 || drawWidth <= 0f) {
				return;
			}

			LayoutMetrics layout = GetLayoutMetrics(regularTypeface, 0, EffectiveTextSize, inlay: false);
			float cellWidth = drawWidth / Math.Max(1, markerCount);
			float centerY = Snap(run.Y + (layout.Height - layout.Baseline * 2f) * 0.5f);
			float radius = Math.Max(1.0f, Math.Min(cellWidth, EffectiveTextSize) * 0.08f);
			IBrush brush = GetBrush(GetInvisibleCharacterColor());
			for (int i = 0; i < markerCount; i++) {
				float centerX = Snap(drawX + cellWidth * (i + 0.5f));
				context.DrawEllipse(brush, null, new Point(centerX, centerY), radius, radius);
			}
		}

		private void DrawTabMarkerRun(DrawingContext context, VisualRun run, float drawX, float drawWidth) {
			if (string.IsNullOrEmpty(run.Text) || drawWidth <= 0f) {
				return;
			}

			LayoutMetrics layout = GetLayoutMetrics(regularTypeface, 0, EffectiveTextSize, inlay: false);
			float centerY = Snap(run.Y + (layout.Height - layout.Baseline * 2f) * 0.5f);
			float padding = Math.Min(drawWidth * 0.25f, 8.0f);
			float left = Snap(drawX + padding);
			float right = Snap(Math.Max(left, drawX + drawWidth - padding));
			float arrow = Math.Min(5.0f, Math.Max(2.0f, (right - left) * 0.35f));
			Pen pen = GetPen(GetInvisibleCharacterColor(), Math.Max(1.0, EffectiveTextSize * 0.06),
							 PenLineCap.Round, PenLineJoin.Round);
			context.DrawLine(pen, new Point(left, centerY), new Point(right, centerY));
			context.DrawLine(pen, new Point(right, centerY), new Point(right - arrow, centerY - arrow));
			context.DrawLine(pen, new Point(right, centerY), new Point(right - arrow, centerY + arrow));
		}

		private void DrawLineBreakMarkerRun(DrawingContext context, VisualRun run, float drawX) {
			string text = run.Text ?? string.Empty;
			if (text.Length == 0) {
				return;
			}

			DrawTextAtBaseline(context, text, regularTypeface, 0, EffectiveTextSize,
							   GetInvisibleCharacterColor(), drawX, run.Y);
		}

		private int GetInvisibleCharacterColor() {
			return theme.InvisibleCharacterColor != 0
				? unchecked((int)theme.InvisibleCharacterColor)
				: (unchecked((int)theme.TextColor) & 0x00FFFFFF) | unchecked((int)0x70000000);
		}

		private void DrawFoldPlaceholderRun(DrawingContext context, VisualRun run, string text, int textColor,
											float drawX, float topY, float drawWidth, float lineHeight,
											Typeface typeface, float textSize) {
			float margin = Math.Max(0f, run.Margin);
			float padding = Math.Max(0f, run.Padding);
			var background =
				new AvaloniaRect(Snap(drawX + margin), Snap(topY), Math.Max(0f, Snap(drawWidth - margin * 2f)),
								 Math.Max(1f, Snap(lineHeight)));
			if (background.Width > 0 && background.Height > 0) {
				FillRoundedRectangle(context, (int)theme.FoldPlaceholderBgColor, background, background.Height * 0.2);
			}
			if (text.Length == 0) {
				return;
			}

			int foreground = theme.FoldPlaceholderTextColor != 0 ? (int)theme.FoldPlaceholderTextColor : textColor;
			DrawTextAtBaseline(context, text, typeface, run.Style.FontStyle, textSize, foreground,
							   drawX + margin + padding, run.Y);
		}

		private void DrawInlayHintRun(DrawingContext context, VisualRun run, string text, int textColor, float drawX,
									  float topY, float drawWidth, float lineHeight, Typeface typeface,
									  float textSize) {
			float margin = Math.Max(0f, run.Margin);
			float padding = Math.Max(0f, run.Padding);
			var background =
				new AvaloniaRect(Snap(drawX + margin), Snap(topY), Math.Max(0f, Snap(drawWidth - margin * 2f)),
								 Math.Max(1f, Snap(lineHeight)));
			if (background.Width <= 0 || background.Height <= 0) {
				return;
			}

			if (run.ColorValue != 0) {
				double blockSize = Math.Max(1, Math.Min(background.Width, background.Height));
				var colorRect = new AvaloniaRect(background.X, background.Y, blockSize, blockSize);
				context.FillRectangle(GetBrush(run.ColorValue), colorRect);
				return;
			}

			FillRoundedRectangle(context, (int)theme.InlayHintBgColor, background, background.Height * 0.2);
			if (run.IconId != 0 && TryGetIconImage(run.IconId, out IImage? iconBmp) && iconBmp != null)
            {
				double iconSize = Math.Max(1, Math.Min(background.Width, background.Height));
				var iconRect = new AvaloniaRect(Snap(background.X + (background.Width - iconSize) * 0.5),
												Snap(background.Y + (background.Height - iconSize) * 0.5),
												Snap(iconSize), Snap(iconSize));
				context.DrawImage(iconBmp, new AvaloniaRect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), iconRect);
				return;
			}

			if (text.Length == 0) {
				return;
			}

			DrawFormattedText(context, text, typeface, run.Style.FontStyle, textSize, textColor, inlay: true,
							  drawX + margin + padding, topY);
		}

		private void DrawTextAtBaseline(DrawingContext context, string text, Typeface typeface, int fontStyle,
										float textSize, int color, float x, float baselineY) {
			if (text.Length == 0) {
				return;
			}
			if (TryCreateGlyphRun(text, 0, text.Length, typeface, textSize, new Point(Snap(x), Snap(baselineY)),
								  out GlyphRun glyphRun, out _)) {
				context.DrawGlyphRun(GetBrush(color), glyphRun);
				return;
			}
			FormattedText formatted = GetFormattedText(text, typeface, fontStyle, textSize, color, inlay: false);
			LayoutMetrics layout = LayoutMetricsFromFormattedText(formatted);
			context.DrawText(formatted, new Point(Snap(x), Snap(baselineY - layout.Baseline)));
		}

		private void DrawFormattedText(DrawingContext context, string text, Typeface typeface, int fontStyle,
									   float textSize, int color, bool inlay, float x, float topY) {
			if (text.Length == 0) {
				return;
			}
			FormattedText formatted = GetFormattedText(text, typeface, fontStyle, textSize, color, inlay);
			context.DrawText(formatted, new Point(Snap(x), Snap(topY)));
		}

		private static LayoutMetrics LayoutMetricsFromFormattedText(FormattedText formatted) {
			return new LayoutMetrics(Math.Max(0.1f, (float)formatted.Baseline), Math.Max(1f, (float)formatted.Height));
		}

		private void FillRoundedRectangle(DrawingContext context, int color, AvaloniaRect rect, double radius) {
			if (color == 0 || rect.Width <= 0 || rect.Height <= 0) {
				return;
			}
			double safeRadius = Math.Max(0, Snap(radius));
			context.DrawRectangle(GetBrush(color), null, rect, safeRadius, safeRadius);
		}

		private float ComputeCodeLensUnderlineY(float baselineY, LayoutMetrics layout) {
			float descent = Math.Max(1f, layout.Height - layout.Baseline);
			float gap = Math.Clamp(descent * 0.25f, 1.0f, 2.0f);
			return Snap(baselineY + gap);
		}

		private void DrawCursor(DrawingContext context, EditorRenderModel model) {
			if (!model.Cursor.Visible) {
				return;
			}
			var rect = new AvaloniaRect(Snap(model.Cursor.Position.X), Snap(model.Cursor.Position.Y), 1.5,
										Math.Max(1, Snap(model.Cursor.Height)));
			context.FillRectangle(GetBrush((int)theme.CursorColor), rect);
		}

		private void DrawGutterOverlay(DrawingContext context, EditorRenderModel model, double viewportHeight) {
			if (model.SplitX <= 0) {
				return;
			}

			context.FillRectangle(GetBrush((int)theme.BackgroundColor),
								  new AvaloniaRect(0, 0, model.SplitX, viewportHeight));
			DrawCurrentLine(context, model, model.SplitX);
			if (model.SplitLineVisible) {
				DrawSplitLine(context, model, viewportHeight);
			}
		}

		private void DrawLineNumbers(DrawingContext context, EditorRenderModel model) {
			if (!model.GutterVisible || model.Lines == null) {
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
			float lineNumberTextSize = EffectiveTextSize;
			LayoutMetrics lineNumberMetrics = GetLayoutMetrics(regularTypeface, 0, lineNumberTextSize, inlay: false);
			Span<VisualLine> lines = CollectionsMarshal.AsSpan(model.Lines);
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
					if (TryCreateGlyphRun(text, 0, text.Length, regularTypeface, lineNumberTextSize,
										  new Point(drawX, baselineY), out GlyphRun glyphRun, out _)) {
						context.DrawGlyphRun(GetBrush(lineNumberColor), glyphRun);
					} else {
						FormattedText formatted = GetFormattedText(text, regularTypeface, 0, lineNumberTextSize,
																   lineNumberColor, inlay: false);
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
					DrawFoldMarkerItem(context, foldMarker,
									   isCurrentLine ? activeLineNumberColor : normalLineNumberColor);
				}
			}
		}

		private void DrawGutterIconItem(DrawingContext context, GutterIconRenderItem item) {
			if (item.Rect.Width <= 0f || item.Rect.Height <= 0f) {
				return;
			}
			if (!TryGetIconImage(item.IconId, out IImage? iconBmp) || iconBmp == null)
            {
				return;
			}

			var dst = new AvaloniaRect(Snap(item.Rect.Origin.X), Snap(item.Rect.Origin.Y),
									   Math.Max(0, Snap(item.Rect.Width)), Math.Max(0, Snap(item.Rect.Height)));
			if (dst.Width <= 0 || dst.Height <= 0) {
				return;
			}
			context.DrawImage(iconBmp, new AvaloniaRect(0, 0, iconBmp.Size.Width, iconBmp.Size.Height), dst);
		}

		private void DrawFoldMarkerItem(DrawingContext context, FoldMarkerRenderItem item, int color) {
			if (item.Rect.Width <= 0f || item.Rect.Height <= 0f || item.FoldState == FoldState.NONE) {
				return;
			}

			float centerX = item.Rect.Origin.X + item.Rect.Width * 0.5f;
			float centerY = item.Rect.Origin.Y + item.Rect.Height * 0.5f;
			float halfSize = Math.Min(item.Rect.Width, item.Rect.Height) * 0.28f;
			float strokeWidth = Math.Max(1f, item.Rect.Height * 0.1f);
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
			int thumbColor =
				((int)(model.ThumbActive ? theme.ScrollbarThumbActiveColor : theme.ScrollbarThumbColor) & 0x00FFFFFF) |
				(alpha << 24);

			context.FillRectangle(GetBrush(trackColor),
								  new AvaloniaRect(Snap(model.Track.Origin.X), Snap(model.Track.Origin.Y),
												   Snap(model.Track.Width), Snap(model.Track.Height)));
			context.FillRectangle(GetBrush(thumbColor),
								  new AvaloniaRect(Snap(model.Thumb.Origin.X), Snap(model.Thumb.Origin.Y),
												   Snap(model.Thumb.Width), Snap(model.Thumb.Height)));
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
			return run.Style.Color != 0 ? run.Style.Color : (int)theme.TextColor;
		}

		private string GetLineNumberText(int logicalLineNumber) {
			if (lineNumberTextCache.TryGetValue(logicalLineNumber, out string? cached))
            {
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

		private static AvaloniaRect GetContentClipRect(EditorRenderModel model, Size viewportSize) {
			double left = model.GutterVisible && model.GutterSticky ? Math.Max(0, model.SplitX) : 0;
			double width = Math.Max(0, viewportSize.Width - left);
			return new AvaloniaRect(left, 0, width, Math.Max(0, viewportSize.Height));
		}

		private AvaloniaRect ToAvaloniaRect(Rect rect) {
			return new AvaloniaRect(Snap(rect.Origin.X), Snap(rect.Origin.Y), Math.Max(0, Snap(rect.Width)),
									Math.Max(0, Snap(rect.Height)));
		}

		private Pen GetPen(int argb, double thickness, PenLineCap lineCap = PenLineCap.Flat,
						   PenLineJoin lineJoin = PenLineJoin.Miter) {
			int thicknessKey = QuantizeSize((float)thickness);
			var key = new PenKey(argb, thicknessKey, lineCap, lineJoin);
			if (penCache.TryGetValue(key, out Pen? pen))
            {
				return pen;
			}

			pen = new Pen(GetBrush(argb), thickness, lineCap: lineCap, lineJoin: lineJoin);
			penCache[key] = pen;
			return pen;
		}
	}
}
