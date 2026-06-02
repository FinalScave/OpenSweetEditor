import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/editor_core.dart' as core;
import '../editor_types.dart';

import 'editor_text_measurer.dart';

class EditorCanvasPainter extends ChangeNotifier implements CustomPainter {
  EditorCanvasPainter({
    required EditorTheme theme,
    required EditorTextMeasurer measurer,
    EditorIconProvider? iconProvider,
    required bool showSelectionHandles,
  }) : _theme = theme,
       _measurer = measurer,
       _iconProvider = iconProvider,
       _showSelectionHandles = showSelectionHandles;

  core.EditorRenderModel _model = const core.EditorRenderModel();
  EditorTheme _theme;
  final EditorTextMeasurer _measurer;
  bool _cursorVisible = true;
  EditorIconProvider? _iconProvider;
  final bool _showSelectionHandles;
  final Map<int, _ResolvedEditorIcon> _resolvedIcons = {};

  void updateModel(core.EditorRenderModel model, bool cursorVisible) {
    _model = model;
    _cursorVisible = cursorVisible;
    notifyListeners();
  }

  void updateCursorVisible(bool visible) {
    if (_cursorVisible != visible) {
      _cursorVisible = visible;
      notifyListeners();
    }
  }

  void updateTheme(EditorTheme theme) {
    _theme = theme;
    notifyListeners();
  }

  void updateIconProvider(EditorIconProvider? provider) {
    if (identical(_iconProvider, provider)) return;
    _iconProvider = provider;
    _disposeResolvedIcons();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposeResolvedIcons();
    super.dispose();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = _model;

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Color(_theme.backgroundColor),
    );

    _drawCurrentLineHighlight(canvas, m, 0, size.width);

    _drawSelectionRects(canvas, m);

    for (final rect in m.bracketHighlightRects) {
      canvas.drawRect(
        Rect.fromLTWH(rect.origin.x, rect.origin.y, rect.width, rect.height),
        Paint()..color = Color(_theme.bracketHighlightBgColor),
      );
    }

    for (final rect in m.linkedEditingRects) {
      final color = rect.isActive
          ? _theme.linkedEditingActiveColor
          : _theme.linkedEditingInactiveColor;
      canvas.drawRect(
        Rect.fromLTWH(rect.origin.x, rect.origin.y, rect.width, rect.height),
        Paint()..color = Color(color & 0x33FFFFFF),
      );
    }

    _drawVisualLines(canvas, m);

    _drawGuideSegments(canvas, m);

    _drawDiagnostics(canvas, m);

    if (m.compositionDecoration.active) {
      final cd = m.compositionDecoration;
      final y = cd.origin.y + cd.height;
      canvas.drawLine(
        Offset(cd.origin.x, y),
        Offset(cd.origin.x + cd.width, y),
        Paint()
          ..color = Color(_theme.compositionUnderlineColor)
          ..strokeWidth = 2,
      );
    }

    if (_cursorVisible && m.cursor.visible) {
      final c = m.cursor;
      canvas.drawRect(
        Rect.fromLTWH(c.position.x, c.position.y, 2, c.height),
        Paint()..color = Color(_theme.cursorColor),
      );
    }

    if (m.splitX > 0 && m.gutterVisible) {
      final splitScreenX = m.splitX;
      if (splitScreenX > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, splitScreenX, size.height),
          Paint()..color = Color(_theme.backgroundColor),
        );
        _drawCurrentLineHighlight(canvas, m, 0, splitScreenX);
        if (m.splitLineVisible) {
          canvas.drawLine(
            Offset(splitScreenX, 0),
            Offset(splitScreenX, size.height),
            Paint()
              ..color = Color(_theme.splitLineColor)
              ..strokeWidth = 1,
          );
        }
      }
    }

    _drawLineNumbers(canvas, m);

    _drawGutterIcons(canvas, m);

    _drawFoldMarkers(canvas, m);

    if (_showSelectionHandles) {
      _drawSelectionHandles(canvas, m);
    }

    // Bracket highlight borders
    for (final rect in m.bracketHighlightRects) {
      canvas.drawRect(
        Rect.fromLTWH(rect.origin.x, rect.origin.y, rect.width, rect.height),
        Paint()
          ..color = Color(_theme.bracketHighlightBorderColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    // Linked editing borders
    for (final rect in m.linkedEditingRects) {
      final color = rect.isActive
          ? _theme.linkedEditingActiveColor
          : _theme.linkedEditingInactiveColor;
      canvas.drawRect(
        Rect.fromLTWH(rect.origin.x, rect.origin.y, rect.width, rect.height),
        Paint()
          ..color = Color(color)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    _drawScrollbars(canvas, size, m);
  }

  void _drawCurrentLineHighlight(
    Canvas canvas,
    core.EditorRenderModel m,
    double left,
    double right,
  ) {
    if (right <= left) return;
    if (m.currentLineRenderMode == core.CurrentLineRenderMode.none) {
      return;
    }
    final y = m.currentLine.y;
    final lineH = m.cursor.visible
        ? m.cursor.height
        : _measurer.getFontMetrics().lineHeight;

    if (m.currentLineRenderMode == core.CurrentLineRenderMode.background) {
      canvas.drawRect(
        Rect.fromLTWH(left, y, right - left, lineH),
        Paint()..color = Color(_theme.currentLineColor),
      );
    } else {
      canvas.drawRect(
        Rect.fromLTWH(left, y, right - left, lineH),
        Paint()
          ..color = Color(_theme.currentLineColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawSelectionRects(Canvas canvas, core.EditorRenderModel m) {
    if (m.selectionRects.isEmpty) return;
    final paint = Paint()..color = Color(_theme.selectionColor);
    for (final r in m.selectionRects) {
      canvas.drawRect(
        Rect.fromLTWH(r.origin.x, r.origin.y, r.width, r.height),
        paint,
      );
    }
  }

  void _drawVisualLines(Canvas canvas, core.EditorRenderModel m) {
    for (final line in m.lines) {
      for (final run in line.runs) {
        switch (run.type) {
          case core.VisualRunType.text:
          case core.VisualRunType.whitespace:
          case core.VisualRunType.tab:
          case core.VisualRunType.codelens:
          case core.VisualRunType.link:
            _drawTextRun(canvas, run);
          case core.VisualRunType.phantomText:
            _drawPhantomTextRun(canvas, run);
          case core.VisualRunType.inlayHint:
            _drawInlayHintRun(canvas, run);
          case core.VisualRunType.foldPlaceholder:
            _drawFoldPlaceholderRun(canvas, run);
          case core.VisualRunType.newline:
            break;
        }
      }
    }
  }

  void _drawTextRun(Canvas canvas, core.VisualRun run) {
    if (run.text.isEmpty) return;
    final screenX = run.x;
    final baselineY = run.y;
    final style = _measurer
        .buildRunStyle(run.style, _theme.textColor)
        .copyWith(
          decoration:
              ((run.type == core.VisualRunType.codelens ||
                      run.type == core.VisualRunType.link) &&
                  run.active)
              ? TextDecoration.underline
              : TextDecoration.none,
        );
    final fontMetrics = _measurer.getFontMetrics(run.style.fontStyle);
    final painter = TextPainter(
      text: TextSpan(text: run.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    if (run.style.backgroundColor != 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          screenX,
          baselineY - fontMetrics.ascent,
          run.width,
          fontMetrics.lineHeight,
        ),
        Paint()..color = Color(run.style.backgroundColor),
      );
    }

    _paintTextAtBaseline(
      canvas,
      painter,
      screenX,
      baselineY,
      fontMetrics.ascent,
    );
  }

  void _drawPhantomTextRun(Canvas canvas, core.VisualRun run) {
    if (run.text.isEmpty) return;
    final style = _measurer.buildPhantomTextStyle(_theme.phantomTextColor);
    final fontMetrics = _measurer.getFontMetrics();
    final painter = TextPainter(
      text: TextSpan(text: run.text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    _paintTextAtBaseline(canvas, painter, run.x, run.y, fontMetrics.ascent);
  }

  void _drawInlayHintRun(Canvas canvas, core.VisualRun run) {
    final screenX = run.x + run.margin;
    final baselineY = run.y;
    final fontMetrics = _measurer.getInlayHintFontMetrics();
    final iconRect = Rect.fromLTWH(
      screenX + run.padding,
      baselineY - fontMetrics.ascent + run.padding,
      math.max(0, run.width - run.margin * 2 - run.padding * 2),
      math.max(0, fontMetrics.lineHeight - run.padding * 2),
    );

    // Color swatch inlay hint
    if (run.colorValue != 0) {
      final blockSize = fontMetrics.lineHeight * 0.8;
      canvas.drawRect(
        Rect.fromLTWH(
          screenX,
          baselineY -
              fontMetrics.ascent +
              (fontMetrics.lineHeight - blockSize) / 2,
          blockSize,
          blockSize,
        ),
        Paint()..color = Color(run.colorValue),
      );
      return;
    }

    // Background pill
    final pillStyle = _measurer.buildInlayHintStyle();
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        screenX,
        baselineY - fontMetrics.ascent,
        run.width - run.margin * 2,
        fontMetrics.lineHeight,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(bgRect, Paint()..color = Color(_theme.inlayHintBgColor));

    if (run.iconId != 0) {
      if (!_drawResolvedIcon(
        canvas,
        run.iconId,
        iconRect,
        _theme.inlayHintIconColor,
      )) {
        _drawIconPlaceholder(canvas, iconRect, _theme.inlayHintIconColor);
      }
      return;
    }

    // Text
    if (run.text.isNotEmpty) {
      final style = pillStyle.copyWith(color: Color(_theme.inlayHintTextColor));
      final painter = TextPainter(
        text: TextSpan(text: run.text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintTextAtBaseline(
        canvas,
        painter,
        screenX + run.padding,
        baselineY,
        fontMetrics.ascent,
      );
    }
  }

  void _drawFoldPlaceholderRun(Canvas canvas, core.VisualRun run) {
    final screenX = run.x;
    final baselineY = run.y;
    final text = run.text.isNotEmpty ? run.text : '...';
    final fontMetrics = _measurer.getFontMetrics();
    final style = TextStyle(
      fontFamily: _measurer.fontFamily,
      fontSize: _measurer.fontSize,
      color: Color(_theme.foldPlaceholderTextColor),
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        screenX,
        baselineY - fontMetrics.ascent,
        run.width,
        fontMetrics.lineHeight,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      bgRect,
      Paint()..color = Color(_theme.foldPlaceholderBgColor),
    );

    _paintTextAtBaseline(
      canvas,
      painter,
      screenX + 4,
      baselineY,
      fontMetrics.ascent,
    );
  }

  void _drawGuideSegments(Canvas canvas, core.EditorRenderModel m) {
    for (final seg in m.guideSegments) {
      final isSeparator = seg.type == core.GuideType.separator;
      final color = isSeparator ? _theme.separatorLineColor : _theme.guideColor;
      final paint = Paint()
        ..color = Color(color)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final startX = seg.start.x;
      final startY = seg.start.y;
      final endX = seg.end.x;
      final endY = seg.end.y;

      if (seg.style == core.GuideStyle.double) {
        const offset = 1.5;
        if (seg.direction == core.GuideDirection.horizontal) {
          canvas.drawLine(
            Offset(startX, startY - offset),
            Offset(endX, endY - offset),
            paint,
          );
          canvas.drawLine(
            Offset(startX, startY + offset),
            Offset(endX, endY + offset),
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(startX - offset, startY),
            Offset(endX - offset, endY),
            paint,
          );
          canvas.drawLine(
            Offset(startX + offset, startY),
            Offset(endX + offset, endY),
            paint,
          );
        }
      } else if (seg.style == core.GuideStyle.dashed) {
        _drawDashedLine(
          canvas,
          Offset(startX, startY),
          Offset(endX, endY),
          paint,
          4.0,
          3.0,
        );
      } else {
        if (seg.arrowEnd) {
          _drawArrowLine(
            canvas,
            Offset(startX, startY),
            Offset(endX, endY),
            paint,
          );
        } else {
          canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
        }
      }
    }
  }

  void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final totalLen = math.sqrt(dx * dx + dy * dy);
    if (totalLen == 0) return;
    final ux = dx / totalLen;
    final uy = dy / totalLen;
    var drawn = 0.0;
    var drawing = true;
    while (drawn < totalLen) {
      final segLen = drawing ? dashLen : gapLen;
      final nextDrawn = math.min(drawn + segLen, totalLen);
      if (drawing) {
        canvas.drawLine(
          Offset(start.dx + ux * drawn, start.dy + uy * drawn),
          Offset(start.dx + ux * nextDrawn, start.dy + uy * nextDrawn),
          paint,
        );
      }
      drawn = nextDrawn;
      drawing = !drawing;
    }
  }

  void _drawArrowLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 6) return;
    final ux = dx / len;
    final uy = dy / len;
    const arrowSize = 5.0;
    final ax = end.dx - ux * arrowSize;
    final ay = end.dy - uy * arrowSize;
    canvas.drawLine(
      end,
      Offset(ax + uy * arrowSize * 0.5, ay - ux * arrowSize * 0.5),
      paint,
    );
    canvas.drawLine(
      end,
      Offset(ax - uy * arrowSize * 0.5, ay + ux * arrowSize * 0.5),
      paint,
    );
  }

  void _drawDiagnostics(Canvas canvas, core.EditorRenderModel m) {
    for (final diag in m.diagnosticDecorations) {
      final x = diag.origin.x;
      final y = diag.origin.y + diag.height;
      final w = diag.width;
      final color = switch (diag.severity) {
        0 => Color(_theme.diagnosticErrorColor),
        1 => Color(_theme.diagnosticWarningColor),
        2 => Color(_theme.diagnosticInfoColor),
        _ => Color(_theme.diagnosticHintColor),
      };

      // severity: 0=error, 1=warning, 2=info, 3=hint
      if (diag.severity >= 3) {
        // Dashed underline for hints
        _drawDashedLine(
          canvas,
          Offset(x, y),
          Offset(x + w, y),
          Paint()
            ..color = color
            ..strokeWidth = 1,
          3,
          2,
        );
      } else {
        // Wavy underline
        _drawWavyLine(canvas, x, y, w, color);
      }
    }
  }

  void _drawWavyLine(
    Canvas canvas,
    double x,
    double y,
    double width,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final path = Path();
    const amplitude = 2.0;
    const wavelength = 4.0;
    path.moveTo(x, y);
    var cx = x;
    var up = true;
    while (cx < x + width) {
      final nextX = math.min(cx + wavelength, x + width);
      path.quadraticBezierTo(
        cx + wavelength / 2,
        up ? y - amplitude : y + amplitude,
        nextX,
        y,
      );
      cx = nextX;
      up = !up;
    }
    canvas.drawPath(path, paint);
  }

  void _drawLineNumbers(Canvas canvas, core.EditorRenderModel m) {
    if (!m.gutterVisible) return;
    final activeLogicalLine = m.cursor.textPosition.line;

    for (final line in m.lines) {
      if (!line.ownsGutterSemantics) continue;
      final isCurrentLine = line.logicalLine == activeLogicalLine;
      final color = isCurrentLine
          ? _theme.currentLineNumberColor
          : _theme.lineNumberColor;
      final pos = line.lineNumberPosition;
      final numX = pos.x;
      final baselineY = pos.y;
      final fontMetrics = _measurer.getFontMetrics();
      final painter = TextPainter(
        text: TextSpan(
          text: '${line.logicalLine + 1}',
          style: TextStyle(
            fontFamily: _measurer.fontFamily,
            fontSize: _measurer.fontSize * 0.85,
            color: Color(color),
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      _paintTextAtBaseline(
        canvas,
        painter,
        numX,
        baselineY,
        fontMetrics.ascent,
      );
    }
  }

  void _paintTextAtBaseline(
    Canvas canvas,
    TextPainter painter,
    double x,
    double baselineY,
    double ascent,
  ) {
    painter.paint(canvas, Offset(x, baselineY - ascent));
  }

  bool _drawResolvedIcon(Canvas canvas, int iconId, Rect rect, int color) {
    if (rect.width <= 0 || rect.height <= 0) return false;
    final resolved = _resolveIcon(iconId);
    if (resolved == null) return false;

    final iconData = resolved.iconData;
    if (iconData != null) {
      _drawIconData(canvas, rect, iconData, color);
      return true;
    }

    final image = resolved.image;
    if (image != null) {
      paintImage(canvas: canvas, rect: rect, image: image, fit: BoxFit.contain);
      return true;
    }

    return false;
  }

  void _drawIconData(Canvas canvas, Rect rect, IconData iconData, int color) {
    final iconSize = math.min(rect.width, rect.height);
    if (iconSize <= 0) return;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          inherit: false,
          color: Color(color),
          fontSize: iconSize,
          fontFamily: iconData.fontFamily,
          package: iconData.fontPackage,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        rect.left + (rect.width - painter.width) / 2,
        rect.top + (rect.height - painter.height) / 2,
      ),
    );
  }

  _ResolvedEditorIcon? _resolveIcon(int iconId) {
    final iconProvider = _iconProvider;
    if (iconProvider == null) return null;
    final source = iconProvider.getIconImage(iconId);
    final cached = _resolvedIcons[iconId];
    if (cached != null && cached.matches(source)) {
      return cached;
    }

    cached?.dispose();
    final resolved = _ResolvedEditorIcon(source: source);
    final iconData = _extractIconData(source);
    if (iconData != null) {
      resolved.iconData = iconData;
      _resolvedIcons[iconId] = resolved;
      return resolved;
    }

    final image = _extractUiImage(source);
    if (image != null) {
      resolved.image = image;
      _resolvedIcons[iconId] = resolved;
      return resolved;
    }

    final imageProvider = _extractImageProvider(source);
    if (imageProvider != null) {
      final stream = imageProvider.resolve(ImageConfiguration.empty);
      late final ImageStreamListener listener;
      listener = ImageStreamListener(
        (imageInfo, _) {
          resolved.image = imageInfo.image;
          notifyListeners();
        },
        onError: (Object exception, StackTrace? stackTrace) {
          notifyListeners();
        },
      );
      resolved.stream = stream;
      resolved.listener = listener;
      stream.addListener(listener);
      _resolvedIcons[iconId] = resolved;
      return resolved;
    }

    _resolvedIcons[iconId] = resolved;
    return resolved;
  }

  IconData? _extractIconData(Object? source) {
    if (source is IconData) return source;
    if (source is Icon) return source.icon;
    return null;
  }

  ui.Image? _extractUiImage(Object? source) {
    if (source is ui.Image) return source;
    return null;
  }

  ImageProvider? _extractImageProvider(Object? source) {
    if (source is ImageProvider) return source;
    if (source is Image) return source.image;
    return null;
  }

  void _drawIconPlaceholder(Canvas canvas, Rect rect, int color) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = Color(_applyAlpha(color, 96))
        ..style = PaintingStyle.fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()
        ..color = Color(color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _disposeResolvedIcons() {
    for (final icon in _resolvedIcons.values) {
      icon.dispose();
    }
    _resolvedIcons.clear();
  }

  void _drawGutterIcons(Canvas canvas, core.EditorRenderModel m) {
    for (final icon in m.gutterIcons) {
      final rect = Rect.fromLTWH(
        icon.origin.x,
        icon.origin.y,
        icon.width,
        icon.height,
      );
      if (!_drawResolvedIcon(
        canvas,
        icon.iconId,
        rect,
        _theme.inlayHintIconColor,
      )) {
        _drawIconPlaceholder(canvas, rect, _theme.inlayHintIconColor);
      }
    }
  }

  void _drawFoldMarkers(Canvas canvas, core.EditorRenderModel m) {
    final activeLogicalLine = m.cursor.textPosition.line;
    final activeColor = _theme.currentLineNumberColor != 0
        ? _theme.currentLineNumberColor
        : _theme.lineNumberColor;
    for (final marker in m.foldMarkers) {
      final x = marker.origin.x;
      final y = marker.origin.y;
      final cx = x + marker.width / 2;
      final cy = y + marker.height / 2;
      final halfSize = math.min(marker.width, marker.height) * 0.28;
      final paint = Paint()
        ..color = Color(
          marker.logicalLine == activeLogicalLine
              ? activeColor
              : _theme.lineNumberColor,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, marker.height * 0.1)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      if (marker.foldState == core.FoldState.collapsed) {
        path.moveTo(cx - halfSize * 0.5, cy - halfSize);
        path.lineTo(cx + halfSize * 0.5, cy);
        path.lineTo(cx - halfSize * 0.5, cy + halfSize);
      } else {
        path.moveTo(cx - halfSize, cy - halfSize * 0.5);
        path.lineTo(cx, cy + halfSize * 0.5);
        path.lineTo(cx + halfSize, cy - halfSize * 0.5);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawSelectionHandles(Canvas canvas, core.EditorRenderModel m) {
    final paint = Paint()..color = Color(_theme.cursorColor);
    if (m.selectionStartHandle.visible) {
      _drawHandle(canvas, m.selectionStartHandle, true, paint);
    }
    if (m.selectionEndHandle.visible) {
      _drawHandle(canvas, m.selectionEndHandle, false, paint);
    }
  }

  static const double _handleLineWidth = 1.5;
  static const double _handleDropRadius = 10.0;
  static const double _handleCenterDist = 24.0;

  void _drawHandle(
    Canvas canvas,
    core.SelectionHandle handle,
    bool isStart,
    Paint paint,
  ) {
    final x = handle.position.x;
    final y = handle.position.y;
    final h = handle.height;

    final lineWidth = _handleLineWidth;
    final dropRadius = _handleDropRadius;
    final dropLength = _handleCenterDist;

    canvas.drawRect(Rect.fromLTWH(x - lineWidth / 2, y, lineWidth, h), paint);

    final tipX = x;
    final tipY = y + h;
    final angle = isStart ? 45.0 : -45.0;

    canvas.save();
    canvas.translate(tipX, tipY);
    canvas.rotate(angle * math.pi / 180);

    final cx = 0.0;
    final cy = dropLength;
    final r = dropRadius;
    final k = r * 0.5522;

    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(0, dropLength * 0.4, cx - r, cy - r * 0.8, cx - r, cy)
      ..cubicTo(cx - r, cy + k, cx - k, cy + r, cx, cy + r)
      ..cubicTo(cx + k, cy + r, cx + r, cy + k, cx + r, cy)
      ..cubicTo(cx + r, cy - r * 0.8, 0, dropLength * 0.4, 0, 0)
      ..close();
    canvas.drawPath(path, paint);

    canvas.restore();
  }

  void _drawScrollbars(Canvas canvas, Size size, core.EditorRenderModel m) {
    _drawScrollbar(canvas, m.verticalScrollbar);
    _drawScrollbar(canvas, m.horizontalScrollbar);
  }

  void _drawScrollbar(Canvas canvas, core.ScrollbarModel sb) {
    if (!sb.visible || sb.alpha <= 0) return;
    final alpha = (sb.alpha * 255).round().clamp(0, 255);
    if (alpha == 0) return;

    // Track
    final trackColor = _applyAlpha(_theme.scrollbarTrackColor, alpha);
    canvas.drawRect(
      Rect.fromLTWH(
        sb.track.origin.x,
        sb.track.origin.y,
        sb.track.width,
        sb.track.height,
      ),
      Paint()..color = Color(trackColor),
    );

    // Thumb
    final thumbBaseColor = sb.thumbActive
        ? _theme.scrollbarThumbActiveColor
        : _theme.scrollbarThumbColor;
    final thumbColor = _applyAlpha(thumbBaseColor, alpha);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          sb.thumb.origin.x,
          sb.thumb.origin.y,
          sb.thumb.width,
          sb.thumb.height,
        ),
        const Radius.circular(3),
      ),
      Paint()..color = Color(thumbColor),
    );
  }

  static int _applyAlpha(int argbColor, int alphaOverride) {
    final origAlpha = (argbColor >> 24) & 0xFF;
    final newAlpha = (origAlpha * alphaOverride / 255).round().clamp(0, 255);
    return (newAlpha << 24) | (argbColor & 0x00FFFFFF);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;

  @override
  bool? hitTest(Offset position) => null;

  @override
  SemanticsBuilderCallback? get semanticsBuilder => null;

  @override
  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => false;
}

class _ResolvedEditorIcon {
  _ResolvedEditorIcon({required this.source});

  final Object? source;
  IconData? iconData;
  ui.Image? image;
  ImageStream? stream;
  ImageStreamListener? listener;

  bool matches(Object? other) => identical(source, other) || source == other;

  void dispose() {
    final imageStream = stream;
    final imageListener = listener;
    if (imageStream != null && imageListener != null) {
      imageStream.removeListener(imageListener);
    }
    stream = null;
    listener = null;
  }
}
