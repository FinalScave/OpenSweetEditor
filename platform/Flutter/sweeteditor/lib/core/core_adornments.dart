// ignore_for_file: unused_element

part of 'editor_core.dart';

enum DiagnosticSeverity {
  diagError(0),
  diagWarning(1),
  diagInfo(2),
  diagHint(3);

  const DiagnosticSeverity(this.value);
  final int value;

  static DiagnosticSeverity fromValue(int value) {
    switch (value) {
      case 0: return diagError;
      case 1: return diagWarning;
      case 2: return diagInfo;
      case 3: return diagHint;
      default: return diagError;
    }
  }
}

enum DocumentHighlightKind {
  text(0),
  read(1),
  write(2);

  const DocumentHighlightKind(this.value);
  final int value;

  static DocumentHighlightKind fromValue(int value) {
    switch (value) {
      case 0: return text;
      case 1: return read;
      case 2: return write;
      default: return text;
    }
  }
}

enum InlayType {
  text(0),
  icon(1),
  color(2);

  const InlayType(this.value);
  final int value;

  static InlayType fromValue(int value) {
    switch (value) {
      case 0: return text;
      case 1: return icon;
      case 2: return color;
      default: return text;
    }
  }
}

enum SeparatorStyle {
  single(0),
  double(1);

  const SeparatorStyle(this.value);
  final int value;

  static SeparatorStyle fromValue(int value) {
    switch (value) {
      case 0: return single;
      case 1: return double;
      default: return single;
    }
  }
}

enum SpanLayer {
  syntax(0),
  semantic(1);

  const SpanLayer(this.value);
  final int value;

  static SpanLayer fromValue(int value) {
    switch (value) {
      case 0: return syntax;
      case 1: return semantic;
      default: return syntax;
    }
  }
}

class BracketGuide {
  const BracketGuide({
    this.parent = const TextPosition(),
    this.end = const TextPosition(),
    this.children = const [],
  });

  final TextPosition parent;
  final TextPosition end;
  final List<TextPosition> children;
}

class CodeLensItem {
  const CodeLensItem({
    this.column = 0,
    this.commandId = 0,
    this.text = '',
  });

  final int column;
  final int commandId;
  final String text;
}

class Diagnostic {
  const Diagnostic({
    this.column = 0,
    this.length = 0,
    this.severity = DiagnosticSeverity.diagError,
  });

  final int column;
  final int length;
  final DiagnosticSeverity severity;
}

class DocumentHighlight {
  const DocumentHighlight({
    this.column = 0,
    this.length = 0,
    this.kind = DocumentHighlightKind.text,
  });

  final int column;
  final int length;
  final DocumentHighlightKind kind;
}

class FlowGuide {
  const FlowGuide({
    this.start = const TextPosition(),
    this.end = const TextPosition(),
  });

  final TextPosition start;
  final TextPosition end;
}

class FoldRegion {
  const FoldRegion({
    this.startLine = 0,
    this.endLine = 0,
    this.collapsed = false,
  });

  final int startLine;
  final int endLine;
  final bool collapsed;
}

class GutterIcon {
  const GutterIcon({
    this.iconId = 0,
  });

  final int iconId;
}

class IndentGuide {
  const IndentGuide({
    this.start = const TextPosition(),
    this.end = const TextPosition(),
  });

  final TextPosition start;
  final TextPosition end;
}

class InlayHint {
  const InlayHint({
    this.type = InlayType.text,
    this.column = 0,
    this.intValue = 0,
    this.text = '',
  });

  final InlayType type;
  final int column;
  final int intValue;
  final String text;
}

class LinkSpan {
  const LinkSpan({
    this.column = 0,
    this.length = 0,
    this.target = '',
  });

  final int column;
  final int length;
  final String target;
}

class PhantomText {
  const PhantomText({
    this.column = 0,
    this.text = '',
  });

  final int column;
  final String text;
}

class SeparatorGuide {
  const SeparatorGuide({
    this.line = 0,
    this.style = SeparatorStyle.single,
    this.count = 0,
    this.textEndColumn = 0,
  });

  final int line;
  final SeparatorStyle style;
  final int count;
  final int textEndColumn;
}

class StyleSpan {
  const StyleSpan({
    this.column = 0,
    this.length = 0,
    this.styleId = 0,
  });

  final int column;
  final int length;
  final int styleId;
}

class TextStyle {
  const TextStyle({
    this.color = 0,
    this.backgroundColor = 0,
    this.fontStyle = 0,
  });

  final int color;
  final int backgroundColor;
  final int fontStyle;
}
