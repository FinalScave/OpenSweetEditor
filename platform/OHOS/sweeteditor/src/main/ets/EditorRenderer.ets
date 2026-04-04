import { EditorIconProvider, EditorTheme } from './EditorTypes';
import {
  HandleConfig,
  ScrollbarConfig,
  ScrollbarMode,
  ScrollbarTrackTapMode
} from './core/EditorCore';
import {
  BracketHighlightRect,
  CompositionDecoration,
  Cursor,
  DiagnosticDecoration,
  EditorRenderModel,
  FoldMarkerRenderItem,
  FoldState,
  GuideDirection,
  GuideSegment,
  GuideStyle,
  GuideType,
  GutterIconRenderItem,
  LinkedEditingRect,
  ScrollbarModel,
  SelectionHandle,
  SelectionRect,
  VisualRun,
  VisualRunType
} from './core/CoreVisual';
import { CurrentLineRenderMode } from './core/CoreFoundation';
import { PerfOverlay } from './perf/PerfOverlay';
import { TextMeasurer } from 'libsweeteditor.so';

const HANDLE_LINE_WIDTH = 1.5;
const HANDLE_DROP_RADIUS = 10.0;
const HANDLE_CENTER_DIST = 24.0;
const DEFAULT_TEXT_SIZE = 28;

interface FontMetricsSnapshot {
  ascent: number;
  descent: number;
}

/**
 * Platform-independent rendering engine for the editor.
 * Owns all draw methods, icon provider, handle/scrollbar config,
 * and text measurement. SweetEditor delegates all rendering to this class.
 */
export class EditorRenderer {
  private theme: EditorTheme;
  private density: number;
  private readonly handleConfig: HandleConfig;
  private scrollbarConfig: ScrollbarConfig | null = null;
  private textSize: number = DEFAULT_TEXT_SIZE;
  private scale: number = 1.0;
  private fontFamily: string = 'monospace';
  private iconProvider: EditorIconProvider | null = null;
  private perfOverlay: PerfOverlay = new PerfOverlay();
  private measurementCtx: CanvasRenderingContext2D | null = null;
  private readonly fontStringCache: Map<string, string> = new Map();
  private readonly fontMetricsCache: Map<string, FontMetricsSnapshot> = new Map();
  private currentFontKey: string = '';
  private readonly measurer: TextMeasurer = {
    measureWidth: (text: string, fontStyle: number): number => {
      return this.measureTextWidth(text, fontStyle);
    },
    measureInlayHintWidth: (text: string): number => {
      return this.measureInlayHintWidth(text);
    },
    measureIconWidth: (_iconId: number): number => {
      return this.measureIconWidth();
    },
    getFontAscent: (): number => {
      return -this.getMainFontMetrics().ascent;
    },
    getFontDescent: (): number => {
      return this.getMainFontMetrics().descent;
    }
  };

  constructor(theme: EditorTheme, density: number) {
    this.theme = theme;
    this.density = density;
    this.handleConfig = this.computeHandleHitConfig();
  }

  getTheme(): EditorTheme {
    return this.theme;
  }

  setEditorIconProvider(provider: EditorIconProvider | null): void {
    this.iconProvider = provider;
  }

  getPerfOverlay(): PerfOverlay {
    return this.perfOverlay;
  }

  getEditorIconProvider(): EditorIconProvider | null {
    return this.iconProvider;
  }

  syncPlatformScale(scale: number): void {
    this.scale = scale;
    this.invalidateFontCaches();
  }

  applyTextSize(textSize: number): void {
    this.textSize = textSize;
    this.invalidateFontCaches();
  }

  applyFontFamily(fontFamily: string): void {
    this.fontFamily = fontFamily;
    this.invalidateFontCaches();
  }

  applyTheme(theme: EditorTheme): void {
    this.theme = theme;
  }

  getTextSize(): number {
    return this.textSize;
  }

  getScale(): number {
    return this.scale;
  }

  getFontFamily(): string {
    return this.fontFamily;
  }

  getDensity(): number {
    return this.density;
  }

  getHandleConfig(): HandleConfig {
    return this.handleConfig;
  }

  setScrollbarConfig(config: ScrollbarConfig | null): void {
    this.scrollbarConfig = config;
  }

  getScrollbarConfig(): ScrollbarConfig | null {
    return this.scrollbarConfig;
  }

  attachCanvasContext(ctx: CanvasRenderingContext2D): void {
    this.measurementCtx = ctx;
    this.invalidateFontCaches();
  }

  getMeasurer(): TextMeasurer {
    return this.measurer;
  }

  /**
   * Render the editor content onto the canvas.
   * Returns true if transient scrollbar refresh should be scheduled.
   */
  render(ctx: CanvasRenderingContext2D, model: EditorRenderModel,
    viewWidth: number, viewHeight: number, cursorVisible: boolean): boolean {
    this.currentFontKey = '';
    ctx.clearRect(0, 0, viewWidth, viewHeight);
    ctx.fillStyle = colorToString(this.theme.backgroundColor);
    ctx.fillRect(0, 0, viewWidth, viewHeight);

    this.drawCurrentLineDecoration(ctx, model, 0, viewWidth);
    this.drawSelectionRects(ctx, model.selectionRects);
    this.drawLines(ctx, model);
    this.drawGuideSegments(ctx, model.guideSegments);
    this.drawCompositionDecoration(ctx, model.compositionDecoration);
    this.drawDiagnosticDecorations(ctx, model.diagnosticDecorations);
    this.drawLinkedEditingRects(ctx, model.linkedEditingRects);
    this.drawBracketHighlightRects(ctx, model.bracketHighlightRects);
    this.drawCursor(ctx, model.cursor, cursorVisible);

    if (model.splitX > 0) {
      ctx.fillStyle = colorToString(this.theme.backgroundColor);
      ctx.fillRect(0, 0, model.splitX, viewHeight);
      this.drawCurrentLineDecoration(ctx, model, 0, model.splitX);
      if (model.splitLineVisible) {
        ctx.strokeStyle = colorToString(this.theme.splitLineColor);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(model.splitX, 0);
        ctx.lineTo(model.splitX, viewHeight);
        ctx.stroke();
      }
    }

    this.drawLineNumbers(ctx, model);
    this.drawSelectionHandles(ctx, model.selectionStartHandle, model.selectionEndHandle);
    const needsTransientRefresh = this.drawScrollbars(ctx, model);

    this.perfOverlay.draw(ctx, viewWidth);

    return needsTransientRefresh;
  }

  private drawLines(ctx: CanvasRenderingContext2D, model: EditorRenderModel): void {
    if (!model.visualLines) {
      return;
    }
    const scaledTextSize = this.textSize * this.scale;
    const inlayHintSize = scaledTextSize * 0.9;

    for (const line of model.visualLines) {
      if (!line.runs) {
        continue;
      }
      for (const run of line.runs) {
        if (run.type === VisualRunType.FOLD_PLACEHOLDER) {
          this.drawFoldPlaceholder(ctx, run, scaledTextSize);
          continue;
        }
        if (run.type === VisualRunType.INLAY_HINT) {
          this.drawInlayHintRun(ctx, run, inlayHintSize);
          continue;
        }
        if (run.type === VisualRunType.TEXT || run.type === VisualRunType.WHITESPACE
          || run.type === VisualRunType.PHANTOM_TEXT) {
          if (!run.text || run.text.length === 0) {
            continue;
          }
          this.drawTextRun(ctx, run, scaledTextSize);
        }
      }
    }
  }

  private drawTextRun(ctx: CanvasRenderingContext2D, run: VisualRun, textSize: number): void {
    const fontStyle = run.style ? run.style.fontStyle : 0;
    const color = (run.style && run.style.color !== 0) ? run.style.color : this.theme.textColor;

    if (run.style && run.style.backgroundColor !== 0) {
      const metrics = this.getFontMetrics(ctx, fontStyle, textSize, this.fontFamily);
      ctx.fillStyle = colorToString(run.style.backgroundColor);
      ctx.fillRect(run.x, run.y - metrics.ascent, run.width, metrics.ascent + metrics.descent);
    } else {
      this.setCanvasFont(ctx, fontStyle, textSize, this.fontFamily);
    }

    if (run.type === VisualRunType.PHANTOM_TEXT) {
      ctx.fillStyle = colorToString(this.theme.phantomTextColor);
    } else {
      ctx.fillStyle = colorToString(color);
    }
    ctx.fillText(run.text, run.x, run.y);
  }

  private drawFoldPlaceholder(ctx: CanvasRenderingContext2D, run: VisualRun, textSize: number): void {
    if (!run.text || run.text.length === 0) {
      return;
    }
    const mgn = run.margin;
    const metrics = this.getFontMetrics(ctx, 0, textSize, this.fontFamily);
    const bgTop = run.y - metrics.ascent;
    const bgBottom = run.y + metrics.descent;
    const bgLeft = run.x + mgn;
    const bgRight = run.x + run.width - mgn;
    const radius = (bgBottom - bgTop) * 0.2;

    ctx.fillStyle = colorToString(this.theme.foldPlaceholderBgColor);
    drawRoundRect(ctx, bgLeft, bgTop, bgRight - bgLeft, bgBottom - bgTop, radius);
    ctx.fill();

    ctx.fillStyle = colorToString(this.theme.foldPlaceholderTextColor);
    ctx.fillText(run.text, run.x + mgn + run.padding, run.y);
  }

  private drawInlayHintRun(ctx: CanvasRenderingContext2D, run: VisualRun, hintSize: number): void {
    const mgn = run.margin;
    const metrics = this.getFontMetrics(ctx, 0, hintSize, 'sans-serif');
    const bgTop = run.y - metrics.ascent;
    const bgBottom = run.y + metrics.descent;
    const bgLeft = run.x + mgn;
    const bgRight = run.x + run.width - mgn;

    if (run.colorValue !== 0) {
      const blockSize = bgBottom - bgTop;
      ctx.fillStyle = colorToString(run.colorValue);
      ctx.globalAlpha = 1.0;
      ctx.fillRect(run.x + mgn, bgTop, blockSize, blockSize);
      ctx.globalAlpha = 1.0;
    } else {
      const radius = (bgBottom - bgTop) * 0.2;
      ctx.fillStyle = colorToString(this.theme.inlayHintBgColor);
      drawRoundRect(ctx, bgLeft, bgTop, bgRight - bgLeft, bgBottom - bgTop, radius);
      ctx.fill();

      if (run.iconId > 0 && this.iconProvider) {
        const pixelMap = this.iconProvider.getIconPixelMap(run.iconId);
        if (pixelMap) {
          const bgW = bgRight - bgLeft;
          const bgH = bgBottom - bgTop;
          const iconSize = Math.min(bgW, bgH);
          const iconLeft = bgLeft + (bgW - iconSize) * 0.5;
          const iconTop = bgTop + (bgH - iconSize) * 0.5;
          ctx.drawImage(pixelMap, iconLeft, iconTop, iconSize, iconSize);
        }
      } else if (run.text && run.text.length > 0) {
        const fontStyle = run.style ? run.style.fontStyle : 0;
        let color: number;
        if (run.style && run.style.color !== 0) {
          const alpha = (this.theme.inlayHintTextColor >>> 24) & 0xFF;
          color = (alpha << 24) | (run.style.color & 0x00FFFFFF);
        } else {
          color = this.theme.inlayHintTextColor;
        }
        this.setCanvasFont(ctx, fontStyle, hintSize, 'sans-serif');
        ctx.fillStyle = colorToString(color);
        ctx.fillText(run.text, run.x + mgn + run.padding, run.y);
      }
    }
  }

  private drawLineNumbers(ctx: CanvasRenderingContext2D, model: EditorRenderModel): void {
    if (!model.gutterVisible) {
      return;
    }
    if (!model.visualLines) {
      return;
    }

    const scaledTextSize = this.textSize * this.scale;
    const lineNumSize = scaledTextSize * 0.85;
    const textMetrics = this.getFontMetrics(ctx, 0, scaledTextSize, this.fontFamily);
    const lineNumMetrics = this.getFontMetrics(ctx, 0, lineNumSize, this.fontFamily);
    // Core provides the main-text baseline; shift the smaller line-number font
    // so its glyph box stays vertically centered in the same line box.
    const lineNumBaselineOffset =
      ((textMetrics.descent - textMetrics.ascent) - (lineNumMetrics.descent - lineNumMetrics.ascent)) * 0.5;
    const gutterIcons = model.gutterIcons;
    const foldMarkers = model.foldMarkers;
    const iconCount = gutterIcons ? gutterIcons.length : 0;
    const markerCount = foldMarkers ? foldMarkers.length : 0;
    let iconCursor = 0;
    let markerCursor = 0;
    const overlayMode = (model.maxGutterIcons === 0);
    const activeLogicalLine = this.getActiveLogicalLine(model);
    const normalColor = this.theme.lineNumberColor;
    const activeColor = this.getActiveLineNumberColor();

    for (const line of model.visualLines) {
      if (line.wrapIndex === 0 && !line.isPhantomLine && line.lineNumberPosition) {
        const logicalLine = line.logicalLine;
        const isCurrentLine = logicalLine === activeLogicalLine;

        while (iconCursor < iconCount && gutterIcons[iconCursor].logicalLine < logicalLine) {
          iconCursor++;
        }
        const iconStart = iconCursor;
        while (iconCursor < iconCount && gutterIcons[iconCursor].logicalLine === logicalLine) {
          iconCursor++;
        }
        const iconEnd = iconCursor;
        const hasIcons = this.iconProvider !== null && iconEnd > iconStart;

        if (overlayMode && hasIcons) {
          this.drawGutterIconItem(ctx, gutterIcons[iconStart]);
        } else {
          this.setCanvasFont(ctx, 0, lineNumSize, this.fontFamily);
          ctx.fillStyle = colorToString(isCurrentLine ? activeColor : normalColor);
          ctx.fillText(
            String(line.logicalLine + 1),
            line.lineNumberPosition.x,
            line.lineNumberPosition.y + lineNumBaselineOffset
          );

          if (hasIcons && !overlayMode) {
            for (let i = iconStart; i < iconEnd; i++) {
              this.drawGutterIconItem(ctx, gutterIcons[i]);
            }
          }
        }

        while (markerCursor < markerCount && foldMarkers[markerCursor].logicalLine < logicalLine) {
          markerCursor++;
        }
        let foldMarker: FoldMarkerRenderItem | null = null;
        while (markerCursor < markerCount && foldMarkers[markerCursor].logicalLine === logicalLine) {
          if (!foldMarker) {
            foldMarker = foldMarkers[markerCursor];
          }
          markerCursor++;
        }
        if (foldMarker) {
          this.drawFoldMarkerItem(ctx, foldMarker,
            isCurrentLine ? activeColor : normalColor);
        }
      }
    }
  }

  private drawGutterIconItem(ctx: CanvasRenderingContext2D, item: GutterIconRenderItem): void {
    if (!this.iconProvider || !item.origin || item.width <= 0 || item.height <= 0) {
      return;
    }
    const pixelMap = this.iconProvider.getIconPixelMap(item.iconId);
    if (!pixelMap) {
      return;
    }
    ctx.drawImage(pixelMap, item.origin.x, item.origin.y, item.width, item.height);
  }

  private drawFoldMarkerItem(ctx: CanvasRenderingContext2D, item: FoldMarkerRenderItem,
    color: number): void {
    if (!item.origin || item.width <= 0 || item.height <= 0) {
      return;
    }
    if (item.foldState === FoldState.NONE) {
      return;
    }

    const centerX = item.origin.x + item.width * 0.5;
    const centerY = item.origin.y + item.height * 0.5;
    const halfSize = Math.min(item.width, item.height) * 0.28;

    ctx.strokeStyle = colorToString(color);
    ctx.lineWidth = Math.max(1, item.height * 0.1);
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();

    if (item.foldState === FoldState.COLLAPSED) {
      ctx.moveTo(centerX - halfSize * 0.5, centerY - halfSize);
      ctx.lineTo(centerX + halfSize * 0.5, centerY);
      ctx.lineTo(centerX - halfSize * 0.5, centerY + halfSize);
    } else {
      ctx.moveTo(centerX - halfSize, centerY - halfSize * 0.5);
      ctx.lineTo(centerX, centerY + halfSize * 0.5);
      ctx.lineTo(centerX + halfSize, centerY - halfSize * 0.5);
    }
    ctx.stroke();
  }

  private drawCurrentLineDecoration(ctx: CanvasRenderingContext2D, model: EditorRenderModel,
    left: number, right: number): void {
    if (!model.currentLine) {
      return;
    }
    if (right <= left) {
      return;
    }
    if (model.currentLineRenderMode === CurrentLineRenderMode.NONE) {
      return;
    }

    const lineHeight = model.cursor ? model.cursor.height : 20;
    const top = model.currentLine.y;
    const bottom = top + lineHeight;

    if (model.currentLineRenderMode === CurrentLineRenderMode.BORDER) {
      const borderColor = this.getCurrentLineBorderColor();
      ctx.strokeStyle = colorToString(borderColor);
      ctx.lineWidth = 1;
      ctx.strokeRect(left, top, right - left, bottom - top);
      return;
    }

    ctx.fillStyle = colorToString(this.theme.currentLineColor);
    ctx.fillRect(left, top, right - left, bottom - top);
  }

  private drawCursor(ctx: CanvasRenderingContext2D, cursor: Cursor | null,
    cursorVisible: boolean): void {
    if (!cursor || !cursor.visible || !cursorVisible) {
      return;
    }
    const cursorWidth = HANDLE_LINE_WIDTH;
    ctx.fillStyle = colorToString(this.theme.cursorColor);
    ctx.fillRect(cursor.position.x, cursor.position.y, cursorWidth, cursor.height);
  }

  private drawSelectionRects(ctx: CanvasRenderingContext2D, rects: SelectionRect[] | null): void {
    if (!rects || rects.length === 0) {
      return;
    }
    ctx.fillStyle = colorToString(this.theme.selectionColor);
    for (const rect of rects) {
      if (!rect.origin) {
        continue;
      }
      ctx.fillRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
    }
  }

  private drawSelectionHandles(ctx: CanvasRenderingContext2D,
    startHandle: SelectionHandle | null,
    endHandle: SelectionHandle | null): void {
    if (startHandle && startHandle.visible && startHandle.position) {
      this.drawHandle(ctx, startHandle.position.x, startHandle.position.y,
        startHandle.height, true);
    }
    if (endHandle && endHandle.visible && endHandle.position) {
      this.drawHandle(ctx, endHandle.position.x, endHandle.position.y,
        endHandle.height, false);
    }
  }

  private drawHandle(ctx: CanvasRenderingContext2D, x: number, y: number,
    height: number, isStart: boolean): void {
    const lineWidth = HANDLE_LINE_WIDTH;
    const dropRadius = HANDLE_DROP_RADIUS;
    const dropLength = HANDLE_CENTER_DIST;

    ctx.fillStyle = colorToString(this.theme.cursorColor);
    ctx.fillRect(x - lineWidth / 2, y, lineWidth, height);

    const tipX = x;
    const tipY = y + height;
    const angle = isStart ? Math.PI / 4 : -Math.PI / 4;
    const cosA = Math.cos(angle);
    const sinA = Math.sin(angle);

    const cx = tipX;
    const cy = tipY + dropLength;
    const k = dropRadius * 0.5522;

    ctx.save();
    ctx.translate(tipX, tipY);
    ctx.rotate(angle);
    ctx.translate(-tipX, -tipY);

    ctx.beginPath();
    ctx.moveTo(tipX, tipY);
    ctx.bezierCurveTo(
      tipX, tipY + dropLength * 0.4,
      cx - dropRadius, cy - dropRadius * 0.8,
      cx - dropRadius, cy
    );
    ctx.bezierCurveTo(cx - dropRadius, cy + k, cx - k, cy + dropRadius, cx, cy + dropRadius);
    ctx.bezierCurveTo(cx + k, cy + dropRadius, cx + dropRadius, cy + k, cx + dropRadius, cy);
    ctx.bezierCurveTo(
      cx + dropRadius, cy - dropRadius * 0.8,
      tipX, tipY + dropLength * 0.4,
      tipX, tipY
    );
    ctx.closePath();
    ctx.fill();
    ctx.restore();
  }

  private drawGuideSegments(ctx: CanvasRenderingContext2D, segments: GuideSegment[] | null): void {
    if (!segments || segments.length === 0) {
      return;
    }
    for (const seg of segments) {
      if (!seg.start || !seg.end) {
        continue;
      }
      const isSeparator = seg.type === GuideType.SEPARATOR;
      ctx.strokeStyle = colorToString(isSeparator ? this.theme.separatorColor : this.theme.guideColor);
      ctx.lineWidth = 1;

      if (seg.style === GuideStyle.DOUBLE) {
        const offset = 1.5;
        ctx.beginPath();
        if (seg.direction === GuideDirection.HORIZONTAL) {
          ctx.moveTo(seg.start.x, seg.start.y - offset);
          ctx.lineTo(seg.end.x, seg.end.y - offset);
          ctx.moveTo(seg.start.x, seg.start.y + offset);
          ctx.lineTo(seg.end.x, seg.end.y + offset);
        } else {
          ctx.moveTo(seg.start.x - offset, seg.start.y);
          ctx.lineTo(seg.end.x - offset, seg.end.y);
          ctx.moveTo(seg.start.x + offset, seg.start.y);
          ctx.lineTo(seg.end.x + offset, seg.end.y);
        }
        ctx.stroke();
      } else {
        if (seg.arrowEnd) {
          const arrowDepth = 8 * Math.cos(Math.PI * 28 / 180);
          const dx = seg.end.x - seg.start.x;
          const dy = seg.end.y - seg.start.y;
          const len = Math.sqrt(dx * dx + dy * dy);
          if (len > arrowDepth) {
            const ratio = (len - arrowDepth) / len;
            const lineEndX = seg.start.x + dx * ratio;
            const lineEndY = seg.start.y + dy * ratio;
            ctx.beginPath();
            ctx.moveTo(seg.start.x, seg.start.y);
            ctx.lineTo(lineEndX, lineEndY);
            ctx.stroke();
          }
          this.drawArrowHead(ctx, seg.start.x, seg.start.y, seg.end.x, seg.end.y);
        } else {
          ctx.beginPath();
          ctx.moveTo(seg.start.x, seg.start.y);
          ctx.lineTo(seg.end.x, seg.end.y);
          ctx.stroke();
        }
      }
    }
  }

  private drawArrowHead(ctx: CanvasRenderingContext2D,
    fromX: number, fromY: number, toX: number, toY: number): void {
    const arrowLen = 8;
    const arrowAngle = Math.PI * 28 / 180;
    const dx = toX - fromX;
    const dy = toY - fromY;
    const len = Math.sqrt(dx * dx + dy * dy);
    if (len < 1) {
      return;
    }
    const ux = dx / len;
    const uy = dy / len;
    const cosA = Math.cos(arrowAngle);
    const sinA = Math.sin(arrowAngle);
    const ax1 = toX - arrowLen * (ux * cosA - uy * sinA);
    const ay1 = toY - arrowLen * (uy * cosA + ux * sinA);
    const ax2 = toX - arrowLen * (ux * cosA + uy * sinA);
    const ay2 = toY - arrowLen * (uy * cosA - ux * sinA);

    ctx.beginPath();
    ctx.moveTo(toX, toY);
    ctx.lineTo(ax1, ay1);
    ctx.lineTo(ax2, ay2);
    ctx.closePath();
    ctx.fill();
  }

  private drawCompositionDecoration(ctx: CanvasRenderingContext2D,
    decoration: CompositionDecoration | null): void {
    if (!decoration || !decoration.active || !decoration.origin) {
      return;
    }
    const y = decoration.origin.y + decoration.height;
    ctx.strokeStyle = colorToString(this.theme.compositionColor);
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(decoration.origin.x, y);
    ctx.lineTo(decoration.origin.x + decoration.width, y);
    ctx.stroke();
  }

  private drawDiagnosticDecorations(ctx: CanvasRenderingContext2D,
    decorations: DiagnosticDecoration[] | null): void {
    if (!decorations || decorations.length === 0) {
      return;
    }

    for (const diag of decorations) {
      if (!diag.origin) {
        continue;
      }
      let color: number;
      if (diag.color !== 0) {
        color = diag.color;
      } else {
        switch (diag.severity) {
          case 0:
            color = this.theme.diagnosticErrorColor;
            break;
          case 1:
            color = this.theme.diagnosticWarningColor;
            break;
          case 2:
            color = this.theme.diagnosticInfoColor;
            break;
          default:
            color = this.theme.diagnosticHintColor; break;
        }
      }

      ctx.save();
      ctx.strokeStyle = colorToString(color);
      const strokeWidth = Math.max(1.25, Math.min(2.25, diag.height * 0.09));
      const halfWave = Math.max(6.0, Math.min(10.0, diag.height * 0.42));
      const amplitude = Math.max(1.5, Math.min(3.0, diag.height * 0.12));
      const dashOn = Math.max(2.5, Math.min(5.0, diag.height * 0.22));
      const dashOff = Math.max(1.5, Math.min(4.0, diag.height * 0.14));
      ctx.lineWidth = strokeWidth;
      ctx.lineCap = 'round';
      ctx.lineJoin = 'round';

      const startX = diag.origin.x;
      const endX = startX + diag.width;
      const baseY = diag.origin.y + diag.height - 1.0;

      if (diag.severity === 3) {
        ctx.setLineDash([dashOn, dashOff]);
        ctx.beginPath();
        ctx.moveTo(startX, baseY);
        ctx.lineTo(endX, baseY);
        ctx.stroke();
        ctx.setLineDash([]);
      } else {
        ctx.beginPath();
        ctx.moveTo(startX, baseY);
        let x = startX;
        let step = 0;
        while (x < endX) {
          const nextX = Math.min(x + halfWave, endX);
          const midX = (x + nextX) / 2;
          const peakY = (step % 2 === 0) ? baseY - amplitude : baseY + amplitude;
          ctx.quadraticCurveTo(midX, peakY, nextX, baseY);
          x = nextX;
          step++;
        }
        ctx.stroke();
      }
      ctx.restore();
    }
  }

  private drawLinkedEditingRects(ctx: CanvasRenderingContext2D,
    rects: LinkedEditingRect[] | null): void {
    if (!rects || rects.length === 0) {
      return;
    }
    for (const rect of rects) {
      if (!rect.origin) {
        continue;
      }
      if (rect.isActive) {
        const bgColor = (this.theme.linkedEditingActiveColor & 0x00FFFFFF) | 0x20000000;
        ctx.fillStyle = colorToString(bgColor);
        ctx.fillRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
        ctx.strokeStyle = colorToString(this.theme.linkedEditingActiveColor);
        ctx.lineWidth = 2;
      } else {
        ctx.strokeStyle = colorToString(this.theme.linkedEditingInactiveColor);
        ctx.lineWidth = 1;
      }
      ctx.strokeRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
    }
  }

  private drawBracketHighlightRects(ctx: CanvasRenderingContext2D,
    rects: BracketHighlightRect[] | null): void {
    if (!rects || rects.length === 0) {
      return;
    }
    for (const rect of rects) {
      if (!rect.origin) {
        continue;
      }
      ctx.fillStyle = colorToString(this.theme.bracketHighlightBgColor);
      ctx.fillRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
      ctx.strokeStyle = colorToString(this.theme.bracketHighlightBorderColor);
      ctx.lineWidth = 1.5;
      ctx.strokeRect(rect.origin.x, rect.origin.y, rect.width, rect.height);
    }
  }

  private drawScrollbars(ctx: CanvasRenderingContext2D, model: EditorRenderModel): boolean {
    const vertical = model.verticalScrollbar;
    const horizontal = model.horizontalScrollbar;
    const verticalAlpha = getScrollbarAlpha(vertical);
    const horizontalAlpha = getScrollbarAlpha(horizontal);
    const hasVertical = isDrawableScrollbar(vertical, verticalAlpha);
    const hasHorizontal = isDrawableScrollbar(horizontal, horizontalAlpha);
    if (!hasVertical && !hasHorizontal) {
      return false;
    }

    let verticalTrackX = 0;
    let verticalTrackWidth = 0;
    let horizontalTrackY = 0;
    let horizontalTrackHeight = 0;

    if (hasVertical) {
      const trackX = vertical.track.origin ? vertical.track.origin.x : 0;
      const trackY = vertical.track.origin ? vertical.track.origin.y : 0;
      const thumbX = vertical.thumb.origin ? vertical.thumb.origin.x : 0;
      const thumbY = vertical.thumb.origin ? vertical.thumb.origin.y : 0;
      verticalTrackX = trackX;
      verticalTrackWidth = vertical.track.width;

      ctx.fillStyle = colorToString(multiplyAlpha(this.theme.scrollbarTrackColor, verticalAlpha));
      ctx.fillRect(trackX, trackY, vertical.track.width, vertical.track.height);

      const vThumbColor = vertical.thumbActive
        ? this.theme.scrollbarThumbActiveColor : this.theme.scrollbarThumbColor;
      ctx.fillStyle = colorToString(multiplyAlpha(vThumbColor, verticalAlpha));
      ctx.fillRect(thumbX, thumbY, vertical.thumb.width, vertical.thumb.height);
    }

    if (hasHorizontal) {
      const trackX = horizontal.track.origin ? horizontal.track.origin.x : 0;
      const trackY = horizontal.track.origin ? horizontal.track.origin.y : 0;
      const thumbX = horizontal.thumb.origin ? horizontal.thumb.origin.x : 0;
      const thumbY = horizontal.thumb.origin ? horizontal.thumb.origin.y : 0;
      horizontalTrackY = trackY;
      horizontalTrackHeight = horizontal.track.height;

      ctx.fillStyle = colorToString(multiplyAlpha(this.theme.scrollbarTrackColor, horizontalAlpha));
      ctx.fillRect(trackX, trackY, horizontal.track.width, horizontal.track.height);

      const hThumbColor = horizontal.thumbActive
        ? this.theme.scrollbarThumbActiveColor : this.theme.scrollbarThumbColor;
      ctx.fillStyle = colorToString(multiplyAlpha(hThumbColor, horizontalAlpha));
      ctx.fillRect(thumbX, thumbY, horizontal.thumb.width, horizontal.thumb.height);
    }

    if (hasVertical && hasHorizontal) {
      ctx.fillStyle = colorToString(multiplyAlpha(
        this.theme.scrollbarTrackColor, Math.max(verticalAlpha, horizontalAlpha)));
      ctx.fillRect(verticalTrackX, horizontalTrackY, verticalTrackWidth, horizontalTrackHeight);
    }

    return this.scrollbarConfig !== null && this.scrollbarConfig.mode === ScrollbarMode.TRANSIENT;
  }

  private getActiveLogicalLine(model: EditorRenderModel): number {
    if (!model.cursor || !model.cursor.textPosition) {
      return -1;
    }
    return model.cursor.textPosition.line;
  }

  private getActiveLineNumberColor(): number {
    let color = this.theme.currentLineNumberColor;
    if (color === 0) {
      color = this.theme.lineNumberColor;
    }
    return (color & 0x00FFFFFF) | 0xFF000000;
  }

  private getCurrentLineBorderColor(): number {
    let color = this.theme.currentLineColor;
    if (color === 0) {
      color = this.theme.lineNumberColor;
    }
    const alpha = (color >>> 24) & 0xFF;
    if (alpha < 0xA0) {
      color = (color & 0x00FFFFFF) | (0xA0 << 24);
    }
    return color;
  }

  private invalidateFontCaches(): void {
    this.fontStringCache.clear();
    this.fontMetricsCache.clear();
    this.currentFontKey = '';
  }

  private getMeasurementContext(): CanvasRenderingContext2D {
    if (this.measurementCtx === null) {
      throw new Error('EditorRenderer measurement context is not attached');
    }
    return this.measurementCtx;
  }

  private getScaledTextSize(): number {
    return this.textSize * this.scale;
  }

  private getScaledInlayHintSize(): number {
    return this.getScaledTextSize() * 0.9;
  }

  private getMainFontMetrics(): FontMetricsSnapshot {
    const ctx = this.getMeasurementContext();
    return this.getFontMetrics(ctx, 0, this.getScaledTextSize(), this.fontFamily);
  }

  private measureTextWidth(text: string, fontStyle: number): number {
    const ctx = this.getMeasurementContext();
    this.setCanvasFont(ctx, fontStyle, this.getScaledTextSize(), this.fontFamily);
    return ctx.measureText(text).width;
  }

  private measureInlayHintWidth(text: string): number {
    const ctx = this.getMeasurementContext();
    this.setCanvasFont(ctx, 0, this.getScaledInlayHintSize(), 'sans-serif');
    return ctx.measureText(text).width;
  }

  private measureIconWidth(): number {
    const metrics = this.getMainFontMetrics();
    return metrics.ascent + metrics.descent;
  }

  private computeHandleHitConfig(): HandleConfig {
    const angle = Math.PI / 4;
    const cos = Math.cos(angle);
    const sin = Math.sin(angle);
    const radius = HANDLE_DROP_RADIUS;
    const centerDistance = HANDLE_CENTER_DIST;
    const points: Array<[number, number]> = [
      [0, 0],
      [-radius, centerDistance],
      [radius, centerDistance],
      [0, centerDistance + radius],
      [0, centerDistance - radius * 0.8]
    ];

    let minX = Number.POSITIVE_INFINITY;
    let minY = Number.POSITIVE_INFINITY;
    let maxX = Number.NEGATIVE_INFINITY;
    let maxY = Number.NEGATIVE_INFINITY;

    for (const point of points) {
      const rx = point[0] * cos - point[1] * sin;
      const ry = point[0] * sin + point[1] * cos;
      minX = Math.min(minX, rx);
      minY = Math.min(minY, ry);
      maxX = Math.max(maxX, rx);
      maxY = Math.max(maxY, ry);
    }

    const pad = 8.0;
    const config = new HandleConfig();
    config.startLeft = minX - pad;
    config.startTop = minY - pad;
    config.startRight = maxX + pad;
    config.startBottom = maxY + pad;
    config.endLeft = -maxX - pad;
    config.endTop = minY - pad;
    config.endRight = -minX + pad;
    config.endBottom = maxY + pad;
    return config;
  }

  private getFontKey(fontStyle: number, size: number, family: string): string {
    return `${fontStyle}|${size}|${family}`;
  }

  private getFontString(fontStyle: number, size: number, family: string): string {
    const key = this.getFontKey(fontStyle, size, family);
    const cached = this.fontStringCache.get(key);
    if (cached) {
      return cached;
    }
    const font = buildFont(fontStyle, size, family);
    this.fontStringCache.set(key, font);
    return font;
  }

  private setCanvasFont(ctx: CanvasRenderingContext2D, fontStyle: number,
    size: number, family: string): void {
    const key = this.getFontKey(fontStyle, size, family);
    if (this.currentFontKey === key) {
      return;
    }
    ctx.font = this.getFontString(fontStyle, size, family);
    this.currentFontKey = key;
  }

  private getFontMetrics(ctx: CanvasRenderingContext2D, fontStyle: number,
    size: number, family: string): FontMetricsSnapshot {
    const key = this.getFontKey(fontStyle, size, family);
    const cached = this.fontMetricsCache.get(key);
    if (cached) {
      this.setCanvasFont(ctx, fontStyle, size, family);
      return cached;
      }
  
      this.setCanvasFont(ctx, fontStyle, size, family);
      const metrics = ctx.measureText('M');
      const ascent = metrics.fontBoundingBoxAscent || metrics.emHeightAscent
        || metrics.actualBoundingBoxAscent || size * 0.8;
      const descent = metrics.fontBoundingBoxDescent || metrics.emHeightDescent
        || metrics.actualBoundingBoxDescent || size * 0.2;
      const snapshot: FontMetricsSnapshot = {
        ascent,
        descent
      };
      this.fontMetricsCache.set(key, snapshot);
      return snapshot;
    }
  }

function colorToString(argb: number): string {
  const a = ((argb >>> 24) & 0xFF) / 255;
  const r = (argb >>> 16) & 0xFF;
  const g = (argb >>> 8) & 0xFF;
  const b = argb & 0xFF;
  if (a >= 1.0) {
    return `#${r.toString(16).padStart(2, '0')}${g.toString(16).padStart(2, '0')}${b.toString(16).padStart(2, '0')}`;
  }
  return `rgba(${r},${g},${b},${a.toFixed(3)})`;
}

function buildFont(fontStyle: number, size: number, family: string): string {
  const bold = (fontStyle & 1) !== 0;
  const italic = (fontStyle & 2) !== 0;
  let prefix = '';
  if (italic) {
    prefix += 'italic ';
  }
  if (bold) {
    prefix += 'bold ';
  }
  return `${prefix}${size}px ${family}`;
}

function drawRoundRect(ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number, r: number): void {
  r = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.arcTo(x + w, y, x + w, y + r, r);
  ctx.lineTo(x + w, y + h - r);
  ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
  ctx.lineTo(x + r, y + h);
  ctx.arcTo(x, y + h, x, y + h - r, r);
  ctx.lineTo(x, y + r);
  ctx.arcTo(x, y, x + r, y, r);
  ctx.closePath();
}

function isDrawableScrollbar(scrollbar: ScrollbarModel | null, alpha: number): boolean {
  return scrollbar !== null
    && scrollbar.visible
    && alpha > 0
    && scrollbar.track !== null
    && scrollbar.thumb !== null
    && scrollbar.track.width > 0
    && scrollbar.track.height > 0
    && scrollbar.thumb.width > 0
    && scrollbar.thumb.height > 0;
}

function getScrollbarAlpha(scrollbar: ScrollbarModel | null): number {
  if (!scrollbar) {
    return 0;
  }
  return Math.max(0, Math.min(1, scrollbar.alpha));
}

function multiplyAlpha(argb: number, alphaMultiplier: number): number {
  const m = Math.max(0, Math.min(1, alphaMultiplier));
  const baseAlpha = (argb >>> 24) & 0xFF;
  const outAlpha = Math.round(baseAlpha * m);
  return (outAlpha << 24) | (argb & 0x00FFFFFF);
}

