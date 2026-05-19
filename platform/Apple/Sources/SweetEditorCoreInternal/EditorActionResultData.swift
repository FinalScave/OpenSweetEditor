import Foundation

struct TextChangeData: Codable {
    let range: TextRangeData
    let new_text: String
}

enum EditorActionReason: Int32, Codable {
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
}

struct ImeSyncSnapshotData: Codable {
    let cursor: TextPositionData
    let has_selection: Bool
    let selection: TextRangeData
    let has_composing_session: Bool
    let has_visible_composition_range: Bool
    let visible_composition_range: TextRangeData
    let has_platform_marked_range: Bool
    let platform_marked_range: TextRangeData
    let preedit_storage: Int32
    let context_policy: Int32
    let clear_platform_preedit: Bool
}

struct EditorActionResultData: Codable {
    let handled: Bool
    let needs_redraw: Bool
    let reason: EditorActionReason
    let content_changed: Bool
    let cursor_changed: Bool
    let selection_changed: Bool
    let scroll_changed: Bool
    let scale_changed: Bool
    let pointer_cursor_changed: Bool
    let composition_changed: Bool
    let decoration_changed: Bool
    let needs_ime_sync: Bool
    let needs_edge_scroll: Bool
    let needs_fling: Bool
    let needs_animation: Bool
    let is_handle_drag: Bool
    let changes: [TextChangeData]
    let cursor_before: TextPositionData
    let cursor_after: TextPositionData
    let has_selection_before: Bool
    let selection_before: TextRangeData
    let has_selection_after: Bool
    let selection_after: TextRangeData
    let scroll_x_before: Float
    let scroll_y_before: Float
    let scroll_x_after: Float
    let scroll_y_after: Float
    let scale_before: Float
    let scale_after: Float
    let pointer_cursor_before: Int32
    let pointer_cursor_after: Int32
    let ime_sync: ImeSyncSnapshotData
    let gesture_type: GestureType
    let gesture_event_type: SEEventType
    let tap_point: PointData
    let hit_target: HitTargetData
    let modifiers: UInt8
    let command: Int32
}
