import CoreGraphics
import CoreText

struct EditorRenderer {
    // MARK: - Theme (mutable, call applyTheme to switch)

    static var theme: EditorTheme = .light()

    /// Switches theme and returns the new background color for view-layer updates.
    /// Also re-registers syntax highlight styles to the C++ core.
    @discardableResult
    static func applyTheme(_ newTheme: EditorTheme, core: SweetEditorCore? = nil) -> CGColor {
        theme = newTheme
        if let core = core {
            core.setEditorRenderColors(renderColors(for: newTheme))
            let stylesById = newTheme.syntaxStyles.mapValues { styleDef in
                (color: styleDef.color, backgroundColor: Int32(0), fontStyle: styleDef.fontStyle)
            }
            core.registerBatchStyles(stylesById)
        }
        return theme.backgroundColor
    }

    // MARK: - Main Draw

    static func draw(context: CGContext,
                     model: EditorRenderModel,
                     core: SweetEditorCore,
                     viewHeight: CGFloat,
                     iconProvider: EditorIconProvider? = nil,
                     isCursorBlinkVisible: Bool = true,
                     scrollbarStyle: ScrollbarVisualStyle? = nil) -> Bool {
        let t = theme
        let resolvedScrollbarStyle = scrollbarStyle ?? ScrollbarVisualStyle.themedDefault(for: t)
        let rect = CGRect(x: 0, y: 0,
                          width: CGFloat(model.viewport_width),
                          height: CGFloat(model.viewport_height))

        // Background
        context.setFillColor(t.backgroundColor)
        context.fill(rect)

        let lineHeight = CGFloat(model.cursor.height)
        if lineHeight > 0 {
            let currentLineRect = CGRect(
                x: CGFloat(model.current_line.x),
                y: CGFloat(model.current_line.y),
                width: CGFloat(model.viewport_width),
                height: lineHeight
            )
            switch model.current_line_render_mode {
            case .BACKGROUND:
                context.setFillColor(t.currentLineColor)
                context.fill(currentLineRect)
            case .BORDER:
                context.setStrokeColor(t.currentLineColor)
                context.setLineWidth(1.0)
                context.stroke(currentLineRect)
            case .NONE:
                break
            }
        }

        // Selection rects
        context.setFillColor(t.selectionColor)
        for sel in model.selection_rects {
            let selRect = CGRect(x: CGFloat(sel.origin.x), y: CGFloat(sel.origin.y),
                                 width: CGFloat(sel.width), height: CGFloat(sel.height))
            context.fill(selRect)
        }

        // Guide lines
        context.setLineWidth(1.0)
        for guide in model.guide_segments {
            let guideColor = (guide.type == .SEPARATOR) ? t.separatorLineColor : t.guideColor
            context.setStrokeColor(guideColor)
            if guide.type == .INDENT || guide.style == .DASHED {
                context.setLineDash(phase: 0, lengths: [3, 3])
            } else {
                context.setLineDash(phase: 0, lengths: [])
            }

            var startX = CGFloat(guide.start.x)
            var endX = CGFloat(guide.end.x)
            if guide.type == .INDENT {
                startX -= 1.0
                endX -= 1.0
            }

            context.move(to: CGPoint(x: startX, y: CGFloat(guide.start.y)))
            context.addLine(to: CGPoint(x: endX, y: CGFloat(guide.end.y)))
            context.strokePath()
        }
        context.setLineDash(phase: 0, lengths: [])

        // Lines and runs (text content)
        for line in model.lines {
            for run in line.runs {
                drawVisualRun(context: context, run: run, core: core, iconProvider: iconProvider)
            }
        }

        // Cursor
        if model.cursor.visible && isCursorBlinkVisible {
            drawCursor(context: context, cursor: model.cursor)
        }

        // Composition decoration (underline)
        if model.composition_decoration.active {
            drawCompositionDecoration(context: context, decoration: model.composition_decoration)
        }

        // Diagnostic decorations (wavy underlines)
        for diag in model.diagnostic_decorations {
            drawDiagnosticDecoration(context: context, decoration: diag)
        }

        // Linked editing highlights (tab stop borders)
        drawLinkedEditingRects(context: context, rects: model.linked_editing_rects)

        // Bracket pair highlights
        drawBracketHighlightRects(context: context, rects: model.bracket_highlight_rects)

        // Gutter overlay: cover content that overflows into line number area
        let splitX = CGFloat(model.split_x)
        if splitX > 0 {
            context.setFillColor(t.backgroundColor)
            context.fill(CGRect(x: 0, y: 0, width: splitX, height: CGFloat(model.viewport_height)))
            if lineHeight > 0 && model.current_line_render_mode == .BACKGROUND {
                context.setFillColor(t.currentLineColor)
                context.fill(CGRect(x: 0, y: CGFloat(model.current_line.y), width: splitX, height: lineHeight))
            }
        }

        // Line split
        drawLineSplit(context: context, x: splitX, height: CGFloat(model.viewport_height))

        if model.gutter_visible {
            for line in model.lines where line.owns_gutter_semantics {
                drawLineNumber(context: context, line: line, font: core.regularFont)
            }

            for item in model.gutter_icons {
                drawGutterIconItem(context: context, item: item, iconProvider: iconProvider)
            }

            for item in model.fold_markers {
                drawFoldMarkerItem(context: context, item: item)
            }
        }

        return drawScrollbars(context: context, model: model, style: resolvedScrollbarStyle)
    }

    // MARK: - Drawing Helpers

    static func drawLineNumber(context: CGContext,
                               line: VisualLine,
                               font: CTFont) {
        let text = "\(line.logical_line + 1)"
        let attrStr = CFAttributedStringCreateMutable(nil, 0)!
        CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), text as CFString)
        let range = CFRange(location: 0, length: text.utf16.count)
        CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
        CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, theme.lineNumberColor)
        let textLine = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: CGFloat(line.line_number_position.x), y: CGFloat(line.line_number_position.y))
        CTLineDraw(textLine, context)
    }

    static func drawGutterIconItem(context: CGContext,
                                   item: GutterIconRenderItem,
                                   iconProvider: EditorIconProvider?) {
        guard let provider = iconProvider,
              let iconImage = provider.iconImage(for: item.icon_id) else { return }
        drawImage(context: context, image: iconImage, rect: rect(from: item.rect))
    }

    static func drawFoldMarkerItem(context: CGContext, item: FoldMarkerRenderItem) {
        guard item.fold_state != .NONE else { return }

        let markerRect = rect(from: item.rect)
        guard markerRect.width > 0, markerRect.height > 0 else { return }

        let halfSize = min(markerRect.width, markerRect.height) * 0.2
        let centerX = markerRect.midX
        let centerY = markerRect.midY

        context.saveGState()
        context.setStrokeColor(theme.lineNumberColor)
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

    static func drawLineSplit(context: CGContext, x: CGFloat, height: CGFloat) {
        context.setStrokeColor(theme.splitLineColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: x, y: 0))
        context.addLine(to: CGPoint(x: x, y: height))
        context.strokePath()
    }

    static func drawVisualRun(context: CGContext,
                              run: VisualRun,
                              core: SweetEditorCore,
                              iconProvider: EditorIconProvider?) {
        let t = theme
        let text = run.text
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

    static func drawText(context: CGContext, text: String, x: CGFloat, y: CGFloat,
                          font: CTFont, color: CGColor) {
        let attrStr = makeRenderedAttributedString(text, font: font, color: color)
        let line = CTLineCreateWithAttributedString(attrStr)
        context.textPosition = CGPoint(x: x, y: y)
        CTLineDraw(line, context)
    }

    static func drawCursor(context: CGContext, cursor: Cursor) {
        context.setFillColor(theme.cursorColor)
        let cursorWidth: CGFloat = 2.0
        let cursorRect = CGRect(x: CGFloat(cursor.position.x),
                                y: CGFloat(cursor.position.y),
                                width: cursorWidth,
                                height: CGFloat(cursor.height))
        context.fill(cursorRect)
    }

    static func drawCompositionDecoration(context: CGContext, decoration: CompositionDecoration) {
        context.setStrokeColor(theme.compositionUnderlineColor)
        context.setLineWidth(2.0)
        let decorationRect = rect(from: decoration.rect)
        let y = decorationRect.maxY
        context.move(to: CGPoint(x: decorationRect.minX, y: y))
        context.addLine(to: CGPoint(x: decorationRect.maxX, y: y))
        context.strokePath()
    }

    static func drawDiagnosticDecoration(context: CGContext, decoration: DiagnosticDecoration) {
        let color: CGColor
        switch decoration.severity {
        case 0: color = theme.diagnosticErrorColor
        case 1: color = theme.diagnosticWarningColor
        case 2: color = theme.diagnosticInfoColor
        default: color = theme.diagnosticHintColor
        }

        let decorationRect = rect(from: decoration.rect)
        let startX = decorationRect.minX
        let endX = decorationRect.maxX
        let baseY = decorationRect.maxY - 1.0

        context.setStrokeColor(color)
        context.setLineWidth(3.0)

        if decoration.severity == 3 {
            // HINT: dashed straight underline
            context.setLineDash(phase: 0, lengths: [3, 2])
            context.move(to: CGPoint(x: startX, y: baseY))
            context.addLine(to: CGPoint(x: endX, y: baseY))
            context.strokePath()
            context.setLineDash(phase: 0, lengths: [])
        } else {
            // ERROR/WARNING/INFO: smooth arc wavy line
            let halfWave: CGFloat = 7.0
            let amplitude: CGFloat = 3.5
            var x = startX
            context.move(to: CGPoint(x: x, y: baseY))
            var step = 0
            while x < endX {
                let nextX = min(x + halfWave, endX)
                let midX = (x + nextX) / 2
                let peakY = (step % 2 == 0) ? baseY - amplitude : baseY + amplitude
                context.addQuadCurve(to: CGPoint(x: nextX, y: baseY),
                                     control: CGPoint(x: midX, y: peakY))
                x = nextX
                step += 1
            }
            context.strokePath()
        }
    }

    static func drawLinkedEditingRects(context: CGContext, rects: [LinkedEditingRect]) {
        if rects.isEmpty { return }
        let t = theme
        for rect in rects {
            let r = self.rect(from: rect.rect)
            if rect.is_active {
                // Active tab stop: semi-transparent fill + thicker border
                let components = t.linkedEditingActiveColor.components ?? [0, 0, 0, 0]
                let fillColor = CGColor(srgbRed: components.count > 0 ? components[0] : 0,
                                        green: components.count > 1 ? components[1] : 0,
                                        blue: components.count > 2 ? components[2] : 0,
                                        alpha: 0.12)
                context.setFillColor(fillColor)
                context.fill(r)
                context.setStrokeColor(t.linkedEditingActiveColor)
                context.setLineWidth(2.0)
            } else {
                // Inactive tab stop: border only
                context.setStrokeColor(t.linkedEditingInactiveColor)
                context.setLineWidth(1.0)
            }
            context.stroke(r)
        }
    }

    static func drawBracketHighlightRects(context: CGContext, rects: [Rect]) {
        if rects.isEmpty { return }
        let t = theme
        for rect in rects {
            let r = self.rect(from: rect)
            // Background fill
            context.setFillColor(t.bracketHighlightBgColor)
            context.fill(r)
            // Border
            context.setStrokeColor(t.bracketHighlightBorderColor)
            context.setLineWidth(1.5)
            context.stroke(r)
        }
    }

    static func drawScrollbars(context: CGContext, model: EditorRenderModel, style: ScrollbarVisualStyle) -> Bool {
        let vertical = model.vertical_scrollbar
        let horizontal = model.horizontal_scrollbar
        let verticalAlpha = scrollbarAlpha(vertical)
        let horizontalAlpha = scrollbarAlpha(horizontal)
        let hasVertical = isDrawableScrollbar(vertical, alpha: verticalAlpha)
        let hasHorizontal = isDrawableScrollbar(horizontal, alpha: horizontalAlpha)
        guard hasVertical || hasHorizontal else {
            return false
        }

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
            context.setFillColor(color(style.thumbColor, alphaMultiplier: verticalAlpha))
            fillRoundedScrollbarRect(thumbRect, context: context, style: style)
        }

        if hasHorizontal {
            let trackRect = insetScrollbarRect(rect(from: horizontal.track), orientation: .horizontal, style: style)
            let thumbRect = insetScrollbarRect(rect(from: horizontal.thumb), orientation: .horizontal, style: style)
            horizontalTrackY = trackRect.minY
            horizontalTrackHeight = trackRect.height
            context.setFillColor(color(style.trackColor, alphaMultiplier: horizontalAlpha))
            fillRoundedScrollbarRect(trackRect, context: context, style: style)
            context.setFillColor(color(style.thumbColor, alphaMultiplier: horizontalAlpha))
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

        return true
    }

    // MARK: - Color Helpers

    private static func renderColors(for theme: EditorTheme) -> EditorRenderColors {
        let codeLensForeground = theme.codeLensColor ?? theme.inlayHintTextColor
        let activeCodeLensForeground = theme.codeLensActiveColor ?? theme.currentLineNumberColor
        let linkForeground = theme.linkColor ?? codeLensForeground
        let activeLinkForeground = theme.linkActiveColor ?? theme.linkColor ?? activeCodeLensForeground
        return EditorRenderColors(
            text_foreground: argbFromCGColor(theme.textColor),
            selection_foreground: argbFromCGColor(theme.selectionTextColor),
            link_foreground: argbFromCGColor(linkForeground),
            active_link_foreground: argbFromCGColor(activeLinkForeground),
            codelens_foreground: argbFromCGColor(codeLensForeground),
            active_codelens_foreground: argbFromCGColor(activeCodeLensForeground)
        )
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

    static func cgColorFromARGB(_ argb: Int32) -> CGColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: a)
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

    private static func insetScrollbarRect(_ rect: CGRect, orientation: ScrollbarOrientation, style: ScrollbarVisualStyle) -> CGRect {
        guard rect.width > 0, rect.height > 0 else { return rect }
        switch orientation {
        case .vertical:
            return rect.insetBy(dx: style.verticalInset, dy: style.longitudinalInset).integral
        case .horizontal:
            return rect.insetBy(dx: style.longitudinalInset, dy: style.horizontalInset).integral
        }
    }

    private static func fillRoundedScrollbarRect(_ rect: CGRect, context: CGContext, style: ScrollbarVisualStyle) {
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

    static func drawImage(context: CGContext, image: CGImage, rect: CGRect) {
        context.saveGState()
        context.translateBy(x: 0, y: rect.origin.y * 2 + rect.size.height)
        context.scaleBy(x: 1.0, y: -1.0)
        let flippedRect = CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
        context.draw(image, in: flippedRect)
        context.restoreGState()
    }

    static func drawTintedImage(context: CGContext, image: CGImage, rect: CGRect, tintColor: CGColor) {
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
