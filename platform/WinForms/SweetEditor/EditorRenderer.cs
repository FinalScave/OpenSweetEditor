using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Text;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using SweetEditor.Perf;

namespace SweetEditor {
	/// <summary>
	/// Platform-independent rendering engine for the WinForms editor.
	/// Owns all Font objects, implements text measurement callbacks, and contains all draw methods.
	/// EditorControl delegates all rendering to this class.
	/// </summary>
	public class EditorRenderer : IDisposable {

		private const float BaseTextFontSize = 11f;
		private const float BaseInlayHintFontSize = 9.5f;
		private const string BaseTextFontFamily = "Consolas";
		private const string BaseInlayHintFontFamily = "Segoe UI";

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

		public EditorRenderer(EditorTheme theme) {
			currentTheme = theme;
			regularFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Regular);
			boldFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Bold);
			italicFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Italic);
			boldItalicFont = new Font(BaseTextFontFamily, BaseTextFontSize, FontStyle.Bold | FontStyle.Italic);
			inlayHintFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Regular);
			inlayHintBoldFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Bold);
			inlayHintItalicFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Italic);
			inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, BaseInlayHintFontSize, FontStyle.Bold | FontStyle.Italic);
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
		}

		public Graphics? GetTextGraphics() => textGraphics;

		public void RecreateTextGraphics(Control control) {
			textGraphics?.Dispose();
			textGraphics = control.CreateGraphics();
			textGraphics.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
		}

		public void SyncPlatformScale(float scale) {
			if (scale <= 0f) return;
			float textSize = Math.Max(1f, BaseTextFontSize * scale);
			float inlaySize = Math.Max(1f, BaseInlayHintFontSize * scale);

			regularFont.Dispose();
			boldFont.Dispose();
			italicFont.Dispose();
			boldItalicFont.Dispose();
			inlayHintFont.Dispose();
			inlayHintBoldFont.Dispose();
			inlayHintItalicFont.Dispose();
			inlayHintBoldItalicFont.Dispose();

			regularFont = new Font(BaseTextFontFamily, textSize, FontStyle.Regular);
			boldFont = new Font(BaseTextFontFamily, textSize, FontStyle.Bold);
			italicFont = new Font(BaseTextFontFamily, textSize, FontStyle.Italic);
			boldItalicFont = new Font(BaseTextFontFamily, textSize, FontStyle.Bold | FontStyle.Italic);
			inlayHintFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Regular);
			inlayHintBoldFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold);
			inlayHintItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Italic);
			inlayHintBoldItalicFont = new Font(BaseInlayHintFontFamily, inlaySize, FontStyle.Bold | FontStyle.Italic);
		}

		private Font GetFontByStyle(int fontStyle) {
			bool isBold = (fontStyle & EditorControl.FONT_STYLE_BOLD) != 0;
			bool isItalic = (fontStyle & EditorControl.FONT_STYLE_ITALIC) != 0;
			if (isBold && isItalic) return boldItalicFont;
			if (isBold) return boldFont;
			if (isItalic) return italicFont;
			return regularFont;
		}

		private Font GetInlayHintFontByStyle(int fontStyle) {
			bool isBold = (fontStyle & EditorControl.FONT_STYLE_BOLD) != 0;
			bool isItalic = (fontStyle & EditorControl.FONT_STYLE_ITALIC) != 0;
			if (isBold && isItalic) return inlayHintBoldItalicFont;
			if (isBold) return inlayHintBoldFont;
			if (isItalic) return inlayHintItalicFont;
			return inlayHintFont;
		}

		private static float GetFontAscent(Graphics g, Font font) {
			int designAscent = font.FontFamily.GetCellAscent(font.Style);
			int designEmHeight = font.FontFamily.GetEmHeight(font.Style);
			float pixelAscent = designAscent * font.SizeInPoints * g.DpiY / (designEmHeight * 72f);
			return pixelAscent;
		}

		private SolidBrush GetOrCreateBrush(int argb) {
			if (!brushCache.TryGetValue(argb, out var b)) {
				b = new SolidBrush(System.Drawing.Color.FromArgb(argb));
				brushCache[argb] = b;
			}
			return b;
		}

		#region TextMeasurer Callbacks

		private float OnMeasureText(string text, int fontStyle) {
			if (string.IsNullOrEmpty(text)) return 0f;
			long startTicks = PerfScope.StartTicks();
			Font font = GetFontByStyle(fontStyle);
			if (textGraphics == null) return 0f;
			Size sz = TextRenderer.MeasureText(textGraphics, text, font, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags);
			float w = sz.Width;
			if (w <= 0)
				w = (float)TextRenderer.MeasureText(textGraphics, text, regularFont, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordText(PerfScope.ElapsedTicks(startTicks), text.Length, fontStyle);
			return w;
		}

		private float OnMeasureInlayHintText(string text) {
			long startTicks = PerfScope.StartTicks();
			if (textGraphics == null) return 0f;
			float width = (float)TextRenderer.MeasureText(textGraphics, text, inlayHintFont, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags).Width;
			perfMeasureStats.RecordInlay(PerfScope.ElapsedTicks(startTicks), text?.Length ?? 0);
			return width;
		}

		private float OnMeasureIconWidth(int iconId) {
			long startTicks = PerfScope.StartTicks();
			float width = textGraphics != null
				? regularFont.GetHeight(textGraphics)
				: regularFont.GetHeight();
			perfMeasureStats.RecordIcon(PerfScope.ElapsedTicks(startTicks), iconId);
			return width;
		}

		private void OnGetFontMetrics(IntPtr arrPtr, UIntPtr length) {
			int designAscent = regularFont.FontFamily.GetCellAscent(regularFont.Style);
			int designDescent = regularFont.FontFamily.GetCellDescent(regularFont.Style);
			int designEmHeight = regularFont.FontFamily.GetEmHeight(regularFont.Style);
			float emSizeInPoints = regularFont.SizeInPoints;
			float pixelAscent = designAscent * emSizeInPoints * textGraphics!.DpiY / (designEmHeight * 72f);
			float pixelDescent = designDescent * emSizeInPoints * textGraphics!.DpiY / (designEmHeight * 72f);
			float[] metrics = [-pixelAscent, pixelDescent];
			Marshal.Copy(metrics, 0, arrPtr, metrics.Length);
		}

		#endregion

		#region Rendering

		public void Render(Graphics g, EditorRenderModel? model, EditorTheme theme, Size clientSize) {
			var perf = PerfStepRecorder.Start();
			g.Clear(theme.BackgroundColor);
			perf.Mark(PerfStepRecorder.StepClear);

			if (!model.HasValue) {
				perf.Finish();
				EditorPerf.LogSlow("Render(no-model)", perf.TotalTicks, EditorPerf.WarnPaintMs);
				perfOverlay.RecordDraw(perf);
				perfOverlay.Draw(g, clientSize.Width);
				return;
			}
			EditorRenderModel modelValue = model.Value;
			g.TextRenderingHint = TextRenderingHint.ClearTypeGridFit;
			g.SmoothingMode = SmoothingMode.AntiAlias;

			DrawCurrentLineDecoration(g, modelValue, 0f, clientSize.Width);
			perf.Mark(PerfStepRecorder.StepCurrent);
			DrawSelectionRects(g, modelValue);
			perf.Mark(PerfStepRecorder.StepSelection);
			DrawLines(g, modelValue);
			perf.Mark(PerfStepRecorder.StepLines);
			DrawGuideSegments(g, modelValue);
			perf.Mark(PerfStepRecorder.StepGuides);
			if (modelValue.CompositionDecoration.Active) {
				DrawCompositionDecoration(g, modelValue.CompositionDecoration);
				perf.Mark(PerfStepRecorder.StepComposition);
			}
			DrawDiagnosticDecorations(g, modelValue);
			perf.Mark(PerfStepRecorder.StepDiagnostics);
			DrawLinkedEditingRects(g, modelValue);
			perf.Mark(PerfStepRecorder.StepLinkedEditing);
			DrawBracketHighlightRects(g, modelValue);
			perf.Mark(PerfStepRecorder.StepBracket);
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
			List<VisualLine> lines = model.VisualLines;
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
			using var brush = new SolidBrush(currentTheme.BackgroundColor);
			g.FillRectangle(brush, 0, 0, model.SplitX, clientHeight);
			DrawCurrentLineDecoration(g, model, 0f, model.SplitX);
			if (model.SplitLineVisible) {
				DrawLineSplit(g, model.SplitX, clientHeight);
			}
		}

		private void DrawLineNumbers(Graphics g, EditorRenderModel model) {
			if (!model.GutterVisible) return;
			List<VisualLine> lines = model.VisualLines;
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
				if (line.WrapIndex != 0 || line.IsPhantomLine) continue;
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

			using var trackBrush = new SolidBrush(currentTheme.ScrollbarTrackColor);
			RectangleF verticalTrackRect = RectangleF.Empty;
			RectangleF horizontalTrackRect = RectangleF.Empty;

			if (hasVertical) {
				var vThumbColor = vertical.ThumbActive ? currentTheme.ScrollbarThumbActiveColor : currentTheme.ScrollbarThumbColor;
				using var vThumbBrush = new SolidBrush(vThumbColor);
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
				var hThumbColor = horizontal.ThumbActive ? currentTheme.ScrollbarThumbActiveColor : currentTheme.ScrollbarThumbColor;
				using var hThumbBrush = new SolidBrush(hThumbColor);
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
			float topY = position.Y - GetFontAscent(g, regularFont);
			bool overlayMode = model.MaxGutterIcons == 0;
			bool hasIcons = editorIconProvider != null && iconEnd > iconStart;
			int newLineNumber = visualLine.LogicalLine + 1;
			if (overlayMode && hasIcons) {
				DrawOverlayGutterIcon(g, gutterIcons![iconStart]);
				currentDrawingLineNumber = newLineNumber;
			} else if (newLineNumber != currentDrawingLineNumber) {
				var rect = new Rectangle((int)position.X, (int)topY, 120, (int)Math.Ceiling(regularFont.GetHeight(g)));
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
			if (item.Width <= 0 || item.Height <= 0) return false;
			int iconId = item.IconId;
			Image? image = editorIconProvider?.GetIconImage(iconId);
			if (image == null) return false;
			InterpolationMode oldInterpolation = g.InterpolationMode;
			g.InterpolationMode = InterpolationMode.HighQualityBicubic;
			g.DrawImage(image, item.Origin.X, item.Origin.Y, item.Width, item.Height);
			g.InterpolationMode = oldInterpolation;
			return true;
		}

		private void DrawFoldMarker(Graphics g, FoldMarkerRenderItem marker, Color color) {
			if (marker.Width <= 0 || marker.Height <= 0) return;
			if (marker.FoldState == FoldState.NONE) return;

			float centerX = marker.Origin.X + marker.Width * 0.5f;
			float centerY = marker.Origin.Y + marker.Height * 0.5f;
			float halfSize = Math.Min(marker.Width, marker.Height) * 0.28f;

			using var path = new GraphicsPath();
			using var pen = new Pen(color, Math.Max(1f, marker.Height * 0.1f)) {
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
			if (!hasText && visualRun.Type != VisualRunType.INLAY_HINT) return;
			Font font = (visualRun.Type == VisualRunType.INLAY_HINT)
				? GetInlayHintFontByStyle(visualRun.Style.FontStyle)
				: GetFontByStyle(visualRun.Style.FontStyle);
			Color color = (visualRun.Style.Color != 0)
				? Color.FromArgb(visualRun.Style.Color)
				: currentTheme.TextColor;

			float ascent = GetFontAscent(g, font);
			float topY = visualRun.Y - ascent;
			int lineHeight = (int)Math.Ceiling(font.GetHeight(g));

			Size measuredSize = TextRenderer.MeasureText(g, drawTextContent, font, new Size(int.MaxValue, int.MaxValue), TextMeasureDrawFlags);
			int drawWidth = Math.Max((int)Math.Ceiling(visualRun.Width), measuredSize.Width);
			if (drawWidth < 1) drawWidth = 1;

			if (visualRun.Type == VisualRunType.FOLD_PLACEHOLDER) {
				float mgn = visualRun.Margin;
				float fontHeight = font.GetHeight(g);
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2;
				float bgHeight = fontHeight;
				float radius = fontHeight * 0.2f;
				using (var bgBrush = new SolidBrush(currentTheme.FoldPlaceholderBgColor)) {
					DrawRoundedRect(g, bgBrush, bgLeft, bgTop, bgWidth, bgHeight, radius);
				}
				float textX = visualRun.X + mgn + visualRun.Padding;
				int foldW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
				foldW = Math.Max(foldW, measuredSize.Width);
				var foldRect = new Rectangle((int)textX, (int)topY, foldW, lineHeight);
				Color foldColor = currentTheme.FoldPlaceholderTextColor;
				TextRenderer.DrawText(g, drawTextContent, font, foldRect, foldColor, TextMeasureDrawFlags);
			} else if (visualRun.Type == VisualRunType.INLAY_HINT) {
				float mgn = visualRun.Margin;
				float fontHeight = font.GetHeight(g);
				float bgLeft = visualRun.X + mgn;
				float bgTop = topY;
				float bgWidth = visualRun.Width - mgn * 2;
				float bgHeight = fontHeight;

				if (visualRun.ColorValue != 0) {
					float blockSize = fontHeight;
					float colorLeft = visualRun.X + mgn;
					float colorTop = topY;
					using (var colorBrush = new SolidBrush(Color.FromArgb(visualRun.ColorValue))) {
						g.FillRectangle(colorBrush, colorLeft, colorTop, blockSize, blockSize);
					}
				} else {
					float radius = fontHeight * 0.2f;
					using (var bgBrush = new SolidBrush(currentTheme.InlayHintBgColor)) {
						DrawRoundedRect(g, bgBrush, bgLeft, bgTop, bgWidth, bgHeight, radius);
					}
						if (visualRun.IconId > 0 && editorIconProvider != null) {
							float iconSize = Math.Min(bgWidth, bgHeight);
							float iconLeft = bgLeft + (bgWidth - iconSize) * 0.5f;
							float iconTop2 = bgTop + (bgHeight - iconSize) * 0.5f;
							DrawGutterIcon(g, new GutterIconRenderItem {
								LogicalLine = -1,
								IconId = visualRun.IconId,
								Origin = new PointF(iconLeft, iconTop2),
								Width = iconSize,
								Height = iconSize,
							});
						} else if (hasText) {
						float textX = visualRun.X + mgn + visualRun.Padding;
						int inlayW = Math.Max(1, (int)Math.Ceiling(visualRun.Width - mgn * 2 - visualRun.Padding * 2));
						inlayW = Math.Max(inlayW, measuredSize.Width);
						var inlayRect = new Rectangle((int)textX, (int)topY, inlayW, lineHeight);
						TextRenderer.DrawText(g, drawTextContent, font, inlayRect, color, TextMeasureDrawFlags);
					}
				}
			} else {
				if (visualRun.Style.BackgroundColor != 0) {
					using var bgBrush = new SolidBrush(Color.FromArgb(visualRun.Style.BackgroundColor));
					g.FillRectangle(bgBrush, visualRun.X, topY, drawWidth, lineHeight);
				}
				var rect = new Rectangle((int)visualRun.X, (int)topY, drawWidth, lineHeight);
				Color drawColor = visualRun.Type == VisualRunType.PHANTOM_TEXT
					? Color.FromArgb(128, color)
					: color;
				TextRenderer.DrawText(g, drawTextContent, font, rect, drawColor, TextMeasureDrawFlags);
			}

			if ((visualRun.Style.FontStyle & EditorControl.FONT_STYLE_STRIKETHROUGH) != 0) {
				float strikeY = topY + ascent * 0.5f;
				using var pen = new Pen(color, 1f);
				g.DrawLine(pen, visualRun.X, strikeY, visualRun.X + visualRun.Width, strikeY);
			}
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
			using var brush = new SolidBrush(currentTheme.CurrentLineColor);
			g.FillRectangle(brush, left, model.CurrentLine.Y, width, lineH);
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

		private void DrawSelectionRects(Graphics g, EditorRenderModel model) {
			if (model.SelectionRects == null || model.SelectionRects.Count == 0) return;
			using var brush = new SolidBrush(currentTheme.SelectionColor);
			foreach (var rect in model.SelectionRects) {
				g.FillRectangle(brush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
			}
		}

		private void DrawCursor(Graphics g, EditorRenderModel model) {
			if (!model.Cursor.Visible) return;
			using var brush = new SolidBrush(currentTheme.CursorColor);
			g.FillRectangle(brush, model.Cursor.Position.X, model.Cursor.Position.Y, 2f, model.Cursor.Height);
		}

		private void DrawCompositionDecoration(Graphics g, CompositionDecoration comp) {
			float y = comp.Origin.Y + comp.Height;
			using var pen = new Pen(currentTheme.CompositionColor, 2f);
			g.DrawLine(pen, comp.Origin.X, y, comp.Origin.X + comp.Width, y);
		}

		private void DrawDiagnosticDecorations(Graphics g, EditorRenderModel model) {
			if (model.DiagnosticDecorations == null || model.DiagnosticDecorations.Count == 0) return;
			foreach (var diag in model.DiagnosticDecorations) {
				var color = diag.Color != 0
					? System.Drawing.Color.FromArgb(diag.Color)
					: diag.Severity switch {
						0 => System.Drawing.Color.FromArgb(255, 255, 0, 0),
						1 => System.Drawing.Color.FromArgb(255, 255, 204, 0),
						2 => System.Drawing.Color.FromArgb(255, 97, 181, 237),
						_ => System.Drawing.Color.FromArgb(178, 153, 153, 153),
					};

				float startX = diag.Origin.X;
				float endX = startX + diag.Width;
				float baseY = diag.Origin.Y + diag.Height - 1f;

				using var pen = new Pen(color, 3.0f);

				if (diag.Severity == 3) {
					pen.DashPattern = [3f, 2f];
					g.DrawLine(pen, startX, baseY, endX, baseY);
				} else {
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
			}
		}

		private void DrawLinkedEditingRects(Graphics g, EditorRenderModel model) {
			if (model.LinkedEditingRects == null || model.LinkedEditingRects.Count == 0) return;
			foreach (var rect in model.LinkedEditingRects) {
				if (rect.IsActive) {
					using var fillBrush = new SolidBrush(System.Drawing.Color.FromArgb(30, 86, 156, 214));
					g.FillRectangle(fillBrush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
					using var pen = new Pen(System.Drawing.Color.FromArgb(204, 86, 156, 214), 2f);
					g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				} else {
					using var pen = new Pen(System.Drawing.Color.FromArgb(102, 86, 156, 214), 1f);
					g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				}
			}
		}

		private void DrawBracketHighlightRects(Graphics g, EditorRenderModel model) {
			if (model.BracketHighlightRects == null || model.BracketHighlightRects.Count == 0) return;
			foreach (var rect in model.BracketHighlightRects) {
				using var fillBrush = new SolidBrush(System.Drawing.Color.FromArgb(48, 255, 215, 0));
				g.FillRectangle(fillBrush, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
				using var pen = new Pen(System.Drawing.Color.FromArgb(204, 255, 215, 0), 1.5f);
				g.DrawRectangle(pen, rect.Origin.X, rect.Origin.Y, rect.Width, rect.Height);
			}
		}

		private void DrawGuideSegments(Graphics g, EditorRenderModel model) {
			if (model.GuideSegments == null || model.GuideSegments.Count == 0) return;
			foreach (var seg in model.GuideSegments) {
				var color = seg.Type switch {
					GuideType.SEPARATOR => currentTheme.SeparatorColor,
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
				$"{PerfStepRecorder.StepSelection}={perf.GetStepMs(PerfStepRecorder.StepSelection):F2}ms " +
				$"{PerfStepRecorder.StepLines}={perf.GetStepMs(PerfStepRecorder.StepLines):F2}ms " +
				$"{PerfStepRecorder.StepGuides}={perf.GetStepMs(PerfStepRecorder.StepGuides):F2}ms " +
				$"{PerfStepRecorder.StepComposition}={perf.GetStepMs(PerfStepRecorder.StepComposition):F2}ms " +
				$"{PerfStepRecorder.StepDiagnostics}={perf.GetStepMs(PerfStepRecorder.StepDiagnostics):F2}ms " +
				$"{PerfStepRecorder.StepLinkedEditing}={perf.GetStepMs(PerfStepRecorder.StepLinkedEditing):F2}ms " +
				$"{PerfStepRecorder.StepBracket}={perf.GetStepMs(PerfStepRecorder.StepBracket):F2}ms " +
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
