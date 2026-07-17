#if os(macOS)
import CoreGraphics
import SweetEditorShared

struct ScrollbarHoverRegions {
    let vertical: CGRect?
    let horizontal: CGRect?

    var isEmpty: Bool {
        vertical == nil && horizontal == nil
    }

    func contains(_ point: CGPoint) -> Bool {
        (vertical?.contains(point) ?? false) || (horizontal?.contains(point) ?? false)
    }
}

struct MacOSScrollbarHoverController {
    private(set) var cachedRegions: ScrollbarHoverRegions?

    mutating func reset() {
        cachedRegions = nil
    }

    mutating func updateZones(enabled: Bool,
                              latestModel: EditorRenderModel?,
                              fallbackMetrics: ScrollMetrics?,
                              scrollbarConfig: ScrollbarConfig?) {
        guard enabled else {
            cachedRegions = nil
            return
        }

        if let latestModel {
            let latestRegions = ScrollbarHoverRegions(
                vertical: revealRect(for: latestModel.vertical_scrollbar),
                horizontal: revealRect(for: latestModel.horizontal_scrollbar)
            )
            if !latestRegions.isEmpty {
                cachedRegions = latestRegions
                return
            }
        }

        if let fallbackMetrics, let scrollbarConfig {
            let fallbackRegions = regions(from: fallbackMetrics, scrollbarConfig: scrollbarConfig)
            if !fallbackRegions.isEmpty {
                cachedRegions = fallbackRegions
            }
        }
    }

    func shouldReveal(at point: CGPoint, currentModel: EditorRenderModel?) -> Bool {
        guard let cachedRegions else { return false }
        guard !hasVisibleScrollbar(currentModel) else { return false }
        return cachedRegions.contains(point)
    }

    private func hasVisibleScrollbar(_ model: EditorRenderModel?) -> Bool {
        guard let model else { return false }
        return isVisible(model.vertical_scrollbar) || isVisible(model.horizontal_scrollbar)
    }

    private func revealRect(for scrollbar: ScrollbarModel) -> CGRect? {
        guard isVisible(scrollbar) else { return nil }
        return CGRect(
            x: CGFloat(scrollbar.track.origin.x),
            y: CGFloat(scrollbar.track.origin.y),
            width: CGFloat(scrollbar.track.width),
            height: CGFloat(scrollbar.track.height)
        )
    }

    private func isVisible(_ scrollbar: ScrollbarModel) -> Bool {
        scrollbar.visible
            && scrollbar.alpha > 0
            && scrollbar.track.width > 0
            && scrollbar.track.height > 0
    }

    private func regions(from metrics: ScrollMetrics,
                         scrollbarConfig: ScrollbarConfig) -> ScrollbarHoverRegions {
        let thickness = CGFloat(max(1.0, scrollbarConfig.thickness))
        let viewportWidth = CGFloat(metrics.viewport_size.width)
        let viewportHeight = CGFloat(metrics.viewport_size.height)
        let showsVertical = metrics.canScrollY
        let showsHorizontal = metrics.canScrollX

        let vertical: CGRect?
        if showsVertical {
            let trackHeight = max(0, viewportHeight - (showsHorizontal ? thickness : 0))
            vertical = trackHeight > 0
                ? CGRect(x: viewportWidth - thickness, y: 0, width: thickness, height: trackHeight)
                : nil
        } else {
            vertical = nil
        }

        let horizontal: CGRect?
        if showsHorizontal {
            let trackWidth = max(0, viewportWidth - metrics.textAreaX - (showsVertical ? thickness : 0))
            horizontal = trackWidth > 0
                ? CGRect(x: metrics.textAreaX, y: viewportHeight - thickness, width: trackWidth, height: thickness)
                : nil
        } else {
            horizontal = nil
        }

        return ScrollbarHoverRegions(vertical: vertical, horizontal: horizontal)
    }
}
#endif
