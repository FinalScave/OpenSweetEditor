import util from '@ohos.util';
import { EditorActionReason, EditorActionResult, ScrollBehavior, editorActionReasonFromValue, scrollBehaviorFromValue } from './CoreAction';
import { BracketGuide, CodeLensItem, Diagnostic, DiagnosticSeverity, FlowGuide, FoldRegion, GutterIcon, IndentGuide, InlayHint, InlayType, LinkSpan, PhantomText, SeparatorGuide, SeparatorStyle, SpanLayer, StyleSpan, TextStyle, diagnosticSeverityFromValue, inlayTypeFromValue, separatorStyleFromValue, spanLayerFromValue } from './CoreAdornments';
import { AutoIndentMode, CurrentLineRenderMode, EditorOptions, FoldArrowMode, HandleConfig, ScrollbarConfig, ScrollbarMode, ScrollbarTrackTapMode, WrapMode, autoIndentModeFromValue, currentLineRenderModeFromValue, foldArrowModeFromValue, scrollbarModeFromValue, scrollbarTrackTapModeFromValue, wrapModeFromValue } from './CoreConfig';
import { IntRange, OffsetRect, PointF, Rect, TextChange, TextPosition, TextRange } from './CoreFoundation';
import { ImeContextPolicy, ImeInputContext, ImeInputContextKind, ImePreeditStorage, ImeScriptClass, ImeSyncSnapshot, ImeTextModelMode, ImeTextRange, ImeTextUnit, imeContextPolicyFromValue, imeInputContextKindFromValue, imePreeditStorageFromValue, imeScriptClassFromValue, imeTextModelModeFromValue, imeTextUnitFromValue } from './CoreIme';
import { EventType, GestureType, HitTarget, HitTargetType, eventTypeFromValue, gestureTypeFromValue, hitTargetTypeFromValue } from './CoreInteraction';
import { EditorBuiltinCommand, KeyBinding, KeyChord, KeyCode, KeyModifier, editorBuiltinCommandFromValue } from './CoreKeymap';
import { LinkedEditingModel, TabStopGroup } from './CoreLinkedEditing';
import { CompositionDecoration, Cursor, CursorRect, DiagnosticDecoration, EditorRenderModel, FoldMarkerRenderItem, FoldState, GuideDirection, GuideSegment, GuideStyle, GuideType, GutterIconRenderItem, LayoutMetrics, LinkedEditingRect, PointerCursorType, ScrollMetrics, ScrollbarModel, SelectionHandle, VisualLine, VisualLineKind, VisualRun, VisualRunType, foldStateFromValue, guideDirectionFromValue, guideStyleFromValue, guideTypeFromValue, pointerCursorTypeFromValue, visualLineKindFromValue, visualRunTypeFromValue } from './CoreVisual';

const UTF8_DECODER = new util.TextDecoder('utf-8');
const UTF8_ENCODER = new util.TextEncoder();

export class BinaryReader {
  private view: DataView;
  private offset: number = 0;

  constructor(buffer: ArrayBuffer) {
    this.view = new DataView(buffer);
  }

  get remaining(): number {
    return this.view.byteLength - this.offset;
  }

  readUint8(): number {
    const value = this.view.getUint8(this.offset);
    this.offset += 1;
    return value;
  }

  readUint16(): number {
    const value = this.view.getUint16(this.offset, true);
    this.offset += 2;
    return value;
  }

  readInt32(): number {
    const value = this.view.getInt32(this.offset, true);
    this.offset += 4;
    return value;
  }

  readInt64(): number {
    const lo = this.view.getUint32(this.offset, true);
    const hi = this.view.getInt32(this.offset + 4, true);
    this.offset += 8;
    return hi * 0x100000000 + lo;
  }

  readFloat32(): number {
    const value = this.view.getFloat32(this.offset, true);
    this.offset += 4;
    return value;
  }

  readFloat64(): number {
    const value = this.view.getFloat64(this.offset, true);
    this.offset += 8;
    return value;
  }

  readUtf8String(): string {
    const length = this.readInt32();
    if (length < 0 || length > this.remaining) {
      throw new Error('Invalid protocol length.');
    }
    if (length === 0) {
      return '';
    }
    const bytes = new Uint8Array(this.view.buffer, this.offset, length);
    this.offset += length;
    return UTF8_DECODER.decodeToString(bytes);
  }
}

export class BinaryWriter {
  private buffer: ArrayBuffer;
  private view: DataView;
  private offset: number = 0;

  constructor(size: number) {
    this.buffer = new ArrayBuffer(size);
    this.view = new DataView(this.buffer);
  }

  writeUint8(value: number): void {
    this.view.setUint8(this.offset, value);
    this.offset += 1;
  }

  writeUint16(value: number): void {
    this.view.setUint16(this.offset, value, true);
    this.offset += 2;
  }

  writeInt32(value: number): void {
    this.view.setInt32(this.offset, value, true);
    this.offset += 4;
  }

  writeInt64(value: number): void {
    const lo = value & 0xFFFFFFFF;
    const hi = Math.floor(value / 0x100000000);
    this.view.setInt32(this.offset, lo, true);
    this.view.setInt32(this.offset + 4, hi, true);
    this.offset += 8;
  }

  writeFloat32(value: number): void {
    this.view.setFloat32(this.offset, value, true);
    this.offset += 4;
  }

  writeFloat64(value: number): void {
    this.view.setFloat64(this.offset, value, true);
    this.offset += 8;
  }

  writeUtf8String(value: string): void {
    const bytes = UTF8_ENCODER.encodeInto(value || '');
    this.writeInt32(bytes.length);
    new Uint8Array(this.buffer, this.offset, bytes.length).set(bytes);
    this.offset += bytes.length;
  }

  getBuffer(): ArrayBuffer {
    return this.buffer;
  }
}

export class CoreProtocol {
  private static sizeOfUtf8String(value: string): number {
    return 4 + UTF8_ENCODER.encodeInto(value || '').length;
  }

  private static writeBracketGuideList(writer: BinaryWriter, values: BracketGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeBracketGuide(writer, values[i]);
    }
  }

  private static sizeOfBracketGuideList(values: BracketGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfBracketGuide(value);
      }
    }
    return size;
  }

  private static writeCodeLensItemList(writer: BinaryWriter, values: CodeLensItem[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeCodeLensItem(writer, values[i]);
    }
  }

  private static sizeOfCodeLensItemList(values: CodeLensItem[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfCodeLensItem(value);
      }
    }
    return size;
  }

  private static writeDiagnosticList(writer: BinaryWriter, values: Diagnostic[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeDiagnostic(writer, values[i]);
    }
  }

  private static sizeOfDiagnosticList(values: Diagnostic[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfDiagnostic(value);
      }
    }
    return size;
  }

  private static readDiagnosticDecorationList(reader: BinaryReader): DiagnosticDecoration[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: DiagnosticDecoration[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readDiagnosticDecoration(reader));
    }
    return values;
  }

  private static writeFlowGuideList(writer: BinaryWriter, values: FlowGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeFlowGuide(writer, values[i]);
    }
  }

  private static sizeOfFlowGuideList(values: FlowGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfFlowGuide(value);
      }
    }
    return size;
  }

  private static readFoldMarkerRenderItemList(reader: BinaryReader): FoldMarkerRenderItem[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: FoldMarkerRenderItem[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readFoldMarkerRenderItem(reader));
    }
    return values;
  }

  private static writeFoldRegionList(writer: BinaryWriter, values: FoldRegion[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeFoldRegion(writer, values[i]);
    }
  }

  private static sizeOfFoldRegionList(values: FoldRegion[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfFoldRegion(value);
      }
    }
    return size;
  }

  private static readGuideSegmentList(reader: BinaryReader): GuideSegment[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: GuideSegment[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readGuideSegment(reader));
    }
    return values;
  }

  private static writeGutterIconList(writer: BinaryWriter, values: GutterIcon[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeGutterIcon(writer, values[i]);
    }
  }

  private static sizeOfGutterIconList(values: GutterIcon[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfGutterIcon(value);
      }
    }
    return size;
  }

  private static readGutterIconRenderItemList(reader: BinaryReader): GutterIconRenderItem[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: GutterIconRenderItem[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readGutterIconRenderItem(reader));
    }
    return values;
  }

  private static writeIndentGuideList(writer: BinaryWriter, values: IndentGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeIndentGuide(writer, values[i]);
    }
  }

  private static sizeOfIndentGuideList(values: IndentGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfIndentGuide(value);
      }
    }
    return size;
  }

  private static writeInlayHintList(writer: BinaryWriter, values: InlayHint[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeInlayHint(writer, values[i]);
    }
  }

  private static sizeOfInlayHintList(values: InlayHint[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfInlayHint(value);
      }
    }
    return size;
  }

  private static readKeyBindingList(reader: BinaryReader): KeyBinding[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: KeyBinding[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readKeyBinding(reader));
    }
    return values;
  }

  private static writeKeyBindingList(writer: BinaryWriter, values: KeyBinding[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeKeyBinding(writer, values[i]);
    }
  }

  private static sizeOfKeyBindingList(values: KeyBinding[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfKeyBinding(value);
      }
    }
    return size;
  }

  private static writeLinkSpanList(writer: BinaryWriter, values: LinkSpan[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeLinkSpan(writer, values[i]);
    }
  }

  private static sizeOfLinkSpanList(values: LinkSpan[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfLinkSpan(value);
      }
    }
    return size;
  }

  private static readLinkedEditingRectList(reader: BinaryReader): LinkedEditingRect[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: LinkedEditingRect[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readLinkedEditingRect(reader));
    }
    return values;
  }

  private static writePhantomTextList(writer: BinaryWriter, values: PhantomText[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writePhantomText(writer, values[i]);
    }
  }

  private static sizeOfPhantomTextList(values: PhantomText[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfPhantomText(value);
      }
    }
    return size;
  }

  private static readRectList(reader: BinaryReader): Rect[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: Rect[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readRect(reader));
    }
    return values;
  }

  private static writeRectList(writer: BinaryWriter, values: Rect[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeRect(writer, values[i]);
    }
  }

  private static sizeOfRectList(values: Rect[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfRect(value);
      }
    }
    return size;
  }

  private static writeSeparatorGuideList(writer: BinaryWriter, values: SeparatorGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeSeparatorGuide(writer, values[i]);
    }
  }

  private static sizeOfSeparatorGuideList(values: SeparatorGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfSeparatorGuide(value);
      }
    }
    return size;
  }

  private static readStyleSpanList(reader: BinaryReader): StyleSpan[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: StyleSpan[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readStyleSpan(reader));
    }
    return values;
  }

  private static writeStyleSpanList(writer: BinaryWriter, values: StyleSpan[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeStyleSpan(writer, values[i]);
    }
  }

  private static sizeOfStyleSpanList(values: StyleSpan[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfStyleSpan(value);
      }
    }
    return size;
  }

  private static writeTabStopGroupList(writer: BinaryWriter, values: TabStopGroup[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeTabStopGroup(writer, values[i]);
    }
  }

  private static sizeOfTabStopGroupList(values: TabStopGroup[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfTabStopGroup(value);
      }
    }
    return size;
  }

  private static readTextChangeList(reader: BinaryReader): TextChange[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: TextChange[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readTextChange(reader));
    }
    return values;
  }

  private static readTextPositionList(reader: BinaryReader): TextPosition[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: TextPosition[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readTextPosition(reader));
    }
    return values;
  }

  private static writeTextPositionList(writer: BinaryWriter, values: TextPosition[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeTextPosition(writer, values[i]);
    }
  }

  private static sizeOfTextPositionList(values: TextPosition[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfTextPosition(value);
      }
    }
    return size;
  }

  private static readTextRangeList(reader: BinaryReader): TextRange[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: TextRange[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readTextRange(reader));
    }
    return values;
  }

  private static writeTextRangeList(writer: BinaryWriter, values: TextRange[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      this.writeTextRange(writer, values[i]);
    }
  }

  private static sizeOfTextRangeList(values: TextRange[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += this.sizeOfTextRange(value);
      }
    }
    return size;
  }

  private static readVisualLineList(reader: BinaryReader): VisualLine[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: VisualLine[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readVisualLine(reader));
    }
    return values;
  }

  private static readVisualRunList(reader: BinaryReader): VisualRun[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: VisualRun[] = [];
    for (let i = 0; i < count; i++) {
      values.push(this.readVisualRun(reader));
    }
    return values;
  }

  private static readEditorActionResult(reader: BinaryReader): EditorActionResult {
    return {
      handled: reader.readInt32() !== 0,
      needsRedraw: reader.readInt32() !== 0,
      reason: editorActionReasonFromValue(reader.readInt32()),
      contentChanged: reader.readInt32() !== 0,
      cursorChanged: reader.readInt32() !== 0,
      selectionChanged: reader.readInt32() !== 0,
      scrollChanged: reader.readInt32() !== 0,
      scaleChanged: reader.readInt32() !== 0,
      pointerCursorChanged: reader.readInt32() !== 0,
      compositionChanged: reader.readInt32() !== 0,
      decorationChanged: reader.readInt32() !== 0,
      needsImeSync: reader.readInt32() !== 0,
      needsEdgeScroll: reader.readInt32() !== 0,
      needsFling: reader.readInt32() !== 0,
      needsAnimation: reader.readInt32() !== 0,
      isHandleDrag: reader.readInt32() !== 0,
      changes: this.readTextChangeList(reader),
      cursorBefore: this.readTextPosition(reader),
      cursorAfter: this.readTextPosition(reader),
      hasSelectionBefore: reader.readInt32() !== 0,
      hasSelectionAfter: reader.readInt32() !== 0,
      selectionBefore: this.readTextRange(reader),
      selectionAfter: this.readTextRange(reader),
      scrollXBefore: reader.readFloat32(),
      scrollYBefore: reader.readFloat32(),
      scrollXAfter: reader.readFloat32(),
      scrollYAfter: reader.readFloat32(),
      scaleBefore: reader.readFloat32(),
      scaleAfter: reader.readFloat32(),
      pointerCursorBefore: pointerCursorTypeFromValue(reader.readInt32()),
      pointerCursorAfter: pointerCursorTypeFromValue(reader.readInt32()),
      imeSync: this.readImeSyncSnapshot(reader),
      gestureType: gestureTypeFromValue(reader.readInt32()),
      gestureEventType: eventTypeFromValue(reader.readInt32()),
      tapPoint: this.readPointF(reader),
      hitTarget: this.readHitTarget(reader),
      modifiers: reader.readInt32(),
      command: reader.readInt32()
    };
  }

  static decodeEditorActionResult(buffer: ArrayBuffer): EditorActionResult {
    return this.readEditorActionResult(new BinaryReader(buffer));
  }

  static writeBracketGuide(writer: BinaryWriter, value: BracketGuide): void {
    this.writeTextPosition(writer, value.parent);
    this.writeTextPosition(writer, value.end);
    this.writeTextPositionList(writer, value.children);
  }

  static sizeOfBracketGuide(value: BracketGuide): number {
    let size = 0;
    size += this.sizeOfTextPosition(value.parent);
    size += this.sizeOfTextPosition(value.end);
    size += this.sizeOfTextPositionList(value.children);
    return size;
  }

  static writeCodeLensItem(writer: BinaryWriter, value: CodeLensItem): void {
    writer.writeInt32(value.column);
    writer.writeInt32(value.commandId);
    writer.writeUtf8String(value.text);
  }

  static sizeOfCodeLensItem(value: CodeLensItem): number {
    let size = 0;
    size += 4;
    size += 4;
    size += this.sizeOfUtf8String(value.text);
    return size;
  }

  static writeDiagnostic(writer: BinaryWriter, value: Diagnostic): void {
    writer.writeInt32(value.column);
    writer.writeInt32(value.length);
    writer.writeInt32(value.severity as number);
  }

  static sizeOfDiagnostic(value: Diagnostic): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  static writeFlowGuide(writer: BinaryWriter, value: FlowGuide): void {
    this.writeTextPosition(writer, value.start);
    this.writeTextPosition(writer, value.end);
  }

  static sizeOfFlowGuide(value: FlowGuide): number {
    let size = 0;
    size += this.sizeOfTextPosition(value.start);
    size += this.sizeOfTextPosition(value.end);
    return size;
  }

  static writeFoldRegion(writer: BinaryWriter, value: FoldRegion): void {
    writer.writeInt32(value.startLine);
    writer.writeInt32(value.endLine);
    writer.writeUint8(value.collapsed ? 1 : 0);
  }

  static sizeOfFoldRegion(value: FoldRegion): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 1;
    return size;
  }

  static writeGutterIcon(writer: BinaryWriter, value: GutterIcon): void {
    writer.writeInt32(value.iconId);
  }

  static sizeOfGutterIcon(value: GutterIcon): number {
    let size = 0;
    size += 4;
    return size;
  }

  static writeIndentGuide(writer: BinaryWriter, value: IndentGuide): void {
    this.writeTextPosition(writer, value.start);
    this.writeTextPosition(writer, value.end);
  }

  static sizeOfIndentGuide(value: IndentGuide): number {
    let size = 0;
    size += this.sizeOfTextPosition(value.start);
    size += this.sizeOfTextPosition(value.end);
    return size;
  }

  static writeInlayHint(writer: BinaryWriter, value: InlayHint): void {
    writer.writeInt32(value.type as number);
    writer.writeInt32(value.column);
    writer.writeInt32(value.intValue);
    writer.writeUtf8String(value.text);
  }

  static sizeOfInlayHint(value: InlayHint): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += this.sizeOfUtf8String(value.text);
    return size;
  }

  static writeLinkSpan(writer: BinaryWriter, value: LinkSpan): void {
    writer.writeInt32(value.column);
    writer.writeInt32(value.length);
    writer.writeUtf8String(value.target);
  }

  static sizeOfLinkSpan(value: LinkSpan): number {
    let size = 0;
    size += 4;
    size += 4;
    size += this.sizeOfUtf8String(value.target);
    return size;
  }

  static writePhantomText(writer: BinaryWriter, value: PhantomText): void {
    writer.writeInt32(value.column);
    writer.writeUtf8String(value.text);
  }

  static sizeOfPhantomText(value: PhantomText): number {
    let size = 0;
    size += 4;
    size += this.sizeOfUtf8String(value.text);
    return size;
  }

  static writeSeparatorGuide(writer: BinaryWriter, value: SeparatorGuide): void {
    writer.writeInt32(value.line);
    writer.writeInt32(value.style as number);
    writer.writeInt32(value.count);
    writer.writeInt32(value.textEndColumn);
  }

  static sizeOfSeparatorGuide(value: SeparatorGuide): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readStyleSpan(reader: BinaryReader): StyleSpan {
    return {
      column: reader.readInt32(),
      length: reader.readInt32(),
      styleId: reader.readInt32()
    };
  }

  static decodeStyleSpan(buffer: ArrayBuffer): StyleSpan {
    return this.readStyleSpan(new BinaryReader(buffer));
  }

  static writeStyleSpan(writer: BinaryWriter, value: StyleSpan): void {
    writer.writeInt32(value.column);
    writer.writeInt32(value.length);
    writer.writeInt32(value.styleId);
  }

  static sizeOfStyleSpan(value: StyleSpan): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readTextStyle(reader: BinaryReader): TextStyle {
    return {
      color: reader.readInt32(),
      backgroundColor: reader.readInt32(),
      fontStyle: reader.readInt32()
    };
  }

  static decodeTextStyle(buffer: ArrayBuffer): TextStyle {
    return this.readTextStyle(new BinaryReader(buffer));
  }

  static writeTextStyle(writer: BinaryWriter, value: TextStyle): void {
    writer.writeInt32(value.color);
    writer.writeInt32(value.backgroundColor);
    writer.writeInt32(value.fontStyle);
  }

  static sizeOfTextStyle(value: TextStyle): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  static writeEditorOptions(writer: BinaryWriter, value: EditorOptions): void {
    writer.writeFloat32(value.touchSlop);
    writer.writeInt64(value.doubleTapTimeout);
    writer.writeInt64(value.longPressMs);
    writer.writeFloat32(value.flingFriction);
    writer.writeFloat32(value.flingMinVelocity);
    writer.writeFloat32(value.flingMaxVelocity);
    writer.writeInt64(value.maxUndoStackSize);
    writer.writeInt64(value.keyChordTimeoutMs);
    writer.writeUint8(value.revealSelectionEndOnSelectAll ? 1 : 0);
  }

  static sizeOfEditorOptions(value: EditorOptions): number {
    let size = 0;
    size += 4;
    size += 8;
    size += 8;
    size += 4;
    size += 4;
    size += 4;
    size += 8;
    size += 8;
    size += 1;
    return size;
  }

  static writeHandleConfig(writer: BinaryWriter, value: HandleConfig): void {
    this.writeOffsetRect(writer, value.startHitOffset);
    this.writeOffsetRect(writer, value.endHitOffset);
  }

  static sizeOfHandleConfig(value: HandleConfig): number {
    let size = 0;
    size += this.sizeOfOffsetRect(value.startHitOffset);
    size += this.sizeOfOffsetRect(value.endHitOffset);
    return size;
  }

  static writeScrollbarConfig(writer: BinaryWriter, value: ScrollbarConfig): void {
    writer.writeFloat32(value.thickness);
    writer.writeFloat32(value.minThumb);
    writer.writeFloat32(value.thumbHitPadding);
    writer.writeInt32(value.mode as number);
    writer.writeUint8(value.thumbDraggable ? 1 : 0);
    writer.writeInt32(value.trackTapMode as number);
    writer.writeUint16(value.fadeDelayMs);
    writer.writeUint16(value.fadeDurationMs);
  }

  static sizeOfScrollbarConfig(value: ScrollbarConfig): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 1;
    size += 4;
    size += 2;
    size += 2;
    return size;
  }

  private static readIntRange(reader: BinaryReader): IntRange {
    return {
      start: reader.readInt32(),
      end: reader.readInt32()
    };
  }

  static decodeIntRange(buffer: ArrayBuffer): IntRange {
    return this.readIntRange(new BinaryReader(buffer));
  }

  static writeIntRange(writer: BinaryWriter, value: IntRange): void {
    writer.writeInt32(value.start);
    writer.writeInt32(value.end);
  }

  static sizeOfIntRange(value: IntRange): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readOffsetRect(reader: BinaryReader): OffsetRect {
    return {
      left: reader.readFloat32(),
      top: reader.readFloat32(),
      right: reader.readFloat32(),
      bottom: reader.readFloat32()
    };
  }

  static decodeOffsetRect(buffer: ArrayBuffer): OffsetRect {
    return this.readOffsetRect(new BinaryReader(buffer));
  }

  static writeOffsetRect(writer: BinaryWriter, value: OffsetRect): void {
    writer.writeFloat32(value.left);
    writer.writeFloat32(value.top);
    writer.writeFloat32(value.right);
    writer.writeFloat32(value.bottom);
  }

  static sizeOfOffsetRect(value: OffsetRect): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readPointF(reader: BinaryReader): PointF {
    return {
      x: reader.readFloat32(),
      y: reader.readFloat32()
    };
  }

  static decodePointF(buffer: ArrayBuffer): PointF {
    return this.readPointF(new BinaryReader(buffer));
  }

  static writePointF(writer: BinaryWriter, value: PointF): void {
    writer.writeFloat32(value.x);
    writer.writeFloat32(value.y);
  }

  static sizeOfPointF(value: PointF): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readRect(reader: BinaryReader): Rect {
    return {
      origin: this.readPointF(reader),
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  static decodeRect(buffer: ArrayBuffer): Rect {
    return this.readRect(new BinaryReader(buffer));
  }

  static writeRect(writer: BinaryWriter, value: Rect): void {
    this.writePointF(writer, value.origin);
    writer.writeFloat32(value.width);
    writer.writeFloat32(value.height);
  }

  static sizeOfRect(value: Rect): number {
    let size = 0;
    size += this.sizeOfPointF(value.origin);
    size += 4;
    size += 4;
    return size;
  }

  private static readTextChange(reader: BinaryReader): TextChange {
    return {
      range: this.readTextRange(reader),
      newText: reader.readUtf8String()
    };
  }

  static decodeTextChange(buffer: ArrayBuffer): TextChange {
    return this.readTextChange(new BinaryReader(buffer));
  }

  private static readTextPosition(reader: BinaryReader): TextPosition {
    return {
      line: reader.readInt32(),
      column: reader.readInt32()
    };
  }

  static decodeTextPosition(buffer: ArrayBuffer): TextPosition {
    return this.readTextPosition(new BinaryReader(buffer));
  }

  static writeTextPosition(writer: BinaryWriter, value: TextPosition): void {
    writer.writeInt32(value.line);
    writer.writeInt32(value.column);
  }

  static sizeOfTextPosition(value: TextPosition): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readTextRange(reader: BinaryReader): TextRange {
    return {
      start: this.readTextPosition(reader),
      end: this.readTextPosition(reader)
    };
  }

  static decodeTextRange(buffer: ArrayBuffer): TextRange {
    return this.readTextRange(new BinaryReader(buffer));
  }

  static writeTextRange(writer: BinaryWriter, value: TextRange): void {
    this.writeTextPosition(writer, value.start);
    this.writeTextPosition(writer, value.end);
  }

  static sizeOfTextRange(value: TextRange): number {
    let size = 0;
    size += this.sizeOfTextPosition(value.start);
    size += this.sizeOfTextPosition(value.end);
    return size;
  }

  private static readImeInputContext(reader: BinaryReader): ImeInputContext {
    return {
      id: reader.readInt64(),
      revision: reader.readInt32(),
      documentStartOffset: reader.readInt32(),
      text: reader.readUtf8String(),
      selection: this.readImeTextRange(reader),
      hasComposition: reader.readInt32() !== 0,
      composition: this.readImeTextRange(reader),
      kind: imeInputContextKindFromValue(reader.readInt32())
    };
  }

  static decodeImeInputContext(buffer: ArrayBuffer): ImeInputContext {
    return this.readImeInputContext(new BinaryReader(buffer));
  }

  private static readImeSyncSnapshot(reader: BinaryReader): ImeSyncSnapshot {
    return {
      cursor: this.readTextPosition(reader),
      selection: this.readTextRange(reader),
      hasSelection: reader.readInt32() !== 0,
      hasComposingSession: reader.readInt32() !== 0,
      hasVisibleCompositionRange: reader.readInt32() !== 0,
      visibleCompositionRange: this.readTextRange(reader),
      hasPlatformMarkedRange: reader.readInt32() !== 0,
      platformMarkedRange: this.readTextRange(reader),
      preeditStorage: imePreeditStorageFromValue(reader.readInt32()),
      contextPolicy: imeContextPolicyFromValue(reader.readInt32()),
      clearPlatformPreedit: reader.readInt32() !== 0
    };
  }

  static decodeImeSyncSnapshot(buffer: ArrayBuffer): ImeSyncSnapshot {
    return this.readImeSyncSnapshot(new BinaryReader(buffer));
  }

  private static readImeTextRange(reader: BinaryReader): ImeTextRange {
    return {
      start: reader.readInt32(),
      end: reader.readInt32()
    };
  }

  static decodeImeTextRange(buffer: ArrayBuffer): ImeTextRange {
    return this.readImeTextRange(new BinaryReader(buffer));
  }

  static writeImeTextRange(writer: BinaryWriter, value: ImeTextRange): void {
    writer.writeInt32(value.start);
    writer.writeInt32(value.end);
  }

  static sizeOfImeTextRange(value: ImeTextRange): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readHitTarget(reader: BinaryReader): HitTarget {
    return {
      type: hitTargetTypeFromValue(reader.readInt32()),
      line: reader.readInt32(),
      column: reader.readInt32(),
      iconId: reader.readInt32(),
      colorValue: reader.readInt32()
    };
  }

  static decodeHitTarget(buffer: ArrayBuffer): HitTarget {
    return this.readHitTarget(new BinaryReader(buffer));
  }

  private static readKeyBinding(reader: BinaryReader): KeyBinding {
    return {
      first: this.readKeyChord(reader),
      second: this.readKeyChord(reader),
      command: reader.readInt32()
    };
  }

  static decodeKeyBinding(buffer: ArrayBuffer): KeyBinding {
    return this.readKeyBinding(new BinaryReader(buffer));
  }

  static writeKeyBinding(writer: BinaryWriter, value: KeyBinding): void {
    this.writeKeyChord(writer, value.first);
    this.writeKeyChord(writer, value.second);
    writer.writeInt32(value.command);
  }

  static sizeOfKeyBinding(value: KeyBinding): number {
    let size = 0;
    size += this.sizeOfKeyChord(value.first);
    size += this.sizeOfKeyChord(value.second);
    size += 4;
    return size;
  }

  private static readKeyChord(reader: BinaryReader): KeyChord {
    return {
      modifiers: reader.readUint8(),
      keyCode: reader.readUint16()
    };
  }

  static decodeKeyChord(buffer: ArrayBuffer): KeyChord {
    return this.readKeyChord(new BinaryReader(buffer));
  }

  static writeKeyChord(writer: BinaryWriter, value: KeyChord): void {
    writer.writeUint8(value.modifiers);
    writer.writeUint16(value.keyCode);
  }

  static sizeOfKeyChord(value: KeyChord): number {
    let size = 0;
    size += 1;
    size += 2;
    return size;
  }

  static writeLinkedEditingModel(writer: BinaryWriter, value: LinkedEditingModel): void {
    this.writeTabStopGroupList(writer, value.groups);
  }

  static sizeOfLinkedEditingModel(value: LinkedEditingModel): number {
    let size = 0;
    size += this.sizeOfTabStopGroupList(value.groups);
    return size;
  }

  static writeTabStopGroup(writer: BinaryWriter, value: TabStopGroup): void {
    writer.writeInt32(value.index);
    this.writeTextRangeList(writer, value.ranges);
    writer.writeUtf8String(value.defaultText);
  }

  static sizeOfTabStopGroup(value: TabStopGroup): number {
    let size = 0;
    size += 4;
    size += this.sizeOfTextRangeList(value.ranges);
    size += this.sizeOfUtf8String(value.defaultText);
    return size;
  }

  private static readCompositionDecoration(reader: BinaryReader): CompositionDecoration {
    return {
      active: reader.readInt32() !== 0,
      rect: this.readRect(reader)
    };
  }

  static decodeCompositionDecoration(buffer: ArrayBuffer): CompositionDecoration {
    return this.readCompositionDecoration(new BinaryReader(buffer));
  }

  private static readCursor(reader: BinaryReader): Cursor {
    return {
      textPosition: this.readTextPosition(reader),
      position: this.readPointF(reader),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0,
      showDragger: reader.readInt32() !== 0
    };
  }

  static decodeCursor(buffer: ArrayBuffer): Cursor {
    return this.readCursor(new BinaryReader(buffer));
  }

  private static readCursorRect(reader: BinaryReader): CursorRect {
    return {
      x: reader.readFloat32(),
      y: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  static decodeCursorRect(buffer: ArrayBuffer): CursorRect {
    return this.readCursorRect(new BinaryReader(buffer));
  }

  static writeCursorRect(writer: BinaryWriter, value: CursorRect): void {
    writer.writeFloat32(value.x);
    writer.writeFloat32(value.y);
    writer.writeFloat32(value.height);
  }

  static sizeOfCursorRect(value: CursorRect): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readDiagnosticDecoration(reader: BinaryReader): DiagnosticDecoration {
    return {
      rect: this.readRect(reader),
      severity: reader.readInt32()
    };
  }

  static decodeDiagnosticDecoration(buffer: ArrayBuffer): DiagnosticDecoration {
    return this.readDiagnosticDecoration(new BinaryReader(buffer));
  }

  private static readEditorRenderModel(reader: BinaryReader): EditorRenderModel {
    return {
      splitX: reader.readFloat32(),
      splitLineVisible: reader.readInt32() !== 0,
      scrollX: reader.readFloat32(),
      scrollY: reader.readFloat32(),
      viewportWidth: reader.readFloat32(),
      viewportHeight: reader.readFloat32(),
      currentLine: this.readPointF(reader),
      currentLineRenderMode: currentLineRenderModeFromValue(reader.readInt32()),
      lines: this.readVisualLineList(reader),
      cursor: this.readCursor(reader),
      selectionRects: this.readRectList(reader),
      selectionStartHandle: this.readSelectionHandle(reader),
      selectionEndHandle: this.readSelectionHandle(reader),
      compositionDecoration: this.readCompositionDecoration(reader),
      guideSegments: this.readGuideSegmentList(reader),
      diagnosticDecorations: this.readDiagnosticDecorationList(reader),
      maxGutterIcons: reader.readInt32(),
      linkedEditingRects: this.readLinkedEditingRectList(reader),
      bracketHighlightRects: this.readRectList(reader),
      gutterIcons: this.readGutterIconRenderItemList(reader),
      foldMarkers: this.readFoldMarkerRenderItemList(reader),
      verticalScrollbar: this.readScrollbarModel(reader),
      horizontalScrollbar: this.readScrollbarModel(reader),
      gutterSticky: reader.readInt32() !== 0,
      gutterVisible: reader.readInt32() !== 0,
      pointerCursorType: pointerCursorTypeFromValue(reader.readInt32())
    };
  }

  static decodeEditorRenderModel(buffer: ArrayBuffer): EditorRenderModel {
    return this.readEditorRenderModel(new BinaryReader(buffer));
  }

  private static readFoldMarkerRenderItem(reader: BinaryReader): FoldMarkerRenderItem {
    return {
      logicalLine: reader.readInt32(),
      foldState: foldStateFromValue(reader.readInt32()),
      rect: this.readRect(reader)
    };
  }

  static decodeFoldMarkerRenderItem(buffer: ArrayBuffer): FoldMarkerRenderItem {
    return this.readFoldMarkerRenderItem(new BinaryReader(buffer));
  }

  private static readGuideSegment(reader: BinaryReader): GuideSegment {
    return {
      direction: guideDirectionFromValue(reader.readInt32()),
      type: guideTypeFromValue(reader.readInt32()),
      style: guideStyleFromValue(reader.readInt32()),
      start: this.readPointF(reader),
      end: this.readPointF(reader),
      arrowEnd: reader.readInt32() !== 0
    };
  }

  static decodeGuideSegment(buffer: ArrayBuffer): GuideSegment {
    return this.readGuideSegment(new BinaryReader(buffer));
  }

  private static readGutterIconRenderItem(reader: BinaryReader): GutterIconRenderItem {
    return {
      logicalLine: reader.readInt32(),
      iconId: reader.readInt32(),
      rect: this.readRect(reader)
    };
  }

  static decodeGutterIconRenderItem(buffer: ArrayBuffer): GutterIconRenderItem {
    return this.readGutterIconRenderItem(new BinaryReader(buffer));
  }

  private static readLayoutMetrics(reader: BinaryReader): LayoutMetrics {
    return {
      fontHeight: reader.readFloat32(),
      fontAscent: reader.readFloat32(),
      lineSpacingAdd: reader.readFloat32(),
      lineSpacingMult: reader.readFloat32(),
      lineNumberMargin: reader.readFloat32(),
      lineNumberWidth: reader.readFloat32(),
      contentStartPadding: reader.readFloat32(),
      maxGutterIcons: reader.readInt32(),
      inlayHintPadding: reader.readFloat32(),
      inlayHintMargin: reader.readFloat32(),
      foldArrowMode: foldArrowModeFromValue(reader.readInt32()),
      hasFoldRegions: reader.readInt32() !== 0,
      gutterSticky: reader.readInt32() !== 0,
      gutterVisible: reader.readInt32() !== 0
    };
  }

  static decodeLayoutMetrics(buffer: ArrayBuffer): LayoutMetrics {
    return this.readLayoutMetrics(new BinaryReader(buffer));
  }

  private static readLinkedEditingRect(reader: BinaryReader): LinkedEditingRect {
    return {
      rect: this.readRect(reader),
      isActive: reader.readInt32() !== 0
    };
  }

  static decodeLinkedEditingRect(buffer: ArrayBuffer): LinkedEditingRect {
    return this.readLinkedEditingRect(new BinaryReader(buffer));
  }

  private static readScrollMetrics(reader: BinaryReader): ScrollMetrics {
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

  static decodeScrollMetrics(buffer: ArrayBuffer): ScrollMetrics {
    return this.readScrollMetrics(new BinaryReader(buffer));
  }

  private static readScrollbarModel(reader: BinaryReader): ScrollbarModel {
    return {
      visible: reader.readInt32() !== 0,
      alpha: reader.readFloat32(),
      thumbActive: reader.readInt32() !== 0,
      track: this.readRect(reader),
      thumb: this.readRect(reader)
    };
  }

  static decodeScrollbarModel(buffer: ArrayBuffer): ScrollbarModel {
    return this.readScrollbarModel(new BinaryReader(buffer));
  }

  private static readSelectionHandle(reader: BinaryReader): SelectionHandle {
    return {
      position: this.readPointF(reader),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0
    };
  }

  static decodeSelectionHandle(buffer: ArrayBuffer): SelectionHandle {
    return this.readSelectionHandle(new BinaryReader(buffer));
  }

  private static readVisualLine(reader: BinaryReader): VisualLine {
    return {
      logicalLine: reader.readInt32(),
      wrapIndex: reader.readInt32(),
      lineNumberPosition: this.readPointF(reader),
      runs: this.readVisualRunList(reader),
      kind: visualLineKindFromValue(reader.readInt32()),
      ownsGutterSemantics: reader.readInt32() !== 0,
      foldState: foldStateFromValue(reader.readInt32())
    };
  }

  static decodeVisualLine(buffer: ArrayBuffer): VisualLine {
    return this.readVisualLine(new BinaryReader(buffer));
  }

  private static readVisualRun(reader: BinaryReader): VisualRun {
    return {
      type: visualRunTypeFromValue(reader.readInt32()),
      x: reader.readFloat32(),
      y: reader.readFloat32(),
      text: reader.readUtf8String(),
      style: this.readTextStyle(reader),
      iconId: reader.readInt32(),
      colorValue: reader.readInt32(),
      width: reader.readFloat32(),
      padding: reader.readFloat32(),
      margin: reader.readFloat32(),
      active: reader.readInt32() !== 0
    };
  }

  static decodeVisualRun(buffer: ArrayBuffer): VisualRun {
    return this.readVisualRun(new BinaryReader(buffer));
  }

  static encodeBracketGuide(value: BracketGuide): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfBracketGuide(value));
    this.writeBracketGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeCodeLensItem(value: CodeLensItem): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfCodeLensItem(value));
    this.writeCodeLensItem(writer, value);
    return writer.getBuffer();
  }

  static encodeDiagnostic(value: Diagnostic): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfDiagnostic(value));
    this.writeDiagnostic(writer, value);
    return writer.getBuffer();
  }

  static encodeFlowGuide(value: FlowGuide): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfFlowGuide(value));
    this.writeFlowGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeFoldRegion(value: FoldRegion): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfFoldRegion(value));
    this.writeFoldRegion(writer, value);
    return writer.getBuffer();
  }

  static encodeGutterIcon(value: GutterIcon): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfGutterIcon(value));
    this.writeGutterIcon(writer, value);
    return writer.getBuffer();
  }

  static encodeIndentGuide(value: IndentGuide): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfIndentGuide(value));
    this.writeIndentGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeInlayHint(value: InlayHint): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfInlayHint(value));
    this.writeInlayHint(writer, value);
    return writer.getBuffer();
  }

  static encodeLinkSpan(value: LinkSpan): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfLinkSpan(value));
    this.writeLinkSpan(writer, value);
    return writer.getBuffer();
  }

  static encodePhantomText(value: PhantomText): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfPhantomText(value));
    this.writePhantomText(writer, value);
    return writer.getBuffer();
  }

  private static writeRegisterBatchTextStylesPayloadWire(writer: BinaryWriter, styleByStyleId: Map<number, TextStyle>): void {
    const styleByStyleIdKeys = styleByStyleId ? Array.from(styleByStyleId.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(styleByStyleIdKeys.length);
    for (const key of styleByStyleIdKeys) {
      writer.writeInt32(key);
      const value = styleByStyleId.get(key)!;
      this.writeTextStyle(writer, value);
    }
  }

  private static sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId: Map<number, TextStyle>): number {
    let size = 0;
    size += 4;
    const styleByStyleIdKeys = styleByStyleId ? Array.from(styleByStyleId.keys()).sort((a, b) => a - b) : [];
    for (const key of styleByStyleIdKeys) {
      size += 4;
      const value = styleByStyleId.get(key)!;
      size += this.sizeOfTextStyle(value);
    }
    return size;
  }

  static encodeRegisterBatchTextStylesPayload(styleByStyleId: Map<number, TextStyle>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId));
    this.writeRegisterBatchTextStylesPayloadWire(writer, styleByStyleId);
    return writer.getBuffer();
  }

  static encodeSeparatorGuide(value: SeparatorGuide): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSeparatorGuide(value));
    this.writeSeparatorGuide(writer, value);
    return writer.getBuffer();
  }

  private static writeSetBatchLineCodeLensPayloadWire(writer: BinaryWriter, itemsByLine: Map<number, CodeLensItem[]>): void {
    const itemsByLineKeys = itemsByLine ? Array.from(itemsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(itemsByLineKeys.length);
    for (const key of itemsByLineKeys) {
      writer.writeInt32(key);
      const value = itemsByLine.get(key)!;
      this.writeCodeLensItemList(writer, value);
    }
  }

  private static sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine: Map<number, CodeLensItem[]>): number {
    let size = 0;
    size += 4;
    const itemsByLineKeys = itemsByLine ? Array.from(itemsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of itemsByLineKeys) {
      size += 4;
      const value = itemsByLine.get(key)!;
      size += this.sizeOfCodeLensItemList(value);
    }
    return size;
  }

  static encodeSetBatchLineCodeLensPayload(itemsByLine: Map<number, CodeLensItem[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine));
    this.writeSetBatchLineCodeLensPayloadWire(writer, itemsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineDiagnosticsPayloadWire(writer: BinaryWriter, diagnosticsByLine: Map<number, Diagnostic[]>): void {
    const diagnosticsByLineKeys = diagnosticsByLine ? Array.from(diagnosticsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(diagnosticsByLineKeys.length);
    for (const key of diagnosticsByLineKeys) {
      writer.writeInt32(key);
      const value = diagnosticsByLine.get(key)!;
      this.writeDiagnosticList(writer, value);
    }
  }

  private static sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine: Map<number, Diagnostic[]>): number {
    let size = 0;
    size += 4;
    const diagnosticsByLineKeys = diagnosticsByLine ? Array.from(diagnosticsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of diagnosticsByLineKeys) {
      size += 4;
      const value = diagnosticsByLine.get(key)!;
      size += this.sizeOfDiagnosticList(value);
    }
    return size;
  }

  static encodeSetBatchLineDiagnosticsPayload(diagnosticsByLine: Map<number, Diagnostic[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine));
    this.writeSetBatchLineDiagnosticsPayloadWire(writer, diagnosticsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineGutterIconsPayloadWire(writer: BinaryWriter, iconsByLine: Map<number, GutterIcon[]>): void {
    const iconsByLineKeys = iconsByLine ? Array.from(iconsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(iconsByLineKeys.length);
    for (const key of iconsByLineKeys) {
      writer.writeInt32(key);
      const value = iconsByLine.get(key)!;
      this.writeGutterIconList(writer, value);
    }
  }

  private static sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine: Map<number, GutterIcon[]>): number {
    let size = 0;
    size += 4;
    const iconsByLineKeys = iconsByLine ? Array.from(iconsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of iconsByLineKeys) {
      size += 4;
      const value = iconsByLine.get(key)!;
      size += this.sizeOfGutterIconList(value);
    }
    return size;
  }

  static encodeSetBatchLineGutterIconsPayload(iconsByLine: Map<number, GutterIcon[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine));
    this.writeSetBatchLineGutterIconsPayloadWire(writer, iconsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineInlayHintsPayloadWire(writer: BinaryWriter, hintsByLine: Map<number, InlayHint[]>): void {
    const hintsByLineKeys = hintsByLine ? Array.from(hintsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(hintsByLineKeys.length);
    for (const key of hintsByLineKeys) {
      writer.writeInt32(key);
      const value = hintsByLine.get(key)!;
      this.writeInlayHintList(writer, value);
    }
  }

  private static sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine: Map<number, InlayHint[]>): number {
    let size = 0;
    size += 4;
    const hintsByLineKeys = hintsByLine ? Array.from(hintsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of hintsByLineKeys) {
      size += 4;
      const value = hintsByLine.get(key)!;
      size += this.sizeOfInlayHintList(value);
    }
    return size;
  }

  static encodeSetBatchLineInlayHintsPayload(hintsByLine: Map<number, InlayHint[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine));
    this.writeSetBatchLineInlayHintsPayloadWire(writer, hintsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineLinksPayloadWire(writer: BinaryWriter, linksByLine: Map<number, LinkSpan[]>): void {
    const linksByLineKeys = linksByLine ? Array.from(linksByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(linksByLineKeys.length);
    for (const key of linksByLineKeys) {
      writer.writeInt32(key);
      const value = linksByLine.get(key)!;
      this.writeLinkSpanList(writer, value);
    }
  }

  private static sizeOfSetBatchLineLinksPayloadWire(linksByLine: Map<number, LinkSpan[]>): number {
    let size = 0;
    size += 4;
    const linksByLineKeys = linksByLine ? Array.from(linksByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of linksByLineKeys) {
      size += 4;
      const value = linksByLine.get(key)!;
      size += this.sizeOfLinkSpanList(value);
    }
    return size;
  }

  static encodeSetBatchLineLinksPayload(linksByLine: Map<number, LinkSpan[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineLinksPayloadWire(linksByLine));
    this.writeSetBatchLineLinksPayloadWire(writer, linksByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLinePhantomTextsPayloadWire(writer: BinaryWriter, phantomsByLine: Map<number, PhantomText[]>): void {
    const phantomsByLineKeys = phantomsByLine ? Array.from(phantomsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(phantomsByLineKeys.length);
    for (const key of phantomsByLineKeys) {
      writer.writeInt32(key);
      const value = phantomsByLine.get(key)!;
      this.writePhantomTextList(writer, value);
    }
  }

  private static sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine: Map<number, PhantomText[]>): number {
    let size = 0;
    size += 4;
    const phantomsByLineKeys = phantomsByLine ? Array.from(phantomsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of phantomsByLineKeys) {
      size += 4;
      const value = phantomsByLine.get(key)!;
      size += this.sizeOfPhantomTextList(value);
    }
    return size;
  }

  static encodeSetBatchLinePhantomTextsPayload(phantomsByLine: Map<number, PhantomText[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine));
    this.writeSetBatchLinePhantomTextsPayloadWire(writer, phantomsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineSpansPayloadWire(writer: BinaryWriter, layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): void {
    writer.writeInt32(layer as number);
    const spansByLineKeys = spansByLine ? Array.from(spansByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(spansByLineKeys.length);
    for (const key of spansByLineKeys) {
      writer.writeInt32(key);
      const value = spansByLine.get(key)!;
      this.writeStyleSpanList(writer, value);
    }
  }

  private static sizeOfSetBatchLineSpansPayloadWire(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): number {
    let size = 0;
    size += 4;
    size += 4;
    const spansByLineKeys = spansByLine ? Array.from(spansByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of spansByLineKeys) {
      size += 4;
      const value = spansByLine.get(key)!;
      size += this.sizeOfStyleSpanList(value);
    }
    return size;
  }

  static encodeSetBatchLineSpansPayload(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBatchLineSpansPayloadWire(layer, spansByLine));
    this.writeSetBatchLineSpansPayloadWire(writer, layer, spansByLine);
    return writer.getBuffer();
  }

  private static writeSetBracketGuidesPayloadWire(writer: BinaryWriter, guides: BracketGuide[]): void {
    this.writeBracketGuideList(writer, guides);
  }

  private static sizeOfSetBracketGuidesPayloadWire(guides: BracketGuide[]): number {
    let size = 0;
    size += this.sizeOfBracketGuideList(guides);
    return size;
  }

  static encodeSetBracketGuidesPayload(guides: BracketGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetBracketGuidesPayloadWire(guides));
    this.writeSetBracketGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetFlowGuidesPayloadWire(writer: BinaryWriter, guides: FlowGuide[]): void {
    this.writeFlowGuideList(writer, guides);
  }

  private static sizeOfSetFlowGuidesPayloadWire(guides: FlowGuide[]): number {
    let size = 0;
    size += this.sizeOfFlowGuideList(guides);
    return size;
  }

  static encodeSetFlowGuidesPayload(guides: FlowGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetFlowGuidesPayloadWire(guides));
    this.writeSetFlowGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetFoldRegionsPayloadWire(writer: BinaryWriter, regions: FoldRegion[]): void {
    this.writeFoldRegionList(writer, regions);
  }

  private static sizeOfSetFoldRegionsPayloadWire(regions: FoldRegion[]): number {
    let size = 0;
    size += this.sizeOfFoldRegionList(regions);
    return size;
  }

  static encodeSetFoldRegionsPayload(regions: FoldRegion[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetFoldRegionsPayloadWire(regions));
    this.writeSetFoldRegionsPayloadWire(writer, regions);
    return writer.getBuffer();
  }

  private static writeSetIndentGuidesPayloadWire(writer: BinaryWriter, guides: IndentGuide[]): void {
    this.writeIndentGuideList(writer, guides);
  }

  private static sizeOfSetIndentGuidesPayloadWire(guides: IndentGuide[]): number {
    let size = 0;
    size += this.sizeOfIndentGuideList(guides);
    return size;
  }

  static encodeSetIndentGuidesPayload(guides: IndentGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetIndentGuidesPayloadWire(guides));
    this.writeSetIndentGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetLineCodeLensPayloadWire(writer: BinaryWriter, line: number, items: CodeLensItem[]): void {
    writer.writeInt32(line);
    this.writeCodeLensItemList(writer, items);
  }

  private static sizeOfSetLineCodeLensPayloadWire(line: number, items: CodeLensItem[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfCodeLensItemList(items);
    return size;
  }

  static encodeSetLineCodeLensPayload(line: number, items: CodeLensItem[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineCodeLensPayloadWire(line, items));
    this.writeSetLineCodeLensPayloadWire(writer, line, items);
    return writer.getBuffer();
  }

  private static writeSetLineDiagnosticsPayloadWire(writer: BinaryWriter, line: number, diagnostics: Diagnostic[]): void {
    writer.writeInt32(line);
    this.writeDiagnosticList(writer, diagnostics);
  }

  private static sizeOfSetLineDiagnosticsPayloadWire(line: number, diagnostics: Diagnostic[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfDiagnosticList(diagnostics);
    return size;
  }

  static encodeSetLineDiagnosticsPayload(line: number, diagnostics: Diagnostic[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineDiagnosticsPayloadWire(line, diagnostics));
    this.writeSetLineDiagnosticsPayloadWire(writer, line, diagnostics);
    return writer.getBuffer();
  }

  private static writeSetLineGutterIconsPayloadWire(writer: BinaryWriter, line: number, icons: GutterIcon[]): void {
    writer.writeInt32(line);
    this.writeGutterIconList(writer, icons);
  }

  private static sizeOfSetLineGutterIconsPayloadWire(line: number, icons: GutterIcon[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfGutterIconList(icons);
    return size;
  }

  static encodeSetLineGutterIconsPayload(line: number, icons: GutterIcon[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineGutterIconsPayloadWire(line, icons));
    this.writeSetLineGutterIconsPayloadWire(writer, line, icons);
    return writer.getBuffer();
  }

  private static writeSetLineInlayHintsPayloadWire(writer: BinaryWriter, line: number, hints: InlayHint[]): void {
    writer.writeInt32(line);
    this.writeInlayHintList(writer, hints);
  }

  private static sizeOfSetLineInlayHintsPayloadWire(line: number, hints: InlayHint[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfInlayHintList(hints);
    return size;
  }

  static encodeSetLineInlayHintsPayload(line: number, hints: InlayHint[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineInlayHintsPayloadWire(line, hints));
    this.writeSetLineInlayHintsPayloadWire(writer, line, hints);
    return writer.getBuffer();
  }

  private static writeSetLineLinksPayloadWire(writer: BinaryWriter, line: number, links: LinkSpan[]): void {
    writer.writeInt32(line);
    this.writeLinkSpanList(writer, links);
  }

  private static sizeOfSetLineLinksPayloadWire(line: number, links: LinkSpan[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfLinkSpanList(links);
    return size;
  }

  static encodeSetLineLinksPayload(line: number, links: LinkSpan[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineLinksPayloadWire(line, links));
    this.writeSetLineLinksPayloadWire(writer, line, links);
    return writer.getBuffer();
  }

  private static writeSetLinePhantomTextsPayloadWire(writer: BinaryWriter, line: number, phantoms: PhantomText[]): void {
    writer.writeInt32(line);
    this.writePhantomTextList(writer, phantoms);
  }

  private static sizeOfSetLinePhantomTextsPayloadWire(line: number, phantoms: PhantomText[]): number {
    let size = 0;
    size += 4;
    size += this.sizeOfPhantomTextList(phantoms);
    return size;
  }

  static encodeSetLinePhantomTextsPayload(line: number, phantoms: PhantomText[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLinePhantomTextsPayloadWire(line, phantoms));
    this.writeSetLinePhantomTextsPayloadWire(writer, line, phantoms);
    return writer.getBuffer();
  }

  private static writeSetLineSpansPayloadWire(writer: BinaryWriter, line: number, layer: SpanLayer, spans: StyleSpan[]): void {
    writer.writeInt32(line);
    writer.writeInt32(layer as number);
    this.writeStyleSpanList(writer, spans);
  }

  private static sizeOfSetLineSpansPayloadWire(line: number, layer: SpanLayer, spans: StyleSpan[]): number {
    let size = 0;
    size += 4;
    size += 4;
    size += this.sizeOfStyleSpanList(spans);
    return size;
  }

  static encodeSetLineSpansPayload(line: number, layer: SpanLayer, spans: StyleSpan[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetLineSpansPayloadWire(line, layer, spans));
    this.writeSetLineSpansPayloadWire(writer, line, layer, spans);
    return writer.getBuffer();
  }

  private static writeSetSeparatorGuidesPayloadWire(writer: BinaryWriter, guides: SeparatorGuide[]): void {
    this.writeSeparatorGuideList(writer, guides);
  }

  private static sizeOfSetSeparatorGuidesPayloadWire(guides: SeparatorGuide[]): number {
    let size = 0;
    size += this.sizeOfSeparatorGuideList(guides);
    return size;
  }

  static encodeSetSeparatorGuidesPayload(guides: SeparatorGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetSeparatorGuidesPayloadWire(guides));
    this.writeSetSeparatorGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  static encodeEditorOptions(value: EditorOptions): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfEditorOptions(value));
    this.writeEditorOptions(writer, value);
    return writer.getBuffer();
  }

  static encodeHandleConfig(value: HandleConfig): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfHandleConfig(value));
    this.writeHandleConfig(writer, value);
    return writer.getBuffer();
  }

  static encodeScrollbarConfig(value: ScrollbarConfig): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfScrollbarConfig(value));
    this.writeScrollbarConfig(writer, value);
    return writer.getBuffer();
  }

  private static writeSetKeyMapPayloadWire(writer: BinaryWriter, bindings: KeyBinding[]): void {
    this.writeKeyBindingList(writer, bindings);
  }

  private static sizeOfSetKeyMapPayloadWire(bindings: KeyBinding[]): number {
    let size = 0;
    size += this.sizeOfKeyBindingList(bindings);
    return size;
  }

  static encodeSetKeyMapPayload(bindings: KeyBinding[]): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfSetKeyMapPayloadWire(bindings));
    this.writeSetKeyMapPayloadWire(writer, bindings);
    return writer.getBuffer();
  }

  static encodeLinkedEditingModel(value: LinkedEditingModel): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfLinkedEditingModel(value));
    this.writeLinkedEditingModel(writer, value);
    return writer.getBuffer();
  }

  private static writeStartLinkedEditingPayloadWire(writer: BinaryWriter, model: LinkedEditingModel): void {
    this.writeLinkedEditingModel(writer, model);
  }

  private static sizeOfStartLinkedEditingPayloadWire(model: LinkedEditingModel): number {
    let size = 0;
    size += this.sizeOfLinkedEditingModel(model);
    return size;
  }

  static encodeStartLinkedEditingPayload(model: LinkedEditingModel): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfStartLinkedEditingPayloadWire(model));
    this.writeStartLinkedEditingPayloadWire(writer, model);
    return writer.getBuffer();
  }

  static encodeTabStopGroup(value: TabStopGroup): ArrayBuffer {
    const writer = new BinaryWriter(this.sizeOfTabStopGroup(value));
    this.writeTabStopGroup(writer, value);
    return writer.getBuffer();
  }
}
