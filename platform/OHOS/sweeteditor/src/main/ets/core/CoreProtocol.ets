import util from '@ohos.util';
import { AnimationFlag, EditorActionResult, EditorActionSource, ScrollBehavior, TextChangeKind, editorActionSourceFromValue, scrollBehaviorFromValue, textChangeKindFromValue } from './CoreAction';
import { BracketGuide, CodeLensItem, Diagnostic, DiagnosticSeverity, DocumentHighlight, DocumentHighlightKind, FlowGuide, FoldRegion, GutterIcon, IndentGuide, InlayHint, InlayType, LinkSpan, PhantomText, SeparatorGuide, SeparatorStyle, SpanLayer, StyleSpan, TextStyle, diagnosticSeverityFromValue, documentHighlightKindFromValue, inlayTypeFromValue, separatorStyleFromValue, spanLayerFromValue } from './CoreAdornments';
import { AutoIndentMode, CurrentLineRenderMode, EditorOptions, EditorRangeEffectStyles, EditorRenderColors, FoldArrowMode, HandleConfig, HandleHitArea, RangeEffectStyle, RangeEffectUnderlineStyle, ScrollbarConfig, ScrollbarMode, ScrollbarTrackTapMode, WhitespaceRenderMode, WrapMode, autoIndentModeFromValue, currentLineRenderModeFromValue, foldArrowModeFromValue, rangeEffectUnderlineStyleFromValue, scrollbarModeFromValue, scrollbarTrackTapModeFromValue, whitespaceRenderModeFromValue, wrapModeFromValue } from './CoreConfig';
import { IntRange, PointF, Rect, Size, TextChange, TextEdit, TextPosition, TextRange } from './CoreFoundation';
import { ImeCommandKind, ImeCommandMessage, ImeContextPolicy, ImeInputContext, ImeInputContextKind, ImeMarkedRange, ImeMarkedRangeRole, ImeOffsetRange, ImeScriptClass, ImeSyncSnapshot, ImeTextPatch, ImeTextUnit, ImeTextUpdateKind, ImeTextUpdateMessage, ImeTextUpdateScope, imeCommandKindFromValue, imeContextPolicyFromValue, imeInputContextKindFromValue, imeMarkedRangeRoleFromValue, imeScriptClassFromValue, imeTextUnitFromValue, imeTextUpdateKindFromValue, imeTextUpdateScopeFromValue } from './CoreIme';
import { EventType, GestureEvent, GestureType, HitTarget, HitTargetType, eventTypeFromValue, gestureTypeFromValue, hitTargetTypeFromValue } from './CoreInteraction';
import { EditorBuiltinCommand, KeyBinding, KeyChord, KeyCode, KeyModifier, editorBuiltinCommandFromValue } from './CoreKeymap';
import { LinkedEditingModel, TabStopGroup } from './CoreLinkedEditing';
import { SearchOptions, SearchRequest, SearchState, SearchStatus, searchStatusFromValue } from './CoreSearch';
import { Cursor, CursorRect, EditorRenderModel, FoldMarkerRenderItem, FoldState, GuideDirection, GuideSegment, GuideStyle, GuideType, GutterIconRenderItem, LayoutMetrics, PointerCursorType, RangeEffectKind, RangeEffectRenderItem, ScrollMetrics, ScrollbarModel, SelectionHandle, VisualLine, VisualLineKind, VisualRun, VisualRunType, foldStateFromValue, guideDirectionFromValue, guideStyleFromValue, guideTypeFromValue, pointerCursorTypeFromValue, rangeEffectKindFromValue, visualLineKindFromValue, visualRunTypeFromValue } from './CoreVisual';

const UTF8_DECODER = new util.TextDecoder('utf-8');
const UTF8_ENCODER = new util.TextEncoder();

function encodeUtf8(value: string): Uint8Array {
  const text = value ? value : '';
  if (text.length === 0) {
    return new Uint8Array(0);
  }
  return UTF8_ENCODER.encodeInto(text);
}

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
    const bytes = encodeUtf8(value);
    this.writeInt32(bytes.length);
    new Uint8Array(this.buffer, this.offset, bytes.length).set(bytes);
    this.offset += bytes.length;
  }

  getBuffer(): ArrayBuffer {
    return this.buffer;
  }
}

export class CoreProtocol {
  private static readerFor(buffer: ArrayBuffer | undefined): BinaryReader {
    if (!buffer) {
      throw new Error('Missing protocol payload.');
    }
    return new BinaryReader(buffer);
  }

  private static sizeOfUtf8String(value: string): number {
    return 4 + encodeUtf8(value).length;
  }

  static encodeUtf8String(value: string): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfUtf8String(value));
    writer.writeUtf8String(value);
    return writer.getBuffer();
  }

  private static writeBracketGuideList(writer: BinaryWriter, values: BracketGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeBracketGuide(writer, values[i]);
    }
  }

  private static sizeOfBracketGuideList(values: BracketGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfBracketGuide(value);
      }
    }
    return size;
  }

  private static writeCodeLensItemList(writer: BinaryWriter, values: CodeLensItem[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeCodeLensItem(writer, values[i]);
    }
  }

  private static sizeOfCodeLensItemList(values: CodeLensItem[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfCodeLensItem(value);
      }
    }
    return size;
  }

  private static writeDiagnosticList(writer: BinaryWriter, values: Diagnostic[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeDiagnostic(writer, values[i]);
    }
  }

  private static sizeOfDiagnosticList(values: Diagnostic[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfDiagnostic(value);
      }
    }
    return size;
  }

  private static writeDocumentHighlightList(writer: BinaryWriter, values: DocumentHighlight[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeDocumentHighlight(writer, values[i]);
    }
  }

  private static sizeOfDocumentHighlightList(values: DocumentHighlight[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfDocumentHighlight(value);
      }
    }
    return size;
  }

  private static writeFlowGuideList(writer: BinaryWriter, values: FlowGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeFlowGuide(writer, values[i]);
    }
  }

  private static sizeOfFlowGuideList(values: FlowGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfFlowGuide(value);
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
      values.push(CoreProtocol.readFoldMarkerRenderItem(reader));
    }
    return values;
  }

  private static writeFoldRegionList(writer: BinaryWriter, values: FoldRegion[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeFoldRegion(writer, values[i]);
    }
  }

  private static sizeOfFoldRegionList(values: FoldRegion[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfFoldRegion(value);
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
      values.push(CoreProtocol.readGuideSegment(reader));
    }
    return values;
  }

  private static writeGutterIconList(writer: BinaryWriter, values: GutterIcon[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeGutterIcon(writer, values[i]);
    }
  }

  private static sizeOfGutterIconList(values: GutterIcon[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfGutterIcon(value);
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
      values.push(CoreProtocol.readGutterIconRenderItem(reader));
    }
    return values;
  }

  private static writeIndentGuideList(writer: BinaryWriter, values: IndentGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeIndentGuide(writer, values[i]);
    }
  }

  private static sizeOfIndentGuideList(values: IndentGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfIndentGuide(value);
      }
    }
    return size;
  }

  private static writeInlayHintList(writer: BinaryWriter, values: InlayHint[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeInlayHint(writer, values[i]);
    }
  }

  private static sizeOfInlayHintList(values: InlayHint[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfInlayHint(value);
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
      values.push(CoreProtocol.readKeyBinding(reader));
    }
    return values;
  }

  private static writeKeyBindingList(writer: BinaryWriter, values: KeyBinding[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeKeyBinding(writer, values[i]);
    }
  }

  private static sizeOfKeyBindingList(values: KeyBinding[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfKeyBinding(value);
      }
    }
    return size;
  }

  private static writeLinkSpanList(writer: BinaryWriter, values: LinkSpan[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeLinkSpan(writer, values[i]);
    }
  }

  private static sizeOfLinkSpanList(values: LinkSpan[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfLinkSpan(value);
      }
    }
    return size;
  }

  private static writePhantomTextList(writer: BinaryWriter, values: PhantomText[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writePhantomText(writer, values[i]);
    }
  }

  private static sizeOfPhantomTextList(values: PhantomText[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfPhantomText(value);
      }
    }
    return size;
  }

  private static readPointFList(reader: BinaryReader): PointF[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: PointF[] = [];
    for (let i = 0; i < count; i++) {
      values.push(CoreProtocol.readPointF(reader));
    }
    return values;
  }

  private static writePointFList(writer: BinaryWriter, values: PointF[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writePointF(writer, values[i]);
    }
  }

  private static sizeOfPointFList(values: PointF[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfPointF(value);
      }
    }
    return size;
  }

  private static readRangeEffectRenderItemList(reader: BinaryReader): RangeEffectRenderItem[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: RangeEffectRenderItem[] = [];
    for (let i = 0; i < count; i++) {
      values.push(CoreProtocol.readRangeEffectRenderItem(reader));
    }
    return values;
  }

  private static writeSeparatorGuideList(writer: BinaryWriter, values: SeparatorGuide[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeSeparatorGuide(writer, values[i]);
    }
  }

  private static sizeOfSeparatorGuideList(values: SeparatorGuide[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfSeparatorGuide(value);
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
      values.push(CoreProtocol.readStyleSpan(reader));
    }
    return values;
  }

  private static writeStyleSpanList(writer: BinaryWriter, values: StyleSpan[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeStyleSpan(writer, values[i]);
    }
  }

  private static sizeOfStyleSpanList(values: StyleSpan[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfStyleSpan(value);
      }
    }
    return size;
  }

  private static writeTabStopGroupList(writer: BinaryWriter, values: TabStopGroup[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeTabStopGroup(writer, values[i]);
    }
  }

  private static sizeOfTabStopGroupList(values: TabStopGroup[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfTabStopGroup(value);
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
      values.push(CoreProtocol.readTextChange(reader));
    }
    return values;
  }

  private static readTextEditList(reader: BinaryReader): TextEdit[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: TextEdit[] = [];
    for (let i = 0; i < count; i++) {
      values.push(CoreProtocol.readTextEdit(reader));
    }
    return values;
  }

  private static writeTextEditList(writer: BinaryWriter, values: TextEdit[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeTextEdit(writer, values[i]);
    }
  }

  private static sizeOfTextEditList(values: TextEdit[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfTextEdit(value);
      }
    }
    return size;
  }

  private static readTextPositionList(reader: BinaryReader): TextPosition[] {
    const count = reader.readInt32();
    if (count < 0 || count > reader.remaining) {
      throw new Error('Invalid protocol length.');
    }
    const values: TextPosition[] = [];
    for (let i = 0; i < count; i++) {
      values.push(CoreProtocol.readTextPosition(reader));
    }
    return values;
  }

  private static writeTextPositionList(writer: BinaryWriter, values: TextPosition[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeTextPosition(writer, values[i]);
    }
  }

  private static sizeOfTextPositionList(values: TextPosition[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfTextPosition(value);
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
      values.push(CoreProtocol.readTextRange(reader));
    }
    return values;
  }

  private static writeTextRangeList(writer: BinaryWriter, values: TextRange[]): void {
    const count = values ? values.length : 0;
    writer.writeInt32(count);
    for (let i = 0; i < count; i++) {
      CoreProtocol.writeTextRange(writer, values[i]);
    }
  }

  private static sizeOfTextRangeList(values: TextRange[]): number {
    let size = 4;
    if (values) {
      for (const value of values) {
        size += CoreProtocol.sizeOfTextRange(value);
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
      values.push(CoreProtocol.readVisualLine(reader));
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
      values.push(CoreProtocol.readVisualRun(reader));
    }
    return values;
  }

  private static readEditorActionResult(reader: BinaryReader): EditorActionResult {
    return {
      handled: reader.readInt32() !== 0,
      needsRedraw: reader.readInt32() !== 0,
      source: editorActionSourceFromValue(reader.readInt32()),
      textChangeKind: textChangeKindFromValue(reader.readInt32()),
      contentChanged: reader.readInt32() !== 0,
      cursorChanged: reader.readInt32() !== 0,
      selectionChanged: reader.readInt32() !== 0,
      scrollChanged: reader.readInt32() !== 0,
      scaleChanged: reader.readInt32() !== 0,
      pointerCursorChanged: reader.readInt32() !== 0,
      compositionChanged: reader.readInt32() !== 0,
      decorationChanged: reader.readInt32() !== 0,
      needsImeSync: reader.readInt32() !== 0,
      animationFlags: reader.readInt32(),
      nextAnimationDelayMs: reader.readInt32(),
      isHandleDrag: reader.readInt32() !== 0,
      changes: CoreProtocol.readTextChangeList(reader),
      cursorBefore: CoreProtocol.readTextPosition(reader),
      cursorAfter: CoreProtocol.readTextPosition(reader),
      hasSelectionBefore: reader.readInt32() !== 0,
      hasSelectionAfter: reader.readInt32() !== 0,
      selectionBefore: CoreProtocol.readTextRange(reader),
      selectionAfter: CoreProtocol.readTextRange(reader),
      scrollXBefore: reader.readFloat32(),
      scrollYBefore: reader.readFloat32(),
      scrollXAfter: reader.readFloat32(),
      scrollYAfter: reader.readFloat32(),
      scaleBefore: reader.readFloat32(),
      scaleAfter: reader.readFloat32(),
      pointerCursorBefore: pointerCursorTypeFromValue(reader.readInt32()),
      pointerCursorAfter: pointerCursorTypeFromValue(reader.readInt32()),
      imeSync: CoreProtocol.readImeSyncSnapshot(reader),
      gestureType: gestureTypeFromValue(reader.readInt32()),
      gestureEventType: eventTypeFromValue(reader.readInt32()),
      tapPoint: CoreProtocol.readPointF(reader),
      hitTarget: CoreProtocol.readHitTarget(reader),
      modifiers: reader.readInt32(),
      command: reader.readInt32()
    };
  }

  static decodeEditorActionResult(buffer: ArrayBuffer | undefined): EditorActionResult {
    return CoreProtocol.readEditorActionResult(CoreProtocol.readerFor(buffer));
  }

  static writeBracketGuide(writer: BinaryWriter, value: BracketGuide): void {
    CoreProtocol.writeTextPosition(writer, value.parent);
    CoreProtocol.writeTextPosition(writer, value.end);
    CoreProtocol.writeTextPositionList(writer, value.children);
  }

  static sizeOfBracketGuide(value: BracketGuide): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextPosition(value.parent);
    size += CoreProtocol.sizeOfTextPosition(value.end);
    size += CoreProtocol.sizeOfTextPositionList(value.children);
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
    size += CoreProtocol.sizeOfUtf8String(value.text);
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

  static writeDocumentHighlight(writer: BinaryWriter, value: DocumentHighlight): void {
    writer.writeInt32(value.column);
    writer.writeInt32(value.length);
    writer.writeInt32(value.kind as number);
  }

  static sizeOfDocumentHighlight(value: DocumentHighlight): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  static writeFlowGuide(writer: BinaryWriter, value: FlowGuide): void {
    CoreProtocol.writeTextPosition(writer, value.start);
    CoreProtocol.writeTextPosition(writer, value.end);
  }

  static sizeOfFlowGuide(value: FlowGuide): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextPosition(value.start);
    size += CoreProtocol.sizeOfTextPosition(value.end);
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
    CoreProtocol.writeTextPosition(writer, value.start);
    CoreProtocol.writeTextPosition(writer, value.end);
  }

  static sizeOfIndentGuide(value: IndentGuide): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextPosition(value.start);
    size += CoreProtocol.sizeOfTextPosition(value.end);
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
    size += CoreProtocol.sizeOfUtf8String(value.text);
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
    size += CoreProtocol.sizeOfUtf8String(value.target);
    return size;
  }

  static writePhantomText(writer: BinaryWriter, value: PhantomText): void {
    writer.writeInt32(value.column);
    writer.writeUtf8String(value.text);
  }

  static sizeOfPhantomText(value: PhantomText): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfUtf8String(value.text);
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

  static decodeStyleSpan(buffer: ArrayBuffer | undefined): StyleSpan {
    return CoreProtocol.readStyleSpan(CoreProtocol.readerFor(buffer));
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

  static decodeTextStyle(buffer: ArrayBuffer | undefined): TextStyle {
    return CoreProtocol.readTextStyle(CoreProtocol.readerFor(buffer));
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

  static writeEditorRangeEffectStyles(writer: BinaryWriter, value: EditorRangeEffectStyles): void {
    CoreProtocol.writeRangeEffectStyle(writer, value.selection);
    CoreProtocol.writeRangeEffectStyle(writer, value.searchMatch);
    CoreProtocol.writeRangeEffectStyle(writer, value.searchCurrent);
    CoreProtocol.writeRangeEffectStyle(writer, value.documentHighlightText);
    CoreProtocol.writeRangeEffectStyle(writer, value.documentHighlightRead);
    CoreProtocol.writeRangeEffectStyle(writer, value.documentHighlightWrite);
    CoreProtocol.writeRangeEffectStyle(writer, value.linkedEditingActive);
    CoreProtocol.writeRangeEffectStyle(writer, value.linkedEditingInactive);
    CoreProtocol.writeRangeEffectStyle(writer, value.imeComposition);
    CoreProtocol.writeRangeEffectStyle(writer, value.bracketMatch);
    CoreProtocol.writeRangeEffectStyle(writer, value.diagnosticError);
    CoreProtocol.writeRangeEffectStyle(writer, value.diagnosticWarning);
    CoreProtocol.writeRangeEffectStyle(writer, value.diagnosticInfo);
    CoreProtocol.writeRangeEffectStyle(writer, value.diagnosticHint);
  }

  static sizeOfEditorRangeEffectStyles(value: EditorRangeEffectStyles): number {
    let size = 0;
    size += CoreProtocol.sizeOfRangeEffectStyle(value.selection);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.searchMatch);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.searchCurrent);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.documentHighlightText);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.documentHighlightRead);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.documentHighlightWrite);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.linkedEditingActive);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.linkedEditingInactive);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.imeComposition);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.bracketMatch);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.diagnosticError);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.diagnosticWarning);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.diagnosticInfo);
    size += CoreProtocol.sizeOfRangeEffectStyle(value.diagnosticHint);
    return size;
  }

  static writeEditorRenderColors(writer: BinaryWriter, value: EditorRenderColors): void {
    writer.writeInt32(value.textForeground);
    writer.writeInt32(value.linkForeground);
    writer.writeInt32(value.activeLinkForeground);
    writer.writeInt32(value.codelensForeground);
    writer.writeInt32(value.activeCodelensForeground);
  }

  static sizeOfEditorRenderColors(value: EditorRenderColors): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  static writeHandleConfig(writer: BinaryWriter, value: HandleConfig): void {
    CoreProtocol.writeHandleHitArea(writer, value.startHitArea);
    CoreProtocol.writeHandleHitArea(writer, value.endHitArea);
  }

  static sizeOfHandleConfig(value: HandleConfig): number {
    let size = 0;
    size += CoreProtocol.sizeOfHandleHitArea(value.startHitArea);
    size += CoreProtocol.sizeOfHandleHitArea(value.endHitArea);
    return size;
  }

  private static readHandleHitArea(reader: BinaryReader): HandleHitArea {
    return {
      left: reader.readFloat32(),
      top: reader.readFloat32(),
      right: reader.readFloat32(),
      bottom: reader.readFloat32()
    };
  }

  static decodeHandleHitArea(buffer: ArrayBuffer | undefined): HandleHitArea {
    return CoreProtocol.readHandleHitArea(CoreProtocol.readerFor(buffer));
  }

  static writeHandleHitArea(writer: BinaryWriter, value: HandleHitArea): void {
    writer.writeFloat32(value.left);
    writer.writeFloat32(value.top);
    writer.writeFloat32(value.right);
    writer.writeFloat32(value.bottom);
  }

  static sizeOfHandleHitArea(value: HandleHitArea): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readRangeEffectStyle(reader: BinaryReader): RangeEffectStyle {
    return {
      foregroundColor: reader.readInt32(),
      backgroundColor: reader.readInt32(),
      borderColor: reader.readInt32(),
      underlineColor: reader.readInt32(),
      underlineStyle: rangeEffectUnderlineStyleFromValue(reader.readInt32())
    };
  }

  static decodeRangeEffectStyle(buffer: ArrayBuffer | undefined): RangeEffectStyle {
    return CoreProtocol.readRangeEffectStyle(CoreProtocol.readerFor(buffer));
  }

  static writeRangeEffectStyle(writer: BinaryWriter, value: RangeEffectStyle): void {
    writer.writeInt32(value.foregroundColor);
    writer.writeInt32(value.backgroundColor);
    writer.writeInt32(value.borderColor);
    writer.writeInt32(value.underlineColor);
    writer.writeInt32(value.underlineStyle as number);
  }

  static sizeOfRangeEffectStyle(value: RangeEffectStyle): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
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

  static decodeIntRange(buffer: ArrayBuffer | undefined): IntRange {
    return CoreProtocol.readIntRange(CoreProtocol.readerFor(buffer));
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

  private static readPointF(reader: BinaryReader): PointF {
    return {
      x: reader.readFloat32(),
      y: reader.readFloat32()
    };
  }

  static decodePointF(buffer: ArrayBuffer | undefined): PointF {
    return CoreProtocol.readPointF(CoreProtocol.readerFor(buffer));
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
      origin: CoreProtocol.readPointF(reader),
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  static decodeRect(buffer: ArrayBuffer | undefined): Rect {
    return CoreProtocol.readRect(CoreProtocol.readerFor(buffer));
  }

  static writeRect(writer: BinaryWriter, value: Rect): void {
    CoreProtocol.writePointF(writer, value.origin);
    writer.writeFloat32(value.width);
    writer.writeFloat32(value.height);
  }

  static sizeOfRect(value: Rect): number {
    let size = 0;
    size += CoreProtocol.sizeOfPointF(value.origin);
    size += 4;
    size += 4;
    return size;
  }

  private static readSize(reader: BinaryReader): Size {
    return {
      width: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  static decodeSize(buffer: ArrayBuffer | undefined): Size {
    return CoreProtocol.readSize(CoreProtocol.readerFor(buffer));
  }

  static writeSize(writer: BinaryWriter, value: Size): void {
    writer.writeFloat32(value.width);
    writer.writeFloat32(value.height);
  }

  static sizeOfSize(value: Size): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readTextChange(reader: BinaryReader): TextChange {
    return {
      range: CoreProtocol.readTextRange(reader),
      newText: reader.readUtf8String()
    };
  }

  static decodeTextChange(buffer: ArrayBuffer | undefined): TextChange {
    return CoreProtocol.readTextChange(CoreProtocol.readerFor(buffer));
  }

  private static readTextEdit(reader: BinaryReader): TextEdit {
    return {
      range: CoreProtocol.readTextRange(reader),
      newText: reader.readUtf8String()
    };
  }

  static decodeTextEdit(buffer: ArrayBuffer | undefined): TextEdit {
    return CoreProtocol.readTextEdit(CoreProtocol.readerFor(buffer));
  }

  static writeTextEdit(writer: BinaryWriter, value: TextEdit): void {
    CoreProtocol.writeTextRange(writer, value.range);
    writer.writeUtf8String(value.newText);
  }

  static sizeOfTextEdit(value: TextEdit): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextRange(value.range);
    size += CoreProtocol.sizeOfUtf8String(value.newText);
    return size;
  }

  private static readTextPosition(reader: BinaryReader): TextPosition {
    return {
      line: reader.readInt32(),
      column: reader.readInt32()
    };
  }

  static decodeTextPosition(buffer: ArrayBuffer | undefined): TextPosition {
    return CoreProtocol.readTextPosition(CoreProtocol.readerFor(buffer));
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
      start: CoreProtocol.readTextPosition(reader),
      end: CoreProtocol.readTextPosition(reader)
    };
  }

  static decodeTextRange(buffer: ArrayBuffer | undefined): TextRange {
    return CoreProtocol.readTextRange(CoreProtocol.readerFor(buffer));
  }

  static writeTextRange(writer: BinaryWriter, value: TextRange): void {
    CoreProtocol.writeTextPosition(writer, value.start);
    CoreProtocol.writeTextPosition(writer, value.end);
  }

  static sizeOfTextRange(value: TextRange): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextPosition(value.start);
    size += CoreProtocol.sizeOfTextPosition(value.end);
    return size;
  }

  static writeImeCommandMessage(writer: BinaryWriter, value: ImeCommandMessage): void {
    writer.writeInt32(value.kind as number);
    writer.writeInt64(value.contextId);
    writer.writeInt32(value.contextRevision);
    writer.writeInt32(value.documentStartOffset);
    CoreProtocol.writeImeOffsetRange(writer, value.range);
    CoreProtocol.writeImeOffsetRange(writer, value.selection);
    writer.writeUtf8String(value.text);
    writer.writeInt32(value.cursorOffset);
    writer.writeInt32(value.deleteBefore);
    writer.writeInt32(value.deleteAfter);
    writer.writeInt32(value.textUnit as number);
    writer.writeInt32(value.markedRole as number);
    writer.writeInt32(value.scriptClass as number);
  }

  static sizeOfImeCommandMessage(value: ImeCommandMessage): number {
    let size = 0;
    size += 4;
    size += 8;
    size += 4;
    size += 4;
    size += CoreProtocol.sizeOfImeOffsetRange(value.range);
    size += CoreProtocol.sizeOfImeOffsetRange(value.selection);
    size += CoreProtocol.sizeOfUtf8String(value.text);
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  private static readImeInputContext(reader: BinaryReader): ImeInputContext {
    return {
      id: reader.readInt64(),
      revision: reader.readInt32(),
      documentStartOffset: reader.readInt32(),
      text: reader.readUtf8String(),
      selection: CoreProtocol.readImeOffsetRange(reader),
      hasPreeditRange: reader.readInt32() !== 0,
      preeditRange: CoreProtocol.readImeOffsetRange(reader),
      hasSystemMarkRange: reader.readInt32() !== 0,
      systemMarkRange: CoreProtocol.readImeOffsetRange(reader),
      kind: imeInputContextKindFromValue(reader.readInt32())
    };
  }

  static decodeImeInputContext(buffer: ArrayBuffer | undefined): ImeInputContext {
    return CoreProtocol.readImeInputContext(CoreProtocol.readerFor(buffer));
  }

  private static readImeMarkedRange(reader: BinaryReader): ImeMarkedRange {
    return {
      role: imeMarkedRangeRoleFromValue(reader.readInt32()),
      range: CoreProtocol.readImeOffsetRange(reader)
    };
  }

  static decodeImeMarkedRange(buffer: ArrayBuffer | undefined): ImeMarkedRange {
    return CoreProtocol.readImeMarkedRange(CoreProtocol.readerFor(buffer));
  }

  static writeImeMarkedRange(writer: BinaryWriter, value: ImeMarkedRange): void {
    writer.writeInt32(value.role as number);
    CoreProtocol.writeImeOffsetRange(writer, value.range);
  }

  static sizeOfImeMarkedRange(value: ImeMarkedRange): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfImeOffsetRange(value.range);
    return size;
  }

  private static readImeOffsetRange(reader: BinaryReader): ImeOffsetRange {
    return {
      start: reader.readInt32(),
      end: reader.readInt32()
    };
  }

  static decodeImeOffsetRange(buffer: ArrayBuffer | undefined): ImeOffsetRange {
    return CoreProtocol.readImeOffsetRange(CoreProtocol.readerFor(buffer));
  }

  static writeImeOffsetRange(writer: BinaryWriter, value: ImeOffsetRange): void {
    writer.writeInt32(value.start);
    writer.writeInt32(value.end);
  }

  static sizeOfImeOffsetRange(value: ImeOffsetRange): number {
    let size = 0;
    size += 4;
    size += 4;
    return size;
  }

  private static readImeSyncSnapshot(reader: BinaryReader): ImeSyncSnapshot {
    return {
      cursor: CoreProtocol.readTextPosition(reader),
      selection: CoreProtocol.readTextRange(reader),
      hasSelection: reader.readInt32() !== 0,
      hasPreeditRange: reader.readInt32() !== 0,
      preeditRange: CoreProtocol.readTextRange(reader),
      hasSystemMarkRange: reader.readInt32() !== 0,
      systemMarkRange: CoreProtocol.readTextRange(reader),
      contextPolicy: imeContextPolicyFromValue(reader.readInt32()),
      clearSystemMark: reader.readInt32() !== 0
    };
  }

  static decodeImeSyncSnapshot(buffer: ArrayBuffer | undefined): ImeSyncSnapshot {
    return CoreProtocol.readImeSyncSnapshot(CoreProtocol.readerFor(buffer));
  }

  private static readImeTextPatch(reader: BinaryReader): ImeTextPatch {
    return {
      range: CoreProtocol.readImeOffsetRange(reader),
      text: reader.readUtf8String()
    };
  }

  static decodeImeTextPatch(buffer: ArrayBuffer | undefined): ImeTextPatch {
    return CoreProtocol.readImeTextPatch(CoreProtocol.readerFor(buffer));
  }

  static writeImeTextPatch(writer: BinaryWriter, value: ImeTextPatch): void {
    CoreProtocol.writeImeOffsetRange(writer, value.range);
    writer.writeUtf8String(value.text);
  }

  static sizeOfImeTextPatch(value: ImeTextPatch): number {
    let size = 0;
    size += CoreProtocol.sizeOfImeOffsetRange(value.range);
    size += CoreProtocol.sizeOfUtf8String(value.text);
    return size;
  }

  static writeImeTextUpdateMessage(writer: BinaryWriter, value: ImeTextUpdateMessage): void {
    writer.writeInt32(value.kind as number);
    writer.writeInt32(value.scope as number);
    writer.writeInt64(value.contextId);
    writer.writeInt32(value.contextRevision);
    writer.writeInt32(value.documentStartOffset);
    writer.writeUtf8String(value.text);
    CoreProtocol.writeImeTextPatch(writer, value.patch);
    CoreProtocol.writeImeOffsetRange(writer, value.selection);
    CoreProtocol.writeImeMarkedRange(writer, value.markedRange);
    writer.writeInt32(value.scriptClass as number);
  }

  static sizeOfImeTextUpdateMessage(value: ImeTextUpdateMessage): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 8;
    size += 4;
    size += 4;
    size += CoreProtocol.sizeOfUtf8String(value.text);
    size += CoreProtocol.sizeOfImeTextPatch(value.patch);
    size += CoreProtocol.sizeOfImeOffsetRange(value.selection);
    size += CoreProtocol.sizeOfImeMarkedRange(value.markedRange);
    size += 4;
    return size;
  }

  static writeGestureEvent(writer: BinaryWriter, value: GestureEvent): void {
    writer.writeInt32(value.type as number);
    CoreProtocol.writePointFList(writer, value.points);
    writer.writeInt32(value.modifiers);
    writer.writeFloat32(value.wheelDeltaX);
    writer.writeFloat32(value.wheelDeltaY);
    writer.writeFloat32(value.directScale);
  }

  static sizeOfGestureEvent(value: GestureEvent): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfPointFList(value.points);
    size += 4;
    size += 4;
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

  static decodeHitTarget(buffer: ArrayBuffer | undefined): HitTarget {
    return CoreProtocol.readHitTarget(CoreProtocol.readerFor(buffer));
  }

  private static readKeyBinding(reader: BinaryReader): KeyBinding {
    return {
      first: CoreProtocol.readKeyChord(reader),
      second: CoreProtocol.readKeyChord(reader),
      command: reader.readInt32()
    };
  }

  static decodeKeyBinding(buffer: ArrayBuffer | undefined): KeyBinding {
    return CoreProtocol.readKeyBinding(CoreProtocol.readerFor(buffer));
  }

  static writeKeyBinding(writer: BinaryWriter, value: KeyBinding): void {
    CoreProtocol.writeKeyChord(writer, value.first);
    CoreProtocol.writeKeyChord(writer, value.second);
    writer.writeInt32(value.command);
  }

  static sizeOfKeyBinding(value: KeyBinding): number {
    let size = 0;
    size += CoreProtocol.sizeOfKeyChord(value.first);
    size += CoreProtocol.sizeOfKeyChord(value.second);
    size += 4;
    return size;
  }

  private static readKeyChord(reader: BinaryReader): KeyChord {
    return {
      modifiers: reader.readUint8(),
      keyCode: reader.readUint16()
    };
  }

  static decodeKeyChord(buffer: ArrayBuffer | undefined): KeyChord {
    return CoreProtocol.readKeyChord(CoreProtocol.readerFor(buffer));
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
    CoreProtocol.writeTabStopGroupList(writer, value.groups);
  }

  static sizeOfLinkedEditingModel(value: LinkedEditingModel): number {
    let size = 0;
    size += CoreProtocol.sizeOfTabStopGroupList(value.groups);
    return size;
  }

  static writeTabStopGroup(writer: BinaryWriter, value: TabStopGroup): void {
    writer.writeInt32(value.index);
    CoreProtocol.writeTextRangeList(writer, value.ranges);
    writer.writeUtf8String(value.defaultText);
  }

  static sizeOfTabStopGroup(value: TabStopGroup): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfTextRangeList(value.ranges);
    size += CoreProtocol.sizeOfUtf8String(value.defaultText);
    return size;
  }

  private static readSearchOptions(reader: BinaryReader): SearchOptions {
    return {
      caseSensitive: reader.readInt32() !== 0,
      wholeWord: reader.readInt32() !== 0,
      useRegex: reader.readInt32() !== 0,
      wrapAround: reader.readInt32() !== 0,
      maxMatches: reader.readInt32()
    };
  }

  static decodeSearchOptions(buffer: ArrayBuffer | undefined): SearchOptions {
    return CoreProtocol.readSearchOptions(CoreProtocol.readerFor(buffer));
  }

  static writeSearchOptions(writer: BinaryWriter, value: SearchOptions): void {
    writer.writeInt32(value.caseSensitive ? 1 : 0);
    writer.writeInt32(value.wholeWord ? 1 : 0);
    writer.writeInt32(value.useRegex ? 1 : 0);
    writer.writeInt32(value.wrapAround ? 1 : 0);
    writer.writeInt32(value.maxMatches);
  }

  static sizeOfSearchOptions(value: SearchOptions): number {
    let size = 0;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    size += 4;
    return size;
  }

  static writeSearchRequest(writer: BinaryWriter, value: SearchRequest): void {
    writer.writeUtf8String(value.pattern);
    CoreProtocol.writeSearchOptions(writer, value.options);
  }

  static sizeOfSearchRequest(value: SearchRequest): number {
    let size = 0;
    size += CoreProtocol.sizeOfUtf8String(value.pattern);
    size += CoreProtocol.sizeOfSearchOptions(value.options);
    return size;
  }

  private static readSearchState(reader: BinaryReader): SearchState {
    return {
      status: searchStatusFromValue(reader.readInt32()),
      pattern: reader.readUtf8String(),
      options: CoreProtocol.readSearchOptions(reader),
      generation: reader.readInt64(),
      matchCount: reader.readInt32(),
      currentIndex: reader.readInt32(),
      hasCurrentMatch: reader.readInt32() !== 0,
      currentRange: CoreProtocol.readTextRange(reader),
      errorMessage: reader.readUtf8String()
    };
  }

  static decodeSearchState(buffer: ArrayBuffer | undefined): SearchState {
    return CoreProtocol.readSearchState(CoreProtocol.readerFor(buffer));
  }

  private static readCursor(reader: BinaryReader): Cursor {
    return {
      textPosition: CoreProtocol.readTextPosition(reader),
      position: CoreProtocol.readPointF(reader),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0,
      showDragger: reader.readInt32() !== 0
    };
  }

  static decodeCursor(buffer: ArrayBuffer | undefined): Cursor {
    return CoreProtocol.readCursor(CoreProtocol.readerFor(buffer));
  }

  private static readCursorRect(reader: BinaryReader): CursorRect {
    return {
      x: reader.readFloat32(),
      y: reader.readFloat32(),
      height: reader.readFloat32()
    };
  }

  static decodeCursorRect(buffer: ArrayBuffer | undefined): CursorRect {
    return CoreProtocol.readCursorRect(CoreProtocol.readerFor(buffer));
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

  private static readEditorRenderModel(reader: BinaryReader): EditorRenderModel {
    return {
      splitX: reader.readFloat32(),
      splitLineVisible: reader.readInt32() !== 0,
      scrollX: reader.readFloat32(),
      scrollY: reader.readFloat32(),
      viewportSize: CoreProtocol.readSize(reader),
      currentLine: CoreProtocol.readPointF(reader),
      currentLineRenderMode: currentLineRenderModeFromValue(reader.readInt32()),
      lines: CoreProtocol.readVisualLineList(reader),
      cursor: CoreProtocol.readCursor(reader),
      rangeEffects: CoreProtocol.readRangeEffectRenderItemList(reader),
      selectionStartHandle: CoreProtocol.readSelectionHandle(reader),
      selectionEndHandle: CoreProtocol.readSelectionHandle(reader),
      guideSegments: CoreProtocol.readGuideSegmentList(reader),
      maxGutterIcons: reader.readInt32(),
      gutterIcons: CoreProtocol.readGutterIconRenderItemList(reader),
      foldMarkers: CoreProtocol.readFoldMarkerRenderItemList(reader),
      verticalScrollbar: CoreProtocol.readScrollbarModel(reader),
      horizontalScrollbar: CoreProtocol.readScrollbarModel(reader),
      gutterSticky: reader.readInt32() !== 0,
      gutterVisible: reader.readInt32() !== 0,
      pointerCursorType: pointerCursorTypeFromValue(reader.readInt32())
    };
  }

  static decodeEditorRenderModel(buffer: ArrayBuffer | undefined): EditorRenderModel {
    return CoreProtocol.readEditorRenderModel(CoreProtocol.readerFor(buffer));
  }

  private static readFoldMarkerRenderItem(reader: BinaryReader): FoldMarkerRenderItem {
    return {
      logicalLine: reader.readInt32(),
      foldState: foldStateFromValue(reader.readInt32()),
      rect: CoreProtocol.readRect(reader)
    };
  }

  static decodeFoldMarkerRenderItem(buffer: ArrayBuffer | undefined): FoldMarkerRenderItem {
    return CoreProtocol.readFoldMarkerRenderItem(CoreProtocol.readerFor(buffer));
  }

  private static readGuideSegment(reader: BinaryReader): GuideSegment {
    return {
      direction: guideDirectionFromValue(reader.readInt32()),
      type: guideTypeFromValue(reader.readInt32()),
      style: guideStyleFromValue(reader.readInt32()),
      start: CoreProtocol.readPointF(reader),
      end: CoreProtocol.readPointF(reader),
      arrowEnd: reader.readInt32() !== 0
    };
  }

  static decodeGuideSegment(buffer: ArrayBuffer | undefined): GuideSegment {
    return CoreProtocol.readGuideSegment(CoreProtocol.readerFor(buffer));
  }

  private static readGutterIconRenderItem(reader: BinaryReader): GutterIconRenderItem {
    return {
      logicalLine: reader.readInt32(),
      iconId: reader.readInt32(),
      rect: CoreProtocol.readRect(reader)
    };
  }

  static decodeGutterIconRenderItem(buffer: ArrayBuffer | undefined): GutterIconRenderItem {
    return CoreProtocol.readGutterIconRenderItem(CoreProtocol.readerFor(buffer));
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

  static decodeLayoutMetrics(buffer: ArrayBuffer | undefined): LayoutMetrics {
    return CoreProtocol.readLayoutMetrics(CoreProtocol.readerFor(buffer));
  }

  private static readRangeEffectRenderItem(reader: BinaryReader): RangeEffectRenderItem {
    return {
      rect: CoreProtocol.readRect(reader),
      kind: rangeEffectKindFromValue(reader.readInt32()),
      style: CoreProtocol.readRangeEffectStyle(reader)
    };
  }

  static decodeRangeEffectRenderItem(buffer: ArrayBuffer | undefined): RangeEffectRenderItem {
    return CoreProtocol.readRangeEffectRenderItem(CoreProtocol.readerFor(buffer));
  }

  private static readScrollMetrics(reader: BinaryReader): ScrollMetrics {
    return {
      scale: reader.readFloat32(),
      scrollX: reader.readFloat32(),
      scrollY: reader.readFloat32(),
      maxScrollX: reader.readFloat32(),
      maxScrollY: reader.readFloat32(),
      contentSize: CoreProtocol.readSize(reader),
      viewportSize: CoreProtocol.readSize(reader),
      textAreaX: reader.readFloat32(),
      textAreaWidth: reader.readFloat32(),
      canScrollX: reader.readInt32() !== 0,
      canScrollY: reader.readInt32() !== 0
    };
  }

  static decodeScrollMetrics(buffer: ArrayBuffer | undefined): ScrollMetrics {
    return CoreProtocol.readScrollMetrics(CoreProtocol.readerFor(buffer));
  }

  private static readScrollbarModel(reader: BinaryReader): ScrollbarModel {
    return {
      visible: reader.readInt32() !== 0,
      alpha: reader.readFloat32(),
      thumbActive: reader.readInt32() !== 0,
      track: CoreProtocol.readRect(reader),
      thumb: CoreProtocol.readRect(reader)
    };
  }

  static decodeScrollbarModel(buffer: ArrayBuffer | undefined): ScrollbarModel {
    return CoreProtocol.readScrollbarModel(CoreProtocol.readerFor(buffer));
  }

  private static readSelectionHandle(reader: BinaryReader): SelectionHandle {
    return {
      position: CoreProtocol.readPointF(reader),
      height: reader.readFloat32(),
      visible: reader.readInt32() !== 0
    };
  }

  static decodeSelectionHandle(buffer: ArrayBuffer | undefined): SelectionHandle {
    return CoreProtocol.readSelectionHandle(CoreProtocol.readerFor(buffer));
  }

  private static readVisualLine(reader: BinaryReader): VisualLine {
    return {
      logicalLine: reader.readInt32(),
      wrapIndex: reader.readInt32(),
      lineNumberPosition: CoreProtocol.readPointF(reader),
      runs: CoreProtocol.readVisualRunList(reader),
      kind: visualLineKindFromValue(reader.readInt32()),
      ownsGutterSemantics: reader.readInt32() !== 0,
      foldState: foldStateFromValue(reader.readInt32())
    };
  }

  static decodeVisualLine(buffer: ArrayBuffer | undefined): VisualLine {
    return CoreProtocol.readVisualLine(CoreProtocol.readerFor(buffer));
  }

  private static readVisualRun(reader: BinaryReader): VisualRun {
    return {
      type: visualRunTypeFromValue(reader.readInt32()),
      x: reader.readFloat32(),
      y: reader.readFloat32(),
      text: reader.readUtf8String(),
      style: CoreProtocol.readTextStyle(reader),
      iconId: reader.readInt32(),
      colorValue: reader.readInt32(),
      width: reader.readFloat32(),
      padding: reader.readFloat32(),
      margin: reader.readFloat32(),
      active: reader.readInt32() !== 0
    };
  }

  static decodeVisualRun(buffer: ArrayBuffer | undefined): VisualRun {
    return CoreProtocol.readVisualRun(CoreProtocol.readerFor(buffer));
  }

  static encodeBracketGuide(value: BracketGuide): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfBracketGuide(value));
    CoreProtocol.writeBracketGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeCodeLensItem(value: CodeLensItem): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfCodeLensItem(value));
    CoreProtocol.writeCodeLensItem(writer, value);
    return writer.getBuffer();
  }

  static encodeDiagnostic(value: Diagnostic): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfDiagnostic(value));
    CoreProtocol.writeDiagnostic(writer, value);
    return writer.getBuffer();
  }

  static encodeDocumentHighlight(value: DocumentHighlight): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfDocumentHighlight(value));
    CoreProtocol.writeDocumentHighlight(writer, value);
    return writer.getBuffer();
  }

  static encodeFlowGuide(value: FlowGuide): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfFlowGuide(value));
    CoreProtocol.writeFlowGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeFoldRegion(value: FoldRegion): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfFoldRegion(value));
    CoreProtocol.writeFoldRegion(writer, value);
    return writer.getBuffer();
  }

  static encodeGutterIcon(value: GutterIcon): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfGutterIcon(value));
    CoreProtocol.writeGutterIcon(writer, value);
    return writer.getBuffer();
  }

  static encodeIndentGuide(value: IndentGuide): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfIndentGuide(value));
    CoreProtocol.writeIndentGuide(writer, value);
    return writer.getBuffer();
  }

  static encodeInlayHint(value: InlayHint): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfInlayHint(value));
    CoreProtocol.writeInlayHint(writer, value);
    return writer.getBuffer();
  }

  static encodeLinkSpan(value: LinkSpan): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfLinkSpan(value));
    CoreProtocol.writeLinkSpan(writer, value);
    return writer.getBuffer();
  }

  static encodePhantomText(value: PhantomText): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfPhantomText(value));
    CoreProtocol.writePhantomText(writer, value);
    return writer.getBuffer();
  }

  private static writeRegisterBatchTextStylesPayloadWire(writer: BinaryWriter, styleByStyleId: Map<number, TextStyle>): void {
    const styleByStyleIdKeys = styleByStyleId ? Array.from(styleByStyleId.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(styleByStyleIdKeys.length);
    for (const key of styleByStyleIdKeys) {
      writer.writeInt32(key);
      const value = styleByStyleId.get(key)!;
      CoreProtocol.writeTextStyle(writer, value);
    }
  }

  private static sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId: Map<number, TextStyle>): number {
    let size = 0;
    size += 4;
    const styleByStyleIdKeys = styleByStyleId ? Array.from(styleByStyleId.keys()).sort((a, b) => a - b) : [];
    for (const key of styleByStyleIdKeys) {
      size += 4;
      const value = styleByStyleId.get(key)!;
      size += CoreProtocol.sizeOfTextStyle(value);
    }
    return size;
  }

  static encodeRegisterBatchTextStylesPayload(styleByStyleId: Map<number, TextStyle>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId));
    CoreProtocol.writeRegisterBatchTextStylesPayloadWire(writer, styleByStyleId);
    return writer.getBuffer();
  }

  static encodeSeparatorGuide(value: SeparatorGuide): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSeparatorGuide(value));
    CoreProtocol.writeSeparatorGuide(writer, value);
    return writer.getBuffer();
  }

  private static writeSetBatchLineCodeLensPayloadWire(writer: BinaryWriter, itemsByLine: Map<number, CodeLensItem[]>): void {
    const itemsByLineKeys = itemsByLine ? Array.from(itemsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(itemsByLineKeys.length);
    for (const key of itemsByLineKeys) {
      writer.writeInt32(key);
      const value = itemsByLine.get(key)!;
      CoreProtocol.writeCodeLensItemList(writer, value);
    }
  }

  private static sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine: Map<number, CodeLensItem[]>): number {
    let size = 0;
    size += 4;
    const itemsByLineKeys = itemsByLine ? Array.from(itemsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of itemsByLineKeys) {
      size += 4;
      const value = itemsByLine.get(key)!;
      size += CoreProtocol.sizeOfCodeLensItemList(value);
    }
    return size;
  }

  static encodeSetBatchLineCodeLensPayload(itemsByLine: Map<number, CodeLensItem[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine));
    CoreProtocol.writeSetBatchLineCodeLensPayloadWire(writer, itemsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineDiagnosticsPayloadWire(writer: BinaryWriter, diagnosticsByLine: Map<number, Diagnostic[]>): void {
    const diagnosticsByLineKeys = diagnosticsByLine ? Array.from(diagnosticsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(diagnosticsByLineKeys.length);
    for (const key of diagnosticsByLineKeys) {
      writer.writeInt32(key);
      const value = diagnosticsByLine.get(key)!;
      CoreProtocol.writeDiagnosticList(writer, value);
    }
  }

  private static sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine: Map<number, Diagnostic[]>): number {
    let size = 0;
    size += 4;
    const diagnosticsByLineKeys = diagnosticsByLine ? Array.from(diagnosticsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of diagnosticsByLineKeys) {
      size += 4;
      const value = diagnosticsByLine.get(key)!;
      size += CoreProtocol.sizeOfDiagnosticList(value);
    }
    return size;
  }

  static encodeSetBatchLineDiagnosticsPayload(diagnosticsByLine: Map<number, Diagnostic[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine));
    CoreProtocol.writeSetBatchLineDiagnosticsPayloadWire(writer, diagnosticsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineDocumentHighlightsPayloadWire(writer: BinaryWriter, highlightsByLine: Map<number, DocumentHighlight[]>): void {
    const highlightsByLineKeys = highlightsByLine ? Array.from(highlightsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(highlightsByLineKeys.length);
    for (const key of highlightsByLineKeys) {
      writer.writeInt32(key);
      const value = highlightsByLine.get(key)!;
      CoreProtocol.writeDocumentHighlightList(writer, value);
    }
  }

  private static sizeOfSetBatchLineDocumentHighlightsPayloadWire(highlightsByLine: Map<number, DocumentHighlight[]>): number {
    let size = 0;
    size += 4;
    const highlightsByLineKeys = highlightsByLine ? Array.from(highlightsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of highlightsByLineKeys) {
      size += 4;
      const value = highlightsByLine.get(key)!;
      size += CoreProtocol.sizeOfDocumentHighlightList(value);
    }
    return size;
  }

  static encodeSetBatchLineDocumentHighlightsPayload(highlightsByLine: Map<number, DocumentHighlight[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineDocumentHighlightsPayloadWire(highlightsByLine));
    CoreProtocol.writeSetBatchLineDocumentHighlightsPayloadWire(writer, highlightsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineGutterIconsPayloadWire(writer: BinaryWriter, iconsByLine: Map<number, GutterIcon[]>): void {
    const iconsByLineKeys = iconsByLine ? Array.from(iconsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(iconsByLineKeys.length);
    for (const key of iconsByLineKeys) {
      writer.writeInt32(key);
      const value = iconsByLine.get(key)!;
      CoreProtocol.writeGutterIconList(writer, value);
    }
  }

  private static sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine: Map<number, GutterIcon[]>): number {
    let size = 0;
    size += 4;
    const iconsByLineKeys = iconsByLine ? Array.from(iconsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of iconsByLineKeys) {
      size += 4;
      const value = iconsByLine.get(key)!;
      size += CoreProtocol.sizeOfGutterIconList(value);
    }
    return size;
  }

  static encodeSetBatchLineGutterIconsPayload(iconsByLine: Map<number, GutterIcon[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine));
    CoreProtocol.writeSetBatchLineGutterIconsPayloadWire(writer, iconsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineInlayHintsPayloadWire(writer: BinaryWriter, hintsByLine: Map<number, InlayHint[]>): void {
    const hintsByLineKeys = hintsByLine ? Array.from(hintsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(hintsByLineKeys.length);
    for (const key of hintsByLineKeys) {
      writer.writeInt32(key);
      const value = hintsByLine.get(key)!;
      CoreProtocol.writeInlayHintList(writer, value);
    }
  }

  private static sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine: Map<number, InlayHint[]>): number {
    let size = 0;
    size += 4;
    const hintsByLineKeys = hintsByLine ? Array.from(hintsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of hintsByLineKeys) {
      size += 4;
      const value = hintsByLine.get(key)!;
      size += CoreProtocol.sizeOfInlayHintList(value);
    }
    return size;
  }

  static encodeSetBatchLineInlayHintsPayload(hintsByLine: Map<number, InlayHint[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine));
    CoreProtocol.writeSetBatchLineInlayHintsPayloadWire(writer, hintsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineLinksPayloadWire(writer: BinaryWriter, linksByLine: Map<number, LinkSpan[]>): void {
    const linksByLineKeys = linksByLine ? Array.from(linksByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(linksByLineKeys.length);
    for (const key of linksByLineKeys) {
      writer.writeInt32(key);
      const value = linksByLine.get(key)!;
      CoreProtocol.writeLinkSpanList(writer, value);
    }
  }

  private static sizeOfSetBatchLineLinksPayloadWire(linksByLine: Map<number, LinkSpan[]>): number {
    let size = 0;
    size += 4;
    const linksByLineKeys = linksByLine ? Array.from(linksByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of linksByLineKeys) {
      size += 4;
      const value = linksByLine.get(key)!;
      size += CoreProtocol.sizeOfLinkSpanList(value);
    }
    return size;
  }

  static encodeSetBatchLineLinksPayload(linksByLine: Map<number, LinkSpan[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineLinksPayloadWire(linksByLine));
    CoreProtocol.writeSetBatchLineLinksPayloadWire(writer, linksByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLinePhantomTextsPayloadWire(writer: BinaryWriter, phantomsByLine: Map<number, PhantomText[]>): void {
    const phantomsByLineKeys = phantomsByLine ? Array.from(phantomsByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(phantomsByLineKeys.length);
    for (const key of phantomsByLineKeys) {
      writer.writeInt32(key);
      const value = phantomsByLine.get(key)!;
      CoreProtocol.writePhantomTextList(writer, value);
    }
  }

  private static sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine: Map<number, PhantomText[]>): number {
    let size = 0;
    size += 4;
    const phantomsByLineKeys = phantomsByLine ? Array.from(phantomsByLine.keys()).sort((a, b) => a - b) : [];
    for (const key of phantomsByLineKeys) {
      size += 4;
      const value = phantomsByLine.get(key)!;
      size += CoreProtocol.sizeOfPhantomTextList(value);
    }
    return size;
  }

  static encodeSetBatchLinePhantomTextsPayload(phantomsByLine: Map<number, PhantomText[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine));
    CoreProtocol.writeSetBatchLinePhantomTextsPayloadWire(writer, phantomsByLine);
    return writer.getBuffer();
  }

  private static writeSetBatchLineSpansPayloadWire(writer: BinaryWriter, layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): void {
    writer.writeInt32(layer as number);
    const spansByLineKeys = spansByLine ? Array.from(spansByLine.keys()).sort((a, b) => a - b) : [];
    writer.writeInt32(spansByLineKeys.length);
    for (const key of spansByLineKeys) {
      writer.writeInt32(key);
      const value = spansByLine.get(key)!;
      CoreProtocol.writeStyleSpanList(writer, value);
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
      size += CoreProtocol.sizeOfStyleSpanList(value);
    }
    return size;
  }

  static encodeSetBatchLineSpansPayload(layer: SpanLayer, spansByLine: Map<number, StyleSpan[]>): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBatchLineSpansPayloadWire(layer, spansByLine));
    CoreProtocol.writeSetBatchLineSpansPayloadWire(writer, layer, spansByLine);
    return writer.getBuffer();
  }

  private static writeSetBracketGuidesPayloadWire(writer: BinaryWriter, guides: BracketGuide[]): void {
    CoreProtocol.writeBracketGuideList(writer, guides);
  }

  private static sizeOfSetBracketGuidesPayloadWire(guides: BracketGuide[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfBracketGuideList(guides);
    return size;
  }

  static encodeSetBracketGuidesPayload(guides: BracketGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetBracketGuidesPayloadWire(guides));
    CoreProtocol.writeSetBracketGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetFlowGuidesPayloadWire(writer: BinaryWriter, guides: FlowGuide[]): void {
    CoreProtocol.writeFlowGuideList(writer, guides);
  }

  private static sizeOfSetFlowGuidesPayloadWire(guides: FlowGuide[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfFlowGuideList(guides);
    return size;
  }

  static encodeSetFlowGuidesPayload(guides: FlowGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetFlowGuidesPayloadWire(guides));
    CoreProtocol.writeSetFlowGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetFoldRegionsPayloadWire(writer: BinaryWriter, regions: FoldRegion[]): void {
    CoreProtocol.writeFoldRegionList(writer, regions);
  }

  private static sizeOfSetFoldRegionsPayloadWire(regions: FoldRegion[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfFoldRegionList(regions);
    return size;
  }

  static encodeSetFoldRegionsPayload(regions: FoldRegion[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetFoldRegionsPayloadWire(regions));
    CoreProtocol.writeSetFoldRegionsPayloadWire(writer, regions);
    return writer.getBuffer();
  }

  private static writeSetIndentGuidesPayloadWire(writer: BinaryWriter, guides: IndentGuide[]): void {
    CoreProtocol.writeIndentGuideList(writer, guides);
  }

  private static sizeOfSetIndentGuidesPayloadWire(guides: IndentGuide[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfIndentGuideList(guides);
    return size;
  }

  static encodeSetIndentGuidesPayload(guides: IndentGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetIndentGuidesPayloadWire(guides));
    CoreProtocol.writeSetIndentGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  private static writeSetLineCodeLensPayloadWire(writer: BinaryWriter, line: number, items: CodeLensItem[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeCodeLensItemList(writer, items);
  }

  private static sizeOfSetLineCodeLensPayloadWire(line: number, items: CodeLensItem[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfCodeLensItemList(items);
    return size;
  }

  static encodeSetLineCodeLensPayload(line: number, items: CodeLensItem[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineCodeLensPayloadWire(line, items));
    CoreProtocol.writeSetLineCodeLensPayloadWire(writer, line, items);
    return writer.getBuffer();
  }

  private static writeSetLineDiagnosticsPayloadWire(writer: BinaryWriter, line: number, diagnostics: Diagnostic[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeDiagnosticList(writer, diagnostics);
  }

  private static sizeOfSetLineDiagnosticsPayloadWire(line: number, diagnostics: Diagnostic[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfDiagnosticList(diagnostics);
    return size;
  }

  static encodeSetLineDiagnosticsPayload(line: number, diagnostics: Diagnostic[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineDiagnosticsPayloadWire(line, diagnostics));
    CoreProtocol.writeSetLineDiagnosticsPayloadWire(writer, line, diagnostics);
    return writer.getBuffer();
  }

  private static writeSetLineDocumentHighlightsPayloadWire(writer: BinaryWriter, line: number, highlights: DocumentHighlight[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeDocumentHighlightList(writer, highlights);
  }

  private static sizeOfSetLineDocumentHighlightsPayloadWire(line: number, highlights: DocumentHighlight[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfDocumentHighlightList(highlights);
    return size;
  }

  static encodeSetLineDocumentHighlightsPayload(line: number, highlights: DocumentHighlight[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineDocumentHighlightsPayloadWire(line, highlights));
    CoreProtocol.writeSetLineDocumentHighlightsPayloadWire(writer, line, highlights);
    return writer.getBuffer();
  }

  private static writeSetLineGutterIconsPayloadWire(writer: BinaryWriter, line: number, icons: GutterIcon[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeGutterIconList(writer, icons);
  }

  private static sizeOfSetLineGutterIconsPayloadWire(line: number, icons: GutterIcon[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfGutterIconList(icons);
    return size;
  }

  static encodeSetLineGutterIconsPayload(line: number, icons: GutterIcon[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineGutterIconsPayloadWire(line, icons));
    CoreProtocol.writeSetLineGutterIconsPayloadWire(writer, line, icons);
    return writer.getBuffer();
  }

  private static writeSetLineInlayHintsPayloadWire(writer: BinaryWriter, line: number, hints: InlayHint[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeInlayHintList(writer, hints);
  }

  private static sizeOfSetLineInlayHintsPayloadWire(line: number, hints: InlayHint[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfInlayHintList(hints);
    return size;
  }

  static encodeSetLineInlayHintsPayload(line: number, hints: InlayHint[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineInlayHintsPayloadWire(line, hints));
    CoreProtocol.writeSetLineInlayHintsPayloadWire(writer, line, hints);
    return writer.getBuffer();
  }

  private static writeSetLineLinksPayloadWire(writer: BinaryWriter, line: number, links: LinkSpan[]): void {
    writer.writeInt32(line);
    CoreProtocol.writeLinkSpanList(writer, links);
  }

  private static sizeOfSetLineLinksPayloadWire(line: number, links: LinkSpan[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfLinkSpanList(links);
    return size;
  }

  static encodeSetLineLinksPayload(line: number, links: LinkSpan[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineLinksPayloadWire(line, links));
    CoreProtocol.writeSetLineLinksPayloadWire(writer, line, links);
    return writer.getBuffer();
  }

  private static writeSetLinePhantomTextsPayloadWire(writer: BinaryWriter, line: number, phantoms: PhantomText[]): void {
    writer.writeInt32(line);
    CoreProtocol.writePhantomTextList(writer, phantoms);
  }

  private static sizeOfSetLinePhantomTextsPayloadWire(line: number, phantoms: PhantomText[]): number {
    let size = 0;
    size += 4;
    size += CoreProtocol.sizeOfPhantomTextList(phantoms);
    return size;
  }

  static encodeSetLinePhantomTextsPayload(line: number, phantoms: PhantomText[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLinePhantomTextsPayloadWire(line, phantoms));
    CoreProtocol.writeSetLinePhantomTextsPayloadWire(writer, line, phantoms);
    return writer.getBuffer();
  }

  private static writeSetLineSpansPayloadWire(writer: BinaryWriter, line: number, layer: SpanLayer, spans: StyleSpan[]): void {
    writer.writeInt32(line);
    writer.writeInt32(layer as number);
    CoreProtocol.writeStyleSpanList(writer, spans);
  }

  private static sizeOfSetLineSpansPayloadWire(line: number, layer: SpanLayer, spans: StyleSpan[]): number {
    let size = 0;
    size += 4;
    size += 4;
    size += CoreProtocol.sizeOfStyleSpanList(spans);
    return size;
  }

  static encodeSetLineSpansPayload(line: number, layer: SpanLayer, spans: StyleSpan[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetLineSpansPayloadWire(line, layer, spans));
    CoreProtocol.writeSetLineSpansPayloadWire(writer, line, layer, spans);
    return writer.getBuffer();
  }

  private static writeSetSeparatorGuidesPayloadWire(writer: BinaryWriter, guides: SeparatorGuide[]): void {
    CoreProtocol.writeSeparatorGuideList(writer, guides);
  }

  private static sizeOfSetSeparatorGuidesPayloadWire(guides: SeparatorGuide[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfSeparatorGuideList(guides);
    return size;
  }

  static encodeSetSeparatorGuidesPayload(guides: SeparatorGuide[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetSeparatorGuidesPayloadWire(guides));
    CoreProtocol.writeSetSeparatorGuidesPayloadWire(writer, guides);
    return writer.getBuffer();
  }

  static encodeEditorOptions(value: EditorOptions): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfEditorOptions(value));
    CoreProtocol.writeEditorOptions(writer, value);
    return writer.getBuffer();
  }

  static encodeEditorRangeEffectStyles(value: EditorRangeEffectStyles): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfEditorRangeEffectStyles(value));
    CoreProtocol.writeEditorRangeEffectStyles(writer, value);
    return writer.getBuffer();
  }

  static encodeEditorRenderColors(value: EditorRenderColors): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfEditorRenderColors(value));
    CoreProtocol.writeEditorRenderColors(writer, value);
    return writer.getBuffer();
  }

  static encodeHandleConfig(value: HandleConfig): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfHandleConfig(value));
    CoreProtocol.writeHandleConfig(writer, value);
    return writer.getBuffer();
  }

  static encodeScrollbarConfig(value: ScrollbarConfig): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfScrollbarConfig(value));
    CoreProtocol.writeScrollbarConfig(writer, value);
    return writer.getBuffer();
  }

  private static writeApplyTextEditsPayloadWire(writer: BinaryWriter, edits: TextEdit[]): void {
    CoreProtocol.writeTextEditList(writer, edits);
  }

  private static sizeOfApplyTextEditsPayloadWire(edits: TextEdit[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfTextEditList(edits);
    return size;
  }

  static encodeApplyTextEditsPayload(edits: TextEdit[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfApplyTextEditsPayloadWire(edits));
    CoreProtocol.writeApplyTextEditsPayloadWire(writer, edits);
    return writer.getBuffer();
  }

  static encodeImeCommandMessage(value: ImeCommandMessage): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfImeCommandMessage(value));
    CoreProtocol.writeImeCommandMessage(writer, value);
    return writer.getBuffer();
  }

  static encodeImeTextUpdateMessage(value: ImeTextUpdateMessage): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfImeTextUpdateMessage(value));
    CoreProtocol.writeImeTextUpdateMessage(writer, value);
    return writer.getBuffer();
  }

  static encodeGestureEvent(value: GestureEvent): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfGestureEvent(value));
    CoreProtocol.writeGestureEvent(writer, value);
    return writer.getBuffer();
  }

  private static writeSetKeyMapPayloadWire(writer: BinaryWriter, bindings: KeyBinding[]): void {
    CoreProtocol.writeKeyBindingList(writer, bindings);
  }

  private static sizeOfSetKeyMapPayloadWire(bindings: KeyBinding[]): number {
    let size = 0;
    size += CoreProtocol.sizeOfKeyBindingList(bindings);
    return size;
  }

  static encodeSetKeyMapPayload(bindings: KeyBinding[]): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSetKeyMapPayloadWire(bindings));
    CoreProtocol.writeSetKeyMapPayloadWire(writer, bindings);
    return writer.getBuffer();
  }

  static encodeLinkedEditingModel(value: LinkedEditingModel): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfLinkedEditingModel(value));
    CoreProtocol.writeLinkedEditingModel(writer, value);
    return writer.getBuffer();
  }

  private static writeStartLinkedEditingPayloadWire(writer: BinaryWriter, model: LinkedEditingModel): void {
    CoreProtocol.writeLinkedEditingModel(writer, model);
  }

  private static sizeOfStartLinkedEditingPayloadWire(model: LinkedEditingModel): number {
    let size = 0;
    size += CoreProtocol.sizeOfLinkedEditingModel(model);
    return size;
  }

  static encodeStartLinkedEditingPayload(model: LinkedEditingModel): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfStartLinkedEditingPayloadWire(model));
    CoreProtocol.writeStartLinkedEditingPayloadWire(writer, model);
    return writer.getBuffer();
  }

  static encodeTabStopGroup(value: TabStopGroup): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfTabStopGroup(value));
    CoreProtocol.writeTabStopGroup(writer, value);
    return writer.getBuffer();
  }

  static encodeSearchRequest(value: SearchRequest): ArrayBuffer {
    const writer = new BinaryWriter(CoreProtocol.sizeOfSearchRequest(value));
    CoreProtocol.writeSearchRequest(writer, value);
    return writer.getBuffer();
  }
}
