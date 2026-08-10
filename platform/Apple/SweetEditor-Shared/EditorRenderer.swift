import CoreGraphics
import CoreText

package struct ScrollbarRenderStyle {
    let trackColor: CGColor
    let thumbColor: CGColor
    let activeThumbColor: CGColor
    let verticalInset: CGFloat
    let horizontalInset: CGFloat
    let longitudinalInset: CGFloat
    let minimumCornerRadius: CGFloat
    let shouldAntialias: Bool

    package init(
        trackColor: CGColor,
        thumbColor: CGColor,
        activeThumbColor: CGColor,
        verticalInset: CGFloat,
        horizontalInset: CGFloat,
        longitudinalInset: CGFloat,
        minimumCornerRadius: CGFloat,
        shouldAntialias: Bool
    ) {
        self.trackColor = trackColor
        self.thumbColor = thumbColor
        self.activeThumbColor = activeThumbColor
        self.verticalInset = verticalInset
        self.horizontalInset = horizontalInset
        self.longitudinalInset = longitudinalInset
        self.minimumCornerRadius = minimumCornerRadius
        self.shouldAntialias = shouldAntialias
    }

    package static func themedDefault(for theme: EditorTheme) -> ScrollbarRenderStyle {
        ScrollbarRenderStyle(
            trackColor: theme.scrollbarTrackColor,
            thumbColor: theme.scrollbarThumbColor,
            activeThumbColor: theme.scrollbarThumbActiveColor,
            verticalInset: 2.0,
            horizontalInset: 2.0,
            longitudinalInset: 1.0,
            minimumCornerRadius: 2.0,
            shouldAntialias: false
        )
    }
}

package struct EditorRenderer {
    package static func applyTheme(_ theme: EditorTheme, core: EditorCore) {
        core.setEditorRenderColors(renderColors(for: theme))
        core.setEditorRangeEffectStyles(rangeEffectStyles(for: theme))
        core.registerBatchTextStyles(theme.textStyles)
    }

    // MARK: - Main Draw

    package static func draw(context: CGContext,
                     model: EditorRenderModel,
                     core: EditorCore,
                     theme: EditorTheme,
                     iconProvider: EditorIconProvider? = nil,
                     isCursorBlinkVisible: Bool = true,
                     showsSelectionHandles: Bool = false,
                     scrollbarStyle: ScrollbarRenderStyle? = nil) {
        let t = theme
        let resolvedScrollbarStyle = scrollbarStyle ?? ScrollbarRenderStyle.themedDefault(for: t)
        let rect = CGRect(x: 0, y: 0,
                          width: CGFloat(model.viewport_size.width),
                          height: CGFloat(model.viewport_size.height))

        // Background
        context.setFillColor(t.backgroundColor)
        context.fill(rect)

        let lineHeight = CGFloat(model.cursor.height)
        drawDiffLineBackgrounds(
            context: context,
            model: model,
            left: 0,
            right: CGFloat(model.viewport_size.width),
            lineHeight: lineHeight,
            font: core.regularFont,
            gutter: false
        )
        drawCurrentLineDecoration(
            context: context,
            model: model,
            left: 0,
            right: CGFloat(model.viewport_size.width),
            lineHeight: lineHeight,
            theme: theme
        )

        drawRangeEffectBackgrounds(context: context, effects: model.range_effects)

        // Lines and runs (text content)
        for line in model.lines {
            for run in line.runs {
                drawVisualRun(context: context, run: run, core: core, theme: theme, iconProvider: iconProvider)
            }
        }

        drawGuideSegments(context: context, guides: model.guide_segments, theme: theme)

        drawRangeEffectOverlays(context: context, effects: model.range_effects)

        // Cursor
        if model.cursor.visible && isCursorBlinkVisible {
            drawCursor(context: context, cursor: model.cursor, theme: theme)
        }

        // Gutter overlay: cover content that overflows into line number area
        let splitX = CGFloat(model.split_x)
        if splitX > 0 {
            context.setFillColor(t.backgroundColor)
            context.fill(CGRect(x: 0, y: 0, width: splitX, height: CGFloat(model.viewport_size.height)))
            drawDiffLineBackgrounds(
                context: context,
                model: model,
                left: 0,
                right: splitX,
                lineHeight: lineHeight,
                font: core.regularFont,
                gutter: true
            )
            drawCurrentLineDecoration(
                context: context,
                model: model,
                left: 0,
                right: splitX,
                lineHeight: lineHeight,
                theme: theme
            )
        }

        if model.gutter_visible && model.split_line_visible && splitX > 0 {
            drawLineSplit(context: context, x: splitX, height: CGFloat(model.viewport_size.height), theme: theme)
        }

        if model.gutter_visible {
            let activeLogicalLine = model.cursor.text_position.line
            let overlayIconLines: Set<Int32> = model.max_gutter_icons == 0 && iconProvider != nil
                ? Set(model.gutter_icons.map(\.logical_line))
                : []
            for line in model.lines where line.line_number >= 0 {
                if !line.owns_gutter_semantics || !overlayIconLines.contains(line.logical_line) {
                    drawLineNumber(
                        context: context,
                        line: line,
                        font: core.regularFont,
                        color: line.owns_gutter_semantics && line.logical_line == activeLogicalLine
                            ? theme.currentLineNumberColor
                            : theme.lineNumberColor
                    )
                }
            }

            for item in model.gutter_icons {
                drawGutterIconItem(context: context, item: item, iconProvider: iconProvider)
            }

            for item in model.fold_markers {
                drawFoldMarkerItem(
                    context: context,
                    item: item,
                    color: item.logical_line == activeLogicalLine
                        ? theme.currentLineNumberColor
                        : theme.lineNumberColor
                )
            }
        }

        if showsSelectionHandles {
            drawSelectionHandles(context: context, model: model, theme: theme)
        }

        drawScrollbars(context: context, model: model, style: resolvedScrollbarStyle)
    }

    // MARK: - Drawing Helpers

    private static func drawCurrentLineDecoration(
        context: CGContext,
        model: EditorRenderModel,
        left: CGFloat,
        right: CGFloat,
        lineHeight: CGFloat,
        theme: EditorTheme
    ) {
        guard right > left, lineHeight > 0, model.current_line_render_mode != .NONE else { return }

        let rect = CGRect(
            x: left,
            y: CGFloat(model.current_line.y),
            width: right - left,
            height: lineHeight
        )
        if model.current_line_render_mode == .BACKGROUND {
            context.setFillColor(theme.currentLineColor)
            context.fill(rect)
            return
        }

        context.setStrokeColor(currentLineBorderColor(theme))
        context.setLineWidth(1.0)
        context.stroke(rect)
    }

    private static func currentLineBorderColor(_ theme: EditorTheme) -> CGColor {
        let color = theme.currentLineColor.alpha > 0 ? theme.currentLineColor : theme.lineNumberColor
        guard color.alpha < 160.0 / 255.0 else { return color }
        return color.copy(alpha: 160.0 / 255.0) ?? color
    }

    private static func drawLineNumber(context: CGContext,
                               line: VisualLine,
                               font: CTFont,
                               color: CGColor) {
        let text = "\(line.line_number)"
        let attrStr = CFAttributedStringCreateMutable(nil, 0)!
        CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), text as CFString)
        let range = CFRange(location: 0, length: text.utf16.count)
        CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
        CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, color)
        let textLine = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: CGFloat(line.line_number_position.x), y: CGFloat(line.line_number_position.y))
        CTLineDraw(textLine, context)
    }

    private static func drawDiffLineBackgrounds(
        context: CGContext,
        model: EditorRenderModel,
        left: CGFloat,
        right: CGFloat,
        lineHeight: CGFloat,
        font: CTFont,
        gutter: Bool
    ) {
        guard right > left, lineHeight > 0 else { return }
        let fontHeight = CTFontGetAscent(font) + CTFontGetDescent(font)
        let topPadding = (lineHeight - fontHeight) * 0.5
        for line in model.lines {
            let argb = gutter ? line.gutter_background_color : line.line_background_color
            guard argb != 0 else { continue }
            let top = CGFloat(line.line_number_position.y) - CTFontGetAscent(font) - topPadding
            context.setFillColor(cgColorFromARGB(argb))
            context.fill(CGRect(x: left, y: top, width: right - left, height: lineHeight))
        }
    }

    private static func drawGutterIconItem(context: CGContext,
                                   item: GutterIconRenderItem,
                                   iconProvider: EditorIconProvider?) {
        guard let provider = iconProvider,
              let iconImage = provider.iconImage(for: item.icon_id) else { return }
        drawImage(context: context, image: iconImage, rect: rect(from: item.rect))
    }

    private static func drawFoldMarkerItem(context: CGContext, item: FoldMarkerRenderItem, color: CGColor) {
        guard item.fold_state != .NONE else { return }

        let markerRect = rect(from: item.rect)
        guard markerRect.width > 0, markerRect.height > 0 else { return }

        let halfSize = min(markerRect.width, markerRect.height) * 0.28
        let centerX = markerRect.midX
        let centerY = markerRect.midY

        context.saveGState()
        context.setStrokeColor(color)
        context.setLineWidth(max(1.0, min(markerRect.width, markerRect.height) * 0.1))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if item.fold_state == .COLLAPSED {
            context.move(to: CGPoint(x: centerX - halfSize * 0.5, y: centerY - halfSize))
            context.addLine(to: CGPoint(x: centerX + halfSize * 0.5, y: centerY))
            context.addLine(to: CGPoint(x: centerX - halfSize * 0.5, y: centerY + halfSize))
        } else {
            context.move(to: CGPoint(x: centerX - halfSize, y: centerY - halfSize * 0.5))
            context.addLine(to: CGPoint(x: centerX, y: centerY + halfSize * 0.5))
            context.addLine(to: CGPoint(x: centerX + halfSize, y: centerY - halfSize * 0.5))
        }

        context.strokePath()
        context.restoreGState()
    }

    private static func drawLineSplit(context: CGContext, x: CGFloat, height: CGFloat, theme: EditorTheme) {
        context.setStrokeColor(theme.splitLineColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: height))
        context.strokePath()
    }

    private static func drawVisualRun(context: CGContext,
                              run: VisualRun,
                              core: EditorCore,
                              theme: EditorTheme,
                              iconProvider: EditorIconProvider?) {
        let t = theme
        let text = run.text
        if drawInvisibleCharacterRun(context: context, run: run, core: core, theme: theme) { return }
        if text.isEmpty && run.type != .INLAY_HINT && run.type != .FOLD_PLACEHOLDER { return }

        let font: CTFont
        if run.type == .INLAY_HINT {
            font = core.inlayHintFont
        } else {
            font = core.fontForStyle(run.style.font_style)
        }

        let textColor: CGColor
        if run.style.color != 0 {
            textColor = cgColorFromARGB(run.style.color)
        } else {
            textColor = t.textColor
        }

        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let fontHeight = ascent + descent + leading
        let topY = CGFloat(run.y) - ascent

        // FoldPlaceholder: semi-transparent rounded background + "…" text
        if run.type == .FOLD_PLACEHOLDER {
            let mgn = CGFloat(run.margin)
            let bgLeft = CGFloat(run.x) + mgn
            let bgTop = topY
            let bgWidth = CGFloat(run.width) - mgn * 2
            let bgHeight = fontHeight
            let radius = fontHeight * 0.2

            context.setFillColor(t.foldPlaceholderBgColor)
            let bgRect = CGRect(x: bgLeft, y: bgTop, width: bgWidth, height: bgHeight)
            let path = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.fillPath()

            if !text.isEmpty {
                let foldColor = t.foldPlaceholderTextColor
                drawText(context: context, text: text, x: CGFloat(run.x) + mgn + CGFloat(run.padding),
                         y: CGFloat(run.y), font: font, color: foldColor)
            }
        }
        // InlayHint: draw background rounded rect + offset text
        else if run.type == .INLAY_HINT {
            let mgn = CGFloat(run.margin)
            let bgLeft = CGFloat(run.x) + mgn
            let bgTop = topY
            let bgWidth = CGFloat(run.width) - mgn * 2
            let bgHeight = fontHeight

            if run.color_value != 0 {
                // COLOR type: solid block, no background, no padding, square corners.
                let blockSize = fontHeight
                let colorLeft = CGFloat(run.x) + mgn
                let colorTop = topY
                let colorCG = cgColorFromARGB(run.color_value)
                context.setFillColor(colorCG)
                let colorRect = CGRect(x: colorLeft, y: colorTop, width: blockSize, height: blockSize)
                context.fill(colorRect)
            } else {
                // TEXT / ICON types: rounded background plus content.
                let radius = fontHeight * 0.2

                context.setFillColor(t.inlayHintBgColor)
                let bgRect = CGRect(x: bgLeft, y: bgTop, width: bgWidth, height: bgHeight)
                let path = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
                context.addPath(path)
                context.fillPath()

                if run.icon_id > 0, let provider = iconProvider,
                   let iconImage = provider.iconImage(for: run.icon_id) {
                    let iconSize = max(1, min(bgWidth, bgHeight))
                    let iconRect = CGRect(
                        x: bgLeft + (bgWidth - iconSize) * 0.5,
                        y: bgTop + (bgHeight - iconSize) * 0.5,
                        width: iconSize,
                        height: iconSize
                    )
                    drawTintedImage(context: context,
                                    image: iconImage,
                                    rect: iconRect,
                                    tintColor: t.inlayHintIconColor)
                } else if !text.isEmpty {
                    let inlayTextColor = t.inlayHintTextColor
                    drawText(context: context, text: text, x: CGFloat(run.x) + mgn + CGFloat(run.padding),
                             y: CGFloat(run.y), font: font, color: inlayTextColor)
                }
            }
        } else {
            // Background color (from semantic highlight / search match etc.)
            if run.style.background_color != 0 {
                let bgColor = cgColorFromARGB(run.style.background_color)
                let bgRect = CGRect(x: CGFloat(run.x), y: topY,
                                    width: CGFloat(run.width), height: fontHeight)
                context.setFillColor(bgColor)
                context.fill(bgRect)
            }
            let drawColor: CGColor
            if run.type == .PHANTOM_TEXT {
                drawColor = t.phantomTextColor
            } else {
                drawColor = textColor
            }
            drawText(context: context, text: text, x: CGFloat(run.x), y: CGFloat(run.y),
                     font: font, color: drawColor)
        }

        // Strikethrough
        if (run.style.font_style & FONT_STYLE_STRIKETHROUGH) != 0 {
            let strikeY = topY + ascent * 0.5
            context.setStrokeColor(textColor)
            context.setLineWidth(1.0)
            context.move(to: CGPoint(x: CGFloat(run.x), y: strikeY))
            context.addLine(to: CGPoint(x: CGFloat(run.x) + CGFloat(run.width), y: strikeY))
            context.strokePath()
        }

        if (run.type == .CODELENS || run.type == .LINK), run.active {
            let underlineY = CGFloat(run.y) + max(1.0, descent * 0.25)
            context.setStrokeColor(textColor)
            context.setLineWidth(1.0)
            context.move(to: CGPoint(x: CGFloat(run.x), y: underlineY))
            context.addLine(to: CGPoint(x: CGFloat(run.x) + CGFloat(run.width), y: underlineY))
            context.strokePath()
        }
    }

    private static func drawInvisibleCharacterRun(context: CGContext,
                                          run: VisualRun,
                                          core: EditorCore,
                                          theme: EditorTheme) -> Bool {
        guard run.type == .WHITESPACE || run.type == .TAB || run.type == .NEWLINE else {
            return false
        }
        let font = core.regularFont
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let fontHeight = ascent + descent + leading
        let topY = CGFloat(run.y) - ascent
        if run.type == .WHITESPACE {
            drawRunBackground(context: context, run: run, topY: topY, fontHeight: fontHeight)
            drawWhitespaceMarkerRun(context: context, run: run, font: font, ascent: ascent, descent: descent, theme: theme)
            return true
        }
        if run.type == .TAB {
            drawRunBackground(context: context, run: run, topY: topY, fontHeight: fontHeight)
            drawTabMarkerRun(context: context, run: run, font: font, ascent: ascent, descent: descent, theme: theme)
            return true
        }
        if run.type == .NEWLINE {
            drawRunBackground(context: context, run: run, topY: topY, fontHeight: fontHeight)
            drawLineBreakMarkerRun(context: context, run: run, font: font, theme: theme)
            return true
        }
        return false
    }

    private static func drawRunBackground(context: CGContext,
                                  run: VisualRun,
                                  topY: CGFloat,
                                  fontHeight: CGFloat) {
        guard run.style.background_color != 0 else { return }
        context.setFillColor(cgColorFromARGB(run.style.background_color))
        context.fill(CGRect(x: CGFloat(run.x), y: topY,
                            width: CGFloat(run.width), height: fontHeight))
    }

    private static func drawWhitespaceMarkerRun(context: CGContext,
                                        run: VisualRun,
                                        font: CTFont,
                                        ascent: CGFloat,
                                        descent: CGFloat,
                                        theme: EditorTheme) {
        let markerCount = run.text.utf16.count
        guard markerCount > 0 && run.width > 0 else { return }

        let cellWidth = CGFloat(run.width) / CGFloat(max(1, markerCount))
        let centerY = CGFloat(run.y) + (descent - ascent) * 0.5
        let radius = max(1.0, min(cellWidth, CTFontGetSize(font)) * 0.08)

        context.saveGState()
        context.setFillColor(theme.invisibleCharacterColor)
        for index in 0..<markerCount {
            let centerX = CGFloat(run.x) + cellWidth * (CGFloat(index) + 0.5)
            context.fillEllipse(in: CGRect(x: centerX - radius, y: centerY - radius,
                                           width: radius * 2, height: radius * 2))
        }
        context.restoreGState()
    }

    private static func drawTabMarkerRun(context: CGContext,
                                 run: VisualRun,
                                 font: CTFont,
                                 ascent: CGFloat,
                                 descent: CGFloat,
                                 theme: EditorTheme) {
        guard !run.text.isEmpty && run.width > 0 else { return }

        let centerY = CGFloat(run.y) + (descent - ascent) * 0.5
        let padding = min(CGFloat(run.width) * 0.25, 8.0)
        let left = CGFloat(run.x) + padding
        let right = max(left, CGFloat(run.x) + CGFloat(run.width) - padding)
        let arrow = min(5.0, max(2.0, (right - left) * 0.35))

        context.saveGState()
        context.setStrokeColor(theme.invisibleCharacterColor)
        context.setLineWidth(max(1.0, CTFontGetSize(font) * 0.06))
        context.setLineCap(.round)
        context.move(to: CGPoint(x: left, y: centerY))
        context.addLine(to: CGPoint(x: right, y: centerY))
        context.move(to: CGPoint(x: right, y: centerY))
        context.addLine(to: CGPoint(x: right - arrow, y: centerY - arrow))
        context.move(to: CGPoint(x: right, y: centerY))
        context.addLine(to: CGPoint(x: right - arrow, y: centerY + arrow))
        context.strokePath()
        context.restoreGState()
    }

    private static func drawLineBreakMarkerRun(context: CGContext,
                                       run: VisualRun,
                                       font: CTFont,
                                       theme: EditorTheme) {
        guard !run.text.isEmpty else { return }
        drawText(context: context, text: run.text, x: CGFloat(run.x), y: CGFloat(run.y),
                 font: font, color: theme.invisibleCharacterColor)
    }

    private static func drawText(context: CGContext, text: String, x: CGFloat, y: CGFloat,
                          font: CTFont, color: CGColor) {
        let attrStr = makeRenderedAttributedString(text, font: font, color: color)
        let line = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    private static func drawCursor(context: CGContext, cursor: Cursor, theme: EditorTheme) {
        context.setFillColor(theme.cursorColor)
        let cursorWidth: CGFloat = 2.0
        let cursorRect = CGRect(x: CGFloat(cursor.position.x),
                                y: CGFloat(cursor.position.y),
                                width: cursorWidth,
                                height: CGFloat(cursor.height))
        context.fill(cursorRect)
    }

    private static func drawSelectionHandles(context: CGContext, model: EditorRenderModel, theme: EditorTheme) {
        context.setFillColor(theme.cursorColor)
        if model.selection_start_handle.visible {
            drawSelectionHandle(context: context, handle: model.selection_start_handle, isStart: true)
        }
        if model.selection_end_handle.visible {
            drawSelectionHandle(context: context, handle: model.selection_end_handle, isStart: false)
        }
    }

    private static func drawSelectionHandle(context: CGContext, handle: SelectionHandle, isStart: Bool) {
        let x = CGFloat(handle.position.x)
        let y = CGFloat(handle.position.y)
        let height = CGFloat(handle.height)
        let lineWidth = selectionHandleLineWidth

        context.fill(CGRect(x: x - lineWidth * 0.5, y: y, width: lineWidth, height: height))
        context.saveGState()
        context.translateBy(x: x, y: y + height)
        context.rotate(by: isStart ? .pi / 4 : -.pi / 4)

        let radius = selectionHandleDropRadius
        let distance = selectionHandleCenterDistance
        let control = radius * 0.5522
        let path = CGMutablePath()
        path.move(to: .zero)
        path.addCurve(
            to: CGPoint(x: -radius, y: distance),
            control1: CGPoint(x: 0, y: distance * 0.4),
            control2: CGPoint(x: -radius, y: distance - radius * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: distance + radius),
            control1: CGPoint(x: -radius, y: distance + control),
            control2: CGPoint(x: -control, y: distance + radius)
        )
        path.addCurve(
            to: CGPoint(x: radius, y: distance),
            control1: CGPoint(x: control, y: distance + radius),
            control2: CGPoint(x: radius, y: distance + control)
        )
        path.addCurve(
            to: .zero,
            control1: CGPoint(x: radius, y: distance - radius * 0.8),
            control2: CGPoint(x: 0, y: distance * 0.4)
        )
        path.closeSubpath()
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    package static func selectionHandleConfig() -> HandleConfig {
        let angle = CGFloat.pi / 4
        let transform = CGAffineTransform(rotationAngle: angle)
        let radius = selectionHandleDropRadius
        let distance = selectionHandleCenterDistance
        let points = [
            CGPoint.zero,
            CGPoint(x: -radius, y: distance),
            CGPoint(x: radius, y: distance),
            CGPoint(x: 0, y: distance + radius),
            CGPoint(x: 0, y: distance - radius * 0.8),
        ].map { $0.applying(transform) }
        let minX = points.map(\.x).min() ?? 0
        let minY = points.map(\.y).min() ?? 0
        let maxX = points.map(\.x).max() ?? 0
        let maxY = points.map(\.y).max() ?? 0
        let padding: CGFloat = 8
        return HandleConfig(
            start_hit_area: HandleHitArea(
                left: Float(minX - padding),
                top: Float(minY - padding),
                right: Float(maxX + padding),
                bottom: Float(maxY + padding)
            ),
            end_hit_area: HandleHitArea(
                left: Float(-maxX - padding),
                top: Float(minY - padding),
                right: Float(-minX + padding),
                bottom: Float(maxY + padding)
            )
        )
    }

    private static let selectionHandleLineWidth: CGFloat = 1.5
    private static let selectionHandleDropRadius: CGFloat = 10
    private static let selectionHandleCenterDistance: CGFloat = 24

    private static func drawRangeEffectBackgrounds(context: CGContext, effects: [RangeEffectRenderItem]) {
        for effect in effects where effect.style.background_color != 0 {
            context.setFillColor(cgColorFromARGB(effect.style.background_color))
            context.fill(rect(from: effect.rect))
        }
    }

    private static func drawRangeEffectOverlays(context: CGContext, effects: [RangeEffectRenderItem]) {
        for effect in effects {
            let effectRect = rect(from: effect.rect)
            if effect.style.border_color != 0 {
                context.setLineDash(phase: 0, lengths: [])
                context.setStrokeColor(cgColorFromARGB(effect.style.border_color))
                context.setLineWidth(effect.kind == .LINKED_EDITING_ACTIVE ? 2.0 : 1.5)
                context.stroke(effectRect)
            }
            if effect.style.underline_color != 0 && effect.style.underline_style != .NONE {
                drawRangeEffectUnderline(context: context, rect: effectRect, style: effect.style)
            }
        }
        context.setLineDash(phase: 0, lengths: [])
    }

    private static func drawRangeEffectUnderline(context: CGContext, rect: CGRect, style: RangeEffectStyle) {
        let startX = rect.minX
        let endX = rect.maxX
        let baseY = rect.maxY - 1.0
        let effectHeight = max(rect.height, 1.0)
        let waveStrokeWidth = max(effectHeight * 0.065, 0.75)

        context.setStrokeColor(cgColorFromARGB(style.underline_color))
        context.setLineWidth(style.underline_style == .WAVY ? waveStrokeWidth : 2.0)

        if style.underline_style == .DASHED {
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.move(to: CGPoint(x: startX, y: baseY))
            context.addLine(to: CGPoint(x: endX, y: baseY))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
            return
        }
        if style.underline_style == .SOLID {
            context.setLineDash(phase: 0, lengths: [])
            context.move(to: CGPoint(x: startX, y: baseY))
            context.addLine(to: CGPoint(x: endX, y: baseY))
            context.strokePath()
            return
        }

        let halfWave = max(effectHeight * 0.2, 2.0)
        let controlOffset = max(effectHeight * 0.1, 1.0)
        let waveY = rect.maxY - controlOffset * 0.5 - waveStrokeWidth * 0.5
        var x = startX
        context.move(to: CGPoint(x: x, y: waveY))
        var step = 0
        while x < endX {
            let nextX = min(x + halfWave, endX)
            let midX = (x + nextX) / 2
            let peakY = (step % 2 == 0) ? waveY - controlOffset : waveY + controlOffset
            context.addQuadCurve(to: CGPoint(x: nextX, y: waveY),
                                 control: CGPoint(x: midX, y: peakY))
            x = nextX
            step += 1
        }
        context.strokePath()
    }

    private static func drawGuideSegments(context: CGContext, guides: [GuideSegment], theme: EditorTheme) {
        guard !guides.isEmpty else { return }

        let t = theme
        context.saveGState()
        context.setLineWidth(1.0)

        for guide in guides {
            let guideColor = (guide.type == .SEPARATOR) ? t.separatorLineColor : t.guideColor
            let (start, end) = guideEndpoints(guide)

            context.setStrokeColor(guideColor)
            if guide.type == .INDENT || guide.style == .DASHED {
                context.setLineDash(phase: 0, lengths: [3, 3])
            } else {
                context.setLineDash(phase: 0, lengths: [])
            }

            if guide.style == .DOUBLE {
                drawDoubleGuideLine(context: context, start: start, end: end, direction: guide.direction)
            } else if guide.arrow_end {
                drawArrowGuideLine(context: context, start: start, end: end, color: guideColor)
            } else {
                drawGuideLine(context: context, start: start, end: end)
            }
        }

        context.restoreGState()
    }

    private static func guideEndpoints(_ guide: GuideSegment) -> (start: CGPoint, end: CGPoint) {
        var startX = CGFloat(guide.start.x)
        var endX = CGFloat(guide.end.x)
        if guide.type == .INDENT {
            startX -= 1.0
            endX -= 1.0
        }

        return (
            CGPoint(x: startX, y: CGFloat(guide.start.y)),
            CGPoint(x: endX, y: CGFloat(guide.end.y))
        )
    }

    private static func drawGuideLine(context: CGContext, start: CGPoint, end: CGPoint) {
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    private static func drawDoubleGuideLine(context: CGContext, start: CGPoint, end: CGPoint, direction: GuideDirection) {
        let offset: CGFloat = 1.5
        if direction == .HORIZONTAL {
            drawGuideLine(
                context: context,
                start: CGPoint(x: start.x, y: start.y - offset),
                end: CGPoint(x: end.x, y: end.y - offset)
            )
            drawGuideLine(
                context: context,
                start: CGPoint(x: start.x, y: start.y + offset),
                end: CGPoint(x: end.x, y: end.y + offset)
            )
        } else {
            drawGuideLine(
                context: context,
                start: CGPoint(x: start.x - offset, y: start.y),
                end: CGPoint(x: end.x - offset, y: end.y)
            )
            drawGuideLine(
                context: context,
                start: CGPoint(x: start.x + offset, y: start.y),
                end: CGPoint(x: end.x + offset, y: end.y)
            )
        }
    }

    private static func drawArrowGuideLine(context: CGContext, start: CGPoint, end: CGPoint, color: CGColor) {
        let arrowLength: CGFloat = 8.0
        let arrowAngle = CGFloat(Double.pi * 28.0 / 180.0)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length >= 1.0 else { return }

        let arrowDepth = arrowLength * CGFloat(cos(Double(arrowAngle)))
        if length > arrowDepth {
            let ratio = (length - arrowDepth) / length
            let lineEnd = CGPoint(x: start.x + dx * ratio, y: start.y + dy * ratio)
            drawGuideLine(context: context, start: start, end: lineEnd)
        }

        let unitX = dx / length
        let unitY = dy / length
        let cosAngle = CGFloat(cos(Double(arrowAngle)))
        let sinAngle = CGFloat(sin(Double(arrowAngle)))
        let left = CGPoint(
            x: end.x - arrowLength * (unitX * cosAngle - unitY * sinAngle),
            y: end.y - arrowLength * (unitY * cosAngle + unitX * sinAngle)
        )
        let right = CGPoint(
            x: end.x - arrowLength * (unitX * cosAngle + unitY * sinAngle),
            y: end.y - arrowLength * (unitY * cosAngle - unitX * sinAngle)
        )

        context.saveGState()
        context.setFillColor(color)
        context.move(to: end)
        context.addLine(to: left)
        context.addLine(to: right)
        context.closePath()
        context.fillPath()
        context.restoreGState()
    }

    private static func drawScrollbars(context: CGContext, model: EditorRenderModel, style: ScrollbarRenderStyle) {
        let vertical = model.vertical_scrollbar
        let horizontal = model.horizontal_scrollbar
        let verticalAlpha = scrollbarAlpha(vertical)
        let horizontalAlpha = scrollbarAlpha(horizontal)
        let hasVertical = isDrawableScrollbar(vertical, alpha: verticalAlpha)
        let hasHorizontal = isDrawableScrollbar(horizontal, alpha: horizontalAlpha)
        guard hasVertical || hasHorizontal else { return }

        var verticalTrackX: CGFloat = 0
        var verticalTrackWidth: CGFloat = 0
        var horizontalTrackY: CGFloat = 0
        var horizontalTrackHeight: CGFloat = 0

        if hasVertical {
            let trackRect = insetScrollbarRect(rect(from: vertical.track), orientation: .vertical, style: style)
            let thumbRect = insetScrollbarRect(rect(from: vertical.thumb), orientation: .vertical, style: style)
            verticalTrackX = trackRect.minX
            verticalTrackWidth = trackRect.width
            context.setFillColor(color(style.trackColor, alphaMultiplier: verticalAlpha))
            fillRoundedScrollbarRect(trackRect, context: context, style: style)
            let thumbColor = vertical.thumb_active ? style.activeThumbColor : style.thumbColor
            context.setFillColor(color(thumbColor, alphaMultiplier: verticalAlpha))
            fillRoundedScrollbarRect(thumbRect, context: context, style: style)
        }

        if hasHorizontal {
            let trackRect = insetScrollbarRect(rect(from: horizontal.track), orientation: .horizontal, style: style)
            let thumbRect = insetScrollbarRect(rect(from: horizontal.thumb), orientation: .horizontal, style: style)
            horizontalTrackY = trackRect.minY
            horizontalTrackHeight = trackRect.height
            context.setFillColor(color(style.trackColor, alphaMultiplier: horizontalAlpha))
            fillRoundedScrollbarRect(trackRect, context: context, style: style)
            let thumbColor = horizontal.thumb_active ? style.activeThumbColor : style.thumbColor
            context.setFillColor(color(thumbColor, alphaMultiplier: horizontalAlpha))
            fillRoundedScrollbarRect(thumbRect, context: context, style: style)
        }

        if hasVertical && hasHorizontal {
            context.setFillColor(color(style.trackColor, alphaMultiplier: max(verticalAlpha, horizontalAlpha)))
            fillRoundedScrollbarRect(
                CGRect(x: verticalTrackX, y: horizontalTrackY, width: verticalTrackWidth, height: horizontalTrackHeight),
                context: context,
                style: style
            )
        }

    }

    // MARK: - Color Helpers

    private static func renderColors(for theme: EditorTheme) -> EditorRenderColors {
        let codeLensForeground = theme.codeLensColor ?? theme.inlayHintTextColor
        let activeCodeLensForeground = theme.codeLensActiveColor ?? theme.currentLineNumberColor
        let linkForeground = theme.linkColor ?? codeLensForeground
        let activeLinkForeground = theme.linkActiveColor ?? theme.linkColor ?? activeCodeLensForeground
        return EditorRenderColors(
            text_foreground: argbFromCGColor(theme.textColor),
            link_foreground: argbFromCGColor(linkForeground),
            active_link_foreground: argbFromCGColor(activeLinkForeground),
            codelens_foreground: argbFromCGColor(codeLensForeground),
            active_codelens_foreground: argbFromCGColor(activeCodeLensForeground),
            diff_added_line_background: argbFromCGColor(theme.diffAddedLineBackgroundColor),
            diff_removed_line_background: argbFromCGColor(theme.diffRemovedLineBackgroundColor),
            diff_added_gutter_background: argbFromCGColor(theme.diffAddedGutterBackgroundColor),
            diff_removed_gutter_background: argbFromCGColor(theme.diffRemovedGutterBackgroundColor)
        )
    }

    private static func rangeEffectStyles(for theme: EditorTheme) -> EditorRangeEffectStyles {
        EditorRangeEffectStyles(
            selection: RangeEffectStyle(
                foreground_color: argbFromCGColor(theme.selectionTextColor),
                background_color: argbFromCGColor(theme.selectionColor)
            ),
            search_match: RangeEffectStyle(
                background_color: argbFromCGColor(theme.searchMatchBgColor)
            ),
            search_current: RangeEffectStyle(
                background_color: argbFromCGColor(theme.searchCurrentBgColor),
                border_color: argbFromCGColor(theme.searchCurrentBorderColor)
            ),
            document_highlight_text: RangeEffectStyle(
                background_color: argbFromCGColor(theme.documentHighlightTextBgColor)
            ),
            document_highlight_read: RangeEffectStyle(
                background_color: argbFromCGColor(theme.documentHighlightReadBgColor)
            ),
            document_highlight_write: RangeEffectStyle(
                background_color: argbFromCGColor(theme.documentHighlightWriteBgColor)
            ),
            linked_editing_active: RangeEffectStyle(
                background_color: argbWithAlpha(argbFromCGColor(theme.linkedEditingActiveColor), alpha: 0x20),
                border_color: argbFromCGColor(theme.linkedEditingActiveColor)
            ),
            linked_editing_inactive: RangeEffectStyle(
                border_color: argbFromCGColor(theme.linkedEditingInactiveColor)
            ),
            ime_composition: RangeEffectStyle(
                underline_color: argbFromCGColor(theme.compositionUnderlineColor),
                underline_style: .SOLID
            ),
            bracket_match: RangeEffectStyle(
                background_color: argbFromCGColor(theme.bracketHighlightBgColor),
                border_color: argbFromCGColor(theme.bracketHighlightBorderColor)
            ),
            diagnostic_error: diagnosticStyle(theme.diagnosticErrorColor, underlineStyle: .WAVY),
            diagnostic_warning: diagnosticStyle(theme.diagnosticWarningColor, underlineStyle: .WAVY),
            diagnostic_info: diagnosticStyle(theme.diagnosticInfoColor, underlineStyle: .WAVY),
            diagnostic_hint: diagnosticStyle(theme.diagnosticHintColor, underlineStyle: .DASHED)
        )
    }

    private static func diagnosticStyle(_ color: CGColor,
                                        underlineStyle: RangeEffectUnderlineStyle) -> RangeEffectStyle {
        RangeEffectStyle(underline_color: argbFromCGColor(color),
                         underline_style: underlineStyle)
    }

    private static func argbWithAlpha(_ color: Int32, alpha: UInt32) -> Int32 {
        let value = UInt32(bitPattern: color)
        return Int32(bitPattern: (value & 0x00FF_FFFF) | ((alpha & 0xFF) << 24))
    }

    private static func cgColorFromARGB(_ color: Int32) -> CGColor {
        let value = UInt32(bitPattern: color)
        let alpha = CGFloat((value >> 24) & 0xFF) / 255.0
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        return CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    private static func argbFromCGColor(_ color: CGColor) -> Int32 {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        let converted = colorSpace.flatMap {
            color.converted(to: $0, intent: .defaultIntent, options: nil)
        } ?? color
        let components = converted.components ?? []
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
        if components.count >= 4 {
            red = components[0]
            green = components[1]
            blue = components[2]
            alpha = components[3]
        } else if components.count >= 2 {
            red = components[0]
            green = components[0]
            blue = components[0]
            alpha = components[1]
        } else {
            red = 0
            green = 0
            blue = 0
            alpha = 1
        }
        let a = UInt32(max(0, min(255, Int((alpha * 255.0).rounded()))))
        let r = UInt32(max(0, min(255, Int((red * 255.0).rounded()))))
        let g = UInt32(max(0, min(255, Int((green * 255.0).rounded()))))
        let b = UInt32(max(0, min(255, Int((blue * 255.0).rounded()))))
        return Int32(bitPattern: (a << 24) | (r << 16) | (g << 8) | b)
    }

    private static func rect(from rect: Rect) -> CGRect {
        CGRect(
            x: CGFloat(rect.origin.x),
            y: CGFloat(rect.origin.y),
            width: CGFloat(rect.width),
            height: CGFloat(rect.height)
        )
    }

    private static func scrollbarAlpha(_ scrollbar: ScrollbarModel) -> CGFloat {
        clampUnit(scrollbar.alpha)
    }

    private static func isDrawableScrollbar(_ scrollbar: ScrollbarModel, alpha: CGFloat) -> Bool {
        scrollbar.visible
            && alpha > 0
            && scrollbar.track.width > 0
            && scrollbar.track.height > 0
            && scrollbar.thumb.width > 0
            && scrollbar.thumb.height > 0
    }

    private static func color(_ base: CGColor, alphaMultiplier: CGFloat) -> CGColor {
        base.copy(alpha: base.alpha * clampUnit(alphaMultiplier)) ?? base
    }

    private enum ScrollbarOrientation {
        case vertical
        case horizontal
    }

    private static func insetScrollbarRect(_ rect: CGRect, orientation: ScrollbarOrientation, style: ScrollbarRenderStyle) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        switch orientation {
        case .vertical:
            return rect.insetBy(dx: style.verticalInset, dy: style.longitudinalInset).integral
        case .horizontal:
            return rect.insetBy(dx: style.longitudinalInset, dy: style.horizontalInset).integral
        }
    }

    private static func fillRoundedScrollbarRect(_ rect: CGRect, context: CGContext, style: ScrollbarRenderStyle) {
        guard rect.width > 0, rect.height > 0 else { return }
        let radius = min(min(rect.width, rect.height) * 0.5, style.minimumCornerRadius)
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
        context.saveGState()
        context.setShouldAntialias(style.shouldAntialias)
        context.addPath(path)
        context.fillPath()
        context.restoreGState()
    }

    private static func clampUnit<T: BinaryFloatingPoint>(_ value: T) -> CGFloat {
        CGFloat(max(0, min(1, value)))
    }

    private static func drawImage(context: CGContext, image: CGImage, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.origin.y * 2 + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        let flippedRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        context.draw(image, in: flippedRect)
        context.restoreGState()
    }

    private static func drawTintedImage(context: CGContext, image: CGImage, rect: CGRect, tintColor: CGColor) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.origin.y * 2 + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        let flippedRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        context.clip(to: flippedRect, mask: image)
        context.setFillColor(tintColor)
        context.fill(flippedRect)
        context.restoreGState()
    }
}
