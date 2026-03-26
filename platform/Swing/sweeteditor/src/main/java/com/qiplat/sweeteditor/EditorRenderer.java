package com.qiplat.sweeteditor;

import com.qiplat.sweeteditor.core.EditorCore;
import com.qiplat.sweeteditor.core.EditorNative;
import com.qiplat.sweeteditor.core.adornment.TextStyle;
import com.qiplat.sweeteditor.core.foundation.CurrentLineRenderMode;
import com.qiplat.sweeteditor.core.visual.*;

import java.awt.*;
import java.awt.font.FontRenderContext;
import java.awt.font.LineMetrics;
import java.awt.geom.*;
import java.lang.foreign.MemorySegment;
import java.lang.foreign.ValueLayout;
import java.util.List;

/**
 * Platform-independent rendering engine for the Swing editor.
 * Owns all Font objects, implements TextMeasureCallback, and contains all draw methods.
 * SweetEditor delegates all rendering to this class.
 */
final class EditorRenderer implements EditorCore.TextMeasureCallback {

    private static final FontRenderContext FALLBACK_FRC = new FontRenderContext(null, true, true);

    private EditorTheme theme;

    private Font regularFont;
    private Font boldFont;
    private Font italicFont;
    private Font boldItalicFont;
    private Font inlayHintFont;
    private Font inlayHintBoldFont;
    private Font inlayHintItalicFont;
    private Font inlayHintBoldItalicFont;
    private final Font baseRegularFont;
    private final Font baseInlayHintFont;

    private EditorIconProvider editorIconProvider;
    private int currentDrawingLineNumber = -1;
    /**
     * Last draw-time FontRenderContext captured from Graphics2D.
     * Measurement callbacks prefer this so layout measurement stays in sync with actual rendering.
     */
    private volatile FontRenderContext lastRenderFontRenderContext = FALLBACK_FRC;

    public EditorRenderer(EditorTheme theme) {
        this.theme = theme;
        baseRegularFont = findMonospaceFont(14);
        baseInlayHintFont = new Font("SansSerif", Font.PLAIN, 12);
        syncPlatformScale(1.0f);
    }

    public EditorCore.TextMeasureCallback getTextMeasureCallback() {
        return this;
    }

    public EditorTheme getTheme() {
        return theme;
    }

    public Font getRegularFont() {
        return regularFont;
    }

    public void setEditorIconProvider(EditorIconProvider provider) {
        this.editorIconProvider = provider;
    }

    public EditorIconProvider getEditorIconProvider() {
        return editorIconProvider;
    }

    public void syncPlatformScale(float scale) {
        if (scale <= 0f) return;
        float textSize = baseRegularFont.getSize2D() * scale;
        regularFont = baseRegularFont.deriveFont(Font.PLAIN, textSize);
        boldFont = baseRegularFont.deriveFont(Font.BOLD, textSize);
        italicFont = baseRegularFont.deriveFont(Font.ITALIC, textSize);
        boldItalicFont = baseRegularFont.deriveFont(Font.BOLD | Font.ITALIC, textSize);
        float inlayHintSize = baseInlayHintFont.getSize2D() * scale;
        inlayHintFont = baseInlayHintFont.deriveFont(Font.PLAIN, inlayHintSize);
        inlayHintBoldFont = baseInlayHintFont.deriveFont(Font.BOLD, inlayHintSize);
        inlayHintItalicFont = baseInlayHintFont.deriveFont(Font.ITALIC, inlayHintSize);
        inlayHintBoldItalicFont = baseInlayHintFont.deriveFont(Font.BOLD | Font.ITALIC, inlayHintSize);
    }

    public void applyTheme(EditorTheme theme) {
        this.theme = theme;
    }

    @Override
    public float measureTextWidth(MemorySegment textPtr, int fontStyle) {
        String text = EditorNative.readUtf16String(textPtr);
        if (text == null || text.isEmpty()) return 0f;
        Font font = getFontByStyle(fontStyle);
        FontRenderContext frc = getFontRenderContext();
        return (float) font.getStringBounds(text, frc).getWidth();
    }

    @Override
    public float measureInlayHintWidth(MemorySegment textPtr) {
        String text = EditorNative.readUtf16String(textPtr);
        if (text == null || text.isEmpty()) return 0f;
        FontRenderContext frc = getFontRenderContext();
        return (float) inlayHintFont.getStringBounds(text, frc).getWidth();
    }

    @Override
    public float measureIconWidth(int iconId) {
        FontRenderContext frc = getFontRenderContext();
        LineMetrics lm = regularFont.getLineMetrics("M", frc);
        return lm.getAscent() + lm.getDescent();
    }

    @Override
    public void getFontMetrics(MemorySegment arrPtr, long length) {
        FontRenderContext frc = getFontRenderContext();
        LineMetrics lm = regularFont.getLineMetrics("M", frc);
        float ascent = lm.getAscent();
        float descent = lm.getDescent();
        arrPtr.reinterpret(length * 4).set(ValueLayout.JAVA_FLOAT, 0, -ascent);
        arrPtr.reinterpret(length * 4).set(ValueLayout.JAVA_FLOAT, 4, descent);
    }

    private FontRenderContext getFontRenderContext() {
        return lastRenderFontRenderContext;
    }

    public void render(Graphics2D g2, EditorRenderModel model,
                       int viewWidth, int viewHeight, boolean cursorVisible) {
        g2.setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_LCD_HRGB);
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        // Keep draw-time glyph positioning consistent with measureTextWidth() FRC (fractional metrics on),
        // otherwise segmented runs can accumulate rounding error and appear overlapped.
        g2.setRenderingHint(RenderingHints.KEY_FRACTIONALMETRICS, RenderingHints.VALUE_FRACTIONALMETRICS_ON);
        // Capture real draw-time FRC so native text measurement callbacks use the same metrics source.
        lastRenderFontRenderContext = g2.getFontRenderContext();

        g2.setColor(theme.backgroundColor);
        g2.fillRect(0, 0, viewWidth, viewHeight);

        if (model == null) return;

        drawCurrentLineDecoration(g2, model, 0f, viewWidth);
        drawSelectionRects(g2, model);
        drawLines(g2, model);
        drawGuideSegments(g2, model);
        if (model.compositionDecoration != null && model.compositionDecoration.active) {
            drawCompositionDecoration(g2, model.compositionDecoration);
        }
        drawDiagnosticDecorations(g2, model);
        drawLinkedEditingRects(g2, model);
        drawBracketHighlightRects(g2, model);
        drawCursor(g2, model, cursorVisible);
        drawGutterOverlay(g2, model, viewWidth, viewHeight);
        drawLineNumbers(g2, model);
        drawScrollbars(g2, model);
    }

    private Font getFontByStyle(int fontStyle) {
        boolean bold = (fontStyle & TextStyle.BOLD) != 0;
        boolean italic = (fontStyle & TextStyle.ITALIC) != 0;
        if (bold && italic) return boldItalicFont;
        if (bold) return boldFont;
        if (italic) return italicFont;
        return regularFont;
    }

    private Font getInlayHintFontByStyle(int fontStyle) {
        boolean bold = (fontStyle & TextStyle.BOLD) != 0;
        boolean italic = (fontStyle & TextStyle.ITALIC) != 0;
        if (bold && italic) return inlayHintBoldItalicFont;
        if (bold) return inlayHintBoldFont;
        if (italic) return inlayHintItalicFont;
        return inlayHintFont;
    }

    private float getFontAscent(Graphics2D g, Font font) {
        java.awt.FontMetrics fm = g.getFontMetrics(font);
        return fm.getAscent();
    }

    private float getFontHeight(Graphics2D g, Font font) {
        java.awt.FontMetrics fm = g.getFontMetrics(font);
        return fm.getAscent() + fm.getDescent();
    }

    private void drawCurrentLineDecoration(Graphics2D g, EditorRenderModel model, float left, float width) {
        if (width <= 0f || model.currentLine == null) return;
        if (model.currentLineRenderMode == CurrentLineRenderMode.NONE.value) return;
        float lineH = model.cursor != null && model.cursor.height > 0 ? model.cursor.height : getFontHeight(g, regularFont);
        if (model.currentLineRenderMode == CurrentLineRenderMode.BORDER.value) {
            Stroke oldStroke = g.getStroke();
            g.setColor(getCurrentLineBorderColor());
            g.setStroke(new BasicStroke(1f));
            g.draw(new Rectangle2D.Float(left, model.currentLine.y, width, lineH));
            g.setStroke(oldStroke);
            return;
        }
        g.setColor(theme.currentLineColor);
        g.fill(new Rectangle2D.Float(left, model.currentLine.y, width, lineH));
    }

    private void drawSelectionRects(Graphics2D g, EditorRenderModel model) {
        if (model.selectionRects == null || model.selectionRects.isEmpty()) return;
        g.setColor(theme.selectionColor);
        for (SelectionRect r : model.selectionRects) {
            g.fillRect((int) r.origin.x, (int) r.origin.y, (int) r.width, (int) r.height);
        }
    }

    private void drawLines(Graphics2D g, EditorRenderModel model) {
        if (model.lines == null) return;
        for (VisualLine line : model.lines) {
            if (line.runs == null) continue;
            for (VisualRun run : line.runs) {
                drawVisualRun(g, run);
            }
        }
    }

    private void drawVisualRun(Graphics2D g, VisualRun run) {
        String text = run.text;
        boolean hasText = text != null && !text.isEmpty();
        if (!hasText && run.type != VisualRunType.INLAY_HINT) return;

        Font font = (run.type == VisualRunType.INLAY_HINT)
                ? getInlayHintFontByStyle(run.style != null ? run.style.fontStyle : 0)
                : getFontByStyle(run.style != null ? run.style.fontStyle : 0);

        Color color = (run.style != null && run.style.color != 0)
                ? argbToColor(run.style.color)
                : theme.textColor;

        float ascent = getFontAscent(g, font);
        float topY = run.y - ascent;
        float fontHeight = getFontHeight(g, font);

        if (run.type == VisualRunType.FOLD_PLACEHOLDER) {
            float mgn = run.margin;
            float bgLeft = run.x + mgn;
            float bgWidth = run.width - mgn * 2;
            float radius = fontHeight * 0.2f;
            g.setColor(theme.foldPlaceholderBgColor);
            g.fill(new RoundRectangle2D.Float(bgLeft, topY, bgWidth, fontHeight, radius * 2, radius * 2));
            if (hasText) {
                float textX = run.x + mgn + run.padding;
                g.setColor(theme.foldPlaceholderTextColor);
                g.setFont(font);
                g.drawString(text, textX, run.y);
            }
        } else if (run.type == VisualRunType.INLAY_HINT) {
            float mgn = run.margin;
            float bgLeft = run.x + mgn;
            float bgWidth = run.width - mgn * 2;

            if (run.colorValue != 0) {
                float blockSize = fontHeight;
                g.setColor(argbToColor(run.colorValue));
                g.fillRect((int) (run.x + mgn), (int) topY, (int) blockSize, (int) blockSize);
            } else {
                float radius = fontHeight * 0.2f;
                g.setColor(theme.inlayHintBgColor);
                g.fill(new RoundRectangle2D.Float(bgLeft, topY, bgWidth, fontHeight, radius * 2, radius * 2));
                if (hasText) {
                    float textX = run.x + mgn + run.padding;
                    g.setColor(color);
                    g.setFont(font);
                    g.drawString(text, textX, run.y);
                }
            }
        } else {
            if (run.style != null && run.style.backgroundColor != 0) {
                g.setColor(argbToColor(run.style.backgroundColor));
                g.fillRect((int) run.x, (int) topY, (int) Math.ceil(run.width), (int) Math.ceil(fontHeight));
            }
            if (hasText) {
                Color drawColor = (run.type == VisualRunType.PHANTOM_TEXT)
                        ? theme.phantomTextColor
                        : color;
                g.setColor(drawColor);
                g.setFont(font);
                g.drawString(text, run.x, run.y);
            }
        }

        if (run.style != null && (run.style.fontStyle & TextStyle.STRIKETHROUGH) != 0) {
            float strikeY = topY + ascent * 0.5f;
            g.setColor(color);
            g.setStroke(new BasicStroke(1f));
            g.drawLine((int) run.x, (int) strikeY, (int) (run.x + run.width), (int) strikeY);
        }
    }

    private void drawGutterOverlay(Graphics2D g, EditorRenderModel model, int viewWidth, int viewHeight) {
        if (model.splitX <= 0) return;
        g.setColor(theme.backgroundColor);
        g.fillRect(0, 0, (int) model.splitX, viewHeight);
        drawCurrentLineDecoration(g, model, 0f, model.splitX);
        if (model.splitLineVisible) {
            g.setColor(theme.splitLineColor);
            g.drawLine((int) model.splitX, 0, (int) model.splitX, viewHeight);
        }
    }

    private void drawLineNumbers(Graphics2D g, EditorRenderModel model) {
        if (!model.gutterVisible) return;
        if (model.lines == null) return;
        List<GutterIconRenderItem> gutterIcons = model.gutterIcons;
        List<FoldMarkerRenderItem> foldMarkers = model.foldMarkers;
        int iconCount = gutterIcons != null ? gutterIcons.size() : 0;
        int markerCount = foldMarkers != null ? foldMarkers.size() : 0;
        int iconCursor = 0;
        int markerCursor = 0;
        int activeLogicalLine = getActiveLogicalLine(model);
        Color activeLineColor = getCurrentLineAccentColor();
        currentDrawingLineNumber = -1;
        for (VisualLine line : model.lines) {
            if (line.wrapIndex != 0 || line.isPhantomLine) continue;
            int logicalLine = line.logicalLine;

            while (iconCursor < iconCount && gutterIcons.get(iconCursor).logicalLine < logicalLine) {
                iconCursor++;
            }
            int iconStart = iconCursor;
            while (iconCursor < iconCount && gutterIcons.get(iconCursor).logicalLine == logicalLine) {
                iconCursor++;
            }
            int iconEnd = iconCursor;

            while (markerCursor < markerCount && foldMarkers.get(markerCursor).logicalLine < logicalLine) {
                markerCursor++;
            }
            FoldMarkerRenderItem foldMarker = null;
            while (markerCursor < markerCount && foldMarkers.get(markerCursor).logicalLine == logicalLine) {
                if (foldMarker == null) foldMarker = foldMarkers.get(markerCursor);
                markerCursor++;
            }

            drawLineNumber(
                    g,
                    line,
                    model,
                    gutterIcons,
                    iconStart,
                    iconEnd,
                    foldMarker,
                    logicalLine == activeLogicalLine,
                    activeLineColor);
        }
    }

    private void drawLineNumber(Graphics2D g, VisualLine vl, EditorRenderModel model,
                                List<GutterIconRenderItem> gutterIcons,
                                int iconStart,
                                int iconEnd,
                                FoldMarkerRenderItem foldMarker,
                                boolean isCurrentLine,
                                Color activeLineColor) {
        PointF pos = vl.lineNumberPosition;
        int newLineNumber = vl.logicalLine + 1;
        boolean overlayMode = model.maxGutterIcons == 0;
        boolean hasIcons = editorIconProvider != null && iconEnd > iconStart;

        if (overlayMode && hasIcons) {
            drawGutterIcon(g, gutterIcons.get(iconStart));
            currentDrawingLineNumber = newLineNumber;
        } else if (newLineNumber != currentDrawingLineNumber) {
            g.setColor(isCurrentLine ? activeLineColor : theme.lineNumberColor);
            g.setFont(regularFont);
            g.drawString(String.valueOf(newLineNumber), pos.x, pos.y);
            currentDrawingLineNumber = newLineNumber;
        }

        if (!overlayMode && hasIcons) {
            for (int i = iconStart; i < iconEnd; i++) {
                drawGutterIcon(g, gutterIcons.get(i));
            }
        }

        drawFoldMarker(g, foldMarker, isCurrentLine ? activeLineColor : theme.lineNumberColor);
    }

    private void drawFoldMarker(Graphics2D g, FoldMarkerRenderItem item, Color color) {
        if (item == null || item.origin == null || item.width <= 0 || item.height <= 0) return;
        if (item.foldState == null || item.foldState == FoldState.NONE) return;

        float centerX = item.origin.x + item.width * 0.5f;
        float centerY = item.origin.y + item.height * 0.5f;
        float halfSize = Math.min(item.width, item.height) * 0.28f;

        g.setColor(color);
        g.setStroke(new BasicStroke(Math.max(1f, item.height * 0.1f), BasicStroke.CAP_ROUND, BasicStroke.JOIN_ROUND));

        GeneralPath path = new GeneralPath();
        if (item.foldState == FoldState.COLLAPSED) {
            path.moveTo(centerX - halfSize * 0.5f, centerY - halfSize);
            path.lineTo(centerX + halfSize * 0.5f, centerY);
            path.lineTo(centerX - halfSize * 0.5f, centerY + halfSize);
        } else {
            path.moveTo(centerX - halfSize, centerY - halfSize * 0.5f);
            path.lineTo(centerX, centerY + halfSize * 0.5f);
            path.lineTo(centerX + halfSize, centerY - halfSize * 0.5f);
        }
        g.draw(path);
    }

    private int getActiveLogicalLine(EditorRenderModel model) {
        if (model.cursor == null || model.cursor.textPosition == null) return -1;
        return model.cursor.textPosition.line;
    }

    private Color getCurrentLineAccentColor() {
        int argb = theme.currentLineNumberColor != null ? theme.currentLineNumberColor.getRGB() : 0;
        if (argb == 0) argb = theme.lineNumberColor.getRGB();
        return new Color((argb & 0x00FFFFFF) | 0xFF000000, true);
    }

    private Color getCurrentLineBorderColor() {
        int argb = theme.currentLineColor.getRGB();
        if (argb == 0) argb = theme.lineNumberColor.getRGB();
        int alpha = (argb >>> 24) & 0xFF;
        if (alpha < 0xA0) {
            argb = (argb & 0x00FFFFFF) | (0xA0 << 24);
        }
        return new Color(argb, true);
    }

    private boolean drawGutterIcon(Graphics2D g, GutterIconRenderItem item) {
        if (editorIconProvider == null || item == null || item.origin == null || item.width <= 0 || item.height <= 0) {
            return false;
        }
        Image image = editorIconProvider.getIconImage(item.iconId);
        if (image == null) return false;
        g.drawImage(
                image,
                (int) item.origin.x,
                (int) item.origin.y,
                (int) Math.ceil(item.width),
                (int) Math.ceil(item.height),
                null);
        return true;
    }

    private void drawScrollbars(Graphics2D g, EditorRenderModel model) {
        ScrollbarModel vertical = model.verticalScrollbar;
        ScrollbarModel horizontal = model.horizontalScrollbar;

        boolean hasVertical = vertical != null
                && vertical.visible
                && vertical.track != null
                && vertical.thumb != null
                && vertical.track.width > 0
                && vertical.track.height > 0;
        boolean hasHorizontal = horizontal != null
                && horizontal.visible
                && horizontal.track != null
                && horizontal.thumb != null
                && horizontal.track.width > 0
                && horizontal.track.height > 0;
        if (!hasVertical && !hasHorizontal) return;

        Color trackColor = theme.scrollbarTrackColor;

        float verticalTrackX = 0f;
        float verticalTrackWidth = 0f;
        float horizontalTrackY = 0f;
        float horizontalTrackHeight = 0f;

        if (hasVertical) {
            float trackX = vertical.track.origin != null ? vertical.track.origin.x : 0f;
            float trackY = vertical.track.origin != null ? vertical.track.origin.y : 0f;
            float thumbX = vertical.thumb.origin != null ? vertical.thumb.origin.x : 0f;
            float thumbY = vertical.thumb.origin != null ? vertical.thumb.origin.y : 0f;
            verticalTrackX = trackX;
            verticalTrackWidth = vertical.track.width;
            g.setColor(trackColor);
            g.fill(new Rectangle2D.Float(trackX, trackY, vertical.track.width, vertical.track.height));
            g.setColor(vertical.thumbActive ? theme.scrollbarThumbActiveColor : theme.scrollbarThumbColor);
            g.fill(new Rectangle2D.Float(thumbX, thumbY, vertical.thumb.width, vertical.thumb.height));
        }

        if (hasHorizontal) {
            float trackX = horizontal.track.origin != null ? horizontal.track.origin.x : 0f;
            float trackY = horizontal.track.origin != null ? horizontal.track.origin.y : 0f;
            float thumbX = horizontal.thumb.origin != null ? horizontal.thumb.origin.x : 0f;
            float thumbY = horizontal.thumb.origin != null ? horizontal.thumb.origin.y : 0f;
            horizontalTrackY = trackY;
            horizontalTrackHeight = horizontal.track.height;
            g.setColor(trackColor);
            g.fill(new Rectangle2D.Float(trackX, trackY, horizontal.track.width, horizontal.track.height));
            g.setColor(horizontal.thumbActive ? theme.scrollbarThumbActiveColor : theme.scrollbarThumbColor);
            g.fill(new Rectangle2D.Float(thumbX, thumbY, horizontal.thumb.width, horizontal.thumb.height));
        }

        if (hasVertical && hasHorizontal) {
            g.setColor(trackColor);
            g.fillRect(
                    (int) verticalTrackX,
                    (int) horizontalTrackY,
                    (int) verticalTrackWidth,
                    (int) horizontalTrackHeight);
        }
    }

    private void drawCursor(Graphics2D g, EditorRenderModel model, boolean cursorVisible) {
        if (model.cursor == null || !model.cursor.visible || !cursorVisible) return;
        g.setColor(theme.cursorColor);
        g.fillRect((int) model.cursor.position.x, (int) model.cursor.position.y,
                2, (int) model.cursor.height);
    }

    private void drawCompositionDecoration(Graphics2D g, CompositionDecoration comp) {
        float y = comp.origin.y + comp.height;
        g.setColor(theme.compositionUnderlineColor);
        g.setStroke(new BasicStroke(2f));
        g.drawLine((int) comp.origin.x, (int) y, (int) (comp.origin.x + comp.width), (int) y);
    }

    private void drawDiagnosticDecorations(Graphics2D g, EditorRenderModel model) {
        if (model.diagnosticDecorations == null || model.diagnosticDecorations.isEmpty()) return;
        for (DiagnosticDecoration diag : model.diagnosticDecorations) {
            Color c = diag.color != 0 ? argbToColor(diag.color) : switch (diag.severity) {
                case 0 -> theme.diagnosticErrorColor;
                case 1 -> theme.diagnosticWarningColor;
                case 2 -> theme.diagnosticInfoColor;
                default -> theme.diagnosticHintColor;
            };

            float startX = diag.origin.x;
            float endX = startX + diag.width;
            float baseY = diag.origin.y + diag.height - 1f;

            g.setColor(c);
            g.setStroke(new BasicStroke(2f));

            if (diag.severity == 3) {
                g.setStroke(new BasicStroke(2f, BasicStroke.CAP_BUTT, BasicStroke.JOIN_MITER, 10f, new float[]{3f, 2f}, 0f));
                g.drawLine((int) startX, (int) baseY, (int) endX, (int) baseY);
            } else {
                float halfWave = 7f;
                float amplitude = 3.5f;
                GeneralPath path = new GeneralPath();
                float x = startX;
                int step = 0;
                path.moveTo(x, baseY);
                while (x < endX) {
                    float nextX = Math.min(x + halfWave, endX);
                    float midX = (x + nextX) / 2f;
                    float peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude;
                    path.quadTo(midX, peakY, nextX, baseY);
                    x = nextX;
                    step++;
                }
                g.setStroke(new BasicStroke(2f));
                g.draw(path);
            }
        }
    }

    private void drawLinkedEditingRects(Graphics2D g, EditorRenderModel model) {
        if (model.linkedEditingRects == null || model.linkedEditingRects.isEmpty()) return;
        for (LinkedEditingRect rect : model.linkedEditingRects) {
            if (rect.origin == null) continue;
            if (rect.isActive) {
                g.setColor(withAlpha(theme.linkedEditingActiveColor, 32));
                g.fillRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
                g.setColor(theme.linkedEditingActiveColor);
                g.setStroke(new BasicStroke(2f));
            } else {
                g.setColor(theme.linkedEditingInactiveColor);
                g.setStroke(new BasicStroke(1f));
            }
            g.drawRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
        }
    }

    private void drawBracketHighlightRects(Graphics2D g, EditorRenderModel model) {
        if (model.bracketHighlightRects == null || model.bracketHighlightRects.isEmpty()) return;
        for (BracketHighlightRect rect : model.bracketHighlightRects) {
            if (rect.origin == null) continue;
            g.setColor(theme.bracketHighlightBgColor);
            g.fillRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
            g.setColor(theme.bracketHighlightBorderColor);
            g.setStroke(new BasicStroke(1.5f));
            g.drawRect((int) rect.origin.x, (int) rect.origin.y, (int) rect.width, (int) rect.height);
        }
    }

    private void drawGuideSegments(Graphics2D g, EditorRenderModel model) {
        if (model.guideSegments == null || model.guideSegments.isEmpty()) return;
        for (GuideSegment seg : model.guideSegments) {
            Color c = (seg.type == GuideType.SEPARATOR) ? theme.separatorLineColor : theme.guideColor;
            g.setColor(c);
            float lineWidth = (seg.type == GuideType.INDENT) ? 1f : 1.2f;
            g.setStroke(new BasicStroke(lineWidth));

            if (seg.arrowEnd) {
                float arrowLen = 9f;
                float arrowAngle = (float) (Math.PI * 28.0 / 180.0);
                float arrowDepth = (float) (arrowLen * Math.cos(arrowAngle));
                float dx = seg.end.x - seg.start.x;
                float dy = seg.end.y - seg.start.y;
                float len = (float) Math.sqrt(dx * dx + dy * dy);
                float trim = arrowDepth + lineWidth * 0.5f;
                if (len > trim) {
                    float ratio = (len - trim) / len;
                    float lineEndX = seg.start.x + dx * ratio;
                    float lineEndY = seg.start.y + dy * ratio;
                    g.draw(new Line2D.Float(seg.start.x, seg.start.y, lineEndX, lineEndY));
                }
                drawArrowHead(g, c, seg.start, seg.end, arrowLen, arrowAngle);
            } else {
                g.draw(new Line2D.Float(seg.start.x, seg.start.y, seg.end.x, seg.end.y));
            }
        }
    }

    private void drawArrowHead(Graphics2D g, Color color, PointF from, PointF to, float arrowLen, float arrowAngle) {
        float dx = to.x - from.x;
        float dy = to.y - from.y;
        float len = (float) Math.sqrt(dx * dx + dy * dy);
        if (len < 1f) return;
        float ux = dx / len, uy = dy / len;
        float cosA = (float) Math.cos(arrowAngle), sinA = (float) Math.sin(arrowAngle);
        float ax1 = to.x - arrowLen * (ux * cosA - uy * sinA);
        float ay1 = to.y - arrowLen * (uy * cosA + ux * sinA);
        float ax2 = to.x - arrowLen * (ux * cosA + uy * sinA);
        float ay2 = to.y - arrowLen * (uy * cosA - ux * sinA);

        GeneralPath path = new GeneralPath();
        path.moveTo(to.x, to.y);
        path.lineTo(ax1, ay1);
        path.lineTo(ax2, ay2);
        path.closePath();
        g.setColor(color);
        g.fill(path);
    }

    private static Font findMonospaceFont(int size) {
        String[] candidates = {
            "JetBrains Mono", "Menlo", "SF Mono", "Consolas",
            "Fira Code", "Source Code Pro", "DejaVu Sans Mono",
            "Liberation Mono", "Courier New", Font.MONOSPACED
        };
        java.util.Set<String> available = new java.util.HashSet<>(
            java.util.Arrays.asList(java.awt.GraphicsEnvironment
                .getLocalGraphicsEnvironment().getAvailableFontFamilyNames()));
        for (String name : candidates) {
            if (available.contains(name)) {
                return new Font(name, Font.PLAIN, size);
            }
        }
        return new Font(Font.MONOSPACED, Font.PLAIN, size);
    }

    static Color argbToColor(int argb) {
        int a = (argb >> 24) & 0xFF;
        int r = (argb >> 16) & 0xFF;
        int g2 = (argb >> 8) & 0xFF;
        int b = argb & 0xFF;
        return new Color(r, g2, b, a);
    }

    private static Color withAlpha(Color color, int alpha) {
        int a = Math.max(0, Math.min(255, alpha));
        return new Color(color.getRed(), color.getGreen(), color.getBlue(), a);
    }
}
