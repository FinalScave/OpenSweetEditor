import Foundation

public enum EditorActionReason: Int32 {
    case NONE = 0
    case SETUP = 1
    case TEXT_EDIT = 2
    case KEY_INPUT = 3
    case IME = 4
    case GESTURE = 5
    case ANIMATION = 6
    case PROGRAMMATIC = 7
    case DECORATION = 8
    case FOLDING = 9
    case LINKED_EDITING = 10
    case TEXT_INSERT = 11
    case TEXT_REPLACE = 12
    case TEXT_DELETE = 13
    case TEXT_UNDO = 14
    case TEXT_REDO = 15
    case SEARCH = 16

    public static func fromValue(_ value: Int32) -> EditorActionReason {
        switch value {
        case 0: return .NONE
        case 1: return .SETUP
        case 2: return .TEXT_EDIT
        case 3: return .KEY_INPUT
        case 4: return .IME
        case 5: return .GESTURE
        case 6: return .ANIMATION
        case 7: return .PROGRAMMATIC
        case 8: return .DECORATION
        case 9: return .FOLDING
        case 10: return .LINKED_EDITING
        case 11: return .TEXT_INSERT
        case 12: return .TEXT_REPLACE
        case 13: return .TEXT_DELETE
        case 14: return .TEXT_UNDO
        case 15: return .TEXT_REDO
        case 16: return .SEARCH
        default: return .NONE
        }
    }
}

public enum ScrollBehavior: Int32 {
    case GOTO_TOP = 0
    case GOTO_CENTER = 1
    case GOTO_BOTTOM = 2

    public static func fromValue(_ value: Int32) -> ScrollBehavior {
        switch value {
        case 0: return .GOTO_TOP
        case 1: return .GOTO_CENTER
        case 2: return .GOTO_BOTTOM
        default: return .GOTO_TOP
        }
    }
}

public struct EditorActionResult {
    public var handled: Bool = false
    public var needs_redraw: Bool = false
    public var reason: EditorActionReason = .NONE
    public var content_changed: Bool = false
    public var cursor_changed: Bool = false
    public var selection_changed: Bool = false
    public var scroll_changed: Bool = false
    public var scale_changed: Bool = false
    public var pointer_cursor_changed: Bool = false
    public var composition_changed: Bool = false
    public var decoration_changed: Bool = false
    public var needs_ime_sync: Bool = false
    public var needs_edge_scroll: Bool = false
    public var needs_fling: Bool = false
    public var needs_animation: Bool = false
    public var is_handle_drag: Bool = false
    public var changes: [TextChange] = []
    public var cursor_before: TextPosition = TextPosition()
    public var cursor_after: TextPosition = TextPosition()
    public var has_selection_before: Bool = false
    public var has_selection_after: Bool = false
    public var selection_before: TextRange = TextRange()
    public var selection_after: TextRange = TextRange()
    public var scroll_x_before: Float = 0
    public var scroll_y_before: Float = 0
    public var scroll_x_after: Float = 0
    public var scroll_y_after: Float = 0
    public var scale_before: Float = 1
    public var scale_after: Float = 1
    public var pointer_cursor_before: PointerCursorType = .TEXT
    public var pointer_cursor_after: PointerCursorType = .TEXT
    public var ime_sync: ImeSyncSnapshot = ImeSyncSnapshot()
    public var gesture_type: GestureType = .UNDEFINED
    public var gesture_event_type: EventType = .UNDEFINED
    public var tap_point: PointF = PointF()
    public var hit_target: HitTarget = HitTarget()
    public var modifiers: Int32 = KeyModifier.NONE
    public var command: Int32 = 0

    public init(handled: Bool = false, needs_redraw: Bool = false, reason: EditorActionReason = .NONE, content_changed: Bool = false, cursor_changed: Bool = false, selection_changed: Bool = false, scroll_changed: Bool = false, scale_changed: Bool = false, pointer_cursor_changed: Bool = false, composition_changed: Bool = false, decoration_changed: Bool = false, needs_ime_sync: Bool = false, needs_edge_scroll: Bool = false, needs_fling: Bool = false, needs_animation: Bool = false, is_handle_drag: Bool = false, changes: [TextChange] = [], cursor_before: TextPosition = TextPosition(), cursor_after: TextPosition = TextPosition(), has_selection_before: Bool = false, has_selection_after: Bool = false, selection_before: TextRange = TextRange(), selection_after: TextRange = TextRange(), scroll_x_before: Float = 0, scroll_y_before: Float = 0, scroll_x_after: Float = 0, scroll_y_after: Float = 0, scale_before: Float = 1, scale_after: Float = 1, pointer_cursor_before: PointerCursorType = .TEXT, pointer_cursor_after: PointerCursorType = .TEXT, ime_sync: ImeSyncSnapshot = ImeSyncSnapshot(), gesture_type: GestureType = .UNDEFINED, gesture_event_type: EventType = .UNDEFINED, tap_point: PointF = PointF(), hit_target: HitTarget = HitTarget(), modifiers: Int32 = KeyModifier.NONE, command: Int32 = 0) {
        self.handled = handled
        self.needs_redraw = needs_redraw
        self.reason = reason
        self.content_changed = content_changed
        self.cursor_changed = cursor_changed
        self.selection_changed = selection_changed
        self.scroll_changed = scroll_changed
        self.scale_changed = scale_changed
        self.pointer_cursor_changed = pointer_cursor_changed
        self.composition_changed = composition_changed
        self.decoration_changed = decoration_changed
        self.needs_ime_sync = needs_ime_sync
        self.needs_edge_scroll = needs_edge_scroll
        self.needs_fling = needs_fling
        self.needs_animation = needs_animation
        self.is_handle_drag = is_handle_drag
        self.changes = changes
        self.cursor_before = cursor_before
        self.cursor_after = cursor_after
        self.has_selection_before = has_selection_before
        self.has_selection_after = has_selection_after
        self.selection_before = selection_before
        self.selection_after = selection_after
        self.scroll_x_before = scroll_x_before
        self.scroll_y_before = scroll_y_before
        self.scroll_x_after = scroll_x_after
        self.scroll_y_after = scroll_y_after
        self.scale_before = scale_before
        self.scale_after = scale_after
        self.pointer_cursor_before = pointer_cursor_before
        self.pointer_cursor_after = pointer_cursor_after
        self.ime_sync = ime_sync
        self.gesture_type = gesture_type
        self.gesture_event_type = gesture_event_type
        self.tap_point = tap_point
        self.hit_target = hit_target
        self.modifiers = modifiers
        self.command = command
    }
}
