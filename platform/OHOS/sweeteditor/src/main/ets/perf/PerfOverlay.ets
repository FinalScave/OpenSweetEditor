
/**
 * Per-frame text measurement performance statistics.
 * Call reset() at the start of each frame, record in each measurement callback,
 * after frame ends, get summary via buildSummary().
 */
export class MeasurePerfStats {
  private textCount: number = 0;
  private textNanosTotal: number = 0;
  private textNanosMax: number = 0;
  private textMaxLen: number = 0;
  private textMaxStyle: number = 0;
  private inlayCount: number = 0;
  private inlayNanosTotal: number = 0;
  private inlayNanosMax: number = 0;
  private inlayMaxLen: number = 0;
  private iconCount: number = 0;
  private iconNanosTotal: number = 0;
  private iconNanosMax: number = 0;

  reset(): void {
    this.textCount = 0;
    this.textNanosTotal = 0;
    this.textNanosMax = 0;
    this.textMaxLen = 0;
    this.textMaxStyle = 0;
    this.inlayCount = 0;
    this.inlayNanosTotal = 0;
    this.inlayNanosMax = 0;
    this.inlayMaxLen = 0;
    this.iconCount = 0;
    this.iconNanosTotal = 0;
    this.iconNanosMax = 0;
  }

  recordText(elapsedNanos: number, textLen: number, fontStyle: number): void {
    this.textCount++;
    this.textNanosTotal += elapsedNanos;
    if (elapsedNanos > this.textNanosMax) {
      this.textNanosMax = elapsedNanos;
      this.textMaxLen = textLen;
      this.textMaxStyle = fontStyle;
    }
  }

  recordInlay(elapsedNanos: number, textLen: number): void {
    this.inlayCount++;
    this.inlayNanosTotal += elapsedNanos;
    if (elapsedNanos > this.inlayNanosMax) {
      this.inlayNanosMax = elapsedNanos;
      this.inlayMaxLen = textLen;
    }
  }

  recordIcon(elapsedNanos: number): void {
    this.iconCount++;
    this.iconNanosTotal += elapsedNanos;
    if (elapsedNanos > this.iconNanosMax) {
      this.iconNanosMax = elapsedNanos;
    }
  }

  shouldLog(): boolean {
    return this.textNanosTotal / 1_000_000 >= 2.0 || this.inlayNanosTotal / 1_000_000 >= 1.0;
  }

  buildSummary(): string {
    return `measure{text=${this.textCount}/${(this.textNanosTotal / 1_000_000).toFixed(2)}ms ` +
      `max=${(this.textNanosMax / 1_000_000).toFixed(2)}ms(len=${this.textMaxLen},style=${this.textMaxStyle}) ` +
      `inlay=${this.inlayCount}/${(this.inlayNanosTotal / 1_000_000).toFixed(2)}ms ` +
      `icon=${this.iconCount}/${(this.iconNanosTotal / 1_000_000).toFixed(2)}ms}`;
  }
}

/**
 * Step-by-step performance timer for recording the duration of each sub-phase.
 */
export class PerfStepRecorder {
  static readonly MAX_STEPS = 32;
  static readonly STEP_BUILD = 'build';
  static readonly STEP_CLEAR = 'clear';
  static readonly STEP_CURRENT = 'current';
  static readonly STEP_SELECTION = 'selection';
  static readonly STEP_LINES = 'lines';
  static readonly STEP_GUIDES = 'guides';
  static readonly STEP_COMPOSITION = 'comp';
  static readonly STEP_DIAGNOSTICS = 'diag';
  static readonly STEP_LINKED = 'linked';
  static readonly STEP_BRACKET = 'bracket';
  static readonly STEP_CURSOR = 'cursor';
  static readonly STEP_GUTTER = 'gutter';
  static readonly STEP_LINE_NO = 'lineNo';
  static readonly STEP_HANDLES = 'handles';
  static readonly STEP_SCROLLBARS = 'scrollbars';
  private stepNames: string[] = [];
  private stepMs: number[] = [];
  private startTimeMs: number;
  private lastMarkMs: number;
  private endTimeMs: number = 0;

  private constructor() {
    this.startTimeMs = Date.now();
    this.lastMarkMs = this.startTimeMs;
  }

  static start(): PerfStepRecorder {
    return new PerfStepRecorder();
  }

  mark(stepName: string): void {
    const now: number = Date.now();
    if (this.stepNames.length < PerfStepRecorder.MAX_STEPS) {
      this.stepNames.push(stepName);
      this.stepMs.push(now - this.lastMarkMs);
    }
    this.lastMarkMs = now;
  }

  finish(): void {
    if (this.endTimeMs === 0) {
      this.endTimeMs = Date.now();
    }
  }

  getTotalMs(): number {
    const end: number = this.endTimeMs !== 0 ? this.endTimeMs : Date.now();
    return end - this.startTimeMs;
  }

  getStepMs(stepName: string): number {
    for (let i = 0; i < this.stepNames.length; i++) {
      if (this.stepNames[i] === stepName) {
        return this.stepMs[i];
      }
    }
    return 0;
  }

  anyStepOver(thresholdMs: number): boolean {
    for (const ms of this.stepMs) {
      if (ms >= thresholdMs) {
        return true;
      }
    }
    return false;
  }

  buildSummary(): string {
    let sb = `total=${this.getTotalMs().toFixed(2)}ms`;
    for (let i = 0; i < this.stepNames.length; i++) {
      sb += ` ${this.stepNames[i]}=${this.stepMs[i].toFixed(2)}ms`;
    }
    return sb;
  }

  getStepCount(): number {
    return this.stepNames.length;
  }

  getStepName(index: number): string {
    return (index >= 0 && index < this.stepNames.length) ? this.stepNames[index] : '';
  }

  getStepMsByIndex(index: number): number {
    return (index >= 0 && index < this.stepMs.length) ? this.stepMs[index] : 0;
  }
}

const WARN_BUILD_MS = 8.0;
const WARN_PAINT_MS = 8.0;
const WARN_INPUT_MS = 3.0;
const WARN_PAINT_STEP_MS = 2.0;
const TEXT_SIZE = 24;
const LINE_SPACING = 4;
const PADDING_H = 10;
const PADDING_V = 8;
const MARGIN = 8;

/**
 * Debug performance info overlay.
 * Draws real-time performance data at the top-left of the editor canvas.
 * Toggle with setEnabled().
 */
export class PerfOverlay {
  private enabled: boolean = false;
  private currentFps: number = 0;
  private lastBuildMs: number = 0;
  private lastDrawMs: number = 0;
  private lastTotalMs: number = 0;
  private lastDrawPerf: PerfStepRecorder | null = null;
  private lastMeasureStats: MeasurePerfStats | null = null;
  private lastInputTag: string = '';
  private lastInputMs: number = 0;

  isEnabled(): boolean {
    return this.enabled;
  }

  setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  recordFrame(buildMs: number, drawMs: number, totalMs: number,
    drawPerf: PerfStepRecorder | null, measureStats: MeasurePerfStats | null): void {
    this.lastBuildMs = buildMs;
    this.lastDrawMs = drawMs;
    this.lastTotalMs = totalMs;
    this.lastDrawPerf = drawPerf;
    this.lastMeasureStats = measureStats;
    this.currentFps = totalMs > 0 ? 1000 / totalMs : 0;
  }

  recordInput(tag: string, inputMs: number): void {
    this.lastInputTag = tag;
    this.lastInputMs = inputMs;
  }

  draw(ctx: CanvasRenderingContext2D, viewWidth: number): void {
    if (!this.enabled) {
      return;
    }

    const maxContentWidth = viewWidth - MARGIN * 2 - PADDING_H * 2;
    const lines = this.buildOverlayLines(ctx, maxContentWidth);

    const lineHeight = TEXT_SIZE + LINE_SPACING;
    const panelHeight = lines.length * lineHeight + PADDING_V * 2;

    let contentWidth = 0;
    ctx.font = `${TEXT_SIZE}px monospace`;
    for (const line of lines) {
      contentWidth = Math.max(contentWidth, ctx.measureText(line).width);
    }
    const panelWidth = Math.min(contentWidth + PADDING_H * 2, viewWidth - MARGIN * 2);

    const left = MARGIN;
    const top = MARGIN;

    ctx.fillStyle = 'rgba(0,0,0,0.7)';
    ctx.fillRect(left, top, panelWidth, panelHeight);

    let x = left + PADDING_H;
    let y = top + PADDING_V + TEXT_SIZE;
    for (const line of lines) {
      if (line.includes('SLOW') || line.includes('!')) {
        ctx.fillStyle = '#FF0000';
      } else {
        ctx.fillStyle = '#00FF00';
      }
      ctx.fillText(line, x, y);
      y += lineHeight;
    }
  }

  private buildOverlayLines(ctx: CanvasRenderingContext2D, maxWidth: number): string[] {
    const lines: string[] = [];

    lines.push(`FPS: ${this.currentFps.toFixed(0)}`);

    const frameSuffix = this.lastTotalMs > 16.6 ? ' SLOW' : '';
    lines.push(`Frame: ${this.lastTotalMs.toFixed(2)}ms (build=${this.lastBuildMs.toFixed(2)} draw=${this.lastDrawMs.toFixed(2)})${frameSuffix}`);

    if (this.lastDrawPerf) {
      this.buildStepLines(lines, ctx, maxWidth);
    }

    if (this.lastMeasureStats) {
      const summary = this.lastMeasureStats.buildSummary();
      if (summary.length > 0) {
        this.wrapText(lines, summary, ctx, maxWidth);
      }
    }

    if (this.lastInputTag.length > 0) {
      const suffix = this.lastInputMs > WARN_INPUT_MS ? ' SLOW' : '';
      lines.push(`Input[${this.lastInputTag}]: ${this.lastInputMs.toFixed(2)}ms${suffix}`);
    }

    return lines;
  }

  private buildStepLines(lines: string[], ctx: CanvasRenderingContext2D, maxWidth: number): void {
    const perf = this.lastDrawPerf!;
    const count = perf.getStepCount();
    if (count === 0) {
      return;
    }

    const prefix = 'Step: ';
    const contPrefix = '  ';
    let sb = prefix;

    for (let i = 0; i < count; i++) {
      let entry = `${perf.getStepName(i)}=${perf.getStepMsByIndex(i).toFixed(1)}`;
      if (perf.getStepMsByIndex(i) >= WARN_PAINT_STEP_MS) {
        entry += '!';
      }

      const candidate = sb.length <= prefix.length ? sb + entry : sb + ' ' + entry;

      if (ctx.measureText(candidate).width > maxWidth && sb.length > prefix.length) {
        lines.push(sb);
        sb = contPrefix + entry;
      } else {
        if (sb.length > prefix.length && sb.length > contPrefix.length) {
          sb += ' ';
        }
        sb += entry;
      }
    }
    if (sb.length > 0) {
      lines.push(sb);
    }
  }

  private wrapText(lines: string[], text: string, ctx: CanvasRenderingContext2D, maxWidth: number): void {
    if (ctx.measureText(text).width <= maxWidth) {
      lines.push(text);
      return;
    }
    const words = text.split(' ');
    let sb = '';
    for (const word of words) {
      const candidate = sb.length === 0 ? word : sb + ' ' + word;
      if (ctx.measureText(candidate).width > maxWidth && sb.length > 0) {
        lines.push(sb);
        sb = '  ' + word;
      } else {
        if (sb.length > 0) {
          sb += ' ';
        }
        sb += word;
      }
    }
    if (sb.length > 0) {
      lines.push(sb);
    }
  }
}

