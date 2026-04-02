import 'package:flutter/services.dart';
import 'package:sweeteditor/editor_core.dart' as core;
import 'package:sweeteditor/sweeteditor.dart';
import 'package:sweetline/sweetline.dart' as sweetline;

import 'demo_file_metadata.dart';

const int iconType = 1;
const int iconAt = 2;

class DemoDecorationProvider implements DecorationProvider {
  DemoDecorationProvider(this._controller);

  static const String _defaultAnalysisFileName = 'sample.cpp';
  static const int _styleColor = EditorTheme.styleUserBase + 1;
  static const int _maxDynamicDiagnostics = 8;
  static const List<String> _syntaxAssets = [
    'assets/demo_shared/syntaxes/cpp.json',
    'assets/demo_shared/syntaxes/java.json',
    'assets/demo_shared/syntaxes/kotlin.json',
    'assets/demo_shared/syntaxes/lua.json',
  ];

  static sweetline.HighlightEngine? _highlightEngine;
  static Future<void>? _initialization;

  final SweetEditorController _controller;
  sweetline.Document? _document;
  sweetline.DocumentAnalyzer? _documentAnalyzer;
  sweetline.DocumentHighlight? _cacheHighlight;
  String _analyzedFileName = _defaultAnalysisFileName;

  static Future<void> ensureSweetLineReady() {
    if (_highlightEngine != null) {
      return Future<void>.value();
    }
    final ongoing = _initialization;
    if (ongoing != null) {
      return ongoing;
    }
    final init = _initializeEngine();
    _initialization = init;
    return init;
  }

  static Future<void> _initializeEngine() async {
    final engine = sweetline.HighlightEngine();
    _registerDemoStyleMap(engine);
    for (final assetPath in _syntaxAssets) {
      final syntaxJson = await rootBundle.loadString(assetPath);
      engine.compileSyntaxFromJson(syntaxJson);
    }
    _highlightEngine = engine;
  }

  static void _registerDemoStyleMap(sweetline.HighlightEngine engine) {
    engine.registerStyleName('keyword', EditorTheme.styleKeyword);
    engine.registerStyleName('type', EditorTheme.styleType);
    engine.registerStyleName('string', EditorTheme.styleString);
    engine.registerStyleName('comment', EditorTheme.styleComment);
    engine.registerStyleName('preprocessor', EditorTheme.stylePreprocessor);
    engine.registerStyleName('macro', EditorTheme.stylePreprocessor);
    engine.registerStyleName('method', EditorTheme.styleFunction);
    engine.registerStyleName('function', EditorTheme.styleFunction);
    engine.registerStyleName('variable', EditorTheme.styleVariable);
    engine.registerStyleName('field', EditorTheme.styleVariable);
    engine.registerStyleName('number', EditorTheme.styleNumber);
    engine.registerStyleName('class', EditorTheme.styleClass);
    engine.registerStyleName('builtin', EditorTheme.styleBuiltin);
    engine.registerStyleName('annotation', EditorTheme.styleAnnotation);
    engine.registerStyleName('color', _styleColor);
  }

  @override
  Set<DecorationType> getCapabilities() => {
    DecorationType.syntaxHighlight,
    DecorationType.inlayHint,
    DecorationType.diagnostic,
    DecorationType.foldRegion,
    DecorationType.indentGuide,
    DecorationType.separatorGuide,
    DecorationType.gutterIcon,
  };

  @override
  void provideDecorations(
    DecorationContext context,
    DecorationReceiver receiver,
  ) {
    final highlightEngine = _highlightEngine;
    if (highlightEngine == null) {
      receiver.accept(DecorationResultBuilder().build());
      return;
    }

    final syntaxSpans = <int, List<core.StyleSpan>>{};
    final inlayHints = <int, List<core.InlayHint>>{};
    final diagnostics = <int, List<core.DiagnosticItem>>{};
    final gutterIcons = <int, List<core.GutterIcon>>{};
    final indentGuides = <core.IndentGuide>[];
    final foldRegions = <core.FoldRegion>[];
    final separatorGuides = <core.SeparatorGuide>[];
    final seenColorHints = <String>{};
    final seenDiagnostics = <String>{};
    final seenFolds = <String>{};
    final diagnosticCount = <int>[0];

    final content = _controller.getContent();
    if (content.isEmpty) {
      receiver.accept(
        DecorationResultBuilder()
            .syntaxSpans(syntaxSpans, ApplyMode.merge)
            .inlayHints(inlayHints, ApplyMode.replaceRange)
            .diagnostics(diagnostics, ApplyMode.replaceAll)
            .indentGuides(indentGuides, ApplyMode.replaceAll)
            .foldRegions(foldRegions, ApplyMode.replaceAll)
            .separatorGuides(separatorGuides, ApplyMode.replaceAll)
            .gutterIcons(gutterIcons, ApplyMode.replaceAll)
            .build(),
      );
      return;
    }

    final currentFileName = _resolveCurrentFileName(context);
    final fileChanged = currentFileName != _analyzedFileName;
    if (_cacheHighlight == null || _documentAnalyzer == null || fileChanged) {
      _documentAnalyzer?.dispose();
      _document?.dispose();
      _document = sweetline.Document('file:///$currentFileName', content);
      _documentAnalyzer = highlightEngine.loadDocument(_document!);
      _cacheHighlight = _documentAnalyzer?.analyze();
      _analyzedFileName = currentFileName;
    } else if (context.textChanges.isNotEmpty) {
      for (final change in context.textChanges) {
        _cacheHighlight = _documentAnalyzer?.analyzeIncremental(
          _convertRange(change.range),
          change.newText,
        );
      }
    }

    final cacheHighlight = _cacheHighlight;
    if (cacheHighlight != null && cacheHighlight.lines.isNotEmpty) {
      final startLine = context.visibleStartLine.clamp(
        0,
        cacheHighlight.lines.length - 1,
      );
      final endLine = context.visibleEndLine.clamp(
        0,
        cacheHighlight.lines.length - 1,
      );
      _TokenRangeInfo? firstKeywordRange;
      for (var line = startLine; line <= endLine; line++) {
        final lineHighlight = cacheHighlight.lines[line];
        for (final token in lineHighlight.spans) {
          _appendStyleSpan(syntaxSpans, token);
          _appendColorInlayHint(inlayHints, seenColorHints, token);
          _appendTextInlayHint(inlayHints, token);
          _appendSeparator(separatorGuides, token);
          _appendGutterIcons(gutterIcons, token);
          firstKeywordRange = _appendDynamicDemoDecorations(
            diagnostics,
            seenDiagnostics,
            diagnosticCount,
            firstKeywordRange,
            token,
          );
        }
      }
      _appendDiagnosticFallbackIfNeeded(
        diagnostics,
        seenDiagnostics,
        diagnosticCount,
        firstKeywordRange,
      );
    }

    if (context.totalLineCount < 2048) {
      final guideResult = _documentAnalyzer?.analyzeIndentGuides();
      if (guideResult != null) {
        for (final guide in guideResult.guideLines) {
          if (guide.endLine < guide.startLine) {
            continue;
          }
          final column = guide.column < 0 ? 0 : guide.column;
          indentGuides.add(
            core.IndentGuide(
              start: core.TextPosition(guide.startLine, column),
              end: core.TextPosition(guide.endLine, column),
            ),
          );
          if (guide.endLine <= guide.startLine) {
            continue;
          }
          final key = '${guide.startLine}:${guide.endLine}';
          if (seenFolds.add(key)) {
            foldRegions.add(
              core.FoldRegion(
                startLine: guide.startLine,
                endLine: guide.endLine,
              ),
            );
          }
        }
      }
    }

    receiver.accept(
      DecorationResultBuilder()
          .syntaxSpans(syntaxSpans, ApplyMode.merge)
          .inlayHints(inlayHints, ApplyMode.replaceRange)
          .diagnostics(diagnostics, ApplyMode.replaceAll)
          .indentGuides(indentGuides, ApplyMode.replaceAll)
          .foldRegions(foldRegions, ApplyMode.replaceAll)
          .separatorGuides(separatorGuides, ApplyMode.replaceAll)
          .gutterIcons(gutterIcons, ApplyMode.replaceAll)
          .build(),
    );
  }

  @override
  void dispose() {
    _documentAnalyzer?.dispose();
    _document?.dispose();
    _documentAnalyzer = null;
    _document = null;
    _cacheHighlight = null;
  }

  _TokenRangeInfo? _appendDynamicDemoDecorations(
    Map<int, List<core.DiagnosticItem>> diagnostics,
    Set<String> seenDiagnostics,
    List<int> diagnosticCount,
    _TokenRangeInfo? firstKeywordRange,
    sweetline.TokenSpan token,
  ) {
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return firstKeywordRange;
    }
    final literal = _getTokenLiteral(range);
    if (literal.isEmpty) {
      return firstKeywordRange;
    }

    final styleId = token.styleId;
    if (styleId == EditorTheme.styleKeyword) {
      return firstKeywordRange ?? range;
    }

    if (styleId == EditorTheme.styleComment) {
      final upper = literal.toUpperCase();
      final fixmeIndex = upper.indexOf('FIXME');
      if (fixmeIndex >= 0) {
        _appendDiagnostic(
          diagnostics,
          seenDiagnostics,
          diagnosticCount,
          line: range.line,
          column: range.startColumn + fixmeIndex,
          length: 5,
          severity: 0,
          color: 0,
        );
      }
      final todoIndex = upper.indexOf('TODO');
      if (todoIndex >= 0) {
        _appendDiagnostic(
          diagnostics,
          seenDiagnostics,
          diagnosticCount,
          line: range.line,
          column: range.startColumn + todoIndex,
          length: 4,
          severity: 1,
          color: 0,
        );
      }
      return firstKeywordRange;
    }

    if (styleId == _styleColor) {
      return firstKeywordRange;
    }

    if (styleId == EditorTheme.styleAnnotation) {
      _appendDiagnostic(
        diagnostics,
        seenDiagnostics,
        diagnosticCount,
        line: range.line,
        column: range.startColumn,
        length: range.length,
        severity: 3,
        color: 0,
      );
    }
    return firstKeywordRange;
  }

  void _appendDiagnostic(
    Map<int, List<core.DiagnosticItem>> diagnostics,
    Set<String> seenDiagnostics,
    List<int> diagnosticCount, {
    required int line,
    required int column,
    required int length,
    required int severity,
    required int color,
  }) {
    if (diagnosticCount[0] >= _maxDynamicDiagnostics ||
        line < 0 ||
        column < 0 ||
        length <= 0) {
      return;
    }
    final key = '$line:$column:$length:$severity:$color';
    if (!seenDiagnostics.add(key)) {
      return;
    }
    diagnostics
        .putIfAbsent(line, () => [])
        .add(
          core.DiagnosticItem(
            column: column,
            length: length,
            severity: severity,
            color: color,
          ),
        );
    diagnosticCount[0]++;
  }

  void _appendDiagnosticFallbackIfNeeded(
    Map<int, List<core.DiagnosticItem>> diagnostics,
    Set<String> seenDiagnostics,
    List<int> diagnosticCount,
    _TokenRangeInfo? firstKeywordRange,
  ) {
    if (diagnosticCount[0] > 0 || firstKeywordRange == null) {
      return;
    }
    _appendDiagnostic(
      diagnostics,
      seenDiagnostics,
      diagnosticCount,
      line: firstKeywordRange.line,
      column: firstKeywordRange.startColumn,
      length: firstKeywordRange.length,
      severity: 3,
      color: 0,
    );
  }

  void _appendStyleSpan(
    Map<int, List<core.StyleSpan>> syntaxSpans,
    sweetline.TokenSpan token,
  ) {
    final styleId = token.styleId;
    if (styleId == null || styleId <= 0) {
      return;
    }
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return;
    }
    syntaxSpans
        .putIfAbsent(range.line, () => [])
        .add(
          core.StyleSpan(
            column: range.startColumn,
            length: range.length,
            styleId: styleId,
          ),
        );
  }

  void _appendColorInlayHint(
    Map<int, List<core.InlayHint>> inlayHints,
    Set<String> seenHints,
    sweetline.TokenSpan token,
  ) {
    if (token.styleId != _styleColor) {
      return;
    }
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return;
    }
    final literal = _getTokenLiteral(range);
    final color = _parseColorLiteral(literal);
    if (color == null) {
      return;
    }
    final key = '${range.line}:${range.startColumn}:$literal';
    if (!seenHints.add(key)) {
      return;
    }
    inlayHints
        .putIfAbsent(range.line, () => [])
        .add(
          core.InlayHint(
            type: core.InlayType.color,
            column: range.startColumn,
            intValue: color,
          ),
        );
  }

  int? _parseColorLiteral(String literal) {
    if (literal.length <= 2 ||
        literal[0] != '0' ||
        (literal[1] != 'x' && literal[1] != 'X')) {
      return null;
    }
    try {
      final hex = literal.substring(2).replaceAll(RegExp(r'[_uUlL]'), '');
      return int.parse(hex, radix: 16);
    } on FormatException {
      return null;
    }
  }

  void _appendTextInlayHint(
    Map<int, List<core.InlayHint>> inlayHints,
    sweetline.TokenSpan token,
  ) {
    if (token.styleId != EditorTheme.styleKeyword) {
      return;
    }
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return;
    }
    final literal = _getTokenLiteral(range);
    String? hintText;
    if (literal == 'const') {
      hintText = 'immutable';
    } else if (literal == 'return') {
      hintText = 'value: ';
    } else if (literal == 'case') {
      hintText = 'condition: ';
    }
    if (hintText == null) {
      return;
    }
    inlayHints
        .putIfAbsent(range.line, () => [])
        .add(
          core.InlayHint(
            type: core.InlayType.text,
            column: range.endColumn + 1,
            text: hintText,
          ),
        );
  }

  void _appendSeparator(
    List<core.SeparatorGuide> separatorGuides,
    sweetline.TokenSpan token,
  ) {
    if (token.styleId != EditorTheme.styleComment) {
      return;
    }
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return;
    }
    final lineText = _controller.getLineText(range.line);
    if (range.endColumn > lineText.length) {
      return;
    }
    var count = -1;
    var isDouble = false;
    for (var i = 0; i < lineText.length; i++) {
      final ch = lineText[i];
      if (count < 0) {
        if (ch == '/') {
          continue;
        }
        if (ch == '=') {
          count = 1;
          isDouble = true;
        } else if (ch == '-') {
          count = 1;
          isDouble = false;
        }
      } else if (isDouble && ch == '=') {
        count++;
      } else if (!isDouble && ch == '-') {
        count++;
      } else {
        break;
      }
    }
    if (count > 0) {
      separatorGuides.add(
        core.SeparatorGuide(
          line: range.line,
          style: isDouble ? 1 : 0,
          count: count,
          textEndColumn: lineText.length,
        ),
      );
    }
  }

  void _appendGutterIcons(
    Map<int, List<core.GutterIcon>> gutterIcons,
    sweetline.TokenSpan token,
  ) {
    final styleId = token.styleId;
    if (styleId != EditorTheme.styleKeyword &&
        styleId != EditorTheme.styleAnnotation) {
      return;
    }
    final range = _extractSingleLineTokenRange(token);
    if (range == null) {
      return;
    }
    if (styleId == EditorTheme.styleKeyword) {
      final literal = _getTokenLiteral(range);
      if (literal == 'class' || literal == 'struct') {
        gutterIcons
            .putIfAbsent(range.line, () => [])
            .add(core.GutterIcon(iconId: iconType));
      }
      return;
    }
    gutterIcons
        .putIfAbsent(range.line, () => [])
        .add(core.GutterIcon(iconId: iconAt));
  }

  _TokenRangeInfo? _extractSingleLineTokenRange(sweetline.TokenSpan token) {
    final styleId = token.styleId;
    if (styleId == null) {
      return null;
    }
    final range = token.range;
    final start = range.start;
    final end = range.end;
    if (start.line < 0 ||
        start.line != end.line ||
        start.column < 0 ||
        end.column <= start.column) {
      return null;
    }
    return _TokenRangeInfo(start.line, start.column, end.column);
  }

  String _getTokenLiteral(_TokenRangeInfo range) {
    final lineText = _controller.getLineText(range.line);
    if (range.endColumn > lineText.length) {
      return '';
    }
    return lineText.substring(range.startColumn, range.endColumn);
  }

  String _resolveCurrentFileName(DecorationContext context) {
    final metadata = context.editorMetadata;
    if (metadata is DemoFileMetadata && metadata.fileName.isNotEmpty) {
      return metadata.fileName;
    }
    return _defaultAnalysisFileName;
  }

  sweetline.TextRange _convertRange(core.TextRange range) {
    return sweetline.TextRange(
      sweetline.TextPosition(range.start.line, range.start.column),
      sweetline.TextPosition(range.end.line, range.end.column),
    );
  }
}

class _TokenRangeInfo {
  const _TokenRangeInfo(this.line, this.startColumn, this.endColumn);

  final int line;
  final int startColumn;
  final int endColumn;

  int get length => endColumn - startColumn;
}
