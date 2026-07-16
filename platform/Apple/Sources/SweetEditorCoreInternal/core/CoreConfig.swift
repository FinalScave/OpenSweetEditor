import Foundation

public enum AutoIndentMode: Int32 {
    case NONE = 0
    case KEEP_INDENT = 1

    public static func fromValue(_ value: Int32) -> AutoIndentMode {
        switch value {
        case 0: return .NONE
        case 1: return .KEEP_INDENT
        default: return .NONE
        }
    }
}

public enum CurrentLineRenderMode: Int32 {
    case BACKGROUND = 0
    case BORDER = 1
    case NONE = 2

    public static func fromValue(_ value: Int32) -> CurrentLineRenderMode {
        switch value {
        case 0: return .BACKGROUND
        case 1: return .BORDER
        case 2: return .NONE
        default: return .BACKGROUND
        }
    }
}

public enum FoldArrowMode: Int32 {
    case AUTO = 0
    case ALWAYS = 1
    case HIDDEN = 2

    public static func fromValue(_ value: Int32) -> FoldArrowMode {
        switch value {
        case 0: return .AUTO
        case 1: return .ALWAYS
        case 2: return .HIDDEN
        default: return .AUTO
        }
    }
}

public enum RangeEffectUnderlineStyle: Int32 {
    case NONE = 0
    case SOLID = 1
    case DASHED = 2
    case WAVY = 3

    public static func fromValue(_ value: Int32) -> RangeEffectUnderlineStyle {
        switch value {
        case 0: return .NONE
        case 1: return .SOLID
        case 2: return .DASHED
        case 3: return .WAVY
        default: return .NONE
        }
    }
}

public enum ScrollbarMode: Int32 {
    case ALWAYS = 0
    case TRANSIENT = 1
    case NEVER = 2

    public static func fromValue(_ value: Int32) -> ScrollbarMode {
        switch value {
        case 0: return .ALWAYS
        case 1: return .TRANSIENT
        case 2: return .NEVER
        default: return .ALWAYS
        }
    }
}

public enum ScrollbarTrackTapMode: Int32 {
    case JUMP = 0
    case DISABLED = 1

    public static func fromValue(_ value: Int32) -> ScrollbarTrackTapMode {
        switch value {
        case 0: return .JUMP
        case 1: return .DISABLED
        default: return .JUMP
        }
    }
}

public enum WhitespaceRenderMode: Int32 {
    case NONE = 0
    case BOUNDARY = 1
    case SELECTION = 2
    case TRAILING = 3
    case ALL = 4

    public static func fromValue(_ value: Int32) -> WhitespaceRenderMode {
        switch value {
        case 0: return .NONE
        case 1: return .BOUNDARY
        case 2: return .SELECTION
        case 3: return .TRAILING
        case 4: return .ALL
        default: return .NONE
        }
    }
}

public enum WrapMode: Int32 {
    case NONE = 0
    case CHAR_BREAK = 1
    case WORD_BREAK = 2

    public static func fromValue(_ value: Int32) -> WrapMode {
        switch value {
        case 0: return .NONE
        case 1: return .CHAR_BREAK
        case 2: return .WORD_BREAK
        default: return .NONE
        }
    }
}

public struct EditorOptions {
    public var touch_slop: Float = 10
    public var double_tap_timeout: Int64 = 300
    public var long_press_ms: Int64 = 500
    public var fling_friction: Float = 3.5
    public var fling_min_velocity: Float = 50.0
    public var fling_max_velocity: Float = 8000.0
    public var max_undo_stack_size: Int64 = 512
    public var key_chord_timeout_ms: Int64 = 2000
    public var reveal_selection_end_on_select_all: Bool = false

    public init(touch_slop: Float = 10, double_tap_timeout: Int64 = 300, long_press_ms: Int64 = 500, fling_friction: Float = 3.5, fling_min_velocity: Float = 50.0, fling_max_velocity: Float = 8000.0, max_undo_stack_size: Int64 = 512, key_chord_timeout_ms: Int64 = 2000, reveal_selection_end_on_select_all: Bool = false) {
        self.touch_slop = touch_slop
        self.double_tap_timeout = double_tap_timeout
        self.long_press_ms = long_press_ms
        self.fling_friction = fling_friction
        self.fling_min_velocity = fling_min_velocity
        self.fling_max_velocity = fling_max_velocity
        self.max_undo_stack_size = max_undo_stack_size
        self.key_chord_timeout_ms = key_chord_timeout_ms
        self.reveal_selection_end_on_select_all = reveal_selection_end_on_select_all
    }
}

public struct EditorRangeEffectStyles {
    public var selection: RangeEffectStyle = RangeEffectStyle()
    public var search_match: RangeEffectStyle = RangeEffectStyle()
    public var search_current: RangeEffectStyle = RangeEffectStyle()
    public var document_highlight_text: RangeEffectStyle = RangeEffectStyle()
    public var document_highlight_read: RangeEffectStyle = RangeEffectStyle()
    public var document_highlight_write: RangeEffectStyle = RangeEffectStyle()
    public var linked_editing_active: RangeEffectStyle = RangeEffectStyle()
    public var linked_editing_inactive: RangeEffectStyle = RangeEffectStyle()
    public var ime_composition: RangeEffectStyle = RangeEffectStyle()
    public var bracket_match: RangeEffectStyle = RangeEffectStyle()
    public var diagnostic_error: RangeEffectStyle = RangeEffectStyle()
    public var diagnostic_warning: RangeEffectStyle = RangeEffectStyle()
    public var diagnostic_info: RangeEffectStyle = RangeEffectStyle()
    public var diagnostic_hint: RangeEffectStyle = RangeEffectStyle()

    public init(selection: RangeEffectStyle = RangeEffectStyle(), search_match: RangeEffectStyle = RangeEffectStyle(), search_current: RangeEffectStyle = RangeEffectStyle(), document_highlight_text: RangeEffectStyle = RangeEffectStyle(), document_highlight_read: RangeEffectStyle = RangeEffectStyle(), document_highlight_write: RangeEffectStyle = RangeEffectStyle(), linked_editing_active: RangeEffectStyle = RangeEffectStyle(), linked_editing_inactive: RangeEffectStyle = RangeEffectStyle(), ime_composition: RangeEffectStyle = RangeEffectStyle(), bracket_match: RangeEffectStyle = RangeEffectStyle(), diagnostic_error: RangeEffectStyle = RangeEffectStyle(), diagnostic_warning: RangeEffectStyle = RangeEffectStyle(), diagnostic_info: RangeEffectStyle = RangeEffectStyle(), diagnostic_hint: RangeEffectStyle = RangeEffectStyle()) {
        self.selection = selection
        self.search_match = search_match
        self.search_current = search_current
        self.document_highlight_text = document_highlight_text
        self.document_highlight_read = document_highlight_read
        self.document_highlight_write = document_highlight_write
        self.linked_editing_active = linked_editing_active
        self.linked_editing_inactive = linked_editing_inactive
        self.ime_composition = ime_composition
        self.bracket_match = bracket_match
        self.diagnostic_error = diagnostic_error
        self.diagnostic_warning = diagnostic_warning
        self.diagnostic_info = diagnostic_info
        self.diagnostic_hint = diagnostic_hint
    }
}

public struct EditorRenderColors {
    public var text_foreground: Int32 = 0
    public var link_foreground: Int32 = 0
    public var active_link_foreground: Int32 = 0
    public var codelens_foreground: Int32 = 0
    public var active_codelens_foreground: Int32 = 0

    public init(text_foreground: Int32 = 0, link_foreground: Int32 = 0, active_link_foreground: Int32 = 0, codelens_foreground: Int32 = 0, active_codelens_foreground: Int32 = 0) {
        self.text_foreground = text_foreground
        self.link_foreground = link_foreground
        self.active_link_foreground = active_link_foreground
        self.codelens_foreground = codelens_foreground
        self.active_codelens_foreground = active_codelens_foreground
    }
}

public struct HandleConfig {
    public var start_hit_area: HandleHitArea = HandleHitArea()
    public var end_hit_area: HandleHitArea = HandleHitArea()

    public init(start_hit_area: HandleHitArea = HandleHitArea(), end_hit_area: HandleHitArea = HandleHitArea()) {
        self.start_hit_area = start_hit_area
        self.end_hit_area = end_hit_area
    }
}

public struct HandleHitArea {
    public var left: Float = 0
    public var top: Float = 0
    public var right: Float = 0
    public var bottom: Float = 0

    public init(left: Float = 0, top: Float = 0, right: Float = 0, bottom: Float = 0) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }
}

public struct RangeEffectStyle {
    public var foreground_color: Int32 = 0
    public var background_color: Int32 = 0
    public var border_color: Int32 = 0
    public var underline_color: Int32 = 0
    public var underline_style: RangeEffectUnderlineStyle = .NONE

    public init(foreground_color: Int32 = 0, background_color: Int32 = 0, border_color: Int32 = 0, underline_color: Int32 = 0, underline_style: RangeEffectUnderlineStyle = .NONE) {
        self.foreground_color = foreground_color
        self.background_color = background_color
        self.border_color = border_color
        self.underline_color = underline_color
        self.underline_style = underline_style
    }
}

public struct ScrollbarConfig {
    public var thickness: Float = 12.0
    public var min_thumb: Float = 24.0
    public var thumb_hit_padding: Float = 0.0
    public var mode: ScrollbarMode = .ALWAYS
    public var thumb_draggable: Bool = true
    public var track_tap_mode: ScrollbarTrackTapMode = .JUMP
    public var fade_delay_ms: Int32 = 700
    public var fade_duration_ms: Int32 = 300

    public init(thickness: Float = 12.0, min_thumb: Float = 24.0, thumb_hit_padding: Float = 0.0, mode: ScrollbarMode = .ALWAYS, thumb_draggable: Bool = true, track_tap_mode: ScrollbarTrackTapMode = .JUMP, fade_delay_ms: Int32 = 700, fade_duration_ms: Int32 = 300) {
        self.thickness = thickness
        self.min_thumb = min_thumb
        self.thumb_hit_padding = thumb_hit_padding
        self.mode = mode
        self.thumb_draggable = thumb_draggable
        self.track_tap_mode = track_tap_mode
        self.fade_delay_ms = fade_delay_ms
        self.fade_duration_ms = fade_duration_ms
    }
}
