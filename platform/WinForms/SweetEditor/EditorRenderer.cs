using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using SweetEditor.Perf;
using DrawingSize = System.Drawing.Size;

namespace SweetEditor {
	/// <summary>
	/// Platform-independent rendering engine for the WinForms editor.
	/// Owns all Font objects, implements text measurement callbacks, and contains all draw methods.
	/// SweetEditorControl delegates all rendering to this class.
	/// </summary>
	public class EditorRenderer : IDisposable {

		private const float InlayHintFontSizeRatio = 0.86f;
		private const string DefaultTextFontFamily = "Consolas";
		private const string BaseInlayHintFontFamily = "Segoe UI";

		internal float baseTextFontSize = EditorSettings.GetDefaultTextSizePoints(96);
		internal string baseTextFontFamily = DefaultTextFontFamily;

		private EditorTheme currentTheme;
		private Font regularFont;
		private Font boldFont;
		private Font italicFont;
		private Font boldItalicFont;
		private Font inlayHintFont;
		private Font inlayHintBoldFont;
		private Font inlayHintItalicFont;
		private Font inlayHintBoldItalicFont;
		private Graphics? textGraphics;
		private EditorIconProvider? editorIconProvider;
		private int currentDrawingLineNumber = -1;

		private readonly Dictionary<int, SolidBrush> brushCache = new Dictionary<int, SolidBrush>();
		private static readonly TextFormatFlags TextMeasureDrawFlags = TextFormatFlags.NoPadding | TextFormatFlags.SingleLine | TextFormatFlags.NoPrefix;

		private readonly MeasurePerfStats perfMeasureStats = new MeasurePerfStats();
		private readonly PerfOverlay perfOverlay = new PerfOverlay();
		private readonly FontMetricsInfo[] textFontMetrics = new FontMetricsInfo[4];
		private readonly FontMetricsInfo[] inlayFontMetrics = new FontMetricsInfo[4];
		private bool fontMetricsCacheValid;
		private float fontMetricsDpiY;

		private readonly record struct FontMetricsInfo(float Ascent, float Descent, float LineHeight);

		public EditorRenderer(EditorTheme theme) {
			currentTheme = theme;
			float inlayHintFontSize = baseTextFontSize * InlayHintFontSizeRatio;
			regularFont = new Font(baseTextFontFamily, baseTextFontSize, FontStyle.Regular);
			boldFont = new Font(baseTextFontFamily, baseTextFontSize, FontStyle.Bold);
			italicFont = new Font(baseTextFontFamily, baseTextFontSize, FontStyle.Italic);
			boldItalicFont = new Font(baseTextFontFamily, baseTextFontSize, FontStyle.Bold | FontStyle.Italic);
			inlayHintFont = new Font(BaseInlayHintFontFamily, inlayHintFontSize, FontStyle.Regular);
			inlayHintBoldFont = new Font(BaseInlayHintFontFamily, inlayHintFontSize, FontStyle.Bold);
			inlayHintItalicFont = new Font(BaseInlayHintFontFamily, inlayHintFontSize, FontStyle.Italic);
			inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, inlayHintFontSize, FontStyle.Bold | FontStyle.Italic);
		}

		public EditorTheme Theme => currentTheme;
		public Font RegularFont => regularFont;
		internal MeasurePerfStats PerfMeasureStats => perfMeasureStats;
		internal PerfOverlay PerfOverlay => perfOverlay;

		public EditorCore.TextMeasurer GetTextMeasurer() {
			return new EditorCore.TextMeasurer {
				MeasureTextWidth = OnMeasureText,
				MeasureInlayHintWidth = OnMeasureInlayHintText,
				MeasureIconWidth = OnMeasureIconWidth,
				GetFontMetrics = OnGetFontMetrics
			};
		}

		public void SetEditorIconProvider(EditorIconProvider? provider) {
			editorIconProvider = provider;
		}

		public EditorIconProvider? GetEditorIconProvider() => editorIconProvider;

		public void SetPerfOverlayEnabled(bool enabled) {
			perfOverlay.SetEnabled(enabled);
		}

		public bool IsPerfOverlayEnabled => perfOverlay.IsEnabled;

		public void ApplyTheme(EditorTheme theme) {
			currentTheme = theme;
		}

		public void SetTextGraphics(Graphics? g) {
			textGraphics = g;
			InvalidateFontMetricsCache();
			EnsureFontMetricsCache(g);
		}

		public Graphics? GetTextGraphics() => textGraphics;

		public void RecreateTextGraphics(Control control) {
			textGraphics?.Dispose();
			textGraphics = control.CreateGraphics();
			textGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			InvalidateFontMetricsCache();
			EnsureFontMetricsCache(textGraphics);
		}

		public void RebuildFonts(float scale) {
			if (scale <= 0f) return;
			float textSize = Math.Max(1f, baseTextFontSize * scale);
			float inlaySize = Math.Max(1f, baseTextFontSize * InlayHintFontSizeRatio * scale);

			regularFont.Dispose();
			boldFont.Dispose();
			italicFont.Dispose();
			boldItalicFont.Dispose();
			inlayHintFont.Dispose();
			inlayHintBoldFont.Dispose();
			inlayHintItalicFont.Dispose();
			inlayHintBoldItalicFont.Dispose();

			regularFont = new Font(baseTextFontFamily, textSize, FontStyle.Regular);
			boldFont = new Font(baseTextFontFamily, textSize, FontStyle.Bold);
			italicFont = new Font(baseTextFontFamily, textSize, FontStyle.Italic);
			boldItalicFont = new Font(baseTextFontFamily, textSize, FontStyle.Bold | FontStyle.Italic);
			inlayHintFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Regular);
			inlayHintBoldFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold);
			inlayHintItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Italic);
			inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold | FontStyle.Italic);
			InvalidateFontMetricsCache();
			EnsureFontMetricsCache(textGraphics);
		}

		private static int GetFontVariantIndex(int fontStyle) {
			bool isBold = (fontStyle & SweetEditorControl.FONT_STYLE_BOLD) != 0;
			bool isItalic = (fontStyle & SweetEditorControl.FONT_STYLE_ITALIC) != 0;
			return (isBold ? 1 : 0) | (isItalic ? 2 : 0);
		}

		private Font GetTextFontByVariant(int variant) {
			return variant switch {
				1 => boldFont,
				2 => italicFont,
				3 => boldItalicFont,
				_ => regularFont,
			};
		}

		private Font GetInlayFontByVariant(int variant) {
			return variant switch {
				1 => inlayHintBoldFont,
				2 => inlayHintItalicFont,
				3 => inlayHintBoldItalicFont,
				_ => inlayHintFont,
			};
		}

		private Font GetFontByStyle(int fontStyle) {
			return GetTextFontByVariant(GetFontVariantIndex(fontStyle));
		}

		private Font GetInlayHintFontByStyle(int fontStyle) {
			return GetInlayFontByVariant(GetFontVariantIndex(fontStyle));
		}

		private static FontMetricsInfo BuildFontMetrics(Font font, float dpiY) {
			int designAscent = font.FontFamily.GetCellAscent(font.Style);
			int designDescent = font.FontFamily.GetCellDescent(font.Style);
			int designEmHeight = font.FontFamily.GetEmHeight(font.Style);
			float scale = font.SizeInPoints * dpiY / (designEmHeight * 72f);
			float pixelAscent = designAscent * scale;
			float pixelDescent = designDescent * scale;
			return new FontMetricsInfo(pixelAscent, pixelDescent, font.GetHeight(dpiY));
		}

		private void InvalidateFontMetricsCache() {
			fontMetricsCacheValid = false;
			fontMetricsDpiY = 0f;
		}

		private void EnsureFontMetricsCache(Graphics? g = null) {
			Graphics? metricsGraphics = g ?? textGraphics;
			if (metricsGraphics == null) {
				return;
			}

			float dpiY = metricsGraphics.DpiY;
			if (fontMetricsCacheValid && Math.Abs(fontMetricsDpiY - dpiY) < 0.01f) {
				return;
			}

			for (int i = 0; i < textFontMetrics.Length; i++) {
				textFontMetrics[i] = BuildFontMetrics(GetTextFontByVariant(i), dpiY);
				inlayFontMetrics[i] = BuildFontMetrics(GetInlayFontByVariant(i), dpiY);
			}
			fontMetricsDpiY = dpiY;
			fontMetricsCacheValid = true;
		}

		private FontMetricsInfo GetTextFontMetrics(int fontStyle, Graphics? g = null) {
			EnsureFontMetricsCache(g);
			int variant = GetFontVariantIndex(fontStyle);
			if (fontMetricsCacheValid) {
				return textFontMetrics[variant];
			}
			float dpiY = g?.DpiY ?? textGraphics?.DpiY ?? 96f;
			return BuildFontMetrics(GetTextFontByVariant(variant), dpiY);
		}

		private FontMetricsInfo GetInlayFontMetrics(int fontStyle, Graphics? g = null) {
			EnsureFontMetricsCache(g);
			int variant = GetFontVariantIndex(fontStyle);
			if (fontMetricsCacheValid) {
				return inlayFontMetrics[variant];
			}
			float dpiY = g?.DpiY ?? textGraphics?.DpiY ?? 96f;
			return BuildFontMetrics(GetInlayFontByVariant(variant), dpiY);
		}

		private SolidBrush GetOrCreateBrush(int argb) {
			if (!brushCache.TryGetValue(argb, out var b)) {
				b = new SolidBrush(System.Drawing.Color.FromArgb(argb));
				brushCache[argb] = b;
			}
			return b;
		}

		private SolidBrush GetOrCreateBrush(Color color) {
			return GetOrCreateBrush(color.ToArgb());
		}

		#region TextMeasurer Callbacks

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) return 0f;
			long startTicks = PerfScope.StartTicks();
			Font font = GetFontByStyle(fontStyle);
			if (textGraphics == null) return 0f;
			DrawingSize sz = TextRenderer.MeasureText(textGraphics, text, font, new DrawingSize(int.MaxValue, int.MaxValue), TextMeasureDrawFlags);
			float w = sz.Width;
			if (w <= 0)
				w = (float)TextRenderer.MeasureText(textGraphics, text, regularFont, new DrawingSize(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordText(PerfScope.ElapsedTicks(startTicks), text.Length, fontStyle);
			return w;
		}

		private float OnMeasureInlayHintText(string text) {
			long startTicks = PerfScope.StartTicks();
			if (textGraphics == null) return 0f;
			float width = (float)TextRenderer.MeasureText(textGraphics, text, inlayHintFont, new DrawingSize(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordInlay(PerfScope.ElapsedTicks(startTicks), text?.Length ?? 0);
			return width;
		}

		private float OnMeasureIconWidth(int iconId) {
			long startTicks = PerfScope.StartTicks();
			float width = textGraphics != null
				? GetTextFontMetrics(0, textGraphics).LineHeight
				: regularFont.GetHeight();
			perfMeasureStats.RecordIcon(PerfScope.ElapsedTicks(startTicks), iconId);
			return width;
		}

		private void OnGetFontMetrics(IntPtr arrPtr, UIntPtr length) {
			FontMetricsInfo metricsInfo = GetTextFontMetrics(0, textGraphics);
			float[] metrics = [-metricsInfo.Ascent, metricsInfo.Descent];
			Marshal.Copy(metrics, 0, arrPtr, metrics.Length);
		}

		#endregion

		#region Rendering

		public void Render(Graphics g, EditorRenderModel? model, EditorTheme theme, DrawingSize clientSize) {
			var perf = PerfStepRecorder.Start();
			g.Clear(theme.BackgroundColor);
			perf.Mark(PerfStepRecorder.StepClear);
			EnsureFontMetricsCache(g);

			if (model == null) {
				perf.Finish();
				EditorPerf.LogSlow("Render(no-model)", perf.TotalTicks, EditorPerf.WarnPaintMs);
				perfOverlay.RecordDraw(perf);
				perfOverlay.Draw(g, clientSize.Width);
				return;
			}
			EditorRenderModel modelValue = model;
			g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			g.SmoothingMode = SmoothingMode.AntiAlias;

			DrawDiffLineBackgrounds(g, modelValue, 0f, clientSize.Width, false);
			DrawCurrentLineDecoration(g, modelValue, 0f, clientSize.Width);
			perf.Mark(PerfStepRecorder.StepCurrent);
			DrawRangeEffectBackgrounds(g, modelValue);
			perf.Mark(PerfStepRecorder.StepRangeEffectBackgrounds);
			DrawLines(g, modelValue);
			perf.Mark(PerfStepRecorder.StepLines);
			DrawGuideSegments(g, modelValue);
			perf.Mark(PerfStepRecorder.StepGuides);
			DrawRangeEffectOverlays(g, modelValue);
			perf.Mark(PerfStepRecorder.StepRangeEffectOverlays);
			DrawCursor(g, modelValue);
			perf.Mark(PerfStepRecorder.StepCursor);
			DrawGutterOverlay(g, modelValue, clientSize.Height);
			perf.Mark(PerfStepRecorder.StepGutter);
			DrawLineNumbers(g, modelValue);
			perf.Mark(PerfStepRecorder.StepLineNumber);
			DrawScrollbars(g, modelValue);
			perf.Mark(PerfStepRecorder.StepScrollbar);
			perf.Mark(PerfStepRecorder.StepPopup);

			perf.Finish();
			LogPaintPerfSummary(perf);
			perfOverlay.RecordDraw(perf);
			perfOverlay.Draw(g, clientSize.Width);
		}

		private void DrawLines(Graphics g, EditorRenderModel model) {
			List<VisualLine> lines = model.Lines;
			if (lines == null) return;
			foreach (var line in lines) {
				if (line.Runs == null) continue;
				foreach (var run in line.Runs) {
					DrawVisualRun(g, run);
				}
			}
		}

		private void DrawGutterOverlay(Graphics g, EditorRenderModel model, int clientHeight) {
			if (model.SplitX <= 0) return;
			SolidBrush brush = GetOrCreateBrush(currentTheme.BackgroundColor);
			g.FillRectangle(brush, 0, 0, model.SplitX, clientHeight);
			DrawDiffLineBackgrounds(g, model, 0f, model.SplitX, true);
			DrawCurrentLineDecoration(g, model, 0f, model.SplitX);
			if (model.SplitLineVisible) {
				DrawLineSplit(g, model.SplitX, clientHeight);
			}
		}

		private void DrawLineNumbers(Graphics g, EditorRenderModel model) {
			if (!model.GutterVisible) return;
			List<VisualLine> lines = model.Lines;
			if (lines == null) return;
			List<GutterIconRenderItem>? gutterIcons = model.GutterIcons;
			List<FoldMarkerRenderItem>? foldMarkers = model.FoldMarkers;
			int iconCount = gutterIcons?.Count ?? 0;
			int markerCount = foldMarkers?.Count ?? 0;
			int iconCursor = 0;
			int markerCursor = 0;
			int activeLogicalLine = GetActiveLogicalLine(model);
			Color activeLineColor = GetCurrentLineAccentColor();
			currentDrawingLineNumber = -1;
			foreach (var line in lines) {
				if (line.LineNumber < 0) continue;
				if (!line.OwnsGutterSemantics) {
					DrawPlainLineNumber(g, line, currentTheme.LineNumberColor);
					continue;
				}
				int logicalLine = line.LogicalLine;

				while (iconCursor < iconCount && gutterIcons![iconCursor].LogicalLine < logicalLine) {
					iconCursor++;
				}
				int iconStart = iconCursor;
				while (iconCursor < iconCount && gutterIcons![iconCursor].LogicalLine == logicalLine) {
					iconCursor++;
				}
				int iconEnd = iconCursor;

				while (markerCursor < markerCount && foldMarkers![markerCursor].LogicalLine < logicalLine) {
					markerCursor++;
				}
				bool hasMarker = false;
				FoldMarkerRenderItem foldMarker = default;
				while (markerCursor < markerCount && foldMarkers![markerCursor].LogicalLine == logicalLine) {
					if (!hasMarker) {
						foldMarker = foldMarkers[markerCursor];
						hasMarker = true;
					}
					markerCursor++;
				}

				DrawLineNumber(
					g,
					line,
					model,
					gutterIcons,
					iconStart,
					iconEnd,
					hasMarker,
					foldMarker,
					logicalLine == activeLogicalLine,
					activeLineColor);
			}
		}

		private void DrawScrollbars(Graphics g, EditorRenderModel model) {
			ScrollbarModel vertical = model.VerticalScrollbar;
			ScrollbarModel horizontal = model.HorizontalScrollbar;
			bool hasVertical = vertical.Visible && vertical.Track.Width > 0 && vertical.Track.Height > 0;
			bool hasHorizontal = horizontal.Visible && horizontal.Track.Width > 0 && horizontal.Track.Height > 0;
			if (!hasVertical && !hasHorizontal) return;

			SolidBrush trackBrush = GetOrCreateBrush(currentTheme.ScrollbarTrackColor);
			RectangleF verticalTrackRect = RectangleF.Empty;
			RectangleF horizontalTrackRect = RectangleF.Empty;

			if (hasVertical) {
				SolidBrush vThumbBrush = GetOrCreateBrush(vertical.ThumbActive ? currentTheme.ScrollbarThumbActiveColor : currentTheme.ScrollbarThumbColor);
				verticalTrackRect = new RectangleF(
					vertical.Track.Origin.X, vertical.Track.Origin.Y,
					vertical.Track.Width, vertical.Track.Height);
				RectangleF verticalThumbRect = new RectangleF(
					vertical.Thumb.Origin.X, vertical.Thumb.Origin.Y,
					vertical.Thumb.Width, vertical.Thumb.Height);
				g.FillRectangle(trackBrush, verticalTrackRect);
				g.FillRectangle(vThumbBrush, verticalThumbRect);
			}

			if (hasHorizontal) {
				SolidBrush hThumbBrush = GetOrCreateBrush(horizontal.ThumbActive ? currentTheme.ScrollbarThumbActiveColor : currentTheme.ScrollbarThumbColor);
				horizontalTrackRect = new RectangleF(
					horizontal.Track.Origin.X, horizontal.Track.Origin.Y,
					horizontal.Track.Width, horizontal.Track.Height);
				RectangleF horizontalThumbRect = new RectangleF(
					horizontal.Thumb.Origin.X, horizontal.Thumb.Origin.Y,
					horizontal.Thumb.Width, horizontal.Thumb.Height);
				g.FillRectangle(trackBrush, horizontalTrackRect);
				g.FillRectangle(hThumbBrush, horizontalThumbRect);
			}

			if (hasVertical && hasHorizontal) {
				var corner = new RectangleF(
					verticalTrackRect.X, horizontalTrackRect.Y,
					verticalTrackRect.Width, horizontalTrackRect.Height);
				g.FillRectangle(trackBrush, corner);
			}
		}

		private void DrawLineNumber(Graphics g, VisualLine visualLine, EditorRenderModel model,
			List<GutterIconRenderItem>? gutterIcons,
			int iconStart, int iconEnd,
			bool hasFoldMarker, FoldMarkerRenderItem foldMarker,
			bool isCurrentLine, Color activeLineColor) {
			PointF position = visualLine.LineNumberPosition;
			FontMetricsInfo metrics = GetTextFontMetrics(0, g);
			float topY = position.Y - metrics.Ascent;
			bool overlayMode = model.MaxGutterIcons == 0;
			bool hasIcons = editorIconProvider != null && iconEnd > iconStart;
			int newLineNumber = visualLine.LineNumber;
			if (overlayMode && hasIcons) {
				DrawOverlayGutterIcon(g, gutterIcons![iconStart]);
				currentDrawingLineNumber = newLineNumber;
			} else if (newLineNumber != currentDrawingLineNumber) {
				var rect = new Rectangle((int)position.X, (int)topY, 120, (int)Math.Ceiling(metrics.LineHeight));
				TextRenderer.DrawText(
					g,
					newLineNumber.ToString(),
					regularFont,
					rect,
					isCurrentLine ? activeLineColor : currentTheme.LineNumberColor,
					TextMeasureDrawFlags);
				currentDrawingLineNumber = newLineNumber;
			}

			if (!overlayMode && hasIcons) {
				for (int i = iconStart; i < iconEnd; i++) {
					DrawGutterIcon(g, gutterIcons![i]);
				}
			}

			if (hasFoldMarker) {
				DrawFoldMarker(g, foldMarker, isCurrentLine ? activeLineColor : currentTheme.LineNumberColor);
			}
		}

		private void DrawLineSplit(Graphics g, float x, int clientHeight) {
			using var pen = new Pen(currentTheme.SplitLineColor, 1f);
			g.DrawLine(pen, x, 0, x, clientHeight);
		}

		private void DrawOverlayGutterIcon(Graphics g, GutterIconRenderItem item) {
			DrawGutterIcon(g, item);
		}

		private bool DrawGutterIcon(Graphics g, GutterIconRenderItem item) {
			if (item.Rect.Width <= 0 || item.Rect.Height <= 0) return false;
			int iconId = item.IconId;
			Image? image = editorIconProvider?.GetIconImage(iconId);
			if (image == null) return false;
			InterpolationMode oldInterpolation = g.InterpolationMode;
			g.InterpolationMode = InterpolationMode.HighQualityBicubic;
			g.DrawImage(image, item.Rect.Origin.X, item.Rect.Origin.Y, item.Rect.Width, item.Rect.Height);
			g.InterpolationMode = oldInterpolation;
			return true;
		}

		private void DrawFoldMarker(Graphics g, FoldMarkerRenderItem marker, Color color) {
			if (marker.Rect.Width <= 0 || marker.Rect.Height <= 0) return;
			if (marker.FoldState == FoldState.NONE) return;

			float centerX = marker.Rect.Origin.X + marker.Rect.Width * 0.5f;
			float centerY = marker.Rect.Origin.Y + marker.Rect.Height * 0.5f;
			float halfSize = Math.Min(marker.Rect.Width, marker.Rect.Height) * 0.28f;

			using var path = new GraphicsPath();
			using var pen = new Pen(color, Math.Max(1f, marker.Rect.Height * 0.1f)) {
				StartCap = LineCap.Round,
				EndCap = LineCap.Round,
				LineJoin = LineJoin.Round
			};

			if (marker.FoldState == FoldState.COLLAPSED) {
				path.AddLines([
					new System.Drawing.PointF(centerX - halfSize * 0.5f, centerY - halfSize),
					new System.Drawing.PointF(centerX + halfSize * 0.5f, centerY),
					new System.Drawing.PointF(centerX - halfSize * 0.5f, centerY + halfSize)
				]);
			} else {
				path.AddLines([
					new System.Drawing.PointF(centerX - halfSize, centerY - halfSize * 0.5f),
					new System.Drawing.PointF(centerX, centerY + halfSize * 0.5f),
					new System.Drawing.PointF(centerX + halfSize, centerY - halfSize * 0.5f)
				]);
			}
			g.DrawPath(pen, path);
		}

		private void DrawVisualRun(Graphics g, VisualRun visualRun) {
			string text = visualRun.Text;
			string drawTextContent = text ?? string.Empty;
			bool hasText = !string.IsNullOrEmpty(text);
			if (DrawInvisibleCharacterRun(g, visualRun)) return;
			if (!hasText && visualRun.Type != VisualRunType.INLAY_HINT) return;
			Font font = (visualRun.Type == VisualRunType.INLAY_HINT)
				? GetInlayHintFontByStyle(visualRun.Style.FontStyle)
				: GetFontByStyle(visualRun.Style.FontStyle);
			FontMetricsInfo metrics = visualRun.Type == VisualRunType.INLAY_HINT
				? GetInlayFontMetrics(visualRun.Style.FontStyle, g)
				: GetTextFontMetrics(visualRun.Style.FontStyle, g);
			Color color = (visualRun.Style.Color != 0)
				? Color.FromArgb(visualRun.Style.Color)
				: currentTheme.TextColor;

			float topY = visualRun.Y - metrics.Ascent;
			int lineHeight = (int)Math.Ceiling(metrics.LineHeight);
			int drawWidth = Math.Max(1, (int)Math.Ceiling(visualRun.Width));

			if (visualRun.Type == VisualRunType.FOLD_PLACEHOLDER) {
				float mgn = visualRun.Margin;
				float fontHeight = metrics.LineHeight;
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2;
				float bgHeight = fontHeight;
				float radius = fontHeight * 0.2f;
				DrawRoundedRect(g, GetOrCreateBrush(currentTheme.FoldPlaceholderBgColor), bgLeft, bgTop, bgWidth, bgHeight, radius);
				float textX = visualRun.X + mgn + visualRun.Padding;
				int foldW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
				var foldRect = new Rectangle((int)textX, (int)topY, foldW, lineHeight);
				Color foldColor = currentTheme.FoldPlaceholderTextColor;
				TextRenderer.DrawText(g, drawTextContent, font, foldRect, foldColor, TextMeasureDrawFlags);
			} else if (visualRun.Type == VisualRunType.INLAY_HINT) {
				float mgn = visualRun.Margin;
				float fontHeight = metrics.LineHeight;
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2;
				float bgHeight = fontHeight;

				if (visualRun.ColorValue != 0) {
					float blockSize = fontHeight;
					float colorLeft = visualRun.X + mgn;
					float colorTop = topY;
					g.FillRectangle(GetOrCreateBrush(visualRun.ColorValue), colorLeft, colorTop, blockSize, blockSize);
				} else {
					float radius = fontHeight * 0.2f;
					DrawRoundedRect(g, GetOrCreateBrush(currentTheme.InlayHintBgColor), bgLeft, bgTop, bgWidth, bgHeight, radius);
					if (visualRun.IconId > 0 && editorIconProvider != null) {
						float iconSize = Math.Min(bgWidth, bgHeight);
						float iconLeft = bgLeft + (bgWidth - iconSize) * 0.5f;
						float iconTop2 = bgTop + (bgHeight - iconSize) * 0.5f;
						DrawGutterIcon(g, new GutterIconRenderItem {
							LogicalLine = -1,
							IconId = visualRun.IconId,
							Rect = new Rect(iconLeft, iconTop2, iconSize, iconSize),
						});
					} else if (hasText) {
						float textX = visualRun.X + mgn + visualRun.Padding;
						int inlayW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
						var inlayRect = new Rectangle((int)textX, (int)topY, inlayW, lineHeight);
						TextRenderer.DrawText(g, drawTextContent, font, inlayRect, color, TextMeasureDrawFlags);
					}
				}
			} else {
				if (visualRun.Style.BackgroundColor != 0) {
					g.FillRectangle(GetOrCreateBrush(visualRun.Style.BackgroundColor), visualRun.X, topY, drawWidth, lineHeight);
				}
				var rect = new Rectangle((int)visualRun.X, (int)topY, drawWidth, lineHeight);
				Color drawColor = visualRun.Type == VisualRunType.PHANTOM_TEXT
					? Color.FromArgb(128, color)
					: color;
				TextRenderer.DrawText(g, drawTextContent, font, rect, drawColor, TextMeasureDrawFlags);
				if ((visualRun.Type == VisualRunType.CODELENS || visualRun.Type == VisualRunType.LINK) && visualRun.Active) {
					float underlineY = visualRun.Y + 1f;
					using var underlinePen = new Pen(drawColor, 1f);
					g.DrawLine(underlinePen, visualRun.X, underlineY, visualRun.X + visualRun.Width, underlineY);
				}
			}

			if ((visualRun.Style.FontStyle & SweetEditorControl.FONT_STYLE_STRIKETHROUGH) != 0) {
				float strikeY = topY + metrics.Ascent * 0.5f;
				using var pen = new Pen(color, 1f);
				g.DrawLine(pen, visualRun.X, strikeY, visualRun.X + visualRun.Width, strikeY);
			}
		}

		private bool DrawInvisibleCharacterRun(Graphics g, VisualRun visualRun) {
			if (visualRun.Type != VisualRunType.WHITESPACE
				&& visualRun.Type != VisualRunType.TAB
				&& visualRun.Type != VisualRunType.NEWLINE) {
				return false;
			}
			FontMetricsInfo metrics = GetTextFontMetrics(visualRun.Style.FontStyle, g);
			float topY = visualRun.Y - metrics.Ascent;
			int lineHeight = (int)Math.Ceiling(metrics.LineHeight);
			int drawWidth = Math.Max(1, (int)Math.Ceiling(visualRun.Width));
			if (visualRun.Type == VisualRunType.WHITESPACE) {
				DrawRunBackground(g, visualRun, topY, drawWidth, lineHeight);
				DrawWhitespaceMarkerRun(g, visualRun, metrics);
				return true;
			}
			if (visualRun.Type == VisualRunType.TAB) {
				DrawRunBackground(g, visualRun, topY, drawWidth, lineHeight);
				DrawTabMarkerRun(g, visualRun, metrics);
				return true;
			}
			if (visualRun.Type == VisualRunType.NEWLINE) {
				DrawRunBackground(g, visualRun, topY, drawWidth, lineHeight);
				DrawLineBreakMarkerRun(g, visualRun, metrics);
				return true;
			}
			return false;
		}

		private void DrawRunBackground(Graphics g, VisualRun visualRun, float topY, int drawWidth, int lineHeight) {
			if (visualRun.Style.BackgroundColor == 0) return;
			g.FillRectangle(GetOrCreateBrush(visualRun.Style.BackgroundColor), visualRun.X, topY, drawWidth, lineHeight);
		}

		private void DrawWhitespaceMarkerRun(Graphics g, VisualRun visualRun, FontMetricsInfo metrics) {
			string text = visualRun.Text ?? string.Empty;
			int markerCount = text.Length;
			if (markerCount <= 0 || visualRun.Width <= 0f) return;

			float cellWidth = visualRun.Width / Math.Max(1, markerCount);
			float centerY = visualRun.Y + (metrics.Descent - metrics.Ascent) * 0.5f;
			float radius = Math.Max(1.0f, Math.Min(cellWidth, regularFont.Size) * 0.08f);
			using var brush = new SolidBrush(GetInvisibleCharacterColor());
			for (int i = 0; i < markerCount; i++) {
				float centerX = visualRun.X + cellWidth * (i + 0.5f);
				g.FillEllipse(brush, centerX - radius, centerY - radius, radius * 2, radius * 2);
			}
		}

		private void DrawTabMarkerRun(Graphics g, VisualRun visualRun, FontMetricsInfo metrics) {
			if (string.IsNullOrEmpty(visualRun.Text) || visualRun.Width <= 0f) return;

			float centerY = visualRun.Y + (metrics.Descent - metrics.Ascent) * 0.5f;
			float padding = Math.Min(visualRun.Width * 0.25f, 8.0f);
			float left = visualRun.X + padding;
			float right = Math.Max(left, visualRun.X + visualRun.Width - padding);
			float arrow = Math.Min(5.0f, Math.Max(2.0f, (right - left) * 0.35f));
			using var pen = new Pen(GetInvisibleCharacterColor(), Math.Max(1.0f, regularFont.Size * 0.06f)) {
				StartCap = LineCap.Round,
				EndCap = LineCap.Round,
				LineJoin = LineJoin.Round
			};
			g.DrawLine(pen, left, centerY, right, centerY);
			g.DrawLine(pen, right, centerY, right - arrow, centerY - arrow);
			g.DrawLine(pen, right, centerY, right - arrow, centerY + arrow);
		}

		private void DrawLineBreakMarkerRun(Graphics g, VisualRun visualRun, FontMetricsInfo metrics) {
			if (string.IsNullOrEmpty(visualRun.Text)) return;
			int width = Math.Max(1, (int)Math.Ceiling(visualRun.Width));
			var rect = new Rectangle((int)visualRun.X, (int)(visualRun.Y - metrics.Ascent), width, (int)Math.Ceiling(metrics.LineHeight));
			TextRenderer.DrawText(g, visualRun.Text, regularFont, rect, GetInvisibleCharacterColor(), TextMeasureDrawFlags);
		}

		private Color GetInvisibleCharacterColor() {
			return currentTheme.InvisibleCharacterColor.IsEmpty
				? Color.FromArgb(0x70, currentTheme.TextColor)
				: currentTheme.InvisibleCharacterColor;
		}

		private static void DrawRoundedRect(Graphics g, Brush brush, float x, float y, float width, float height, float radius) {
			if (radius <= 0) {
				g.FillRectangle(brush, x, y, width, height);
				return;
			}
			using (var path = new GraphicsPath()) {
				float d = radius * 2;
				path.AddArc(x, y, d, d, 180, 90);
				path.AddArc(x + width - d, y, d, d, 270, 90);
				path.AddArc(x + width - d, y + height - d, d, d, 0, 90);
				path.AddArc(x, y + height - d, d, d, 90, 90);
				path.CloseFigure();
				g.FillPath(brush, path);
			}
		}

		private void DrawCurrentLineDecoration(Graphics g, EditorRenderModel model, float left, float width) {
			if (width <= 0f) return;
			float lineH = model.Cursor.Height > 0 ? model.Cursor.Height : regularFont.GetHeight(g);
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.NONE) return;
			if (model.CurrentLineRenderMode == CurrentLineRenderMode.BORDER) {
				using var pen = new Pen(GetCurrentLineBorderColor(), 1f);
				g.DrawRectangle(pen, left, model.CurrentLine.Y, width, lineH);
				return;
			}
			SolidBrush brush = GetOrCreateBrush(currentTheme.CurrentLineColor);
			g.FillRectangle(brush, left, model.CurrentLine.Y, width, lineH);
		}

		private void DrawDiffLineBackgrounds(Graphics g, EditorRenderModel model,
			float left, float width, bool gutter) {
			if (width <= 0f || model.Lines == null) return;
			float lineHeight = model.Cursor.Height > 0 ? model.Cursor.Height : regularFont.GetHeight(g);
			FontMetricsInfo metrics = GetTextFontMetrics(0, g);
			float topPadding = (lineHeight - metrics.LineHeight) * 0.5f;
			foreach (VisualLine line in model.Lines) {
				int color = gutter ? line.GutterBackgroundColor : line.LineBackgroundColor;
				if (color == 0) continue;
				float top = line.LineNumberPosition.Y - metrics.Ascent - topPadding;
				g.FillRectangle(GetOrCreateBrush(color), left, top, width, lineHeight);
			}
		}

		private void DrawPlainLineNumber(Graphics g, VisualLine line, Color color) {
			FontMetricsInfo metrics = GetTextFontMetrics(0, g);
			var rect = new Rectangle((int)line.LineNumberPosition.X,
				(int)(line.LineNumberPosition.Y - metrics.Ascent), 120,
				(int)Math.Ceiling(metrics.LineHeight));
			TextRenderer.DrawText(g, line.LineNumber.ToString(), regularFont, rect, color, TextMeasureDrawFlags);
		}

		private int GetActiveLogicalLine(EditorRenderModel model) => model.Cursor.TextPosition.Line;

		private Color GetCurrentLineAccentColor() {
			int argb = currentTheme.CurrentLineNumberColor.ToArgb();
			if (argb == 0) argb = currentTheme.LineNumberColor.ToArgb();
			return Color.FromArgb(unchecked((int)((uint)argb | 0xFF000000u)));
		}

		private Color GetCurrentLineBorderColor() {
			int argb = currentTheme.CurrentLineColor.ToArgb();
			if (argb == 0) argb = currentTheme.LineNumberColor.ToArgb();
			int alpha = (argb >> 24) & 0xFF;
			if (alpha < 0xA0) {
				argb = (argb & 0x00FFFFFF) | unchecked((int)0xA0000000);
			}
			return Color.FromArgb(argb);
		}

		private void DrawRangeEffectBackgrounds(Graphics g, EditorRenderModel model) {
			if (model.RangeEffects == null || model.RangeEffects.Count == 0) return;
			foreach (var effect in model.RangeEffects) {
				if (effect.Style.BackgroundColor == 0) continue;
				SolidBrush brush = GetOrCreateBrush(effect.Style.BackgroundColor);
				g.FillRectangle(brush, effect.Rect.Origin.X, effect.Rect.Origin.Y, effect.Rect.Width, effect.Rect.Height);
			}
		}

		private void DrawCursor(Graphics g, EditorRenderModel model) {
			if (!model.Cursor.Visible) return;
			SolidBrush brush = GetOrCreateBrush(currentTheme.CursorColor);
			g.FillRectangle(brush, model.Cursor.Position.X, model.Cursor.Position.Y, 2f, model.Cursor.Height);
		}

		private void DrawRangeEffectOverlays(Graphics g, EditorRenderModel model) {
			if (model.RangeEffects == null || model.RangeEffects.Count == 0) return;
			foreach (var effect in model.RangeEffects) {
				if (effect.Style.BorderColor != 0) {
					using var pen = new Pen(Color.FromArgb(effect.Style.BorderColor), BorderStrokeWidth(effect.Kind));
					g.DrawRectangle(pen, effect.Rect.Origin.X, effect.Rect.Origin.Y, effect.Rect.Width, effect.Rect.Height);
				}
				if (effect.Style.UnderlineColor != 0 && effect.Style.UnderlineStyle != RangeEffectUnderlineStyle.NONE) {
					DrawRangeEffectUnderline(g, effect.Rect, effect.Style);
				}
			}
		}

		private static float BorderStrokeWidth(RangeEffectKind kind) {
			return kind == RangeEffectKind.LINKED_EDITING_ACTIVE ? 2f : 1.5f;
		}

		private void DrawRangeEffectUnderline(Graphics g, Rect rect, RangeEffectStyle style) {
			float startX = rect.Origin.X;
			float endX = startX + rect.Width;
			float baseY = rect.Origin.Y + rect.Height - 1f;
			using var pen = new Pen(Color.FromArgb(style.UnderlineColor),
				style.UnderlineStyle == RangeEffectUnderlineStyle.WAVY ? 3f : 2f);

			if (style.UnderlineStyle == RangeEffectUnderlineStyle.DASHED) {
				pen.DashPattern = [3f, 2f];
				g.DrawLine(pen, startX, baseY, endX, baseY);
				return;
			}

			if (style.UnderlineStyle == RangeEffectUnderlineStyle.SOLID) {
				g.DrawLine(pen, startX, baseY, endX, baseY);
				return;
			}

			float halfWave = 7f;
			float amplitude = 3.5f;
			using var path = new GraphicsPath();
			float x = startX;
			int step = 0;
			while (x < endX) {
				float nextX = Math.Min(x + halfWave, endX);
				float midX = (x + nextX) / 2f;
				float peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude;
				float c1x = x + 2f / 3f * (midX - x);
				float c1y = baseY + 2f / 3f * (peakY - baseY);
				float c2x = nextX + 2f / 3f * (midX - nextX);
				float c2y = baseY + 2f / 3f * (peakY - baseY);
				var p0 = step == 0
					? new System.Drawing.PointF(x, baseY)
					: path.GetLastPoint();
				path.AddBezier(p0,
					new System.Drawing.PointF(c1x, c1y),
					new System.Drawing.PointF(c2x, c2y),
					new System.Drawing.PointF(nextX, baseY));
				x = nextX;
				step++;
			}
			g.DrawPath(pen, path);
		}

		private void DrawGuideSegments(Graphics g, EditorRenderModel model) {
			if (model.GuideSegments == null || model.GuideSegments.Count == 0) return;
			foreach (var seg in model.GuideSegments) {
				var color = seg.Type switch {
					GuideType.SEPARATOR => currentTheme.SeparatorLineColor,
					_ => currentTheme.GuideColor
				};
				float lineWidth = seg.Type == GuideType.INDENT ? 1f : 1.2f;
				using var pen = new Pen(color, lineWidth);

				if (seg.ArrowEnd) {
					float dpiScale = g.DpiX / 96f;
					float arrowLen = (seg.Type == GuideType.FLOW ? 9f : 8f) * dpiScale;
					float arrowAngle = (float)(Math.PI * 28.0 / 180.0);
					float arrowDepth = (float)(arrowLen * Math.Cos(arrowAngle));
					float dx = seg.End.X - seg.Start.X;
					float dy = seg.End.Y - seg.Start.Y;
					float len = (float)Math.Sqrt(dx * dx + dy * dy);
					float trim = arrowDepth + lineWidth * 0.5f;
					if (len > trim) {
						float ratio = (len - trim) / len;
						float lineEndX = seg.Start.X + dx * ratio;
						float lineEndY = seg.Start.Y + dy * ratio;
						g.DrawLine(pen, seg.Start.X, seg.Start.Y, lineEndX, lineEndY);
					}
					DrawArrowHead(g, color, seg.Start, seg.End, arrowLen, arrowAngle);
				} else {
					g.DrawLine(pen, seg.Start.X, seg.Start.Y, seg.End.X, seg.End.Y);
				}
			}
		}

		private static void DrawArrowHead(Graphics g, System.Drawing.Color color, PointF from, PointF to, float arrowLen, float arrowAngle) {
			float dx = to.X - from.X;
			float dy = to.Y - from.Y;
			float len = (float)Math.Sqrt(dx * dx + dy * dy);
			if (len < 1f) return;
			float ux = dx / len;
			float uy = dy / len;
			float cosA = (float)Math.Cos(arrowAngle);
			float sinA = (float)Math.Sin(arrowAngle);
			float ax1 = to.X - arrowLen * (ux * cosA - uy * sinA);
			float ay1 = to.Y - arrowLen * (uy * cosA + ux * sinA);
			float ax2 = to.X - arrowLen * (ux * cosA + uy * sinA);
			float ay2 = to.Y - arrowLen * (uy * cosA - ux * sinA);

			using var brush = new SolidBrush(color);
			using var path = new GraphicsPath();
			path.AddPolygon([
				new System.Drawing.PointF(to.X, to.Y),
				new System.Drawing.PointF(ax1, ay1),
				new System.Drawing.PointF(ax2, ay2)
			]);
			g.FillPath(brush, path);
		}

		#endregion

		#region Perf Logging

		internal void LogBuildPerfSummary(PerfStepRecorder perf) {
			if (!EditorPerf.Enabled) return;
			double totalMs = EditorPerf.TicksToMs(perf.TotalTicks);
			double buildMs = perf.GetStepMs(PerfStepRecorder.StepBuild);
			bool shouldLog = totalMs >= EditorPerf.WarnBuildMs || buildMs >= EditorPerf.WarnBuildMs || perfMeasureStats.ShouldLogBuild();
			if (!shouldLog) return;
			System.Diagnostics.Debug.WriteLine(
				$"[PERF][Build] total={totalMs:F2}ms " +
				$"{PerfStepRecorder.StepPrep}={perf.GetStepMs(PerfStepRecorder.StepPrep):F2}ms " +
				$"{PerfStepRecorder.StepBuild}={buildMs:F2}ms " +
				$"{PerfStepRecorder.StepMetrics}={perf.GetStepMs(PerfStepRecorder.StepMetrics):F2}ms " +
				$"{PerfStepRecorder.StepAnchor}={perf.GetStepMs(PerfStepRecorder.StepAnchor):F2}ms " +
				$"{PerfStepRecorder.StepInvalidate}={perf.GetStepMs(PerfStepRecorder.StepInvalidate):F2}ms " +
				$"| {perfMeasureStats.BuildSummary()}");
		}

		private void LogPaintPerfSummary(PerfStepRecorder perf) {
			if (!EditorPerf.Enabled) return;
			double totalMs = EditorPerf.TicksToMs(perf.TotalTicks);
			if (totalMs < EditorPerf.WarnPaintMs && !perf.AnyStepOver(EditorPerf.WarnPaintStepMs)) return;
			System.Diagnostics.Debug.WriteLine(
				$"[PERF][Paint] total={totalMs:F2}ms " +
				$"{PerfStepRecorder.StepClear}={perf.GetStepMs(PerfStepRecorder.StepClear):F2}ms " +
				$"{PerfStepRecorder.StepCurrent}={perf.GetStepMs(PerfStepRecorder.StepCurrent):F2}ms " +
				$"{PerfStepRecorder.StepRangeEffectBackgrounds}={perf.GetStepMs(PerfStepRecorder.StepRangeEffectBackgrounds):F2}ms " +
				$"{PerfStepRecorder.StepLines}={perf.GetStepMs(PerfStepRecorder.StepLines):F2}ms " +
				$"{PerfStepRecorder.StepGuides}={perf.GetStepMs(PerfStepRecorder.StepGuides):F2}ms " +
				$"{PerfStepRecorder.StepRangeEffectOverlays}={perf.GetStepMs(PerfStepRecorder.StepRangeEffectOverlays):F2}ms " +
				$"{PerfStepRecorder.StepCursor}={perf.GetStepMs(PerfStepRecorder.StepCursor):F2}ms " +
				$"{PerfStepRecorder.StepGutter}={perf.GetStepMs(PerfStepRecorder.StepGutter):F2}ms " +
				$"{PerfStepRecorder.StepLineNumber}={perf.GetStepMs(PerfStepRecorder.StepLineNumber):F2}ms " +
				$"{PerfStepRecorder.StepScrollbar}={perf.GetStepMs(PerfStepRecorder.StepScrollbar):F2}ms " +
				$"{PerfStepRecorder.StepPopup}={perf.GetStepMs(PerfStepRecorder.StepPopup):F2}ms");
		}

		internal void RecordInputPerf(string tag, double elapsedMs) {
			perfOverlay.RecordInput(tag, elapsedMs);
		}

		internal PerfScope StartInputPerf(string tag) {
			return PerfScope.Start(tag, EditorPerf.WarnInputMs, RecordInputPerf);
		}

		#endregion

		public void Dispose() {
			perfOverlay.Dispose();
			textGraphics?.Dispose();
			foreach (var b in brushCache.Values) b.Dispose();
			brushCache.Clear();
		}
	}
}
