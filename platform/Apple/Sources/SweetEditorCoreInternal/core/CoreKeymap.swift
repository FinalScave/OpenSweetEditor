import Foundation

public enum EditorBuiltinCommand: Int32 {
    case NONE = 0
    case CURSOR_LEFT = 1
    case CURSOR_RIGHT = 2
    case CURSOR_UP = 3
    case CURSOR_DOWN = 4
    case CURSOR_LINE_START = 5
    case CURSOR_LINE_END = 6
    case CURSOR_PAGE_UP = 7
    case CURSOR_PAGE_DOWN = 8
    case SELECT_LEFT = 9
    case SELECT_RIGHT = 10
    case SELECT_UP = 11
    case SELECT_DOWN = 12
    case SELECT_LINE_START = 13
    case SELECT_LINE_END = 14
    case SELECT_PAGE_UP = 15
    case SELECT_PAGE_DOWN = 16
    case SELECT_ALL = 17
    case BACKSPACE = 18
    case DELETE_FORWARD = 19
    case INSERT_TAB = 20
    case INSERT_NEWLINE = 21
    case INSERT_LINE_ABOVE = 22
    case INSERT_LINE_BELOW = 23
    case UNDO = 24
    case REDO = 25
    case MOVE_LINE_UP = 26
    case MOVE_LINE_DOWN = 27
    case COPY_LINE_UP = 28
    case COPY_LINE_DOWN = 29
    case DELETE_LINE = 30
    case COPY = 31
    case PASTE = 32
    case CUT = 33
    case TRIGGER_COMPLETION = 34

    public static func fromValue(_ value: Int32) -> EditorBuiltinCommand {
        switch value {
        case 0: return .NONE
        case 1: return .CURSOR_LEFT
        case 2: return .CURSOR_RIGHT
        case 3: return .CURSOR_UP
        case 4: return .CURSOR_DOWN
        case 5: return .CURSOR_LINE_START
        case 6: return .CURSOR_LINE_END
        case 7: return .CURSOR_PAGE_UP
        case 8: return .CURSOR_PAGE_DOWN
        case 9: return .SELECT_LEFT
        case 10: return .SELECT_RIGHT
        case 11: return .SELECT_UP
        case 12: return .SELECT_DOWN
        case 13: return .SELECT_LINE_START
        case 14: return .SELECT_LINE_END
        case 15: return .SELECT_PAGE_UP
        case 16: return .SELECT_PAGE_DOWN
        case 17: return .SELECT_ALL
        case 18: return .BACKSPACE
        case 19: return .DELETE_FORWARD
        case 20: return .INSERT_TAB
        case 21: return .INSERT_NEWLINE
        case 22: return .INSERT_LINE_ABOVE
        case 23: return .INSERT_LINE_BELOW
        case 24: return .UNDO
        case 25: return .REDO
        case 26: return .MOVE_LINE_UP
        case 27: return .MOVE_LINE_DOWN
        case 28: return .COPY_LINE_UP
        case 29: return .COPY_LINE_DOWN
        case 30: return .DELETE_LINE
        case 31: return .COPY
        case 32: return .PASTE
        case 33: return .CUT
        case 34: return .TRIGGER_COMPLETION
        default: return .NONE
        }
    }
}

public enum KeyCode {
    public static let NONE: Int32 = 0
    public static let BACKSPACE: Int32 = 8
    public static let TAB: Int32 = 9
    public static let ENTER: Int32 = 13
    public static let ESCAPE: Int32 = 27
    public static let DELETE_KEY: Int32 = 46
    public static let LEFT: Int32 = 37
    public static let UP: Int32 = 38
    public static let RIGHT: Int32 = 39
    public static let DOWN: Int32 = 40
    public static let HOME: Int32 = 36
    public static let END: Int32 = 35
    public static let PAGE_UP: Int32 = 33
    public static let PAGE_DOWN: Int32 = 34
    public static let A: Int32 = 65
    public static let C: Int32 = 67
    public static let D: Int32 = 68
    public static let V: Int32 = 86
    public static let X: Int32 = 88
    public static let Z: Int32 = 90
    public static let Y: Int32 = 89
    public static let K: Int32 = 75
    public static let SPACE: Int32 = 32
}

public enum KeyModifier {
    public static let NONE: Int32 = 0
    public static let SHIFT: Int32 = 1
    public static let CTRL: Int32 = 2
    public static let ALT: Int32 = 4
    public static let META: Int32 = 8
}

public struct KeyBinding {
    public var first: KeyChord = KeyChord()
    public var second: KeyChord = KeyChord()
    public var command: Int32 = 0

    public init(first: KeyChord = KeyChord(), second: KeyChord = KeyChord(), command: Int32 = 0) {
        self.first = first
        self.second = second
        self.command = command
    }
}

public struct KeyChord {
    public var modifiers: Int32 = KeyModifier.NONE
    public var key_code: Int32 = KeyCode.NONE

    public init(modifiers: Int32 = KeyModifier.NONE, key_code: Int32 = KeyCode.NONE) {
        self.modifiers = modifiers
        self.key_code = key_code
    }
}
