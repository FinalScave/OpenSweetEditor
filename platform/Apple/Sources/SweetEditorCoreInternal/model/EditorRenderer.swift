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
            for (styleId, styleDef) in newTheme.syntaxStyles {
                core.registerStyle(styleId: styleId, color: styleDef.color, fontStyle: styleDef.fontStyle)
            }
        }
        return theme.backgroundColor
    }

    // MARK: - Main Draw

    static func draw(context: CGContext,
                     model: EditorRenderModel,
                     core: SweetEditorCore,
                     viewHeight: CGFloat,
                     iconProvider: EditorIconProvider? = nil,
                     isCursorBlinkVisible: Bool = true) {
        let t = theme
        let rect = CGRect(x: 0, y: 0,
                          width: CGFloat(model.viewport_width),
                          height: CGFloat(model.viewport_height))

        // Background
        context.setFillColor(t.backgroundColor)
        context.fill(rect)

        // Current line highlight
        let lineHeight = CGFloat(model.cursor.height)
        if lineHeight > 0 {
            context.setFillColor(t.currentLineColor)
            let currentLineRect = CGRect(
                x: CGFloat(model.current_line.x),
                y: CGFloat(model.current_line.y),
                width: CGFloat(model.viewport_width),
                height: lineHeight
            )
            context.fill(currentLineRect)
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
            let guideColor = (guide.type == .SEPARATOR) ? t.separatorLineColor : t.guideLineColor
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
            // Re-draw current line highlight in gutter area
            if lineHeight > 0 {
                context.setFillColor(t.currentLineColor)
                context.fill(CGRect(x: 0, y: CGFloat(model.current_line.y), width: splitX, height: lineHeight))
            }
        }

        // Line split
        drawLineSplit(context: context, x: splitX, height: CGFloat(model.viewport_height))

        // Line numbers (drawn after gutter overlay)
        for line in model.lines where line.wrap_index == 0 && !line.is_phantom_line {
            drawLineNumber(context: context,
                           lineNumber: line.logical_line + 1,
                           visualLine: line,
                           model: model,
                           font: core.regularFont,
                           iconProvider: iconProvider)
        }
    }

    // MARK: - Drawing Helpers

    static func drawLineNumber(context: CGContext,
                               lineNumber: Int,
                               visualLine: VisualLine,
                               model: EditorRenderModel,
                               font: CTFont,
                               iconProvider: EditorIconProvider?) {
        let position = visualLine.line_number_position
        let hasIcons = iconProvider != nil && !visualLine.gutter_icon_ids.isEmpty
        let overlayMode = model.max_gutter_icons == 0

        if overlayMode, hasIcons, let provider = iconProvider,
           let iconImage = provider.iconImage(for: visualLine.gutter_icon_ids[0]) {
            let ascent = CTFontGetAscent(font)
            let descent = CTFontGetDescent(font)
            let iconSize = max(1, ascent + descent)
            let rect = CGRect(
                x: CGFloat(position.x),
                y: CGFloat(position.y) - ascent,
                width: iconSize,
                height: iconSize
            )
            drawImage(context: context, image: iconImage, rect: rect)
        } else {
            let text = "\(lineNumber)"
            let attrStr = CFAttributedStringCreateMutable(nil, 0)!
            CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), text as CFString)
            let range = CFRange(location: 0, length: text.utf16.count)
            CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
            CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, theme.lineNumberColor)
            let line = CTLineCreateWithAttributedString(attrStr)
            context.textPosition = CGPoint(x: CGFloat(position.x), y: CGFloat(position.y))
            CTLineDraw(line, context)

            if hasIcons, let provider = iconProvider {
                let ascent = CTFontGetAscent(font)
                let descent = CTFontGetDescent(font)
                let lineHeight = max(1, ascent + descent)
                let top = CGFloat(position.y) - ascent
                var rightEdge = model.fold_arrow_x > 0
                    ? CGFloat(model.fold_arrow_x) - lineHeight * 0.5
                    : CGFloat(model.split_x) - 2.0
                let maxIcons = min(Int(model.max_gutter_icons), visualLine.gutter_icon_ids.count)
                if maxIcons > 0 {
                    for index in stride(from: maxIcons - 1, through: 0, by: -1) {
                        let iconId = visualLine.gutter_icon_ids[index]
                        guard let iconImage = provider.iconImage(for: iconId) else { continue }
                        let rect = CGRect(x: rightEdge - lineHeight, y: top, width: lineHeight, height: lineHeight)
                        drawImage(context: context, image: iconImage, rect: rect)
                        rightEdge -= lineHeight
                    }
                }
            }
        }

        if visualLine.fold_state != .NONE {
            drawFoldArrow(context: context,
                          position: position,
                          foldState: visualLine.fold_state,
                          model: model,
                          font: font)
        }
    }

    static func drawFoldArrow(context: CGContext,
                              position: PointData,
                              foldState: FoldState,
                              model: EditorRenderModel,
                              font: CTFont) {
        let ascent = CTFontGetAscent(font)
        let descent = CTFontGetDescent(font)
        let leading = CTFontGetLeading(font)
        let lineHeight = ascent + descent + leading
        guard lineHeight > 0 else { return }

        let lineTop = CGFloat(position.y) - ascent
        let halfSize = lineHeight * 0.2
        let centerX = model.fold_arrow_x > 0
            ? CGFloat(model.fold_arrow_x)
            : CGFloat(model.split_x) - lineHeight * 0.5
        let centerY = lineTop + lineHeight * 0.5

        context.saveGState()
        context.setStrokeColor(theme.lineNumberColor)
        context.setLineWidth(max(1.0, lineHeight * 0.1))
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if foldState == .COLLAPSED {
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

            context.setFillColor(t.inlayHintBgColor.copy(alpha: t.foldPlaceholderBgAlpha)!)
            let bgRect = CGRect(x: bgLeft, y: bgTop, width: bgWidth, height: bgHeight)
            let path = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
            context.addPath(path)
            context.fillPath()

            if !text.isEmpty {
                let foldColor = textColor.copy(alpha: t.foldPlaceholderTextAlpha)!
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
                    let inlayTextColor = textColor.copy(alpha: t.inlayHintTextAlpha) ?? textColor
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
                drawColor = textColor.copy(alpha: t.phantomTextAlpha) ?? textColor
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
    }

    static func drawText(context: CGContext, text: String, x: CGFloat, y: CGFloat,
                          font: CTFont, color: CGColor) {
        let attrStr = CFAttributedStringCreateMutable(nil, 0)!
        CFAttributedStringReplaceString(attrStr, CFRange(location: 0, length: 0), text as CFString)
        let range = CFRange(location: 0, length: text.utf16.count)
        CFAttributedStringSetAttribute(attrStr, range, kCTFontAttributeName, font)
        CFAttributedStringSetAttribute(attrStr, range, kCTForegroundColorAttributeName, color)
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
        let y = CGFloat(decoration.origin.y) + CGFloat(decoration.height)
        context.move(to: CGPoint(x: CGFloat(decoration.origin.x), y: y))
        context.addLine(to: CGPoint(x: CGFloat(decoration.origin.x) + CGFloat(decoration.width), y: y))
        context.strokePath()
    }

    static func drawDiagnosticDecoration(context: CGContext, decoration: DiagnosticDecoration) {
        let color: CGColor
        if decoration.color != 0 {
            color = cgColorFromARGB(decoration.color)
        } else {
            switch decoration.severity {
            case 0: color = theme.diagnosticErrorColor
            case 1: color = theme.diagnosticWarningColor
            case 2: color = theme.diagnosticInfoColor
            default: color = theme.diagnosticHintColor
            }
        }

        let startX = CGFloat(decoration.origin.x)
        let endX = startX + CGFloat(decoration.width)
        let baseY = CGFloat(decoration.origin.y) + CGFloat(decoration.height) - 1.0

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
            let r = CGRect(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y),
                           width: CGFloat(rect.width), height: CGFloat(rect.height))
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

    static func drawBracketHighlightRects(context: CGContext, rects: [BracketHighlightRect]) {
        if rects.isEmpty { return }
        let t = theme
        for rect in rects {
            let r = CGRect(x: CGFloat(rect.origin.x), y: CGFloat(rect.origin.y),
                           width: CGFloat(rect.width), height: CGFloat(rect.height))
            // Background fill
            context.setFillColor(t.bracketHighlightBgColor)
            context.fill(r)
            // Border
            context.setStrokeColor(t.bracketHighlightBorderColor)
            context.setLineWidth(1.5)
            context.stroke(r)
        }
    }

    // MARK: - Color Helpers

    static func cgColorFromARGB(_ argb: Int32) -> CGColor {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        return CGColor(red: r, green: g, blue: b, alpha: a == 0 ? 1.0 : a)
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
