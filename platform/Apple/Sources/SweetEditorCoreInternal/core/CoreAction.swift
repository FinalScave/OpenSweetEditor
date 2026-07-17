import Foundation

public enum AnimationFlag {
    public static let NONE: Int32 = 0
    public static let EDGE_SCROLL: Int32 = 1
    public static let FLING: Int32 = 2
    public static let TRANSIENT_SCROLLBAR: Int32 = 4
}

public enum EditorActionSource: Int32 {
    case NONE = 0
    case SETUP = 1
    case PROGRAMMATIC = 2
    case KEYBOARD = 3
    case IME = 4
    case GESTURE = 5
    case ANIMATION = 6
    case DECORATION = 7
    case FOLDING = 8
    case SEARCH = 9
    case LINKED_EDITING = 10

    public static func fromValue(_ value: Int32) -> EditorActionSource {
        switch value {
        case 0: return .NONE
        case 1: return .SETUP
        case 2: return .PROGRAMMATIC
        case 3: return .KEYBOARD
        case 4: return .IME
        case 5: return .GESTURE
        case 6: return .ANIMATION
        case 7: return .DECORATION
        case 8: return .FOLDING
        case 9: return .SEARCH
        case 10: return .LINKED_EDITING
        default: return .NONE
        }
    }
}

public enum InteractionFlag {
    public static let NONE: Int32 = 0
    public static let PRIMARY_POINTER: Int32 = 1
    public static let SELECTION_DRAG: Int32 = 2
    public static let VIEWPORT_GESTURE: Int32 = 4
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

public enum TextChangeKind: Int32 {
    case NONE = 0
    case INSERTION = 1
    case REPLACEMENT = 2
    case DELETION = 3
    case MOVE = 4
    case UNDO = 5
    case REDO = 6
    case MIXED = 7

    public static func fromValue(_ value: Int32) -> TextChangeKind {
        switch value {
        case 0: return .NONE
        case 1: return .INSERTION
        case 2: return .REPLACEMENT
        case 3: return .DELETION
        case 4: return .MOVE
        case 5: return .UNDO
        case 6: return .REDO
        case 7: return .MIXED
        default: return .NONE
        }
    }
}

public struct EditorActionResult {
    public var handled: Bool = false
    public var needs_redraw: Bool = false
    public var source: EditorActionSource = .NONE
    public var text_change_kind: TextChangeKind = .NONE
    public var content_changed: Bool = false
    public var cursor_changed: Bool = false
    public var selection_changed: Bool = false
    public var scroll_changed: Bool = false
    public var scale_changed: Bool = false
    public var pointer_cursor_changed: Bool = false
    public var composition_changed: Bool = false
    public var decoration_changed: Bool = false
    public var needs_ime_sync: Bool = false
    public var animation_flags: Int32 = 0
    public var next_animation_delay_ms: Int32 = 0
    public var interaction_flags: Int32 = 0
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

    public init(handled: Bool = false, needs_redraw: Bool = false, source: EditorActionSource = .NONE, text_change_kind: TextChangeKind = .NONE, content_changed: Bool = false, cursor_changed: Bool = false, selection_changed: Bool = false, scroll_changed: Bool = false, scale_changed: Bool = false, pointer_cursor_changed: Bool = false, composition_changed: Bool = false, decoration_changed: Bool = false, needs_ime_sync: Bool = false, animation_flags: Int32 = 0, next_animation_delay_ms: Int32 = 0, interaction_flags: Int32 = 0, changes: [TextChange] = [], cursor_before: TextPosition = TextPosition(), cursor_after: TextPosition = TextPosition(), has_selection_before: Bool = false, has_selection_after: Bool = false, selection_before: TextRange = TextRange(), selection_after: TextRange = TextRange(), scroll_x_before: Float = 0, scroll_y_before: Float = 0, scroll_x_after: Float = 0, scroll_y_after: Float = 0, scale_before: Float = 1, scale_after: Float = 1, pointer_cursor_before: PointerCursorType = .TEXT, pointer_cursor_after: PointerCursorType = .TEXT, ime_sync: ImeSyncSnapshot = ImeSyncSnapshot(), gesture_type: GestureType = .UNDEFINED, gesture_event_type: EventType = .UNDEFINED, tap_point: PointF = PointF(), hit_target: HitTarget = HitTarget(), modifiers: Int32 = KeyModifier.NONE, command: Int32 = 0) {
        self.handled = handled
        self.needs_redraw = needs_redraw
        self.source = source
        self.text_change_kind = text_change_kind
        self.content_changed = content_changed
        self.cursor_changed = cursor_changed
        self.selection_changed = selection_changed
        self.scroll_changed = scroll_changed
        self.scale_changed = scale_changed
        self.pointer_cursor_changed = pointer_cursor_changed
        self.composition_changed = composition_changed
        self.decoration_changed = decoration_changed
        self.needs_ime_sync = needs_ime_sync
        self.animation_flags = animation_flags
        self.next_animation_delay_ms = next_animation_delay_ms
        self.interaction_flags = interaction_flags
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
