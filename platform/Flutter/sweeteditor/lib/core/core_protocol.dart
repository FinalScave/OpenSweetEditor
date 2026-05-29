// ignore_for_file: unused_element

part of 'editor_core.dart';

class _BinaryReader {
  _BinaryReader.fromPointer(ffi.Pointer<ffi.Uint8> ptr, int size)
    : _data = ByteData.sublistView(ptr.asTypedList(size));

  final ByteData _data;
  int _offset = 0;

  int readUint8() {
    final value = _data.getUint8(_offset);
    _offset += 1;
    return value;
  }

  int readUint16() {
    final value = _data.getUint16(_offset, Endian.little);
    _offset += 2;
    return value;
  }

  int readInt32() {
    final value = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readUint32() {
    final value = _data.getUint32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  int readInt64() {
    final value = _data.getInt64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  int readUint64() {
    final value = _data.getUint64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  double readFloat32() {
    final value = _data.getFloat32(_offset, Endian.little);
    _offset += 4;
    return value;
  }

  double readFloat64() {
    final value = _data.getFloat64(_offset, Endian.little);
    _offset += 8;
    return value;
  }

  bool readBoolI32() => readInt32() != 0;
  bool readBoolUint8() => readUint8() != 0;

  Uint8List readBytes(int length) {
    final bytes = _data.buffer.asUint8List(_data.offsetInBytes + _offset, length);
    _offset += length;
    return bytes;
  }
}

class _BinaryWriter {
  _BinaryWriter(int size) : _data = ByteData(size);

  final ByteData _data;
  int _offset = 0;

  Uint8List toBytes() => _data.buffer.asUint8List();

  void writeUint8(int value) {
    _data.setUint8(_offset, value);
    _offset += 1;
  }

  void writeUint16(int value) {
    _data.setUint16(_offset, value, Endian.little);
    _offset += 2;
  }

  void writeInt32(int value) {
    _data.setInt32(_offset, value, Endian.little);
    _offset += 4;
  }

  void writeUint32(int value) {
    _data.setUint32(_offset, value, Endian.little);
    _offset += 4;
  }

  void writeInt64(int value) {
    _data.setInt64(_offset, value, Endian.little);
    _offset += 8;
  }

  void writeUint64(int value) {
    _data.setUint64(_offset, value, Endian.little);
    _offset += 8;
  }

  void writeFloat32(double value) {
    _data.setFloat32(_offset, value, Endian.little);
    _offset += 4;
  }

  void writeFloat64(double value) {
    _data.setFloat64(_offset, value, Endian.little);
    _offset += 8;
  }

  void writeBoolI32(bool value) => writeInt32(value ? 1 : 0);
  void writeBoolUint8(bool value) => writeUint8(value ? 1 : 0);

  void writeBytes(List<int> bytes) {
    _data.buffer.asUint8List().setAll(_offset, bytes);
    _offset += bytes.length;
  }
}

String _readUtf8String(_BinaryReader reader) {
  final length = reader.readInt32();
  if (length <= 0) return '';
  return utf8.decode(reader.readBytes(length));
}

void _writeUtf8String(_BinaryWriter writer, String? value) {
  final bytes = value == null ? const <int>[] : utf8.encode(value);
  writer.writeInt32(bytes.length);
  writer.writeBytes(bytes);
}

int _sizeOfUtf8String(String? value) {
  return 4 + (value == null ? 0 : utf8.encode(value).length);
}

void _writeBracketGuideList(_BinaryWriter writer, List<BracketGuide>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeBracketGuide(writer, values![i]);
  }
}

int _sizeOfBracketGuideList(List<BracketGuide>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfBracketGuide(value);
    }
  }
  return size;
}

void _writeCodeLensItemList(_BinaryWriter writer, List<CodeLensItem>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeCodeLensItem(writer, values![i]);
  }
}

int _sizeOfCodeLensItemList(List<CodeLensItem>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfCodeLensItem(value);
    }
  }
  return size;
}

void _writeDiagnosticList(_BinaryWriter writer, List<Diagnostic>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeDiagnostic(writer, values![i]);
  }
}

int _sizeOfDiagnosticList(List<Diagnostic>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfDiagnostic(value);
    }
  }
  return size;
}

List<DiagnosticDecoration> _readDiagnosticDecorationList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <DiagnosticDecoration>[];
  for (var i = 0; i < count; i++) {
    values.add(_readDiagnosticDecoration(reader));
  }
  return values;
}

void _writeFlowGuideList(_BinaryWriter writer, List<FlowGuide>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeFlowGuide(writer, values![i]);
  }
}

int _sizeOfFlowGuideList(List<FlowGuide>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfFlowGuide(value);
    }
  }
  return size;
}

List<FoldMarkerRenderItem> _readFoldMarkerRenderItemList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <FoldMarkerRenderItem>[];
  for (var i = 0; i < count; i++) {
    values.add(_readFoldMarkerRenderItem(reader));
  }
  return values;
}

void _writeFoldRegionList(_BinaryWriter writer, List<FoldRegion>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeFoldRegion(writer, values![i]);
  }
}

int _sizeOfFoldRegionList(List<FoldRegion>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfFoldRegion(value);
    }
  }
  return size;
}

List<GuideSegment> _readGuideSegmentList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <GuideSegment>[];
  for (var i = 0; i < count; i++) {
    values.add(_readGuideSegment(reader));
  }
  return values;
}

void _writeGutterIconList(_BinaryWriter writer, List<GutterIcon>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeGutterIcon(writer, values![i]);
  }
}

int _sizeOfGutterIconList(List<GutterIcon>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfGutterIcon(value);
    }
  }
  return size;
}

List<GutterIconRenderItem> _readGutterIconRenderItemList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <GutterIconRenderItem>[];
  for (var i = 0; i < count; i++) {
    values.add(_readGutterIconRenderItem(reader));
  }
  return values;
}

void _writeIndentGuideList(_BinaryWriter writer, List<IndentGuide>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeIndentGuide(writer, values![i]);
  }
}

int _sizeOfIndentGuideList(List<IndentGuide>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfIndentGuide(value);
    }
  }
  return size;
}

void _writeInlayHintList(_BinaryWriter writer, List<InlayHint>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeInlayHint(writer, values![i]);
  }
}

int _sizeOfInlayHintList(List<InlayHint>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfInlayHint(value);
    }
  }
  return size;
}

List<KeyBinding> _readKeyBindingList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <KeyBinding>[];
  for (var i = 0; i < count; i++) {
    values.add(_readKeyBinding(reader));
  }
  return values;
}

void _writeKeyBindingList(_BinaryWriter writer, List<KeyBinding>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeKeyBinding(writer, values![i]);
  }
}

int _sizeOfKeyBindingList(List<KeyBinding>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfKeyBinding(value);
    }
  }
  return size;
}

void _writeLinkSpanList(_BinaryWriter writer, List<LinkSpan>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeLinkSpan(writer, values![i]);
  }
}

int _sizeOfLinkSpanList(List<LinkSpan>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfLinkSpan(value);
    }
  }
  return size;
}

List<LinkedEditingRect> _readLinkedEditingRectList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <LinkedEditingRect>[];
  for (var i = 0; i < count; i++) {
    values.add(_readLinkedEditingRect(reader));
  }
  return values;
}

void _writePhantomTextList(_BinaryWriter writer, List<PhantomText>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writePhantomText(writer, values![i]);
  }
}

int _sizeOfPhantomTextList(List<PhantomText>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfPhantomText(value);
    }
  }
  return size;
}

List<Rect> _readRectList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <Rect>[];
  for (var i = 0; i < count; i++) {
    values.add(_readRect(reader));
  }
  return values;
}

void _writeRectList(_BinaryWriter writer, List<Rect>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeRect(writer, values![i]);
  }
}

int _sizeOfRectList(List<Rect>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfRect(value);
    }
  }
  return size;
}

void _writeSeparatorGuideList(_BinaryWriter writer, List<SeparatorGuide>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeSeparatorGuide(writer, values![i]);
  }
}

int _sizeOfSeparatorGuideList(List<SeparatorGuide>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfSeparatorGuide(value);
    }
  }
  return size;
}

List<StyleSpan> _readStyleSpanList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <StyleSpan>[];
  for (var i = 0; i < count; i++) {
    values.add(_readStyleSpan(reader));
  }
  return values;
}

void _writeStyleSpanList(_BinaryWriter writer, List<StyleSpan>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeStyleSpan(writer, values![i]);
  }
}

int _sizeOfStyleSpanList(List<StyleSpan>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfStyleSpan(value);
    }
  }
  return size;
}

void _writeTabStopGroupList(_BinaryWriter writer, List<TabStopGroup>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeTabStopGroup(writer, values![i]);
  }
}

int _sizeOfTabStopGroupList(List<TabStopGroup>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfTabStopGroup(value);
    }
  }
  return size;
}

List<TextChange> _readTextChangeList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <TextChange>[];
  for (var i = 0; i < count; i++) {
    values.add(_readTextChange(reader));
  }
  return values;
}

List<TextPosition> _readTextPositionList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <TextPosition>[];
  for (var i = 0; i < count; i++) {
    values.add(_readTextPosition(reader));
  }
  return values;
}

void _writeTextPositionList(_BinaryWriter writer, List<TextPosition>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeTextPosition(writer, values![i]);
  }
}

int _sizeOfTextPositionList(List<TextPosition>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfTextPosition(value);
    }
  }
  return size;
}

List<TextRange> _readTextRangeList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <TextRange>[];
  for (var i = 0; i < count; i++) {
    values.add(_readTextRange(reader));
  }
  return values;
}

void _writeTextRangeList(_BinaryWriter writer, List<TextRange>? values) {
  final count = values == null ? 0 : values.length;
  writer.writeInt32(count);
  for (var i = 0; i < count; i++) {
    _writeTextRange(writer, values![i]);
  }
}

int _sizeOfTextRangeList(List<TextRange>? values) {
  var size = 4;
  if (values != null) {
    for (final value in values) {
      size += _sizeOfTextRange(value);
    }
  }
  return size;
}

List<VisualLine> _readVisualLineList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <VisualLine>[];
  for (var i = 0; i < count; i++) {
    values.add(_readVisualLine(reader));
  }
  return values;
}

List<VisualRun> _readVisualRunList(_BinaryReader reader) {
  final count = reader.readInt32();
  final values = <VisualRun>[];
  for (var i = 0; i < count; i++) {
    values.add(_readVisualRun(reader));
  }
  return values;
}

EditorActionResult _readEditorActionResult(_BinaryReader reader) {
  return EditorActionResult(
    handled: reader.readBoolI32(),
    needsRedraw: reader.readBoolI32(),
    reason: EditorActionReason.fromValue(reader.readInt32()),
    contentChanged: reader.readBoolI32(),
    cursorChanged: reader.readBoolI32(),
    selectionChanged: reader.readBoolI32(),
    scrollChanged: reader.readBoolI32(),
    scaleChanged: reader.readBoolI32(),
    pointerCursorChanged: reader.readBoolI32(),
    compositionChanged: reader.readBoolI32(),
    decorationChanged: reader.readBoolI32(),
    needsImeSync: reader.readBoolI32(),
    needsEdgeScroll: reader.readBoolI32(),
    needsFling: reader.readBoolI32(),
    needsAnimation: reader.readBoolI32(),
    isHandleDrag: reader.readBoolI32(),
    changes: _readTextChangeList(reader),
    cursorBefore: _readTextPosition(reader),
    cursorAfter: _readTextPosition(reader),
    hasSelectionBefore: reader.readBoolI32(),
    hasSelectionAfter: reader.readBoolI32(),
    selectionBefore: _readTextRange(reader),
    selectionAfter: _readTextRange(reader),
    scrollXBefore: reader.readFloat32(),
    scrollYBefore: reader.readFloat32(),
    scrollXAfter: reader.readFloat32(),
    scrollYAfter: reader.readFloat32(),
    scaleBefore: reader.readFloat32(),
    scaleAfter: reader.readFloat32(),
    pointerCursorBefore: PointerCursorType.fromValue(reader.readInt32()),
    pointerCursorAfter: PointerCursorType.fromValue(reader.readInt32()),
    imeSync: _readImeSyncSnapshot(reader),
    gestureType: GestureType.fromValue(reader.readInt32()),
    gestureEventType: EventType.fromValue(reader.readInt32()),
    tapPoint: _readPointF(reader),
    hitTarget: _readHitTarget(reader),
    modifiers: reader.readInt32(),
    command: reader.readInt32(),
  );
}

void _writeBracketGuide(_BinaryWriter writer, BracketGuide value) {
  _writeTextPosition(writer, value.parent);
  _writeTextPosition(writer, value.end);
  _writeTextPositionList(writer, value.children);
}

int _sizeOfBracketGuide(BracketGuide value) {
  var size = 0;
  size += _sizeOfTextPosition(value.parent);
  size += _sizeOfTextPosition(value.end);
  size += _sizeOfTextPositionList(value.children);
  return size;
}

void _writeCodeLensItem(_BinaryWriter writer, CodeLensItem value) {
  writer.writeInt32(value.column);
  writer.writeInt32(value.commandId);
  _writeUtf8String(writer, value.text);
}

int _sizeOfCodeLensItem(CodeLensItem value) {
  var size = 0;
  size += 4;
  size += 4;
  size += _sizeOfUtf8String(value.text);
  return size;
}

void _writeDiagnostic(_BinaryWriter writer, Diagnostic value) {
  writer.writeUint32(value.column);
  writer.writeUint32(value.length);
  writer.writeInt32(value.severity.value);
}

int _sizeOfDiagnostic(Diagnostic value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

void _writeFlowGuide(_BinaryWriter writer, FlowGuide value) {
  _writeTextPosition(writer, value.start);
  _writeTextPosition(writer, value.end);
}

int _sizeOfFlowGuide(FlowGuide value) {
  var size = 0;
  size += _sizeOfTextPosition(value.start);
  size += _sizeOfTextPosition(value.end);
  return size;
}

void _writeFoldRegion(_BinaryWriter writer, FoldRegion value) {
  writer.writeUint32(value.startLine);
  writer.writeUint32(value.endLine);
  writer.writeBoolUint8(value.collapsed);
}

int _sizeOfFoldRegion(FoldRegion value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 1;
  return size;
}

void _writeGutterIcon(_BinaryWriter writer, GutterIcon value) {
  writer.writeInt32(value.iconId);
}

int _sizeOfGutterIcon(GutterIcon value) {
  var size = 0;
  size += 4;
  return size;
}

void _writeIndentGuide(_BinaryWriter writer, IndentGuide value) {
  _writeTextPosition(writer, value.start);
  _writeTextPosition(writer, value.end);
}

int _sizeOfIndentGuide(IndentGuide value) {
  var size = 0;
  size += _sizeOfTextPosition(value.start);
  size += _sizeOfTextPosition(value.end);
  return size;
}

void _writeInlayHint(_BinaryWriter writer, InlayHint value) {
  writer.writeInt32(value.type.value);
  writer.writeUint32(value.column);
  writer.writeInt32(value.intValue);
  _writeUtf8String(writer, value.text);
}

int _sizeOfInlayHint(InlayHint value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  size += _sizeOfUtf8String(value.text);
  return size;
}

void _writeLinkSpan(_BinaryWriter writer, LinkSpan value) {
  writer.writeUint32(value.column);
  writer.writeUint32(value.length);
  _writeUtf8String(writer, value.target);
}

int _sizeOfLinkSpan(LinkSpan value) {
  var size = 0;
  size += 4;
  size += 4;
  size += _sizeOfUtf8String(value.target);
  return size;
}

void _writePhantomText(_BinaryWriter writer, PhantomText value) {
  writer.writeUint32(value.column);
  _writeUtf8String(writer, value.text);
}

int _sizeOfPhantomText(PhantomText value) {
  var size = 0;
  size += 4;
  size += _sizeOfUtf8String(value.text);
  return size;
}

void _writeSeparatorGuide(_BinaryWriter writer, SeparatorGuide value) {
  writer.writeInt32(value.line);
  writer.writeInt32(value.style.value);
  writer.writeInt32(value.count);
  writer.writeUint32(value.textEndColumn);
}

int _sizeOfSeparatorGuide(SeparatorGuide value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

StyleSpan _readStyleSpan(_BinaryReader reader) {
  return StyleSpan(
    column: reader.readUint32(),
    length: reader.readUint32(),
    styleId: reader.readUint32(),
  );
}

void _writeStyleSpan(_BinaryWriter writer, StyleSpan value) {
  writer.writeUint32(value.column);
  writer.writeUint32(value.length);
  writer.writeUint32(value.styleId);
}

int _sizeOfStyleSpan(StyleSpan value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

TextStyle _readTextStyle(_BinaryReader reader) {
  return TextStyle(
    color: reader.readInt32(),
    backgroundColor: reader.readInt32(),
    fontStyle: reader.readInt32(),
  );
}

void _writeTextStyle(_BinaryWriter writer, TextStyle value) {
  writer.writeInt32(value.color);
  writer.writeInt32(value.backgroundColor);
  writer.writeInt32(value.fontStyle);
}

int _sizeOfTextStyle(TextStyle value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

void _writeEditorOptions(_BinaryWriter writer, EditorOptions value) {
  writer.writeFloat32(value.touchSlop);
  writer.writeInt64(value.doubleTapTimeout);
  writer.writeInt64(value.longPressMs);
  writer.writeFloat32(value.flingFriction);
  writer.writeFloat32(value.flingMinVelocity);
  writer.writeFloat32(value.flingMaxVelocity);
  writer.writeUint64(value.maxUndoStackSize);
  writer.writeInt64(value.keyChordTimeoutMs);
  writer.writeBoolUint8(value.revealSelectionEndOnSelectAll);
}

int _sizeOfEditorOptions(EditorOptions value) {
  var size = 0;
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

void _writeHandleConfig(_BinaryWriter writer, HandleConfig value) {
  _writeOffsetRect(writer, value.startHitOffset);
  _writeOffsetRect(writer, value.endHitOffset);
}

int _sizeOfHandleConfig(HandleConfig value) {
  var size = 0;
  size += _sizeOfOffsetRect(value.startHitOffset);
  size += _sizeOfOffsetRect(value.endHitOffset);
  return size;
}

void _writeScrollbarConfig(_BinaryWriter writer, ScrollbarConfig value) {
  writer.writeFloat32(value.thickness);
  writer.writeFloat32(value.minThumb);
  writer.writeFloat32(value.thumbHitPadding);
  writer.writeInt32(value.mode.value);
  writer.writeBoolUint8(value.thumbDraggable);
  writer.writeInt32(value.trackTapMode.value);
  writer.writeUint16(value.fadeDelayMs);
  writer.writeUint16(value.fadeDurationMs);
}

int _sizeOfScrollbarConfig(ScrollbarConfig value) {
  var size = 0;
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

IntRange _readIntRange(_BinaryReader reader) {
  return IntRange(
    start: reader.readInt32(),
    end: reader.readInt32(),
  );
}

void _writeIntRange(_BinaryWriter writer, IntRange value) {
  writer.writeInt32(value.start);
  writer.writeInt32(value.end);
}

int _sizeOfIntRange(IntRange value) {
  var size = 0;
  size += 4;
  size += 4;
  return size;
}

OffsetRect _readOffsetRect(_BinaryReader reader) {
  return OffsetRect(
    left: reader.readFloat32(),
    top: reader.readFloat32(),
    right: reader.readFloat32(),
    bottom: reader.readFloat32(),
  );
}

void _writeOffsetRect(_BinaryWriter writer, OffsetRect value) {
  writer.writeFloat32(value.left);
  writer.writeFloat32(value.top);
  writer.writeFloat32(value.right);
  writer.writeFloat32(value.bottom);
}

int _sizeOfOffsetRect(OffsetRect value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

PointF _readPointF(_BinaryReader reader) {
  return PointF(
    x: reader.readFloat32(),
    y: reader.readFloat32(),
  );
}

void _writePointF(_BinaryWriter writer, PointF value) {
  writer.writeFloat32(value.x);
  writer.writeFloat32(value.y);
}

int _sizeOfPointF(PointF value) {
  var size = 0;
  size += 4;
  size += 4;
  return size;
}

Rect _readRect(_BinaryReader reader) {
  return Rect(
    origin: _readPointF(reader),
    width: reader.readFloat32(),
    height: reader.readFloat32(),
  );
}

void _writeRect(_BinaryWriter writer, Rect value) {
  _writePointF(writer, value.origin);
  writer.writeFloat32(value.width);
  writer.writeFloat32(value.height);
}

int _sizeOfRect(Rect value) {
  var size = 0;
  size += _sizeOfPointF(value.origin);
  size += 4;
  size += 4;
  return size;
}

TextChange _readTextChange(_BinaryReader reader) {
  return TextChange(
    range: _readTextRange(reader),
    newText: _readUtf8String(reader),
  );
}

TextPosition _readTextPosition(_BinaryReader reader) {
  return TextPosition(
    line: reader.readInt32(),
    column: reader.readInt32(),
  );
}

void _writeTextPosition(_BinaryWriter writer, TextPosition value) {
  writer.writeInt32(value.line);
  writer.writeInt32(value.column);
}

int _sizeOfTextPosition(TextPosition value) {
  var size = 0;
  size += 4;
  size += 4;
  return size;
}

TextRange _readTextRange(_BinaryReader reader) {
  return TextRange(
    start: _readTextPosition(reader),
    end: _readTextPosition(reader),
  );
}

void _writeTextRange(_BinaryWriter writer, TextRange value) {
  _writeTextPosition(writer, value.start);
  _writeTextPosition(writer, value.end);
}

int _sizeOfTextRange(TextRange value) {
  var size = 0;
  size += _sizeOfTextPosition(value.start);
  size += _sizeOfTextPosition(value.end);
  return size;
}

ImeInputContext _readImeInputContext(_BinaryReader reader) {
  return ImeInputContext(
    id: reader.readUint64(),
    revision: reader.readInt32(),
    documentStartOffset: reader.readInt32(),
    text: _readUtf8String(reader),
    selection: _readImeTextRange(reader),
    hasComposition: reader.readBoolI32(),
    composition: _readImeTextRange(reader),
    kind: ImeInputContextKind.fromValue(reader.readInt32()),
  );
}

ImeSyncSnapshot _readImeSyncSnapshot(_BinaryReader reader) {
  return ImeSyncSnapshot(
    cursor: _readTextPosition(reader),
    selection: _readTextRange(reader),
    hasSelection: reader.readBoolI32(),
    hasComposingSession: reader.readBoolI32(),
    hasVisibleCompositionRange: reader.readBoolI32(),
    visibleCompositionRange: _readTextRange(reader),
    hasPlatformMarkedRange: reader.readBoolI32(),
    platformMarkedRange: _readTextRange(reader),
    preeditStorage: ImePreeditStorage.fromValue(reader.readInt32()),
    contextPolicy: ImeContextPolicy.fromValue(reader.readInt32()),
    clearPlatformPreedit: reader.readBoolI32(),
  );
}

ImeTextRange _readImeTextRange(_BinaryReader reader) {
  return ImeTextRange(
    start: reader.readInt32(),
    end: reader.readInt32(),
  );
}

void _writeImeTextRange(_BinaryWriter writer, ImeTextRange value) {
  writer.writeInt32(value.start);
  writer.writeInt32(value.end);
}

int _sizeOfImeTextRange(ImeTextRange value) {
  var size = 0;
  size += 4;
  size += 4;
  return size;
}

HitTarget _readHitTarget(_BinaryReader reader) {
  return HitTarget(
    type: HitTargetType.fromValue(reader.readInt32()),
    line: reader.readInt32(),
    column: reader.readInt32(),
    iconId: reader.readInt32(),
    colorValue: reader.readInt32(),
  );
}

KeyBinding _readKeyBinding(_BinaryReader reader) {
  return KeyBinding(
    first: _readKeyChord(reader),
    second: _readKeyChord(reader),
    command: reader.readUint32(),
  );
}

void _writeKeyBinding(_BinaryWriter writer, KeyBinding value) {
  _writeKeyChord(writer, value.first);
  _writeKeyChord(writer, value.second);
  writer.writeUint32(value.command);
}

int _sizeOfKeyBinding(KeyBinding value) {
  var size = 0;
  size += _sizeOfKeyChord(value.first);
  size += _sizeOfKeyChord(value.second);
  size += 4;
  return size;
}

KeyChord _readKeyChord(_BinaryReader reader) {
  return KeyChord(
    modifiers: reader.readUint8(),
    keyCode: reader.readUint16(),
  );
}

void _writeKeyChord(_BinaryWriter writer, KeyChord value) {
  writer.writeUint8(value.modifiers);
  writer.writeUint16(value.keyCode);
}

int _sizeOfKeyChord(KeyChord value) {
  var size = 0;
  size += 1;
  size += 2;
  return size;
}

void _writeLinkedEditingModel(_BinaryWriter writer, LinkedEditingModel value) {
  _writeTabStopGroupList(writer, value.groups);
}

int _sizeOfLinkedEditingModel(LinkedEditingModel value) {
  var size = 0;
  size += _sizeOfTabStopGroupList(value.groups);
  return size;
}

void _writeTabStopGroup(_BinaryWriter writer, TabStopGroup value) {
  writer.writeUint32(value.index);
  _writeTextRangeList(writer, value.ranges);
  _writeUtf8String(writer, value.defaultText);
}

int _sizeOfTabStopGroup(TabStopGroup value) {
  var size = 0;
  size += 4;
  size += _sizeOfTextRangeList(value.ranges);
  size += _sizeOfUtf8String(value.defaultText);
  return size;
}

CompositionDecoration _readCompositionDecoration(_BinaryReader reader) {
  return CompositionDecoration(
    active: reader.readBoolI32(),
    rect: _readRect(reader),
  );
}

Cursor _readCursor(_BinaryReader reader) {
  return Cursor(
    textPosition: _readTextPosition(reader),
    position: _readPointF(reader),
    height: reader.readFloat32(),
    visible: reader.readBoolI32(),
    showDragger: reader.readBoolI32(),
  );
}

CursorRect _readCursorRect(_BinaryReader reader) {
  return CursorRect(
    x: reader.readFloat32(),
    y: reader.readFloat32(),
    height: reader.readFloat32(),
  );
}

void _writeCursorRect(_BinaryWriter writer, CursorRect value) {
  writer.writeFloat32(value.x);
  writer.writeFloat32(value.y);
  writer.writeFloat32(value.height);
}

int _sizeOfCursorRect(CursorRect value) {
  var size = 0;
  size += 4;
  size += 4;
  size += 4;
  return size;
}

DiagnosticDecoration _readDiagnosticDecoration(_BinaryReader reader) {
  return DiagnosticDecoration(
    rect: _readRect(reader),
    severity: reader.readInt32(),
  );
}

EditorRenderModel _readEditorRenderModel(_BinaryReader reader) {
  return EditorRenderModel(
    splitX: reader.readFloat32(),
    splitLineVisible: reader.readBoolI32(),
    scrollX: reader.readFloat32(),
    scrollY: reader.readFloat32(),
    viewportWidth: reader.readFloat32(),
    viewportHeight: reader.readFloat32(),
    currentLine: _readPointF(reader),
    currentLineRenderMode: CurrentLineRenderMode.fromValue(reader.readInt32()),
    lines: _readVisualLineList(reader),
    cursor: _readCursor(reader),
    selectionRects: _readRectList(reader),
    selectionStartHandle: _readSelectionHandle(reader),
    selectionEndHandle: _readSelectionHandle(reader),
    compositionDecoration: _readCompositionDecoration(reader),
    guideSegments: _readGuideSegmentList(reader),
    diagnosticDecorations: _readDiagnosticDecorationList(reader),
    maxGutterIcons: reader.readUint32(),
    linkedEditingRects: _readLinkedEditingRectList(reader),
    bracketHighlightRects: _readRectList(reader),
    gutterIcons: _readGutterIconRenderItemList(reader),
    foldMarkers: _readFoldMarkerRenderItemList(reader),
    verticalScrollbar: _readScrollbarModel(reader),
    horizontalScrollbar: _readScrollbarModel(reader),
    gutterSticky: reader.readBoolI32(),
    gutterVisible: reader.readBoolI32(),
    pointerCursorType: PointerCursorType.fromValue(reader.readInt32()),
  );
}

FoldMarkerRenderItem _readFoldMarkerRenderItem(_BinaryReader reader) {
  return FoldMarkerRenderItem(
    logicalLine: reader.readInt32(),
    foldState: FoldState.fromValue(reader.readInt32()),
    rect: _readRect(reader),
  );
}

GuideSegment _readGuideSegment(_BinaryReader reader) {
  return GuideSegment(
    direction: GuideDirection.fromValue(reader.readInt32()),
    type: GuideType.fromValue(reader.readInt32()),
    style: GuideStyle.fromValue(reader.readInt32()),
    start: _readPointF(reader),
    end: _readPointF(reader),
    arrowEnd: reader.readBoolI32(),
  );
}

GutterIconRenderItem _readGutterIconRenderItem(_BinaryReader reader) {
  return GutterIconRenderItem(
    logicalLine: reader.readInt32(),
    iconId: reader.readInt32(),
    rect: _readRect(reader),
  );
}

LayoutMetrics _readLayoutMetrics(_BinaryReader reader) {
  return LayoutMetrics(
    fontHeight: reader.readFloat32(),
    fontAscent: reader.readFloat32(),
    lineSpacingAdd: reader.readFloat32(),
    lineSpacingMult: reader.readFloat32(),
    lineNumberMargin: reader.readFloat32(),
    lineNumberWidth: reader.readFloat32(),
    contentStartPadding: reader.readFloat32(),
    maxGutterIcons: reader.readUint32(),
    inlayHintPadding: reader.readFloat32(),
    inlayHintMargin: reader.readFloat32(),
    foldArrowMode: FoldArrowMode.fromValue(reader.readInt32()),
    hasFoldRegions: reader.readBoolI32(),
    gutterSticky: reader.readBoolI32(),
    gutterVisible: reader.readBoolI32(),
  );
}

LinkedEditingRect _readLinkedEditingRect(_BinaryReader reader) {
  return LinkedEditingRect(
    rect: _readRect(reader),
    isActive: reader.readBoolI32(),
  );
}

ScrollMetrics _readScrollMetrics(_BinaryReader reader) {
  return ScrollMetrics(
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
    canScrollX: reader.readBoolI32(),
    canScrollY: reader.readBoolI32(),
  );
}

ScrollbarModel _readScrollbarModel(_BinaryReader reader) {
  return ScrollbarModel(
    visible: reader.readBoolI32(),
    alpha: reader.readFloat32(),
    thumbActive: reader.readBoolI32(),
    track: _readRect(reader),
    thumb: _readRect(reader),
  );
}

SelectionHandle _readSelectionHandle(_BinaryReader reader) {
  return SelectionHandle(
    position: _readPointF(reader),
    height: reader.readFloat32(),
    visible: reader.readBoolI32(),
  );
}

VisualLine _readVisualLine(_BinaryReader reader) {
  return VisualLine(
    logicalLine: reader.readInt32(),
    wrapIndex: reader.readInt32(),
    lineNumberPosition: _readPointF(reader),
    runs: _readVisualRunList(reader),
    kind: VisualLineKind.fromValue(reader.readInt32()),
    ownsGutterSemantics: reader.readBoolI32(),
    foldState: FoldState.fromValue(reader.readInt32()),
  );
}

VisualRun _readVisualRun(_BinaryReader reader) {
  return VisualRun(
    type: VisualRunType.fromValue(reader.readInt32()),
    x: reader.readFloat32(),
    y: reader.readFloat32(),
    text: _readUtf8String(reader),
    style: _readTextStyle(reader),
    iconId: reader.readInt32(),
    colorValue: reader.readInt32(),
    width: reader.readFloat32(),
    padding: reader.readFloat32(),
    margin: reader.readFloat32(),
    active: reader.readBoolI32(),
  );
}

class CoreProtocol {
  CoreProtocol._();

  static EditorActionResult decodeEditorActionResultFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readEditorActionResult(reader);
  }

  static StyleSpan decodeStyleSpanFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readStyleSpan(reader);
  }

  static TextStyle decodeTextStyleFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readTextStyle(reader);
  }

  static IntRange decodeIntRangeFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readIntRange(reader);
  }

  static OffsetRect decodeOffsetRectFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readOffsetRect(reader);
  }

  static PointF decodePointFFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readPointF(reader);
  }

  static Rect decodeRectFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readRect(reader);
  }

  static TextChange decodeTextChangeFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readTextChange(reader);
  }

  static TextPosition decodeTextPositionFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readTextPosition(reader);
  }

  static TextRange decodeTextRangeFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readTextRange(reader);
  }

  static ImeInputContext decodeImeInputContextFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readImeInputContext(reader);
  }

  static ImeSyncSnapshot decodeImeSyncSnapshotFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readImeSyncSnapshot(reader);
  }

  static ImeTextRange decodeImeTextRangeFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readImeTextRange(reader);
  }

  static HitTarget decodeHitTargetFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readHitTarget(reader);
  }

  static KeyBinding decodeKeyBindingFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readKeyBinding(reader);
  }

  static KeyChord decodeKeyChordFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readKeyChord(reader);
  }

  static CompositionDecoration decodeCompositionDecorationFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readCompositionDecoration(reader);
  }

  static Cursor decodeCursorFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readCursor(reader);
  }

  static CursorRect decodeCursorRectFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readCursorRect(reader);
  }

  static DiagnosticDecoration decodeDiagnosticDecorationFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readDiagnosticDecoration(reader);
  }

  static EditorRenderModel decodeEditorRenderModelFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readEditorRenderModel(reader);
  }

  static FoldMarkerRenderItem decodeFoldMarkerRenderItemFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readFoldMarkerRenderItem(reader);
  }

  static GuideSegment decodeGuideSegmentFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readGuideSegment(reader);
  }

  static GutterIconRenderItem decodeGutterIconRenderItemFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readGutterIconRenderItem(reader);
  }

  static LayoutMetrics decodeLayoutMetricsFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readLayoutMetrics(reader);
  }

  static LinkedEditingRect decodeLinkedEditingRectFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readLinkedEditingRect(reader);
  }

  static ScrollMetrics decodeScrollMetricsFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readScrollMetrics(reader);
  }

  static ScrollbarModel decodeScrollbarModelFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readScrollbarModel(reader);
  }

  static SelectionHandle decodeSelectionHandleFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readSelectionHandle(reader);
  }

  static VisualLine decodeVisualLineFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readVisualLine(reader);
  }

  static VisualRun decodeVisualRunFromPointer(ffi.Pointer<ffi.Uint8> ptr, int size) {
    final reader = _BinaryReader.fromPointer(ptr, size);
    return _readVisualRun(reader);
  }

  static Uint8List encodeBracketGuide(BracketGuide value) {
    final writer = _BinaryWriter(_sizeOfBracketGuide(value));
    _writeBracketGuide(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeCodeLensItem(CodeLensItem value) {
    final writer = _BinaryWriter(_sizeOfCodeLensItem(value));
    _writeCodeLensItem(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeDiagnostic(Diagnostic value) {
    final writer = _BinaryWriter(_sizeOfDiagnostic(value));
    _writeDiagnostic(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeFlowGuide(FlowGuide value) {
    final writer = _BinaryWriter(_sizeOfFlowGuide(value));
    _writeFlowGuide(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeFoldRegion(FoldRegion value) {
    final writer = _BinaryWriter(_sizeOfFoldRegion(value));
    _writeFoldRegion(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeGutterIcon(GutterIcon value) {
    final writer = _BinaryWriter(_sizeOfGutterIcon(value));
    _writeGutterIcon(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeIndentGuide(IndentGuide value) {
    final writer = _BinaryWriter(_sizeOfIndentGuide(value));
    _writeIndentGuide(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeInlayHint(InlayHint value) {
    final writer = _BinaryWriter(_sizeOfInlayHint(value));
    _writeInlayHint(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeLinkSpan(LinkSpan value) {
    final writer = _BinaryWriter(_sizeOfLinkSpan(value));
    _writeLinkSpan(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodePhantomText(PhantomText value) {
    final writer = _BinaryWriter(_sizeOfPhantomText(value));
    _writePhantomText(writer, value);
    return writer.toBytes();
  }

  static void _writeRegisterBatchTextStylesPayloadWire(_BinaryWriter writer, Map<int, TextStyle>? styleByStyleId) {
    final keys = styleByStyleId == null ? <int>[] : (styleByStyleId.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = styleByStyleId![key]!;
      writer.writeUint32(key);
      _writeTextStyle(writer, value);
    }
  }

  static int _sizeOfRegisterBatchTextStylesPayloadWire(Map<int, TextStyle>? styleByStyleId) {
    var size = 0;
    size += 4;
    if (styleByStyleId != null) {
      final keys = styleByStyleId.keys.toList()..sort();
      for (final key in keys) {
        final value = styleByStyleId[key]!;
        size += 4;
        size += _sizeOfTextStyle(value);
      }
    }
    return size;
  }

  static Uint8List encodeRegisterBatchTextStylesPayload(Map<int, TextStyle>? styleByStyleId) {
    final writer = _BinaryWriter(_sizeOfRegisterBatchTextStylesPayloadWire(styleByStyleId));
    _writeRegisterBatchTextStylesPayloadWire(writer, styleByStyleId);
    return writer.toBytes();
  }

  static Uint8List encodeSeparatorGuide(SeparatorGuide value) {
    final writer = _BinaryWriter(_sizeOfSeparatorGuide(value));
    _writeSeparatorGuide(writer, value);
    return writer.toBytes();
  }

  static void _writeSetBatchLineCodeLensPayloadWire(_BinaryWriter writer, Map<int, List<CodeLensItem>>? itemsByLine) {
    final keys = itemsByLine == null ? <int>[] : (itemsByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = itemsByLine![key]!;
      writer.writeUint32(key);
      _writeCodeLensItemList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineCodeLensPayloadWire(Map<int, List<CodeLensItem>>? itemsByLine) {
    var size = 0;
    size += 4;
    if (itemsByLine != null) {
      final keys = itemsByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = itemsByLine[key]!;
        size += 4;
        size += _sizeOfCodeLensItemList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineCodeLensPayload(Map<int, List<CodeLensItem>>? itemsByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineCodeLensPayloadWire(itemsByLine));
    _writeSetBatchLineCodeLensPayloadWire(writer, itemsByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLineDiagnosticsPayloadWire(_BinaryWriter writer, Map<int, List<Diagnostic>>? diagnosticsByLine) {
    final keys = diagnosticsByLine == null ? <int>[] : (diagnosticsByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = diagnosticsByLine![key]!;
      writer.writeUint32(key);
      _writeDiagnosticList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineDiagnosticsPayloadWire(Map<int, List<Diagnostic>>? diagnosticsByLine) {
    var size = 0;
    size += 4;
    if (diagnosticsByLine != null) {
      final keys = diagnosticsByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = diagnosticsByLine[key]!;
        size += 4;
        size += _sizeOfDiagnosticList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineDiagnosticsPayload(Map<int, List<Diagnostic>>? diagnosticsByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineDiagnosticsPayloadWire(diagnosticsByLine));
    _writeSetBatchLineDiagnosticsPayloadWire(writer, diagnosticsByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLineGutterIconsPayloadWire(_BinaryWriter writer, Map<int, List<GutterIcon>>? iconsByLine) {
    final keys = iconsByLine == null ? <int>[] : (iconsByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = iconsByLine![key]!;
      writer.writeUint32(key);
      _writeGutterIconList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineGutterIconsPayloadWire(Map<int, List<GutterIcon>>? iconsByLine) {
    var size = 0;
    size += 4;
    if (iconsByLine != null) {
      final keys = iconsByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = iconsByLine[key]!;
        size += 4;
        size += _sizeOfGutterIconList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineGutterIconsPayload(Map<int, List<GutterIcon>>? iconsByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineGutterIconsPayloadWire(iconsByLine));
    _writeSetBatchLineGutterIconsPayloadWire(writer, iconsByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLineInlayHintsPayloadWire(_BinaryWriter writer, Map<int, List<InlayHint>>? hintsByLine) {
    final keys = hintsByLine == null ? <int>[] : (hintsByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = hintsByLine![key]!;
      writer.writeUint32(key);
      _writeInlayHintList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineInlayHintsPayloadWire(Map<int, List<InlayHint>>? hintsByLine) {
    var size = 0;
    size += 4;
    if (hintsByLine != null) {
      final keys = hintsByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = hintsByLine[key]!;
        size += 4;
        size += _sizeOfInlayHintList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineInlayHintsPayload(Map<int, List<InlayHint>>? hintsByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineInlayHintsPayloadWire(hintsByLine));
    _writeSetBatchLineInlayHintsPayloadWire(writer, hintsByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLineLinksPayloadWire(_BinaryWriter writer, Map<int, List<LinkSpan>>? linksByLine) {
    final keys = linksByLine == null ? <int>[] : (linksByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = linksByLine![key]!;
      writer.writeUint32(key);
      _writeLinkSpanList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineLinksPayloadWire(Map<int, List<LinkSpan>>? linksByLine) {
    var size = 0;
    size += 4;
    if (linksByLine != null) {
      final keys = linksByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = linksByLine[key]!;
        size += 4;
        size += _sizeOfLinkSpanList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineLinksPayload(Map<int, List<LinkSpan>>? linksByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineLinksPayloadWire(linksByLine));
    _writeSetBatchLineLinksPayloadWire(writer, linksByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLinePhantomTextsPayloadWire(_BinaryWriter writer, Map<int, List<PhantomText>>? phantomsByLine) {
    final keys = phantomsByLine == null ? <int>[] : (phantomsByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = phantomsByLine![key]!;
      writer.writeUint32(key);
      _writePhantomTextList(writer, value);
    }
  }

  static int _sizeOfSetBatchLinePhantomTextsPayloadWire(Map<int, List<PhantomText>>? phantomsByLine) {
    var size = 0;
    size += 4;
    if (phantomsByLine != null) {
      final keys = phantomsByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = phantomsByLine[key]!;
        size += 4;
        size += _sizeOfPhantomTextList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLinePhantomTextsPayload(Map<int, List<PhantomText>>? phantomsByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLinePhantomTextsPayloadWire(phantomsByLine));
    _writeSetBatchLinePhantomTextsPayloadWire(writer, phantomsByLine);
    return writer.toBytes();
  }

  static void _writeSetBatchLineSpansPayloadWire(_BinaryWriter writer, SpanLayer layer, Map<int, List<StyleSpan>>? spansByLine) {
    writer.writeInt32(layer.value);
    final keys = spansByLine == null ? <int>[] : (spansByLine.keys.toList()..sort());
    writer.writeInt32(keys.length);
    for (final key in keys) {
      final value = spansByLine![key]!;
      writer.writeUint32(key);
      _writeStyleSpanList(writer, value);
    }
  }

  static int _sizeOfSetBatchLineSpansPayloadWire(SpanLayer layer, Map<int, List<StyleSpan>>? spansByLine) {
    var size = 0;
    size += 4;
    size += 4;
    if (spansByLine != null) {
      final keys = spansByLine.keys.toList()..sort();
      for (final key in keys) {
        final value = spansByLine[key]!;
        size += 4;
        size += _sizeOfStyleSpanList(value);
      }
    }
    return size;
  }

  static Uint8List encodeSetBatchLineSpansPayload(SpanLayer layer, Map<int, List<StyleSpan>>? spansByLine) {
    final writer = _BinaryWriter(_sizeOfSetBatchLineSpansPayloadWire(layer, spansByLine));
    _writeSetBatchLineSpansPayloadWire(writer, layer, spansByLine);
    return writer.toBytes();
  }

  static void _writeSetBracketGuidesPayloadWire(_BinaryWriter writer, List<BracketGuide>? guides) {
    _writeBracketGuideList(writer, guides);
  }

  static int _sizeOfSetBracketGuidesPayloadWire(List<BracketGuide>? guides) {
    var size = 0;
    size += _sizeOfBracketGuideList(guides);
    return size;
  }

  static Uint8List encodeSetBracketGuidesPayload(List<BracketGuide>? guides) {
    final writer = _BinaryWriter(_sizeOfSetBracketGuidesPayloadWire(guides));
    _writeSetBracketGuidesPayloadWire(writer, guides);
    return writer.toBytes();
  }

  static void _writeSetFlowGuidesPayloadWire(_BinaryWriter writer, List<FlowGuide>? guides) {
    _writeFlowGuideList(writer, guides);
  }

  static int _sizeOfSetFlowGuidesPayloadWire(List<FlowGuide>? guides) {
    var size = 0;
    size += _sizeOfFlowGuideList(guides);
    return size;
  }

  static Uint8List encodeSetFlowGuidesPayload(List<FlowGuide>? guides) {
    final writer = _BinaryWriter(_sizeOfSetFlowGuidesPayloadWire(guides));
    _writeSetFlowGuidesPayloadWire(writer, guides);
    return writer.toBytes();
  }

  static void _writeSetFoldRegionsPayloadWire(_BinaryWriter writer, List<FoldRegion>? regions) {
    _writeFoldRegionList(writer, regions);
  }

  static int _sizeOfSetFoldRegionsPayloadWire(List<FoldRegion>? regions) {
    var size = 0;
    size += _sizeOfFoldRegionList(regions);
    return size;
  }

  static Uint8List encodeSetFoldRegionsPayload(List<FoldRegion>? regions) {
    final writer = _BinaryWriter(_sizeOfSetFoldRegionsPayloadWire(regions));
    _writeSetFoldRegionsPayloadWire(writer, regions);
    return writer.toBytes();
  }

  static void _writeSetIndentGuidesPayloadWire(_BinaryWriter writer, List<IndentGuide>? guides) {
    _writeIndentGuideList(writer, guides);
  }

  static int _sizeOfSetIndentGuidesPayloadWire(List<IndentGuide>? guides) {
    var size = 0;
    size += _sizeOfIndentGuideList(guides);
    return size;
  }

  static Uint8List encodeSetIndentGuidesPayload(List<IndentGuide>? guides) {
    final writer = _BinaryWriter(_sizeOfSetIndentGuidesPayloadWire(guides));
    _writeSetIndentGuidesPayloadWire(writer, guides);
    return writer.toBytes();
  }

  static void _writeSetLineCodeLensPayloadWire(_BinaryWriter writer, int line, List<CodeLensItem>? items) {
    writer.writeUint32(line);
    _writeCodeLensItemList(writer, items);
  }

  static int _sizeOfSetLineCodeLensPayloadWire(int line, List<CodeLensItem>? items) {
    var size = 0;
    size += 4;
    size += _sizeOfCodeLensItemList(items);
    return size;
  }

  static Uint8List encodeSetLineCodeLensPayload(int line, List<CodeLensItem>? items) {
    final writer = _BinaryWriter(_sizeOfSetLineCodeLensPayloadWire(line, items));
    _writeSetLineCodeLensPayloadWire(writer, line, items);
    return writer.toBytes();
  }

  static void _writeSetLineDiagnosticsPayloadWire(_BinaryWriter writer, int line, List<Diagnostic>? diagnostics) {
    writer.writeUint32(line);
    _writeDiagnosticList(writer, diagnostics);
  }

  static int _sizeOfSetLineDiagnosticsPayloadWire(int line, List<Diagnostic>? diagnostics) {
    var size = 0;
    size += 4;
    size += _sizeOfDiagnosticList(diagnostics);
    return size;
  }

  static Uint8List encodeSetLineDiagnosticsPayload(int line, List<Diagnostic>? diagnostics) {
    final writer = _BinaryWriter(_sizeOfSetLineDiagnosticsPayloadWire(line, diagnostics));
    _writeSetLineDiagnosticsPayloadWire(writer, line, diagnostics);
    return writer.toBytes();
  }

  static void _writeSetLineGutterIconsPayloadWire(_BinaryWriter writer, int line, List<GutterIcon>? icons) {
    writer.writeUint32(line);
    _writeGutterIconList(writer, icons);
  }

  static int _sizeOfSetLineGutterIconsPayloadWire(int line, List<GutterIcon>? icons) {
    var size = 0;
    size += 4;
    size += _sizeOfGutterIconList(icons);
    return size;
  }

  static Uint8List encodeSetLineGutterIconsPayload(int line, List<GutterIcon>? icons) {
    final writer = _BinaryWriter(_sizeOfSetLineGutterIconsPayloadWire(line, icons));
    _writeSetLineGutterIconsPayloadWire(writer, line, icons);
    return writer.toBytes();
  }

  static void _writeSetLineInlayHintsPayloadWire(_BinaryWriter writer, int line, List<InlayHint>? hints) {
    writer.writeUint32(line);
    _writeInlayHintList(writer, hints);
  }

  static int _sizeOfSetLineInlayHintsPayloadWire(int line, List<InlayHint>? hints) {
    var size = 0;
    size += 4;
    size += _sizeOfInlayHintList(hints);
    return size;
  }

  static Uint8List encodeSetLineInlayHintsPayload(int line, List<InlayHint>? hints) {
    final writer = _BinaryWriter(_sizeOfSetLineInlayHintsPayloadWire(line, hints));
    _writeSetLineInlayHintsPayloadWire(writer, line, hints);
    return writer.toBytes();
  }

  static void _writeSetLineLinksPayloadWire(_BinaryWriter writer, int line, List<LinkSpan>? links) {
    writer.writeUint32(line);
    _writeLinkSpanList(writer, links);
  }

  static int _sizeOfSetLineLinksPayloadWire(int line, List<LinkSpan>? links) {
    var size = 0;
    size += 4;
    size += _sizeOfLinkSpanList(links);
    return size;
  }

  static Uint8List encodeSetLineLinksPayload(int line, List<LinkSpan>? links) {
    final writer = _BinaryWriter(_sizeOfSetLineLinksPayloadWire(line, links));
    _writeSetLineLinksPayloadWire(writer, line, links);
    return writer.toBytes();
  }

  static void _writeSetLinePhantomTextsPayloadWire(_BinaryWriter writer, int line, List<PhantomText>? phantoms) {
    writer.writeUint32(line);
    _writePhantomTextList(writer, phantoms);
  }

  static int _sizeOfSetLinePhantomTextsPayloadWire(int line, List<PhantomText>? phantoms) {
    var size = 0;
    size += 4;
    size += _sizeOfPhantomTextList(phantoms);
    return size;
  }

  static Uint8List encodeSetLinePhantomTextsPayload(int line, List<PhantomText>? phantoms) {
    final writer = _BinaryWriter(_sizeOfSetLinePhantomTextsPayloadWire(line, phantoms));
    _writeSetLinePhantomTextsPayloadWire(writer, line, phantoms);
    return writer.toBytes();
  }

  static void _writeSetLineSpansPayloadWire(_BinaryWriter writer, int line, SpanLayer layer, List<StyleSpan>? spans) {
    writer.writeUint32(line);
    writer.writeInt32(layer.value);
    _writeStyleSpanList(writer, spans);
  }

  static int _sizeOfSetLineSpansPayloadWire(int line, SpanLayer layer, List<StyleSpan>? spans) {
    var size = 0;
    size += 4;
    size += 4;
    size += _sizeOfStyleSpanList(spans);
    return size;
  }

  static Uint8List encodeSetLineSpansPayload(int line, SpanLayer layer, List<StyleSpan>? spans) {
    final writer = _BinaryWriter(_sizeOfSetLineSpansPayloadWire(line, layer, spans));
    _writeSetLineSpansPayloadWire(writer, line, layer, spans);
    return writer.toBytes();
  }

  static void _writeSetSeparatorGuidesPayloadWire(_BinaryWriter writer, List<SeparatorGuide>? guides) {
    _writeSeparatorGuideList(writer, guides);
  }

  static int _sizeOfSetSeparatorGuidesPayloadWire(List<SeparatorGuide>? guides) {
    var size = 0;
    size += _sizeOfSeparatorGuideList(guides);
    return size;
  }

  static Uint8List encodeSetSeparatorGuidesPayload(List<SeparatorGuide>? guides) {
    final writer = _BinaryWriter(_sizeOfSetSeparatorGuidesPayloadWire(guides));
    _writeSetSeparatorGuidesPayloadWire(writer, guides);
    return writer.toBytes();
  }

  static Uint8List encodeEditorOptions(EditorOptions value) {
    final writer = _BinaryWriter(_sizeOfEditorOptions(value));
    _writeEditorOptions(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeHandleConfig(HandleConfig value) {
    final writer = _BinaryWriter(_sizeOfHandleConfig(value));
    _writeHandleConfig(writer, value);
    return writer.toBytes();
  }

  static Uint8List encodeScrollbarConfig(ScrollbarConfig value) {
    final writer = _BinaryWriter(_sizeOfScrollbarConfig(value));
    _writeScrollbarConfig(writer, value);
    return writer.toBytes();
  }

  static void _writeSetKeyMapPayloadWire(_BinaryWriter writer, List<KeyBinding>? bindings) {
    _writeKeyBindingList(writer, bindings);
  }

  static int _sizeOfSetKeyMapPayloadWire(List<KeyBinding>? bindings) {
    var size = 0;
    size += _sizeOfKeyBindingList(bindings);
    return size;
  }

  static Uint8List encodeSetKeyMapPayload(List<KeyBinding>? bindings) {
    final writer = _BinaryWriter(_sizeOfSetKeyMapPayloadWire(bindings));
    _writeSetKeyMapPayloadWire(writer, bindings);
    return writer.toBytes();
  }

  static Uint8List encodeLinkedEditingModel(LinkedEditingModel value) {
    final writer = _BinaryWriter(_sizeOfLinkedEditingModel(value));
    _writeLinkedEditingModel(writer, value);
    return writer.toBytes();
  }

  static void _writeStartLinkedEditingPayloadWire(_BinaryWriter writer, LinkedEditingModel model) {
    _writeLinkedEditingModel(writer, model);
  }

  static int _sizeOfStartLinkedEditingPayloadWire(LinkedEditingModel model) {
    var size = 0;
    size += _sizeOfLinkedEditingModel(model);
    return size;
  }

  static Uint8List encodeStartLinkedEditingPayload(LinkedEditingModel model) {
    final writer = _BinaryWriter(_sizeOfStartLinkedEditingPayloadWire(model));
    _writeStartLinkedEditingPayloadWire(writer, model);
    return writer.toBytes();
  }

  static Uint8List encodeTabStopGroup(TabStopGroup value) {
    final writer = _BinaryWriter(_sizeOfTabStopGroup(value));
    _writeTabStopGroup(writer, value);
    return writer.toBytes();
  }
}
