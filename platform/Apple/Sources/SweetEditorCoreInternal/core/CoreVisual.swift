import Foundation

public enum FoldState: Int32 {
    case NONE = 0
    case EXPANDED = 1
    case COLLAPSED = 2

    public static func fromValue(_ value: Int32) -> FoldState {
        switch value {
        case 0: return .NONE
        case 1: return .EXPANDED
        case 2: return .COLLAPSED
        default: return .NONE
        }
    }
}

public enum GuideDirection: Int32 {
    case HORIZONTAL = 0
    case VERTICAL = 1

    public static func fromValue(_ value: Int32) -> GuideDirection {
        switch value {
        case 0: return .HORIZONTAL
        case 1: return .VERTICAL
        default: return .VERTICAL
        }
    }
}

public enum GuideStyle: Int32 {
    case SOLID = 0
    case DASHED = 1
    case DOUBLE = 2

    public static func fromValue(_ value: Int32) -> GuideStyle {
        switch value {
        case 0: return .SOLID
        case 1: return .DASHED
        case 2: return .DOUBLE
        default: return .SOLID
        }
    }
}

public enum GuideType: Int32 {
    case INDENT = 0
    case BRACKET = 1
    case FLOW = 2
    case SEPARATOR = 3

    public static func fromValue(_ value: Int32) -> GuideType {
        switch value {
        case 0: return .INDENT
        case 1: return .BRACKET
        case 2: return .FLOW
        case 3: return .SEPARATOR
        default: return .INDENT
        }
    }
}

public enum PointerCursorType: Int32 {
    case DEFAULT = 0
    case TEXT = 1
    case HAND = 2

    public static func fromValue(_ value: Int32) -> PointerCursorType {
        switch value {
        case 0: return .DEFAULT
        case 1: return .TEXT
        case 2: return .HAND
        default: return .DEFAULT
        }
    }
}

public enum VisualLineKind: Int32 {
    case CONTENT = 0
    case PHANTOM = 1
    case CODELENS = 2

    public static func fromValue(_ value: Int32) -> VisualLineKind {
        switch value {
        case 0: return .CONTENT
        case 1: return .PHANTOM
        case 2: return .CODELENS
        default: return .CONTENT
        }
    }
}

public enum VisualRunType: Int32 {
    case TEXT = 0
    case WHITESPACE = 1
    case NEWLINE = 2
    case INLAY_HINT = 3
    case PHANTOM_TEXT = 4
    case FOLD_PLACEHOLDER = 5
    case TAB = 6
    case CODELENS = 7
    case LINK = 8

    public static func fromValue(_ value: Int32) -> VisualRunType {
        switch value {
        case 0: return .TEXT
        case 1: return .WHITESPACE
        case 2: return .NEWLINE
        case 3: return .INLAY_HINT
        case 4: return .PHANTOM_TEXT
        case 5: return .FOLD_PLACEHOLDER
        case 6: return .TAB
        case 7: return .CODELENS
        case 8: return .LINK
        default: return .TEXT
        }
    }
}

public struct CompositionDecoration {
    public var active: Bool = false
    public var rect: Rect = Rect()

    public init(active: Bool = false, rect: Rect = Rect()) {
        self.active = active
        self.rect = rect
    }
}

public struct Cursor {
    public var text_position: TextPosition = TextPosition()
    public var position: PointF = PointF()
    public var height: Float = 0
    public var visible: Bool = true
    public var show_dragger: Bool = false

    public init(text_position: TextPosition = TextPosition(), position: PointF = PointF(), height: Float = 0, visible: Bool = true, show_dragger: Bool = false) {
        self.text_position = text_position
        self.position = position
        self.height = height
        self.visible = visible
        self.show_dragger = show_dragger
    }
}

public struct CursorRect {
    public var x: Float = 0
    public var y: Float = 0
    public var height: Float = 0

    public init(x: Float = 0, y: Float = 0, height: Float = 0) {
        self.x = x
        self.y = y
        self.height = height
    }
}

public struct DiagnosticDecoration {
    public var rect: Rect = Rect()
    public var severity: Int32 = 0

    public init(rect: Rect = Rect(), severity: Int32 = 0) {
        self.rect = rect
        self.severity = severity
    }
}

public struct EditorRenderModel {
    public var split_x: Float = 0
    public var split_line_visible: Bool = true
    public var scroll_x: Float = 0
    public var scroll_y: Float = 0
    public var viewport_width: Float = 0
    public var viewport_height: Float = 0
    public var current_line: PointF = PointF()
    public var current_line_render_mode: CurrentLineRenderMode = .BACKGROUND
    public var lines: [VisualLine] = []
    public var cursor: Cursor = Cursor()
    public var selection_rects: [Rect] = []
    public var selection_start_handle: SelectionHandle = SelectionHandle()
    public var selection_end_handle: SelectionHandle = SelectionHandle()
    public var composition_decoration: CompositionDecoration = CompositionDecoration()
    public var guide_segments: [GuideSegment] = []
    public var diagnostic_decorations: [DiagnosticDecoration] = []
    public var max_gutter_icons: Int32 = 0
    public var linked_editing_rects: [LinkedEditingRect] = []
    public var bracket_highlight_rects: [Rect] = []
    public var gutter_icons: [GutterIconRenderItem] = []
    public var fold_markers: [FoldMarkerRenderItem] = []
    public var vertical_scrollbar: ScrollbarModel = ScrollbarModel()
    public var horizontal_scrollbar: ScrollbarModel = ScrollbarModel()
    public var gutter_sticky: Bool = true
    public var gutter_visible: Bool = true
    public var pointer_cursor_type: PointerCursorType = .TEXT

    public init(split_x: Float = 0, split_line_visible: Bool = true, scroll_x: Float = 0, scroll_y: Float = 0, viewport_width: Float = 0, viewport_height: Float = 0, current_line: PointF = PointF(), current_line_render_mode: CurrentLineRenderMode = .BACKGROUND, lines: [VisualLine] = [], cursor: Cursor = Cursor(), selection_rects: [Rect] = [], selection_start_handle: SelectionHandle = SelectionHandle(), selection_end_handle: SelectionHandle = SelectionHandle(), composition_decoration: CompositionDecoration = CompositionDecoration(), guide_segments: [GuideSegment] = [], diagnostic_decorations: [DiagnosticDecoration] = [], max_gutter_icons: Int32 = 0, linked_editing_rects: [LinkedEditingRect] = [], bracket_highlight_rects: [Rect] = [], gutter_icons: [GutterIconRenderItem] = [], fold_markers: [FoldMarkerRenderItem] = [], vertical_scrollbar: ScrollbarModel = ScrollbarModel(), horizontal_scrollbar: ScrollbarModel = ScrollbarModel(), gutter_sticky: Bool = true, gutter_visible: Bool = true, pointer_cursor_type: PointerCursorType = .TEXT) {
        self.split_x = split_x
        self.split_line_visible = split_line_visible
        self.scroll_x = scroll_x
        self.scroll_y = scroll_y
        self.viewport_width = viewport_width
        self.viewport_height = viewport_height
        self.current_line = current_line
        self.current_line_render_mode = current_line_render_mode
        self.lines = lines
        self.cursor = cursor
        self.selection_rects = selection_rects
        self.selection_start_handle = selection_start_handle
        self.selection_end_handle = selection_end_handle
        self.composition_decoration = composition_decoration
        self.guide_segments = guide_segments
        self.diagnostic_decorations = diagnostic_decorations
        self.max_gutter_icons = max_gutter_icons
        self.linked_editing_rects = linked_editing_rects
        self.bracket_highlight_rects = bracket_highlight_rects
        self.gutter_icons = gutter_icons
        self.fold_markers = fold_markers
        self.vertical_scrollbar = vertical_scrollbar
        self.horizontal_scrollbar = horizontal_scrollbar
        self.gutter_sticky = gutter_sticky
        self.gutter_visible = gutter_visible
        self.pointer_cursor_type = pointer_cursor_type
    }
}

public struct FoldMarkerRenderItem {
    public var logical_line: Int32 = 0
    public var fold_state: FoldState = .NONE
    public var rect: Rect = Rect()

    public init(logical_line: Int32 = 0, fold_state: FoldState = .NONE, rect: Rect = Rect()) {
        self.logical_line = logical_line
        self.fold_state = fold_state
        self.rect = rect
    }
}

public struct GuideSegment {
    public var direction: GuideDirection = .VERTICAL
    public var type: GuideType = .INDENT
    public var style: GuideStyle = .SOLID
    public var start: PointF = PointF()
    public var end: PointF = PointF()
    public var arrow_end: Bool = false

    public init(direction: GuideDirection = .VERTICAL, type: GuideType = .INDENT, style: GuideStyle = .SOLID, start: PointF = PointF(), end: PointF = PointF(), arrow_end: Bool = false) {
        self.direction = direction
        self.type = type
        self.style = style
        self.start = start
        self.end = end
        self.arrow_end = arrow_end
    }
}

public struct GutterIconRenderItem {
    public var logical_line: Int32 = 0
    public var icon_id: Int32 = 0
    public var rect: Rect = Rect()

    public init(logical_line: Int32 = 0, icon_id: Int32 = 0, rect: Rect = Rect()) {
        self.logical_line = logical_line
        self.icon_id = icon_id
        self.rect = rect
    }
}

public struct LayoutMetrics {
    public var font_height: Float = 20
    public var font_ascent: Float = 0
    public var line_spacing_add: Float = 0
    public var line_spacing_mult: Float = 1.2
    public var line_number_margin: Float = 10
    public var line_number_width: Float = 10
    public var content_start_padding: Float = 0
    public var max_gutter_icons: Int32 = 0
    public var inlay_hint_padding: Float = 0
    public var inlay_hint_margin: Float = 0
    public var fold_arrow_mode: FoldArrowMode = .AUTO
    public var has_fold_regions: Bool = false
    public var gutter_sticky: Bool = true
    public var gutter_visible: Bool = true

    public init(font_height: Float = 20, font_ascent: Float = 0, line_spacing_add: Float = 0, line_spacing_mult: Float = 1.2, line_number_margin: Float = 10, line_number_width: Float = 10, content_start_padding: Float = 0, max_gutter_icons: Int32 = 0, inlay_hint_padding: Float = 0, inlay_hint_margin: Float = 0, fold_arrow_mode: FoldArrowMode = .AUTO, has_fold_regions: Bool = false, gutter_sticky: Bool = true, gutter_visible: Bool = true) {
        self.font_height = font_height
        self.font_ascent = font_ascent
        self.line_spacing_add = line_spacing_add
        self.line_spacing_mult = line_spacing_mult
        self.line_number_margin = line_number_margin
        self.line_number_width = line_number_width
        self.content_start_padding = content_start_padding
        self.max_gutter_icons = max_gutter_icons
        self.inlay_hint_padding = inlay_hint_padding
        self.inlay_hint_margin = inlay_hint_margin
        self.fold_arrow_mode = fold_arrow_mode
        self.has_fold_regions = has_fold_regions
        self.gutter_sticky = gutter_sticky
        self.gutter_visible = gutter_visible
    }
}

public struct LinkedEditingRect {
    public var rect: Rect = Rect()
    public var is_active: Bool = false

    public init(rect: Rect = Rect(), is_active: Bool = false) {
        self.rect = rect
        self.is_active = is_active
    }
}

public struct ScrollMetrics {
    public var scale: Float = 1
    public var scroll_x: Float = 0
    public var scroll_y: Float = 0
    public var max_scroll_x: Float = 0
    public var max_scroll_y: Float = 0
    public var content_width: Float = 0
    public var content_height: Float = 0
    public var viewport_width: Float = 0
    public var viewport_height: Float = 0
    public var text_area_x: Float = 0
    public var text_area_width: Float = 0
    public var can_scroll_x: Bool = false
    public var can_scroll_y: Bool = false

    public init(scale: Float = 1, scroll_x: Float = 0, scroll_y: Float = 0, max_scroll_x: Float = 0, max_scroll_y: Float = 0, content_width: Float = 0, content_height: Float = 0, viewport_width: Float = 0, viewport_height: Float = 0, text_area_x: Float = 0, text_area_width: Float = 0, can_scroll_x: Bool = false, can_scroll_y: Bool = false) {
        self.scale = scale
        self.scroll_x = scroll_x
        self.scroll_y = scroll_y
        self.max_scroll_x = max_scroll_x
        self.max_scroll_y = max_scroll_y
        self.content_width = content_width
        self.content_height = content_height
        self.viewport_width = viewport_width
        self.viewport_height = viewport_height
        self.text_area_x = text_area_x
        self.text_area_width = text_area_width
        self.can_scroll_x = can_scroll_x
        self.can_scroll_y = can_scroll_y
    }
}

public struct ScrollbarModel {
    public var visible: Bool = false
    public var alpha: Float = 0
    public var thumb_active: Bool = false
    public var track: Rect = Rect()
    public var thumb: Rect = Rect()

    public init(visible: Bool = false, alpha: Float = 0, thumb_active: Bool = false, track: Rect = Rect(), thumb: Rect = Rect()) {
        self.visible = visible
        self.alpha = alpha
        self.thumb_active = thumb_active
        self.track = track
        self.thumb = thumb
    }
}

public struct SelectionHandle {
    public var position: PointF = PointF()
    public var height: Float = 0
    public var visible: Bool = false

    public init(position: PointF = PointF(), height: Float = 0, visible: Bool = false) {
        self.position = position
        self.height = height
        self.visible = visible
    }
}

public struct VisualLine {
    public var logical_line: Int32 = 0
    public var wrap_index: Int32 = 0
    public var line_number_position: PointF = PointF()
    public var runs: [VisualRun] = []
    public var kind: VisualLineKind = .CONTENT
    public var owns_gutter_semantics: Bool = false
    public var fold_state: FoldState = .NONE

    public init(logical_line: Int32 = 0, wrap_index: Int32 = 0, line_number_position: PointF = PointF(), runs: [VisualRun] = [], kind: VisualLineKind = .CONTENT, owns_gutter_semantics: Bool = false, fold_state: FoldState = .NONE) {
        self.logical_line = logical_line
        self.wrap_index = wrap_index
        self.line_number_position = line_number_position
        self.runs = runs
        self.kind = kind
        self.owns_gutter_semantics = owns_gutter_semantics
        self.fold_state = fold_state
    }
}

public struct VisualRun {
    public var type: VisualRunType = .TEXT
    public var x: Float = 0
    public var y: Float = 0
    public var text: String = ""
    public var style: TextStyle = TextStyle()
    public var icon_id: Int32 = 0
    public var color_value: Int32 = 0
    public var width: Float = 0
    public var padding: Float = 0
    public var margin: Float = 0
    public var active: Bool = false

    public init(type: VisualRunType = .TEXT, x: Float = 0, y: Float = 0, text: String = "", style: TextStyle = TextStyle(), icon_id: Int32 = 0, color_value: Int32 = 0, width: Float = 0, padding: Float = 0, margin: Float = 0, active: Bool = false) {
        self.type = type
        self.x = x
        self.y = y
        self.text = text
        self.style = style
        self.icon_id = icon_id
        self.color_value = color_value
        self.width = width
        self.padding = padding
        self.margin = margin
        self.active = active
    }
}
