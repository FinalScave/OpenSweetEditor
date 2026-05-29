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

public struct HandleConfig {
    public var start_hit_offset: OffsetRect = OffsetRect()
    public var end_hit_offset: OffsetRect = OffsetRect()

    public init(start_hit_offset: OffsetRect = OffsetRect(), end_hit_offset: OffsetRect = OffsetRect()) {
        self.start_hit_offset = start_hit_offset
        self.end_hit_offset = end_hit_offset
    }
}

public struct ScrollbarConfig {
    public var thickness: Float = 10.0
    public var min_thumb: Float = 24.0
    public var thumb_hit_padding: Float = 0.0
    public var mode: ScrollbarMode = .ALWAYS
    public var thumb_draggable: Bool = true
    public var track_tap_mode: ScrollbarTrackTapMode = .JUMP
    public var fade_delay_ms: Int32 = 700
    public var fade_duration_ms: Int32 = 300

    public init(thickness: Float = 10.0, min_thumb: Float = 24.0, thumb_hit_padding: Float = 0.0, mode: ScrollbarMode = .ALWAYS, thumb_draggable: Bool = true, track_tap_mode: ScrollbarTrackTapMode = .JUMP, fade_delay_ms: Int32 = 700, fade_duration_ms: Int32 = 300) {
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
