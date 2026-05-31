import Foundation

public enum EventType: Int32 {
    case UNDEFINED = 0
    case TOUCH_DOWN = 1
    case TOUCH_POINTER_DOWN = 2
    case TOUCH_MOVE = 3
    case TOUCH_POINTER_UP = 4
    case TOUCH_UP = 5
    case TOUCH_CANCEL = 6
    case MOUSE_DOWN = 7
    case MOUSE_MOVE = 8
    case MOUSE_UP = 9
    case MOUSE_WHEEL = 10
    case MOUSE_RIGHT_DOWN = 11
    case DIRECT_SCALE = 12
    case DIRECT_SCROLL = 13

    public static func fromValue(_ value: Int32) -> EventType {
        switch value {
        case 0: return .UNDEFINED
        case 1: return .TOUCH_DOWN
        case 2: return .TOUCH_POINTER_DOWN
        case 3: return .TOUCH_MOVE
        case 4: return .TOUCH_POINTER_UP
        case 5: return .TOUCH_UP
        case 6: return .TOUCH_CANCEL
        case 7: return .MOUSE_DOWN
        case 8: return .MOUSE_MOVE
        case 9: return .MOUSE_UP
        case 10: return .MOUSE_WHEEL
        case 11: return .MOUSE_RIGHT_DOWN
        case 12: return .DIRECT_SCALE
        case 13: return .DIRECT_SCROLL
        default: return .UNDEFINED
        }
    }
}

public enum GestureType: Int32 {
    case UNDEFINED = 0
    case TAP = 1
    case DOUBLE_TAP = 2
    case LONG_PRESS = 3
    case SCALE = 4
    case SCROLL = 5
    case FAST_SCROLL = 6
    case DRAG_SELECT = 7
    case CONTEXT_MENU = 8

    public static func fromValue(_ value: Int32) -> GestureType {
        switch value {
        case 0: return .UNDEFINED
        case 1: return .TAP
        case 2: return .DOUBLE_TAP
        case 3: return .LONG_PRESS
        case 4: return .SCALE
        case 5: return .SCROLL
        case 6: return .FAST_SCROLL
        case 7: return .DRAG_SELECT
        case 8: return .CONTEXT_MENU
        default: return .UNDEFINED
        }
    }
}

public enum HitTargetType: Int32 {
    case NONE = 0
    case INLAY_HINT_TEXT = 1
    case INLAY_HINT_ICON = 2
    case GUTTER_ICON = 3
    case FOLD_PLACEHOLDER = 4
    case FOLD_GUTTER = 5
    case INLAY_HINT_COLOR = 6
    case CODELENS = 7
    case LINK = 8

    public static func fromValue(_ value: Int32) -> HitTargetType {
        switch value {
        case 0: return .NONE
        case 1: return .INLAY_HINT_TEXT
        case 2: return .INLAY_HINT_ICON
        case 3: return .GUTTER_ICON
        case 4: return .FOLD_PLACEHOLDER
        case 5: return .FOLD_GUTTER
        case 6: return .INLAY_HINT_COLOR
        case 7: return .CODELENS
        case 8: return .LINK
        default: return .NONE
        }
    }
}

public struct GestureEvent {
    public var type: EventType = .UNDEFINED
    public var points: [PointF] = []
    public var modifiers: Int32 = KeyModifier.NONE
    public var wheel_delta_x: Float = 0
    public var wheel_delta_y: Float = 0
    public var direct_scale: Float = 1

    public init(type: EventType = .UNDEFINED, points: [PointF] = [], modifiers: Int32 = KeyModifier.NONE, wheel_delta_x: Float = 0, wheel_delta_y: Float = 0, direct_scale: Float = 1) {
        self.type = type
        self.points = points
        self.modifiers = modifiers
        self.wheel_delta_x = wheel_delta_x
        self.wheel_delta_y = wheel_delta_y
        self.direct_scale = direct_scale
    }
}

public struct HitTarget {
    public var type: HitTargetType = .NONE
    public var line: Int32 = 0
    public var column: Int32 = 0
    public var icon_id: Int32 = 0
    public var color_value: Int32 = 0

    public init(type: HitTargetType = .NONE, line: Int32 = 0, column: Int32 = 0, icon_id: Int32 = 0, color_value: Int32 = 0) {
        self.type = type
        self.line = line
        self.column = column
        self.icon_id = icon_id
        self.color_value = color_value
    }
}
