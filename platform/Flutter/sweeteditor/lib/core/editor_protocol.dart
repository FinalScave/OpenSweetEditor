part of '../editor_core.dart';

class _BinaryReader {
  _BinaryReader(this._ptr, this._size)
    : _data = ByteData.sublistView(_ptr.asTypedList(_size));

  final ffi.Pointer<ffi.Uint8> _ptr;
  final int _size;
  final ByteData _data;
  int _offset = 0;

  bool hasRemaining([int bytes = 1]) => _offset + bytes <= _size;

  int readInt32() {
    final v = _data.getInt32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  double readFloat32() {
    final v = _data.getFloat32(_offset, Endian.little);
    _offset += 4;
    return v;
  }

  PointF readPoint() => PointF(x: readFloat32(), y: readFloat32());

  TextPosition readTextPosition() => TextPosition(readInt32(), readInt32());

  TextRange readTextRange() =>
      TextRange(readTextPosition(), readTextPosition());

  TextStyle readTextStyle() => TextStyle(
    color: readInt32(),
    backgroundColor: readInt32(),
    fontStyle: readInt32(),
  );

  String readUtf8String() {
    final len = readInt32();
    if (len <= 0) return '';
    final bytes = _ptr.asTypedList(_size).sublist(_offset, _offset + len);
    _offset += len;
    return utf8.decode(bytes);
  }
}

class ProtocolEncoder {
  ProtocolEncoder._();

  static Uint8List packBatchTextStyles(Map<int, TextStyle> stylesById) {
    final keys = stylesById.keys.toList()..sort();
    final data = ByteData(4 + keys.length * 16);
    var offset = 0;
    data.setInt32(offset, keys.length, Endian.little);
    offset += 4;
    for (final key in keys) {
      final style = stylesById[key]!;
      data.setInt32(offset, key, Endian.little);
      offset += 4;
      data.setInt32(offset, style.color, Endian.little);
      offset += 4;
      data.setInt32(offset, style.backgroundColor, Endian.little);
      offset += 4;
      data.setInt32(offset, style.fontStyle, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packLineSpans(int line, int layer, List<StyleSpan> spans) {
    final data = ByteData(12 + spans.length * 12);
    var offset = 0;
    data.setInt32(offset, line, Endian.little);
    offset += 4;
    data.setInt32(offset, layer, Endian.little);
    offset += 4;
    data.setInt32(offset, spans.length, Endian.little);
    offset += 4;
    for (final s in spans) {
      data.setInt32(offset, s.column, Endian.little);
      offset += 4;
      data.setInt32(offset, s.length, Endian.little);
      offset += 4;
      data.setInt32(offset, s.styleId, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBatchLineSpans(
    int layer,
    Map<int, List<StyleSpan>> spansByLine,
  ) {
    var totalSpans = 0;
    spansByLine.forEach((_, spans) => totalSpans += spans.length);
    final data = ByteData(8 + spansByLine.length * 8 + totalSpans * 12);
    var offset = 0;
    data.setInt32(offset, layer, Endian.little);
    offset += 4;
    data.setInt32(offset, spansByLine.length, Endian.little);
    offset += 4;
    spansByLine.forEach((line, spans) {
      data.setInt32(offset, line, Endian.little);
      offset += 4;
      data.setInt32(offset, spans.length, Endian.little);
      offset += 4;
      for (final s in spans) {
        data.setInt32(offset, s.column, Endian.little);
        offset += 4;
        data.setInt32(offset, s.length, Endian.little);
        offset += 4;
        data.setInt32(offset, s.styleId, Endian.little);
        offset += 4;
      }
    });
    return data.buffer.asUint8List();
  }

  static Uint8List packLineInlayHints(int line, List<InlayHint> hints) {
    final textBytesList = <Uint8List>[];
    var textBlobSize = 0;
    for (final h in hints) {
      if (h.type == InlayType.text && h.text != null) {
        final bytes = Uint8List.fromList(h.text!.codeUnits);
        textBytesList.add(bytes);
        textBlobSize += bytes.length;
      } else {
        textBytesList.add(Uint8List(0));
      }
    }
    final data = ByteData(8 + hints.length * 16 + textBlobSize);
    var offset = 0;
    data.setInt32(offset, line, Endian.little);
    offset += 4;
    data.setInt32(offset, hints.length, Endian.little);
    offset += 4;
    for (var i = 0; i < hints.length; i++) {
      final h = hints[i];
      data.setInt32(offset, h.type.value, Endian.little);
      offset += 4;
      data.setInt32(offset, h.column, Endian.little);
      offset += 4;
      data.setInt32(offset, h.intValue, Endian.little);
      offset += 4;
      final tb = textBytesList[i];
      data.setInt32(offset, tb.length, Endian.little);
      offset += 4;
      if (tb.isNotEmpty) {
        data.buffer.asUint8List().setAll(offset, tb);
        offset += tb.length;
      }
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBatchLineInlayHints(
    Map<int, List<InlayHint>> hintsByLine,
  ) {
    final allTextBytes = <int, List<Uint8List>>{};
    var totalSize = 4;
    hintsByLine.forEach((line, hints) {
      totalSize += 8;
      final lineTextBytes = <Uint8List>[];
      for (final h in hints) {
        if (h.type == InlayType.text && h.text != null) {
          final bytes = Uint8List.fromList(h.text!.codeUnits);
          lineTextBytes.add(bytes);
          totalSize += 16 + bytes.length;
        } else {
          lineTextBytes.add(Uint8List(0));
          totalSize += 16;
        }
      }
      allTextBytes[line] = lineTextBytes;
    });
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, hintsByLine.length, Endian.little);
    offset += 4;
    hintsByLine.forEach((line, hints) {
      buf.setInt32(offset, line, Endian.little);
      offset += 4;
      buf.setInt32(offset, hints.length, Endian.little);
      offset += 4;
      final lineTextBytes = allTextBytes[line]!;
      for (var i = 0; i < hints.length; i++) {
        final h = hints[i];
        buf.setInt32(offset, h.type.value, Endian.little);
        offset += 4;
        buf.setInt32(offset, h.column, Endian.little);
        offset += 4;
        buf.setInt32(offset, h.intValue, Endian.little);
        offset += 4;
        final tb = lineTextBytes[i];
        buf.setInt32(offset, tb.length, Endian.little);
        offset += 4;
        if (tb.isNotEmpty) {
          buf.buffer.asUint8List().setAll(offset, tb);
          offset += tb.length;
        }
      }
    });
    return buf.buffer.asUint8List();
  }

  static Uint8List packLinePhantomTexts(int line, List<PhantomText> phantoms) {
    final textBytesList = <Uint8List>[];
    var textBlobSize = 0;
    for (final p in phantoms) {
      final bytes = Uint8List.fromList(p.text.codeUnits);
      textBytesList.add(bytes);
      textBlobSize += bytes.length;
    }
    final data = ByteData(8 + phantoms.length * 8 + textBlobSize);
    var offset = 0;
    data.setInt32(offset, line, Endian.little);
    offset += 4;
    data.setInt32(offset, phantoms.length, Endian.little);
    offset += 4;
    for (var i = 0; i < phantoms.length; i++) {
      data.setInt32(offset, phantoms[i].column, Endian.little);
      offset += 4;
      final tb = textBytesList[i];
      data.setInt32(offset, tb.length, Endian.little);
      offset += 4;
      if (tb.isNotEmpty) {
        data.buffer.asUint8List().setAll(offset, tb);
        offset += tb.length;
      }
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBatchLinePhantomTexts(
    Map<int, List<PhantomText>> phantomsByLine,
  ) {
    final allTextBytes = <int, List<Uint8List>>{};
    var totalSize = 4;
    phantomsByLine.forEach((line, phantoms) {
      totalSize += 8;
      final lineTextBytes = <Uint8List>[];
      for (final p in phantoms) {
        final bytes = Uint8List.fromList(p.text.codeUnits);
        lineTextBytes.add(bytes);
        totalSize += 8 + bytes.length;
      }
      allTextBytes[line] = lineTextBytes;
    });
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, phantomsByLine.length, Endian.little);
    offset += 4;
    phantomsByLine.forEach((line, phantoms) {
      buf.setInt32(offset, line, Endian.little);
      offset += 4;
      buf.setInt32(offset, phantoms.length, Endian.little);
      offset += 4;
      final lineTextBytes = allTextBytes[line]!;
      for (var i = 0; i < phantoms.length; i++) {
        buf.setInt32(offset, phantoms[i].column, Endian.little);
        offset += 4;
        final tb = lineTextBytes[i];
        buf.setInt32(offset, tb.length, Endian.little);
        offset += 4;
        if (tb.isNotEmpty) {
          buf.buffer.asUint8List().setAll(offset, tb);
          offset += tb.length;
        }
      }
    });
    return buf.buffer.asUint8List();
  }

  static Uint8List packLineGutterIcons(int line, List<GutterIcon> icons) {
    final data = ByteData(8 + icons.length * 4);
    var offset = 0;
    data.setInt32(offset, line, Endian.little);
    offset += 4;
    data.setInt32(offset, icons.length, Endian.little);
    offset += 4;
    for (final icon in icons) {
      data.setInt32(offset, icon.iconId, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBatchLineGutterIcons(
    Map<int, List<GutterIcon>> iconsByLine,
  ) {
    var totalIcons = 0;
    iconsByLine.forEach((_, icons) => totalIcons += icons.length);
    final data = ByteData(4 + iconsByLine.length * 8 + totalIcons * 4);
    var offset = 0;
    data.setInt32(offset, iconsByLine.length, Endian.little);
    offset += 4;
    iconsByLine.forEach((line, icons) {
      data.setInt32(offset, line, Endian.little);
      offset += 4;
      data.setInt32(offset, icons.length, Endian.little);
      offset += 4;
      for (final icon in icons) {
        data.setInt32(offset, icon.iconId, Endian.little);
        offset += 4;
      }
    });
    return data.buffer.asUint8List();
  }

  static Uint8List packLineCodeLens(int line, List<CodeLensItem> items) {
    final allTextBytes = <Uint8List>[];
    var totalSize = 8; // line(4) + count(4)
    for (final item in items) {
      final tb = utf8.encode(item.text);
      allTextBytes.add(tb);
      totalSize +=
          12 + tb.length; // column(4) + command_id(4) + text_len(4) + text
    }
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, line, Endian.little);
    offset += 4;
    buf.setInt32(offset, items.length, Endian.little);
    offset += 4;
    for (var i = 0; i < items.length; i++) {
      buf.setInt32(offset, items[i].column, Endian.little);
      offset += 4;
      buf.setInt32(offset, items[i].commandId, Endian.little);
      offset += 4;
      final tb = allTextBytes[i];
      buf.setInt32(offset, tb.length, Endian.little);
      offset += 4;
      if (tb.isNotEmpty) {
        buf.buffer.asUint8List().setAll(offset, tb);
        offset += tb.length;
      }
    }
    return buf.buffer.asUint8List();
  }

  static Uint8List packBatchLineCodeLens(
    Map<int, List<CodeLensItem>> itemsByLine,
  ) {
    final allTextBytes = <int, List<Uint8List>>{};
    var totalSize = 4; // entry_count(4)
    itemsByLine.forEach((line, items) {
      totalSize += 8; // line(4) + item_count(4)
      final lineTexts = <Uint8List>[];
      for (final item in items) {
        final tb = utf8.encode(item.text);
        lineTexts.add(tb);
        totalSize += 12 + tb.length;
      }
      allTextBytes[line] = lineTexts;
    });
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, itemsByLine.length, Endian.little);
    offset += 4;
    itemsByLine.forEach((line, items) {
      buf.setInt32(offset, line, Endian.little);
      offset += 4;
      buf.setInt32(offset, items.length, Endian.little);
      offset += 4;
      final lineTexts = allTextBytes[line]!;
      for (var i = 0; i < items.length; i++) {
        buf.setInt32(offset, items[i].column, Endian.little);
        offset += 4;
        buf.setInt32(offset, items[i].commandId, Endian.little);
        offset += 4;
        final tb = lineTexts[i];
        buf.setInt32(offset, tb.length, Endian.little);
        offset += 4;
        if (tb.isNotEmpty) {
          buf.buffer.asUint8List().setAll(offset, tb);
          offset += tb.length;
        }
      }
    });
    return buf.buffer.asUint8List();
  }

  static Uint8List packLineLinks(int line, List<LinkSpan> links) {
    final allTargetBytes = <Uint8List>[];
    var totalSize = 8;
    for (final link in links) {
      final tb = Uint8List.fromList(utf8.encode(link.target));
      allTargetBytes.add(tb);
      totalSize += 12 + tb.length;
    }
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, line, Endian.little);
    offset += 4;
    buf.setInt32(offset, links.length, Endian.little);
    offset += 4;
    for (var i = 0; i < links.length; i++) {
      final link = links[i];
      buf.setInt32(offset, link.column, Endian.little);
      offset += 4;
      buf.setInt32(offset, link.length, Endian.little);
      offset += 4;
      final tb = allTargetBytes[i];
      buf.setInt32(offset, tb.length, Endian.little);
      offset += 4;
      if (tb.isNotEmpty) {
        buf.buffer.asUint8List().setAll(offset, tb);
        offset += tb.length;
      }
    }
    return buf.buffer.asUint8List();
  }

  static Uint8List packBatchLineLinks(Map<int, List<LinkSpan>> linksByLine) {
    final allTargetBytes = <int, List<Uint8List>>{};
    var totalSize = 4;
    linksByLine.forEach((line, links) {
      totalSize += 8;
      final lineTargets = <Uint8List>[];
      for (final link in links) {
        final tb = Uint8List.fromList(utf8.encode(link.target));
        lineTargets.add(tb);
        totalSize += 12 + tb.length;
      }
      allTargetBytes[line] = lineTargets;
    });
    final buf = ByteData(totalSize);
    var offset = 0;
    buf.setInt32(offset, linksByLine.length, Endian.little);
    offset += 4;
    linksByLine.forEach((line, links) {
      buf.setInt32(offset, line, Endian.little);
      offset += 4;
      buf.setInt32(offset, links.length, Endian.little);
      offset += 4;
      final lineTargets = allTargetBytes[line]!;
      for (var i = 0; i < links.length; i++) {
        final link = links[i];
        buf.setInt32(offset, link.column, Endian.little);
        offset += 4;
        buf.setInt32(offset, link.length, Endian.little);
        offset += 4;
        final tb = lineTargets[i];
        buf.setInt32(offset, tb.length, Endian.little);
        offset += 4;
        if (tb.isNotEmpty) {
          buf.buffer.asUint8List().setAll(offset, tb);
          offset += tb.length;
        }
      }
    });
    return buf.buffer.asUint8List();
  }

  static Uint8List packLineDiagnostics(int line, List<Diagnostic> items) {
    final data = ByteData(8 + items.length * 12);
    var offset = 0;
    data.setInt32(offset, line, Endian.little);
    offset += 4;
    data.setInt32(offset, items.length, Endian.little);
    offset += 4;
    for (final d in items) {
      data.setInt32(offset, d.column, Endian.little);
      offset += 4;
      data.setInt32(offset, d.length, Endian.little);
      offset += 4;
      data.setInt32(offset, d.severity, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBatchLineDiagnostics(
    Map<int, List<Diagnostic>> diagsByLine,
  ) {
    var totalDiags = 0;
    diagsByLine.forEach((_, items) => totalDiags += items.length);
    final data = ByteData(4 + diagsByLine.length * 8 + totalDiags * 12);
    var offset = 0;
    data.setInt32(offset, diagsByLine.length, Endian.little);
    offset += 4;
    diagsByLine.forEach((line, items) {
      data.setInt32(offset, line, Endian.little);
      offset += 4;
      data.setInt32(offset, items.length, Endian.little);
      offset += 4;
      for (final d in items) {
        data.setInt32(offset, d.column, Endian.little);
        offset += 4;
        data.setInt32(offset, d.length, Endian.little);
        offset += 4;
        data.setInt32(offset, d.severity, Endian.little);
        offset += 4;
      }
    });
    return data.buffer.asUint8List();
  }

  static Uint8List packFoldRegions(List<FoldRegion> regions) {
    final data = ByteData(4 + regions.length * 8);
    var offset = 0;
    data.setInt32(offset, regions.length, Endian.little);
    offset += 4;
    for (final r in regions) {
      data.setInt32(offset, r.startLine, Endian.little);
      offset += 4;
      data.setInt32(offset, r.endLine, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packIndentGuides(List<IndentGuide> guides) {
    final data = ByteData(4 + guides.length * 16);
    var offset = 0;
    data.setInt32(offset, guides.length, Endian.little);
    offset += 4;
    for (final g in guides) {
      data.setInt32(offset, g.start.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.start.column, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.column, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packBracketGuides(List<BracketGuide> guides) {
    var totalChildren = 0;
    for (final g in guides) {
      totalChildren += g.children.length;
    }
    final data = ByteData(4 + guides.length * 20 + totalChildren * 8);
    var offset = 0;
    data.setInt32(offset, guides.length, Endian.little);
    offset += 4;
    for (final g in guides) {
      data.setInt32(offset, g.parent.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.parent.column, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.column, Endian.little);
      offset += 4;
      data.setInt32(offset, g.children.length, Endian.little);
      offset += 4;
      for (final c in g.children) {
        data.setInt32(offset, c.line, Endian.little);
        offset += 4;
        data.setInt32(offset, c.column, Endian.little);
        offset += 4;
      }
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packFlowGuides(List<FlowGuide> guides) {
    final data = ByteData(4 + guides.length * 16);
    var offset = 0;
    data.setInt32(offset, guides.length, Endian.little);
    offset += 4;
    for (final g in guides) {
      data.setInt32(offset, g.start.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.start.column, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.end.column, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packSeparatorGuides(List<SeparatorGuide> guides) {
    final data = ByteData(4 + guides.length * 16);
    var offset = 0;
    data.setInt32(offset, guides.length, Endian.little);
    offset += 4;
    for (final g in guides) {
      data.setInt32(offset, g.line, Endian.little);
      offset += 4;
      data.setInt32(offset, g.style.value, Endian.little);
      offset += 4;
      data.setInt32(offset, g.count, Endian.little);
      offset += 4;
      data.setInt32(offset, g.textEndColumn, Endian.little);
      offset += 4;
    }
    return data.buffer.asUint8List();
  }

  static Uint8List packLinkedEditingModel(LinkedEditingModel model) {
    final groups = model.groups;
    var rangeCount = 0;
    final groupTextBytes = <Uint8List?>[];
    var stringBlobSize = 0;
    for (final group in groups) {
      rangeCount += group.ranges.length;
      if (group.defaultText != null) {
        final bytes = Uint8List.fromList(group.defaultText!.codeUnits);
        groupTextBytes.add(bytes);
        stringBlobSize += bytes.length;
      } else {
        groupTextBytes.add(null);
      }
    }
    final data = ByteData(
      12 + groups.length * 12 + rangeCount * 20 + stringBlobSize,
    );
    var offset = 0;
    data.setInt32(offset, groups.length, Endian.little);
    offset += 4;
    data.setInt32(offset, rangeCount, Endian.little);
    offset += 4;
    data.setInt32(offset, stringBlobSize, Endian.little);
    offset += 4;
    var textOffset = 0;
    for (var i = 0; i < groups.length; i++) {
      data.setInt32(offset, groups[i].index, Endian.little);
      offset += 4;
      final bytes = groupTextBytes[i];
      if (bytes == null) {
        data.setUint32(offset, 0xFFFFFFFF, Endian.little);
        offset += 4;
        data.setInt32(offset, 0, Endian.little);
        offset += 4;
      } else {
        data.setInt32(offset, textOffset, Endian.little);
        offset += 4;
        data.setInt32(offset, bytes.length, Endian.little);
        offset += 4;
        textOffset += bytes.length;
      }
    }
    for (var gi = 0; gi < groups.length; gi++) {
      for (final range in groups[gi].ranges) {
        data.setInt32(offset, gi, Endian.little);
        offset += 4;
        data.setInt32(offset, range.startLine, Endian.little);
        offset += 4;
        data.setInt32(offset, range.startColumn, Endian.little);
        offset += 4;
        data.setInt32(offset, range.endLine, Endian.little);
        offset += 4;
        data.setInt32(offset, range.endColumn, Endian.little);
        offset += 4;
      }
    }
    for (final bytes in groupTextBytes) {
      if (bytes != null && bytes.isNotEmpty) {
        data.buffer.asUint8List().setAll(offset, bytes);
        offset += bytes.length;
      }
    }
    return data.buffer.asUint8List();
  }
}

class ProtocolDecoder {
  ProtocolDecoder._();

  static TextEditResult decodeTextEditResult(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return TextEditResult.empty;
    final r = _BinaryReader(ptr, size);
    final changed = r.readInt32();
    if (changed == 0) return TextEditResult.empty;
    return _readTextEditResultBody(r);
  }

  static ImeActionResult decodeImeActionResult(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return ImeActionResult.empty;
    final r = _BinaryReader(ptr, size);
    final handled = r.readInt32() != 0;
    final contentChanged = r.readInt32() != 0;
    final cursorChanged = r.readInt32() != 0;
    final selectionChanged = r.readInt32() != 0;
    final hasEdit = r.readInt32() != 0;
    var editResult = TextEditResult.empty;
    if (hasEdit) {
      editResult = _readTextEditResultBody(r);
    }
    return ImeActionResult(
      handled: handled,
      contentChanged: contentChanged,
      cursorChanged: cursorChanged,
      selectionChanged: selectionChanged,
      editResult: editResult,
      sync: _readImeSyncSnapshot(r),
    );
  }

  static ImeSyncSnapshot decodeImeSyncSnapshot(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return ImeSyncSnapshot.empty;
    return _readImeSyncSnapshot(_BinaryReader(ptr, size));
  }

  static KeyEventResult decodeKeyEventResult(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return KeyEventResult.empty;
    final r = _BinaryReader(ptr, size);
    final handled = r.readInt32() != 0;
    final contentChanged = r.readInt32() != 0;
    final cursorChanged = r.readInt32() != 0;
    final selectionChanged = r.readInt32() != 0;
    final hasEdit = r.readInt32() != 0;
    TextEditResult? editResult;
    if (hasEdit) {
      editResult = _readTextEditResultBody(r);
    }
    final command = r.hasRemaining(4) ? r.readInt32() : EditorCommand.none;
    return KeyEventResult(
      handled: handled,
      contentChanged: contentChanged,
      cursorChanged: cursorChanged,
      selectionChanged: selectionChanged,
      editResult: editResult,
      command: command,
    );
  }

  static TextEditResult _readTextEditResultBody(_BinaryReader r) {
    final count = r.readInt32();
    final changes = <TextChange>[];
    for (var i = 0; i < count; i++) {
      final range = r.readTextRange();
      changes.add(TextChange(range, r.readUtf8String()));
    }
    return TextEditResult(changed: true, changes: changes);
  }

  static ImeSyncSnapshot _readImeSyncSnapshot(_BinaryReader r) {
    return ImeSyncSnapshot(
      cursor: r.readTextPosition(),
      hasSelection: r.readInt32() != 0,
      selection: r.readTextRange(),
      hasComposingSession: r.readInt32() != 0,
      hasVisibleCompositionRange: r.readInt32() != 0,
      visibleCompositionRange: r.readTextRange(),
      hasPlatformMarkedRange: r.readInt32() != 0,
      platformMarkedRange: r.readTextRange(),
      platformTextWindowText: r.readUtf8String(),
      platformTextWindowStartOffset: r.readInt32(),
      platformTextWindowSelectionStartOffset: r.readInt32(),
      platformTextWindowSelectionEndOffset: r.readInt32(),
      platformTextWindowComposingStartOffset: r.readInt32(),
      platformTextWindowComposingEndOffset: r.readInt32(),
      preeditStorage: ImePreeditStorage.fromValue(r.readInt32()),
      contextPolicy: ImeContextPolicy.fromValue(r.readInt32()),
      clearPlatformPreedit: r.readInt32() != 0,
    );
  }

  static GestureResult decodeGestureResult(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return GestureResult.empty;
    final r = _BinaryReader(ptr, size);
    final gestureTypeValue = r.readInt32();
    final gestureType = GestureType.fromValue(gestureTypeValue);
    var tapPoint = const PointF();
    if (gestureType == GestureType.tap ||
        gestureType == GestureType.doubleTap ||
        gestureType == GestureType.longPress ||
        gestureType == GestureType.dragSelect ||
        gestureType == GestureType.contextMenu) {
      tapPoint = r.readPoint();
    }
    final cursorPosition = r.readTextPosition();
    final hasSelection = r.readInt32() != 0;
    final selection = TextRange(r.readTextPosition(), r.readTextPosition());
    final viewScrollX = r.readFloat32();
    final viewScrollY = r.readFloat32();
    final viewScale = r.readFloat32();
    var hitTarget = const HitTarget();
    if (r.hasRemaining(20)) {
      hitTarget = HitTarget(
        type: HitTargetType.fromValue(r.readInt32()),
        line: r.readInt32(),
        column: r.readInt32(),
        iconId: r.readInt32(),
        colorValue: r.readInt32(),
      );
    }
    var needsEdgeScroll = false;
    if (r.hasRemaining(4)) needsEdgeScroll = r.readInt32() != 0;
    var needsFling = false;
    if (r.hasRemaining(4)) needsFling = r.readInt32() != 0;
    var needsAnimation = false;
    if (r.hasRemaining(4)) needsAnimation = r.readInt32() != 0;
    var isHandleDrag = false;
    if (r.hasRemaining(4)) isHandleDrag = r.readInt32() != 0;
    var pointerCursorType = PointerCursorType.text;
    if (r.hasRemaining(4)) {
      pointerCursorType = PointerCursorType.fromValue(r.readInt32());
    }
    return GestureResult(
      type: gestureType,
      tapPoint: tapPoint,
      cursorPosition: cursorPosition,
      hasSelection: hasSelection,
      selection: selection,
      viewScrollX: viewScrollX,
      viewScrollY: viewScrollY,
      viewScale: viewScale,
      hitTarget: hitTarget,
      needsEdgeScroll: needsEdgeScroll,
      needsFling: needsFling,
      needsAnimation: needsAnimation,
      isHandleDrag: isHandleDrag,
      pointerCursorType: pointerCursorType,
    );
  }

  static ScrollMetrics decodeScrollMetrics(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size < 52) return ScrollMetrics.empty;
    final r = _BinaryReader(ptr, size);
    return ScrollMetrics(
      scale: r.readFloat32(),
      scrollX: r.readFloat32(),
      scrollY: r.readFloat32(),
      maxScrollX: r.readFloat32(),
      maxScrollY: r.readFloat32(),
      contentWidth: r.readFloat32(),
      contentHeight: r.readFloat32(),
      viewportWidth: r.readFloat32(),
      viewportHeight: r.readFloat32(),
      textAreaX: r.readFloat32(),
      textAreaWidth: r.readFloat32(),
      canScrollX: r.readInt32() != 0,
      canScrollY: r.readInt32() != 0,
    );
  }

  static LayoutMetrics decodeLayoutMetrics(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size < 44) return LayoutMetrics.empty;
    final r = _BinaryReader(ptr, size);
    return LayoutMetrics(
      fontHeight: r.readFloat32(),
      fontAscent: r.readFloat32(),
      lineSpacingAdd: r.readFloat32(),
      lineSpacingMult: r.readFloat32(),
      lineNumberMargin: r.readFloat32(),
      lineNumberWidth: r.readFloat32(),
      maxGutterIcons: r.readInt32(),
      inlayHintPadding: r.readFloat32(),
      inlayHintMargin: r.readFloat32(),
      foldArrowMode: FoldArrowMode.values.firstWhere(
        (mode) => mode.value == r.readInt32(),
        orElse: () => FoldArrowMode.always,
      ),
      hasFoldRegions: r.readInt32() != 0,
    );
  }

  static EditorRenderModel decodeRenderModel(
    ffi.Pointer<ffi.Uint8> ptr,
    int size,
  ) {
    if (ptr == ffi.nullptr || size == 0) return EditorRenderModel.empty;
    final r = _BinaryReader(ptr, size);

    final splitX = r.readFloat32();
    final splitLineVisible = r.readInt32() != 0;
    final scrollX = r.readFloat32();
    final scrollY = r.readFloat32();
    final viewportWidth = r.readFloat32();
    final viewportHeight = r.readFloat32();
    final currentLine = r.readPoint();
    final currentLineRenderMode = r.readInt32();

    final lineCount = r.readInt32();
    final visualLines = <VisualLine>[];
    for (var i = 0; i < lineCount; i++) {
      visualLines.add(_readVisualLine(r));
    }

    final gutterIconCount = r.readInt32();
    final gutterIcons = <GutterIconRenderItem>[];
    for (var i = 0; i < gutterIconCount; i++) {
      gutterIcons.add(_readGutterIconRenderItem(r));
    }

    final foldMarkerCount = r.readInt32();
    final foldMarkers = <FoldMarkerRenderItem>[];
    for (var i = 0; i < foldMarkerCount; i++) {
      foldMarkers.add(_readFoldMarkerRenderItem(r));
    }

    final cursor = _readCursor(r);

    final selRectCount = r.readInt32();
    final selectionRects = <SelectionRect>[];
    for (var i = 0; i < selRectCount; i++) {
      selectionRects.add(_readSelectionRect(r));
    }

    final selectionStartHandle = _readSelectionHandle(r);
    final selectionEndHandle = _readSelectionHandle(r);
    final compositionDecoration = _readCompositionDecoration(r);

    final guideCount = r.readInt32();
    final guideSegments = <GuideSegment>[];
    for (var i = 0; i < guideCount; i++) {
      guideSegments.add(_readGuideSegment(r));
    }

    final diagCount = r.readInt32();
    final diagnosticDecorations = <DiagnosticDecoration>[];
    for (var i = 0; i < diagCount; i++) {
      diagnosticDecorations.add(_readDiagnosticDecoration(r));
    }

    final maxGutterIcons = r.readInt32();

    final linkedRectCount = r.readInt32();
    final linkedEditingRects = <LinkedEditingRect>[];
    for (var i = 0; i < linkedRectCount; i++) {
      linkedEditingRects.add(_readLinkedEditingRect(r));
    }

    final bracketRectCount = r.readInt32();
    final bracketHighlightRects = <BracketHighlightRect>[];
    for (var i = 0; i < bracketRectCount; i++) {
      bracketHighlightRects.add(_readBracketHighlightRect(r));
    }

    var verticalScrollbar = const ScrollbarModel();
    var horizontalScrollbar = const ScrollbarModel();
    if (r.hasRemaining(88)) {
      verticalScrollbar = _readScrollbarModel(r);
      horizontalScrollbar = _readScrollbarModel(r);
    }

    var gutterSticky = true;
    if (r.hasRemaining(4)) {
      gutterSticky = r.readInt32() != 0;
    }

    var gutterVisible = true;
    if (r.hasRemaining(4)) {
      gutterVisible = r.readInt32() != 0;
    }

    var pointerCursorType = PointerCursorType.text;
    if (r.hasRemaining(4)) {
      pointerCursorType = PointerCursorType.fromValue(r.readInt32());
    }

    return EditorRenderModel(
      splitX: splitX,
      splitLineVisible: splitLineVisible,
      scrollX: scrollX,
      scrollY: scrollY,
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      currentLine: currentLine,
      currentLineRenderMode: currentLineRenderMode,
      visualLines: visualLines,
      gutterIcons: gutterIcons,
      foldMarkers: foldMarkers,
      cursor: cursor,
      selectionRects: selectionRects,
      selectionStartHandle: selectionStartHandle,
      selectionEndHandle: selectionEndHandle,
      compositionDecoration: compositionDecoration,
      guideSegments: guideSegments,
      diagnosticDecorations: diagnosticDecorations,
      maxGutterIcons: maxGutterIcons,
      linkedEditingRects: linkedEditingRects,
      bracketHighlightRects: bracketHighlightRects,
      verticalScrollbar: verticalScrollbar,
      horizontalScrollbar: horizontalScrollbar,
      gutterSticky: gutterSticky,
      gutterVisible: gutterVisible,
      pointerCursorType: pointerCursorType,
    );
  }

  static VisualRun _readVisualRun(_BinaryReader r) {
    return VisualRun(
      type: VisualRunType.fromValue(r.readInt32()),
      x: r.readFloat32(),
      y: r.readFloat32(),
      text: r.readUtf8String(),
      style: r.readTextStyle(),
      iconId: r.readInt32(),
      colorValue: r.readInt32(),
      width: r.readFloat32(),
      padding: r.readFloat32(),
      margin: r.readFloat32(),
      active: r.readInt32() != 0,
    );
  }

  static VisualLine _readVisualLine(_BinaryReader r) {
    final logicalLine = r.readInt32();
    final wrapIndex = r.readInt32();
    final lineNumberPosition = r.readPoint();
    final kind = VisualLineKind.fromValue(r.readInt32());
    final ownsGutterSemantics = r.readInt32() != 0;
    final foldState = FoldState.fromValue(r.readInt32());
    final runCount = r.readInt32();
    final runs = <VisualRun>[];
    for (var i = 0; i < runCount; i++) {
      runs.add(_readVisualRun(r));
    }
    return VisualLine(
      logicalLine: logicalLine,
      wrapIndex: wrapIndex,
      lineNumberPosition: lineNumberPosition,
      runs: runs,
      kind: kind,
      ownsGutterSemantics: ownsGutterSemantics,
      foldState: foldState,
    );
  }

  static GutterIconRenderItem _readGutterIconRenderItem(_BinaryReader r) {
    return GutterIconRenderItem(
      logicalLine: r.readInt32(),
      iconId: r.readInt32(),
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static FoldMarkerRenderItem _readFoldMarkerRenderItem(_BinaryReader r) {
    return FoldMarkerRenderItem(
      logicalLine: r.readInt32(),
      foldState: FoldState.fromValue(r.readInt32()),
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static Cursor _readCursor(_BinaryReader r) {
    return Cursor(
      textPosition: r.readTextPosition(),
      position: r.readPoint(),
      height: r.readFloat32(),
      visible: r.readInt32() != 0,
      showDragger: r.readInt32() != 0,
    );
  }

  static SelectionRect _readSelectionRect(_BinaryReader r) {
    return SelectionRect(
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static SelectionHandle _readSelectionHandle(_BinaryReader r) {
    return SelectionHandle(
      position: r.readPoint(),
      height: r.readFloat32(),
      visible: r.readInt32() != 0,
    );
  }

  static CompositionDecoration _readCompositionDecoration(_BinaryReader r) {
    return CompositionDecoration(
      active: r.readInt32() != 0,
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static GuideSegment _readGuideSegment(_BinaryReader r) {
    return GuideSegment(
      direction: GuideDirection.fromValue(r.readInt32()),
      type: GuideType.fromValue(r.readInt32()),
      style: GuideStyle.fromValue(r.readInt32()),
      start: r.readPoint(),
      end: r.readPoint(),
      arrowEnd: r.readInt32() != 0,
    );
  }

  static DiagnosticDecoration _readDiagnosticDecoration(_BinaryReader r) {
    return DiagnosticDecoration(
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
      severity: r.readInt32(),
    );
  }

  static LinkedEditingRect _readLinkedEditingRect(_BinaryReader r) {
    return LinkedEditingRect(
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
      isActive: r.readInt32() != 0,
    );
  }

  static BracketHighlightRect _readBracketHighlightRect(_BinaryReader r) {
    return BracketHighlightRect(
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static ScrollbarRect _readScrollbarRect(_BinaryReader r) {
    return ScrollbarRect(
      origin: r.readPoint(),
      width: r.readFloat32(),
      height: r.readFloat32(),
    );
  }

  static ScrollbarModel _readScrollbarModel(_BinaryReader r) {
    return ScrollbarModel(
      visible: r.readInt32() != 0,
      alpha: r.readFloat32(),
      thumbActive: r.readInt32() != 0,
      track: _readScrollbarRect(r),
      thumb: _readScrollbarRect(r),
    );
  }
}

ffi.Pointer<ffi.Char> _toNativeUtf8(String value, ffi.Allocator allocator) {
  return value.toNativeUtf8(allocator: allocator).cast<ffi.Char>();
}

ffi.Pointer<ffi.Uint16> _toNativeUtf16(String value, ffi.Allocator allocator) {
  final units = value.codeUnits;
  final ptr = allocator.allocate<ffi.Uint16>(
    (units.length + 1) * ffi.sizeOf<ffi.Uint16>(),
  );
  final list = ptr.asTypedList(units.length + 1);
  list.setAll(0, units);
  list[units.length] = 0;
  return ptr;
}

String _readNativeUtf8(ffi.Pointer<ffi.Char> ptr) {
  if (ptr == ffi.nullptr) return '';
  try {
    return ptr.cast<Utf8>().toDartString();
  } finally {
    bindings.free_u8_string(ptr.address);
  }
}

String _readNativeUtf16(ffi.Pointer<ffi.Uint16> ptr) {
  if (ptr == ffi.nullptr) return '';
  try {
    var len = 0;
    while (ptr[len] != 0) {
      len++;
    }
    if (len == 0) return '';
    return String.fromCharCodes(ptr.asTypedList(len));
  } finally {
    bindings.free_u16_string(ptr.address);
  }
}

/// Call a native function that returns owned binary data + size,
/// parse it with [parser], then free the native buffer.
T _callAndParse<T>(
  T emptyValue,
  ffi.Pointer<ffi.Uint8> Function(ffi.Pointer<ffi.Size> outSize) nativeCall,
  T Function(ffi.Pointer<ffi.Uint8> ptr, int size) parser,
) {
  return using((arena) {
    final outSize = arena.allocate<ffi.Size>(ffi.sizeOf<ffi.Size>());
    final ptr = nativeCall(outSize);
    if (ptr == ffi.nullptr) return emptyValue;
    final size = outSize.value;
    try {
      return parser(ptr, size);
    } finally {
      bindings.free_binary_data(ptr.address);
    }
  });
}

/// Copy a Dart [Uint8List] to native memory and call [fn].
void _callWithBinaryData(
  Uint8List data,
  void Function(ffi.Pointer<ffi.Uint8>, int) fn,
) {
  using((arena) {
    final ptr = arena.allocate<ffi.Uint8>(data.length);
    ptr.asTypedList(data.length).setAll(0, data);
    fn(ptr, data.length);
  });
}
