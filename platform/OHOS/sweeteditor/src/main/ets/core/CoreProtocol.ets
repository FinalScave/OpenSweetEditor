import {
  EditorOptions,
  GestureResult,
  GestureType,
  HitTarget,
  HitTargetType,
  KeyEventResult,
  TextChange,
  TextEditResult
} from './EditorCore';
import { TextPosition, TextRange } from './CoreFoundation';
import {
  BracketGuide,
  DiagnosticItem,
  FlowGuide,
  FoldRegion,
  GutterIcon,
  IndentGuide,
  InlayHint,
  InlayType,
  PhantomText,
  SeparatorGuide,
  StyleSpan,
  TextStyle
} from './CoreAdornments';
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
  PointF,
  ScrollbarModel,
  ScrollbarRect,
  ScrollMetrics,
  SelectionHandle,
  SelectionRect,
  VisualLine,
  VisualRun,
  VisualRunType
} from './CoreVisual';
import { LinkedEditingModel } from './CoreLinkedEditing';
import util from '@ohos.util';

class BinaryReader {
  private view: DataView;
  private offset: number = 0;

  constructor(buffer: ArrayBuffer) {
    this.view = new DataView(buffer);
  }

  hasRemaining(bytes: number = 1): boolean {
    return this.offset + bytes <= this.view.byteLength;
  }

  readInt32(): number {
    const val = this.view.getInt32(this.offset, true);
    this.offset += 4;
    return val;
  }

  readFloat32(): number {
    const val = this.view.getFloat32(this.offset, true);
    this.offset += 4;
    return val;
  }

  readPoint(): PointF {
    return { x: this.readFloat32(), y: this.readFloat32() };
  }

  readTextPosition(): TextPosition {
    return { line: this.readInt32(), column: this.readInt32() };
  }

  readUtf8String(): string {
    const len = this.readInt32();
    if (len <= 0) {
      return '';
    }
    const bytes = new Uint8Array(this.view.buffer, this.offset, len);
    this.offset += len;
    const decoder = new util.TextDecoder('utf-8');
    return decoder.decodeToString(bytes);
  }

  readTextStyle(): TextStyle {
    return {
      color: this.readInt32(),
      backgroundColor: this.readInt32(),
      fontStyle: this.readInt32()
    };
  }

  getOffset(): number {
    return this.offset;
  }

  getLength(): number {
    return this.view.byteLength;
  }
}

class BinaryWriter {
  private buffer: ArrayBuffer;
  private view: DataView;
  private offset: number = 0;

  constructor(size: number) {
    this.buffer = new ArrayBuffer(size);
    this.view = new DataView(this.buffer);
  }

  writeInt32(value: number): void {
    this.view.setInt32(this.offset, value, true);
    this.offset += 4;
  }

  writeFloat32(value: number): void {
    this.view.setFloat32(this.offset, value, true);
    this.offset += 4;
  }

  writeInt64(value: number): void {
    const lo = value & 0xFFFFFFFF;
    const hi = Math.floor(value / 0x100000000);
    this.view.setInt32(this.offset, lo, true);
    this.view.setInt32(this.offset + 4, hi, true);
    this.offset += 8;
  }

  writeUint64(value: number): void {
    this.writeInt64(value);
  }

  writeBytes(bytes: Uint8Array): void {
    const target = new Uint8Array(this.buffer, this.offset, bytes.length);
    target.set(bytes);
    this.offset += bytes.length;
  }

  getBuffer(): ArrayBuffer {
    return this.buffer;
  }

  getOffset(): number {
    return this.offset;
  }
}

export class ProtocolEncoder {
  static packEditorOptions(options: EditorOptions): ArrayBuffer {
    const writer = new BinaryWriter(40);
    writer.writeFloat32(options.touchSlop);
    writer.writeInt64(options.doubleTapTimeout);
    writer.writeInt64(options.longPressMs);
    writer.writeFloat32(options.flingFriction);
    writer.writeFloat32(options.flingMinVelocity);
    writer.writeFloat32(options.flingMaxVelocity);
    writer.writeUint64(options.maxUndoStackSize);
    return writer.getBuffer();
  }

  static packBatchTextStyles(stylesById: Map<number, TextStyle>): ArrayBuffer {
    const keys = Array.from(stylesById.keys()).sort((a, b) => a - b);
    const writer = new BinaryWriter(4 + keys.length * 16);
    writer.writeInt32(keys.length);
    for (const key of keys) {
      const style = stylesById.get(key)!;
      writer.writeInt32(key);
      writer.writeInt32(style.color);
      writer.writeInt32(style.backgroundColor);
      writer.writeInt32(style.fontStyle);
    }
    return writer.getBuffer();
  }

  static packLineSpans(line: number, layer: number, spans: StyleSpan[]): ArrayBuffer {
    const writer = new BinaryWriter(12 + spans.length * 12);
    writer.writeInt32(line);
    writer.writeInt32(layer);
    writer.writeInt32(spans.length);
    for (const s of spans) {
      writer.writeInt32(s.column);
      writer.writeInt32(s.length);
      writer.writeInt32(s.styleId);
    }
    return writer.getBuffer();
  }

  static packBatchLineSpans(layer: number, spansByLine: Map<number, StyleSpan[]>): ArrayBuffer {
    let totalSpans = 0;
    spansByLine.forEach(spans => totalSpans += spans.length);
    const writer = new BinaryWriter(8 + spansByLine.size * 8 + totalSpans * 12);
    writer.writeInt32(layer);
    writer.writeInt32(spansByLine.size);
    spansByLine.forEach((spans, line) => {
      writer.writeInt32(line);
      writer.writeInt32(spans.length);
      for (const s of spans) {
        writer.writeInt32(s.column);
        writer.writeInt32(s.length);
        writer.writeInt32(s.styleId);
      }
    });
    return writer.getBuffer();
  }

  static packBatchLineInlayHints(hintsByLine: Map<number, InlayHint[]>): ArrayBuffer {
    const encoder = new util.TextEncoder();
    // Pre-encode all text
    const allTextBytes: Map<number, Uint8Array[]> = new Map();
    let totalSize = 4; // entry_count
    hintsByLine.forEach((hints, line) => {
      totalSize += 8; // line + hint_count
      const lineTextBytes: Uint8Array[] = [];
      for (const h of hints) {
        if (h.type === InlayType.Text && h.text) {
          const bytes = encoder.encodeInto(h.text);
          lineTextBytes.push(bytes);
          totalSize += 16 + bytes.length;
        } else {
          lineTextBytes.push(new Uint8Array(0));
          totalSize += 16;
        }
      }
      allTextBytes.set(line, lineTextBytes);
    });
    const writer = new BinaryWriter(totalSize);
    writer.writeInt32(hintsByLine.size);
    hintsByLine.forEach((hints, line) => {
      writer.writeInt32(line);
      writer.writeInt32(hints.length);
      const lineTextBytes = allTextBytes.get(line)!;
      for (let i = 0; i < hints.length; i++) {
        const h = hints[i];
        writer.writeInt32(h.type as number);
        writer.writeInt32(h.column);
        writer.writeInt32(h.intValue);
        const tb = lineTextBytes[i];
        writer.writeInt32(tb.length);
        if (tb.length > 0) {
          writer.writeBytes(tb);
        }
      }
    });
    return writer.getBuffer();
  }

  static packBatchLinePhantomTexts(phantomsByLine: Map<number, PhantomText[]>): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const allTextBytes: Map<number, Uint8Array[]> = new Map();
    let totalSize = 4; // entry_count
    phantomsByLine.forEach((phantoms, line) => {
      totalSize += 8; // line + phantom_count
      const lineTextBytes: Uint8Array[] = [];
      for (const p of phantoms) {
        const bytes = encoder.encodeInto(p.text || '');
        lineTextBytes.push(bytes);
        totalSize += 8 + bytes.length;
      }
      allTextBytes.set(line, lineTextBytes);
    });
    const writer = new BinaryWriter(totalSize);
    writer.writeInt32(phantomsByLine.size);
    phantomsByLine.forEach((phantoms, line) => {
      writer.writeInt32(line);
      writer.writeInt32(phantoms.length);
      const lineTextBytes = allTextBytes.get(line)!;
      for (let i = 0; i < phantoms.length; i++) {
        writer.writeInt32(phantoms[i].column);
        const tb = lineTextBytes[i];
        writer.writeInt32(tb.length);
        if (tb.length > 0) {
          writer.writeBytes(tb);
        }
      }
    });
    return writer.getBuffer();
  }

  static packBatchLineGutterIcons(iconsByLine: Map<number, GutterIcon[]>): ArrayBuffer {
    let totalIcons = 0;
    iconsByLine.forEach(icons => totalIcons += icons.length);
    const writer = new BinaryWriter(4 + iconsByLine.size * 8 + totalIcons * 4);
    writer.writeInt32(iconsByLine.size);
    iconsByLine.forEach((icons, line) => {
      writer.writeInt32(line);
      writer.writeInt32(icons.length);
      for (const icon of icons) {
        writer.writeInt32(icon.iconId);
      }
    });
    return writer.getBuffer();
  }

  static packBatchLineDiagnostics(diagsByLine: Map<number, DiagnosticItem[]>): ArrayBuffer {
    let totalDiags = 0;
    diagsByLine.forEach(items => totalDiags += items.length);
    const writer = new BinaryWriter(4 + diagsByLine.size * 8 + totalDiags * 16);
    writer.writeInt32(diagsByLine.size);
    diagsByLine.forEach((items, line) => {
      writer.writeInt32(line);
      writer.writeInt32(items.length);
      for (const d of items) {
        writer.writeInt32(d.column);
        writer.writeInt32(d.length);
        writer.writeInt32(d.severity);
        writer.writeInt32(d.color);
      }
    });
    return writer.getBuffer();
  }

  static packLineInlayHints(line: number, hints: InlayHint[]): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const textBytesArray: Uint8Array[] = [];
    let textBlobSize = 0;
    for (const h of hints) {
      if (h.type === InlayType.Text && h.text) {
        const bytes = encoder.encodeInto(h.text);
        textBytesArray.push(bytes);
        textBlobSize += bytes.length;
      } else {
        textBytesArray.push(new Uint8Array(0));
      }
    }
    const writer = new BinaryWriter(8 + hints.length * 16 + textBlobSize);
    writer.writeInt32(line);
    writer.writeInt32(hints.length);
    for (let i = 0; i < hints.length; i++) {
      const h = hints[i];
      writer.writeInt32(h.type as number);
      writer.writeInt32(h.column);
      writer.writeInt32(h.intValue);
      const tb = textBytesArray[i];
      writer.writeInt32(tb.length);
      if (tb.length > 0) {
        writer.writeBytes(tb);
      }
    }
    return writer.getBuffer();
  }

  static packLinePhantomTexts(line: number, phantoms: PhantomText[]): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const textBytesArray: Uint8Array[] = [];
    let textBlobSize = 0;
    for (const p of phantoms) {
      const bytes = encoder.encodeInto(p.text || '');
      textBytesArray.push(bytes);
      textBlobSize += bytes.length;
    }
    const writer = new BinaryWriter(8 + phantoms.length * 8 + textBlobSize);
    writer.writeInt32(line);
    writer.writeInt32(phantoms.length);
    for (let i = 0; i < phantoms.length; i++) {
      writer.writeInt32(phantoms[i].column);
      const tb = textBytesArray[i];
      writer.writeInt32(tb.length);
      if (tb.length > 0) {
        writer.writeBytes(tb);
      }
    }
    return writer.getBuffer();
  }

  static packLineGutterIcons(line: number, icons: GutterIcon[]): ArrayBuffer {
    const writer = new BinaryWriter(8 + icons.length * 4);
    writer.writeInt32(line);
    writer.writeInt32(icons.length);
    for (const icon of icons) {
      writer.writeInt32(icon.iconId);
    }
    return writer.getBuffer();
  }

  static packLineDiagnostics(line: number, items: DiagnosticItem[]): ArrayBuffer {
    const writer = new BinaryWriter(8 + items.length * 16);
    writer.writeInt32(line);
    writer.writeInt32(items.length);
    for (const d of items) {
      writer.writeInt32(d.column);
      writer.writeInt32(d.length);
      writer.writeInt32(d.severity);
      writer.writeInt32(d.color);
    }
    return writer.getBuffer();
  }

  static packFoldRegions(regions: FoldRegion[]): ArrayBuffer {
    const writer = new BinaryWriter(4 + regions.length * 8);
    writer.writeInt32(regions.length);
    for (const r of regions) {
      writer.writeInt32(r.startLine);
      writer.writeInt32(r.endLine);
    }
    return writer.getBuffer();
  }

  static packIndentGuides(guides: IndentGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(4 + guides.length * 16);
    writer.writeInt32(guides.length);
    for (const g of guides) {
      writer.writeInt32(g.start.line);
      writer.writeInt32(g.start.column);
      writer.writeInt32(g.end.line);
      writer.writeInt32(g.end.column);
    }
    return writer.getBuffer();
  }

  static packBracketGuides(guides: BracketGuide[]): ArrayBuffer {
    let totalChildren = 0;
    for (const g of guides) {
      totalChildren += g.children.length;
    }
    const writer = new BinaryWriter(4 + guides.length * 20 + totalChildren * 8);
    writer.writeInt32(guides.length);
    for (const g of guides) {
      writer.writeInt32(g.parent.line);
      writer.writeInt32(g.parent.column);
      writer.writeInt32(g.end.line);
      writer.writeInt32(g.end.column);
      writer.writeInt32(g.children.length);
      for (const c of g.children) {
        writer.writeInt32(c.line);
        writer.writeInt32(c.column);
      }
    }
    return writer.getBuffer();
  }

  static packFlowGuides(guides: FlowGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(4 + guides.length * 16);
    writer.writeInt32(guides.length);
    for (const g of guides) {
      writer.writeInt32(g.start.line);
      writer.writeInt32(g.start.column);
      writer.writeInt32(g.end.line);
      writer.writeInt32(g.end.column);
    }
    return writer.getBuffer();
  }

  static packSeparatorGuides(guides: SeparatorGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(4 + guides.length * 16);
    writer.writeInt32(guides.length);
    for (const g of guides) {
      writer.writeInt32(g.line);
      writer.writeInt32(g.style);
      writer.writeInt32(g.count);
      writer.writeInt32(g.textEndColumn);
    }
    return writer.getBuffer();
  }

  static packLinkedEditingModel(model: LinkedEditingModel): ArrayBuffer {
    const encoder = new util.TextEncoder();
    const groups = model.groups;
    let rangeCount = 0;
    const groupTextBytes: (Uint8Array | null)[] = [];
    let stringBlobSize = 0;
    for (const group of groups) {
      rangeCount += group.ranges.length;
      if (group.defaultText !== null) {
        const bytes = encoder.encodeInto(group.defaultText);
        groupTextBytes.push(bytes);
        stringBlobSize += bytes.length;
      } else {
        groupTextBytes.push(null);
      }
    }
    const writer = new BinaryWriter(12 + groups.length * 12 + rangeCount * 20 + stringBlobSize);
    writer.writeInt32(groups.length);
    writer.writeInt32(rangeCount);
    writer.writeInt32(stringBlobSize);
    let textOffset = 0;
    for (let i = 0; i < groups.length; i++) {
      writer.writeInt32(groups[i].index);
      const bytes = groupTextBytes[i];
      if (bytes === null) {
        writer.writeInt32(0xFFFFFFFF);
        writer.writeInt32(0);
      } else {
        writer.writeInt32(textOffset);
        writer.writeInt32(bytes.length);
        textOffset += bytes.length;
      }
    }
    for (let gi = 0; gi < groups.length; gi++) {
      for (const range of groups[gi].ranges) {
        writer.writeInt32(gi);
        writer.writeInt32(range.startLine);
        writer.writeInt32(range.startColumn);
        writer.writeInt32(range.endLine);
        writer.writeInt32(range.endColumn);
      }
    }
    for (const bytes of groupTextBytes) {
      if (bytes !== null && bytes.length > 0) {
        writer.writeBytes(bytes);
      }
    }
    return writer.getBuffer();
  }
}

export class ProtocolDecoder {
  static decodeTextEditResult(payload: ArrayBuffer | undefined): TextEditResult {
    const empty: TextEditResult = { changes: [] };
    if (!payload || payload.byteLength === 0) {
      return empty;
    }
    const reader = new BinaryReader(payload);
    const changed = reader.readInt32();
    if (changed === 0) {
      return empty;
    }
    const count = reader.readInt32();
    const changes: TextChange[] = [];
    for (let i = 0; i < count; i++) {
      const range: TextRange = {
        start: reader.readTextPosition(),
        end: reader.readTextPosition()
      };
      const newText = reader.readUtf8String();
      changes.push({ range, newText });
    }
    return { changes };
  }

  static decodeKeyEventResult(payload: ArrayBuffer | undefined): KeyEventResult {
    const empty: KeyEventResult = {
      handled: false,
      contentChanged: false,
      cursorChanged: false,
      selectionChanged: false,
      editResult: null,
      command: 0
    };
    if (!payload || payload.byteLength === 0) {
      return empty;
    }
    const reader = new BinaryReader(payload);
    const handled = reader.readInt32() !== 0;
    const contentChanged = reader.readInt32() !== 0;
    const cursorChanged = reader.readInt32() !== 0;
    const selectionChanged = reader.readInt32() !== 0;
    const hasEdit = reader.readInt32() !== 0;
    let editResult: TextEditResult | null = null;
    if (hasEdit) {
      const count = reader.readInt32();
      const changes: TextChange[] = [];
      for (let i = 0; i < count; i++) {
        const range: TextRange = {
          start: reader.readTextPosition(),
          end: reader.readTextPosition()
        };
        changes.push({ range, newText: reader.readUtf8String() });
      }
      editResult = { changes };
    }
    return {
      handled,
      contentChanged,
      cursorChanged,
      selectionChanged,
      editResult,
      command: reader.readInt32()
    };
  }

  static decodeGestureResult(payload: ArrayBuffer | undefined): GestureResult {
    const defaultResult: GestureResult = {
      type: GestureType.UNDEFINED,
      tapPoint: { x: 0, y: 0 },
      cursorPosition: { line: 0, column: 0 },
      hasSelection: false,
      selection: { start: { line: 0, column: 0 }, end: { line: 0, column: 0 } },
      viewScrollX: 0,
      viewScrollY: 0,
      viewScale: 1,
      hitTarget: {
        type: HitTargetType.NONE,
        line: 0,
        column: 0,
        iconId: 0,
        colorValue: 0
      },
      isHandleDrag: false,
      needsEdgeScroll: false,
      needsFling: false,
      needsAnimation: false
    };
    if (!payload || payload.byteLength === 0) {
      return defaultResult;
    }
    const reader = new BinaryReader(payload);
    const gestureType = reader.readInt32() as GestureType;
    let tapPoint: PointF = { x: 0, y: 0 };
    if (gestureType === GestureType.TAP || gestureType === GestureType.DOUBLE_TAP ||
      gestureType === GestureType.LONG_PRESS || gestureType === GestureType.DRAG_SELECT ||
      gestureType === GestureType.CONTEXT_MENU) {
      tapPoint = reader.readPoint();
    }
    const cursorPosition = reader.readTextPosition();
    const hasSelection = reader.readInt32() !== 0;
    const selection: TextRange = { start: reader.readTextPosition(), end: reader.readTextPosition() };
    const viewScrollX = reader.readFloat32();
    const viewScrollY = reader.readFloat32();
    const viewScale = reader.readFloat32();
    let hitTarget: HitTarget = {
      type: HitTargetType.NONE,
      line: 0,
      column: 0,
      iconId: 0,
      colorValue: 0
    };
    if (reader.hasRemaining(20)) {
      hitTarget = {
        type: reader.readInt32() as HitTargetType,
        line: reader.readInt32(),
        column: reader.readInt32(),
        iconId: reader.readInt32(),
        colorValue: reader.readInt32()
      };
    }
    let needsEdgeScroll = false;
    if (reader.hasRemaining(4)) {
      needsEdgeScroll = reader.readInt32() !== 0;
    }
    let needsFling = false;
    if (reader.hasRemaining(4)) {
      needsFling = reader.readInt32() !== 0;
    }
    let needsAnimation = false;
    if (reader.hasRemaining(4)) {
      needsAnimation = reader.readInt32() !== 0;
    }
    return {
      type: gestureType,
      tapPoint,
      cursorPosition,
      hasSelection,
      selection,
      viewScrollX,
      viewScrollY,
      viewScale,
      hitTarget,
      isHandleDrag: false,
      needsEdgeScroll,
      needsFling,
      needsAnimation
    };
  }

  static decodeScrollMetrics(payload: ArrayBuffer | undefined): ScrollMetrics {
    const defaultMetrics: ScrollMetrics = {
      scale: 1,
      scrollX: 0,
      scrollY: 0,
      maxScrollX: 0,
      maxScrollY: 0,
      contentWidth: 0,
      contentHeight: 0,
      viewportWidth: 0,
      viewportHeight: 0,
      textAreaX: 0,
      textAreaWidth: 0,
      canScrollX: false,
      canScrollY: false
    };
    if (!payload || payload.byteLength < 52) {
      return defaultMetrics;
    }
    const reader = new BinaryReader(payload);
    return {
      scale: reader.readFloat32(),
      scrollX: reader.readFloat32(),
      scrollY: reader.readFloat32(),
      maxScrollX: reader.readFloat32(),
      maxScrollY: reader.readFloat32(),
      contentWidth: reader.readFloat32(),
      contentHeight: reader.readFloat32(),
      viewportWidth: reader.readFloat32(),
      viewportHeight: reader.readFloat32(),
      textAreaX: reader.readFloat32(),
      textAreaWidth: reader.readFloat32(),
      canScrollX: reader.readInt32() !== 0,
      canScrollY: reader.readInt32() !== 0
    };
  }

  static decodeRenderModel(payload: ArrayBuffer | undefined): EditorRenderModel {
    const empty = ProtocolDecoder.createEmptyRenderModel();
    if (!payload || payload.byteLength === 0) {
      return empty;
    }
    const reader = new BinaryReader(payload);
    const model = ProtocolDecoder.createEmptyRenderModel();
    model.splitX = reader.readFloat32();
    model.splitLineVisible = reader.readInt32() !== 0;
    model.scrollX = reader.readFloat32();
    model.scrollY = reader.readFloat32();
    model.viewportWidth = reader.readFloat32();
    model.viewportHeight = reader.readFloat32();
    model.currentLine = reader.readPoint();
    model.currentLineRenderMode = reader.readInt32();
    const lineCount = reader.readInt32();
    model.visualLines = [];
    for (let i = 0; i < lineCount; i++) {
      model.visualLines.push(ProtocolDecoder.readVisualLine(reader));
    }
    const gutterIconCount = reader.readInt32();
    model.gutterIcons = [];
    for (let i = 0; i < gutterIconCount; i++) {
      model.gutterIcons.push(ProtocolDecoder.readGutterIconRenderItem(reader));
    }
    const foldMarkerCount = reader.readInt32();
    model.foldMarkers = [];
    for (let i = 0; i < foldMarkerCount; i++) {
      model.foldMarkers.push(ProtocolDecoder.readFoldMarkerRenderItem(reader));
    }
    model.cursor = ProtocolDecoder.readCursor(reader);
    const selRectCount = reader.readInt32();
    model.selectionRects = [];
    for (let i = 0; i < selRectCount; i++) {
      model.selectionRects.push(ProtocolDecoder.readSelectionRect(reader));
    }
    model.selectionStartHandle = ProtocolDecoder.readSelectionHandle(reader);
    model.selectionEndHandle = ProtocolDecoder.readSelectionHandle(reader);
    model.compositionDecoration = ProtocolDecoder.readCompositionDecoration(reader);
    const guideCount = reader.readInt32();
    model.guideSegments = [];
    for (let i = 0; i < guideCount; i++) {
      model.guideSegments.push(ProtocolDecoder.readGuideSegment(reader));
    }
    const diagCount = reader.readInt32();
    model.diagnosticDecorations = [];
    for (let i = 0; i < diagCount; i++) {
      model.diagnosticDecorations.push(ProtocolDecoder.readDiagnosticDecoration(reader));
    }
    model.maxGutterIcons = reader.readInt32();
    const linkedRectCount = reader.readInt32();
    model.linkedEditingRects = [];
    for (let i = 0; i < linkedRectCount; i++) {
      model.linkedEditingRects.push(ProtocolDecoder.readLinkedEditingRect(reader));
    }
    const bracketRectCount = reader.readInt32();
    model.bracketHighlightRects = [];
    for (let i = 0; i < bracketRectCount; i++) {
      model.bracketHighlightRects.push(ProtocolDecoder.readBracketHighlightRect(reader));
    }
    if (reader.getOffset() + 80 <= reader.getLength()) {
      model.verticalScrollbar = ProtocolDecoder.readScrollbarModel(reader);
      model.horizontalScrollbar = ProtocolDecoder.readScrollbarModel(reader);
    }
    if (reader.hasRemaining(4)) {
      model.gutterSticky = reader.readInt32() !== 0;
    }
    if (reader.hasRemaining(4)) {
      model.gutterVisible = reader.readInt32() !== 0;
    }
    return model;
  }

  private static createEmptyRenderModel(): EditorRenderModel {
    const defaultHandle: SelectionHandle = { position: { x: 0, y: 0 }, height: 0, visible: false };
    const defaultScrollbar: ScrollbarModel = {
      visible: false,
      alpha: 0,
      thumbActive: false,
      track: { origin: { x: 0, y: 0 }, width: 0, height: 0 },
      thumb: { origin: { x: 0, y: 0 }, width: 0, height: 0 }
    };
    return {
      splitX: 0,
      splitLineVisible: true,
      scrollX: 0,
      scrollY: 0,
      viewportWidth: 0,
      viewportHeight: 0,
      currentLine: { x: 0, y: 0 },
      currentLineRenderMode: 0,
      visualLines: [],
      gutterIcons: [],
      foldMarkers: [],
      cursor: {
        textPosition: { line: 0, column: 0 },
        position: { x: 0, y: 0 },
        height: 0,
        visible: true,
        showDragger: false
      },
      selectionRects: [],
      selectionStartHandle: defaultHandle,
      selectionEndHandle: defaultHandle,
      compositionDecoration: {
        active: false,
        origin: { x: 0, y: 0 },
        width: 0,
        height: 0
      },
      guideSegments: [],
      diagnosticDecorations: [],
      maxGutterIcons: 0,
      linkedEditingRects: [],
      bracketHighlightRects: [],
      verticalScrollbar: defaultScrollbar,
      horizontalScrollbar: defaultScrollbar,
      gutterSticky: true,
      gutterVisible: true
    };
  }

  private static readVisualRun(reader: BinaryReader): VisualRun {
    return {
      type: reader.readInt32() as VisualRunType,
      x: reader.readFloat32(),
      y: reader.readFloat32(),
      text: reader.readUtf8String(),
      style: reader.readTextStyle(),
      iconId: reader.readInt32(),
      colorValue: reader.readInt32(),
      width: reader.readFloat32(),
      padding: reader.readFloat32(),
      margin: reader.readFloat32()
    };
  }

  private static readVisualLine(reader: BinaryReader): VisualLine {
    const logicalLine = reader.readInt32();
    const wrapIndex = reader.readInt32();
    const lineNumberPosition = reader.readPoint();
    const isPhantomLine = reader.readInt32() !== 0;
    const foldState = reader.readInt32() as FoldState;
    const runCount = reader.readInt32();
    const runs: VisualRun[] = [];
    for (let i = 0; i < runCount; i++) {
      runs.push(ProtocolDecoder.readVisualRun(reader));
    }
    return {
      logicalLine,
      wrapIndex,
      lineNumberPosition,
      runs,
      isPhantomLine,
      foldState
    };
  }

  private static readGutterIconRenderItem(reader: BinaryReader): GutterIconRenderItem {
    return {
      logicalLine: reader.readInt32(),
      iconId: reader.readInt32(),
      origin: reader.readPoint(),
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  private static readFoldMarkerRenderItem(reader: BinaryReader): FoldMarkerRenderItem {
    return {
      logicalLine: reader.readInt32(),
      foldState: reader.readInt32() as FoldState,
      origin: reader.readPoint(),
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  private static readCursor(reader: BinaryReader): Cursor {
    return {
      textPosition: reader.readTextPosition(),
      position: reader.readPoint(),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0,
      showDragger: reader.readInt32() !== 0
    };
  }

  private static readSelectionRect(reader: BinaryReader): SelectionRect {
    return { origin: reader.readPoint(), width: reader.readFloat32(), height: reader.readFloat32() };
  }

  private static readSelectionHandle(reader: BinaryReader): SelectionHandle {
    return {
      position: reader.readPoint(),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0
    };
  }

  private static readCompositionDecoration(reader: BinaryReader): CompositionDecoration {
    return {
      active: reader.readInt32() !== 0,
      origin: reader.readPoint(),
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  private static readGuideSegment(reader: BinaryReader): GuideSegment {
    return {
      direction: reader.readInt32() as GuideDirection,
      type: reader.readInt32() as GuideType,
      style: reader.readInt32() as GuideStyle,
      start: reader.readPoint(),
      end: reader.readPoint(),
      arrowEnd: reader.readInt32() !== 0
    };
  }

  private static readDiagnosticDecoration(reader: BinaryReader): DiagnosticDecoration {
    return {
      origin: reader.readPoint(),
      width: reader.readFloat32(),
      height: reader.readFloat32(),
      severity: reader.readInt32(),
      color: reader.readInt32()
    };
  }

  private static readLinkedEditingRect(reader: BinaryReader): LinkedEditingRect {
    return {
      origin: reader.readPoint(),
      width: reader.readFloat32(),
      height: reader.readFloat32(),
      isActive: reader.readInt32() !== 0
    };
  }

  private static readBracketHighlightRect(reader: BinaryReader): BracketHighlightRect {
    return { origin: reader.readPoint(), width: reader.readFloat32(), height: reader.readFloat32() };
  }

  private static readScrollbarRect(reader: BinaryReader): ScrollbarRect {
    return { origin: reader.readPoint(), width: reader.readFloat32(), height: reader.readFloat32() };
  }

  private static readScrollbarModel(reader: BinaryReader): ScrollbarModel {
    return {
      visible: reader.readInt32() !== 0,
      alpha: reader.readFloat32(),
      thumbActive: reader.readInt32() !== 0,
      track: ProtocolDecoder.readScrollbarRect(reader),
      thumb: ProtocolDecoder.readScrollbarRect(reader)
    };
  }
}

