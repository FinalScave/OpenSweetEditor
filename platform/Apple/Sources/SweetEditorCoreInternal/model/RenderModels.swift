import Foundation

// MARK: - Render Model (matches C++ EditorRenderModel in visual.h)

struct EditorRenderModel: Codable {
    let split_x: Float
    let scroll_x: Float
    let scroll_y: Float
    let viewport_width: Float
    let viewport_height: Float
    let current_line: PointData
    let lines: [VisualLine]
    let cursor: Cursor
    let selection_rects: [SelectionRect]
    let selection_start_handle: SelectionHandle
    let selection_end_handle: SelectionHandle
    let composition_decoration: CompositionDecoration
    let guide_segments: [GuideSegment]
    let diagnostic_decorations: [DiagnosticDecoration]
    let max_gutter_icons: UInt32
    let fold_arrow_x: Float
    let linked_editing_rects: [LinkedEditingRect]
    let bracket_highlight_rects: [BracketHighlightRect]
}

struct PointData: Codable {
    let x: Float
    let y: Float
}

struct TextPositionData: Codable {
    let line: Int
    let column: Int
}

struct VisualLine: Codable {
    let logical_line: Int
    let wrap_index: Int
    let line_number_position: PointData
    let runs: [VisualRun]
    let is_phantom_line: Bool
    let gutter_icon_ids: [Int32]
    let fold_state: FoldState

    init(logical_line: Int, wrap_index: Int, line_number_position: PointData, runs: [VisualRun], is_phantom_line: Bool, gutter_icon_ids: [Int32], fold_state: FoldState) {
        self.logical_line = logical_line
        self.wrap_index = wrap_index
        self.line_number_position = line_number_position
        self.runs = runs
        self.is_phantom_line = is_phantom_line
        self.gutter_icon_ids = gutter_icon_ids
        self.fold_state = fold_state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        logical_line = try container.decode(Int.self, forKey: .logical_line)
        wrap_index = try container.decode(Int.self, forKey: .wrap_index)
        line_number_position = try container.decode(PointData.self, forKey: .line_number_position)
        runs = try container.decode([VisualRun].self, forKey: .runs)
        is_phantom_line = try container.decode(Bool.self, forKey: .is_phantom_line)
        gutter_icon_ids = try container.decode([Int32].self, forKey: .gutter_icon_ids)
        fold_state = try container.decodeIfPresent(FoldState.self, forKey: .fold_state) ?? .NONE
    }
}

/// Fold state enum (matches C++ FoldState).
enum FoldState: String, Codable {
    case NONE
    case EXPANDED
    case COLLAPSED
}

enum VisualRunType: String, Codable {
    case TEXT
    case WHITESPACE
    case NEWLINE
    case INLAY_HINT
    case PHANTOM_TEXT
    case FOLD_PLACEHOLDER
}

struct InlineStyle: Codable {
    let font_style: Int32
    let color: Int32
    let background_color: Int32

    init(font_style: Int32, color: Int32, background_color: Int32) {
        self.font_style = font_style
        self.color = color
        self.background_color = background_color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        font_style = try container.decode(Int32.self, forKey: .font_style)
        color = try container.decode(Int32.self, forKey: .color)
        background_color = try container.decodeIfPresent(Int32.self, forKey: .background_color) ?? 0
    }
}

struct VisualRun: Codable {
    let type: VisualRunType
    let x: Float
    let y: Float
    let text: String
    let style: InlineStyle
    let icon_id: Int32
    let color_value: Int32
    let width: Float
    let padding: Float
    let margin: Float

    init(type: VisualRunType, x: Float, y: Float, text: String, style: InlineStyle, icon_id: Int32, color_value: Int32, width: Float, padding: Float, margin: Float) {
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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(VisualRunType.self, forKey: .type)
        x = try container.decode(Float.self, forKey: .x)
        y = try container.decode(Float.self, forKey: .y)
        text = try container.decode(String.self, forKey: .text)
        style = try container.decode(InlineStyle.self, forKey: .style)
        icon_id = try container.decode(Int32.self, forKey: .icon_id)
        color_value = try container.decodeIfPresent(Int32.self, forKey: .color_value) ?? 0
        width = try container.decode(Float.self, forKey: .width)
        padding = try container.decode(Float.self, forKey: .padding)
        margin = try container.decode(Float.self, forKey: .margin)
    }
}

struct Cursor: Codable {
    let text_position: TextPositionData
    let position: PointData
    let height: Float
    let visible: Bool
    let show_dragger: Bool
}

struct SelectionRect: Codable {
    let origin: PointData
    let width: Float
    let height: Float
}

struct SelectionHandle: Codable {
    let position: PointData
    let height: Float
    let visible: Bool
}

struct CompositionDecoration: Codable {
    let active: Bool
    let origin: PointData
    let width: Float
    let height: Float
}

struct DiagnosticDecoration: Codable {
    let origin: PointData
    let width: Float
    let height: Float
    let severity: Int32   // 0=ERROR, 1=WARNING, 2=INFO, 3=HINT
    let color: Int32      // ARGB, 0=use severity default
}

struct LinkedEditingRect: Codable {
    let origin: PointData
    let width: Float
    let height: Float
    let is_active: Bool
}

struct BracketHighlightRect: Codable {
    let origin: PointData
    let width: Float
    let height: Float
}

enum GuideDirection: String, Codable {
    case HORIZONTAL
    case VERTICAL
}

enum GuideType: String, Codable {
    case INDENT
    case BRACKET
    case FLOW
    case SEPARATOR
}

enum GuideStyle: String, Codable {
    case SOLID
    case DASHED
    case DOUBLE
}

struct GuideSegment: Codable {
    let direction: GuideDirection
    let type: GuideType
    let style: GuideStyle
    let start: PointData
    let end: PointData
    let arrow_end: Bool
}

// MARK: - Hit Target (matches C++ HitTarget in gesture.h)

enum HitTargetType: String, Codable {
    case NONE
    case INLAY_HINT_TEXT
    case INLAY_HINT_ICON
    case GUTTER_ICON
    case FOLD_PLACEHOLDER
    case FOLD_GUTTER
    case INLAY_HINT_COLOR
}

struct HitTargetData: Codable {
    let type: HitTargetType
    let line: Int
    let column: Int
    let icon_id: Int32
    let color_value: Int32

    init(type: HitTargetType, line: Int, column: Int, icon_id: Int32, color_value: Int32) {
        self.type = type
        self.line = line
        self.column = column
        self.icon_id = icon_id
        self.color_value = color_value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(HitTargetType.self, forKey: .type)
        line = try container.decode(Int.self, forKey: .line)
        column = try container.decode(Int.self, forKey: .column)
        icon_id = try container.decode(Int32.self, forKey: .icon_id)
        color_value = try container.decodeIfPresent(Int32.self, forKey: .color_value) ?? 0
    }
}

// MARK: - Text Range (matches C++ TextRange in foundation.h)

struct TextRangeData: Codable {
    let start: TextPositionData
    let end: TextPositionData
}

// MARK: - Gesture Result (matches C++ GestureResult in gesture.h)

enum GestureType: String, Codable {
    case UNDEFINED
    case TAP
    case DOUBLE_TAP
    case LONG_PRESS
    case SCALE
    case SCROLL
    case FAST_SCROLL
    case DRAG_SELECT
    case CONTEXT_MENU
}

struct GestureResultData: Codable {
    let type: GestureType
    let tap_point: PointData
    let modifiers: UInt8
    let scale: Float
    let scroll_x: Float
    let scroll_y: Float
    let cursor_position: TextPositionData
    let has_selection: Bool
    let selection: TextRangeData
    let view_scroll_x: Float
    let view_scroll_y: Float
    let view_scale: Float
    let hit_target: HitTargetData
}

// MARK: - Key Event Result (matches C++ KeyEventResult in editor_core.h)

/// Single text change (precise edit info for one edit location; platform side keeps only range + new_text).
struct TextChangeData: Codable {
    let range: TextRangeData
    let new_text: String
}

struct TextEditResultData: Codable {
    let changed: Bool
    let changes: [TextChangeData]
    let cursor_before: TextPositionData
    let cursor_after: TextPositionData
}

/// Simplified form of C API `textEditResultToU16Json` serialization (contains only `changes`).
struct TextEditResultLite: Codable {
    let changes: [TextChangeData]
}

struct KeyEventResultData: Codable {
    let handled: Bool
    let content_changed: Bool
    let cursor_changed: Bool
    let selection_changed: Bool
    let edit_result: TextEditResultData
}

// MARK: - Layout Metrics (matches C++ LayoutMetrics in visual.h)

struct LayoutMetrics: Codable {
    let font_height: Float
    let font_ascent: Float
    let line_spacing_add: Float
    let line_spacing_mult: Float
    let line_number_margin: Float
    let line_number_width: Float
    let max_gutter_icons: UInt32
    let inlay_hint_padding: Float
    let inlay_hint_margin: Float
    let fold_arrow_mode: String
    let has_fold_regions: Bool
}
