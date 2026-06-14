import Foundation

public enum ImeCommandKind: Int32 {
    case SET_SELECTION = 0
    case SET_PREEDIT_TEXT = 1
    case COMMIT_TEXT = 2
    case FINISH_PREEDIT = 3
    case CANCEL_PREEDIT = 4
    case SET_MARKED_RANGE = 5
    case CLEAR_MARKED_RANGE = 6
    case REPLACE_TEXT = 7
    case DELETE_SURROUNDING_TEXT = 8
    case SET_KEYBOARD_SCRIPT = 9

    public static func fromValue(_ value: Int32) -> ImeCommandKind {
        switch value {
        case 0: return .SET_SELECTION
        case 1: return .SET_PREEDIT_TEXT
        case 2: return .COMMIT_TEXT
        case 3: return .FINISH_PREEDIT
        case 4: return .CANCEL_PREEDIT
        case 5: return .SET_MARKED_RANGE
        case 6: return .CLEAR_MARKED_RANGE
        case 7: return .REPLACE_TEXT
        case 8: return .DELETE_SURROUNDING_TEXT
        case 9: return .SET_KEYBOARD_SCRIPT
        default: return .SET_SELECTION
        }
    }
}

public enum ImeContextPolicy: Int32 {
    case NONE = 0
    case LIMITED_FOR_CANDIDATES = 1

    public static func fromValue(_ value: Int32) -> ImeContextPolicy {
        switch value {
        case 0: return .NONE
        case 1: return .LIMITED_FOR_CANDIDATES
        default: return .NONE
        }
    }
}

public enum ImeInputContextKind: Int32 {
    case NONE = 0
    case SELECTION_ONLY = 1
    case DOCUMENT_WINDOW = 2
    case TRANSIENT_INPUT = 3

    public static func fromValue(_ value: Int32) -> ImeInputContextKind {
        switch value {
        case 0: return .NONE
        case 1: return .SELECTION_ONLY
        case 2: return .DOCUMENT_WINDOW
        case 3: return .TRANSIENT_INPUT
        default: return .NONE
        }
    }
}

public enum ImeMarkedRangeRole: Int32 {
    case NONE = 0
    case PREEDIT = 1
    case SYSTEM_MARK = 2

    public static func fromValue(_ value: Int32) -> ImeMarkedRangeRole {
        switch value {
        case 0: return .NONE
        case 1: return .PREEDIT
        case 2: return .SYSTEM_MARK
        default: return .NONE
        }
    }
}

public enum ImePreeditStorage: Int32 {
    case NONE = 0
    case VISIBLE_DOCUMENT_PREEDIT = 1
    case SHADOW_ONLY = 2

    public static func fromValue(_ value: Int32) -> ImePreeditStorage {
        switch value {
        case 0: return .NONE
        case 1: return .VISIBLE_DOCUMENT_PREEDIT
        case 2: return .SHADOW_ONLY
        default: return .NONE
        }
    }
}

public enum ImeScriptClass: Int32 {
    case UNKNOWN = 0
    case LATIN = 1
    case CJK = 2
    case KANA = 3
    case HANGUL = 4

    public static func fromValue(_ value: Int32) -> ImeScriptClass {
        switch value {
        case 0: return .UNKNOWN
        case 1: return .LATIN
        case 2: return .CJK
        case 3: return .KANA
        case 4: return .HANGUL
        default: return .UNKNOWN
        }
    }
}

public enum ImeTextUnit: Int32 {
    case GRAPHEME = 0
    case CODE_POINT = 1

    public static func fromValue(_ value: Int32) -> ImeTextUnit {
        switch value {
        case 0: return .GRAPHEME
        case 1: return .CODE_POINT
        default: return .GRAPHEME
        }
    }
}

public enum ImeTextUpdateKind: Int32 {
    case SNAPSHOT = 0
    case PATCH = 1

    public static func fromValue(_ value: Int32) -> ImeTextUpdateKind {
        switch value {
        case 0: return .SNAPSHOT
        case 1: return .PATCH
        default: return .SNAPSHOT
        }
    }
}

public enum ImeTextUpdateScope: Int32 {
    case DOCUMENT_WINDOW = 0
    case TRANSIENT_INPUT = 1

    public static func fromValue(_ value: Int32) -> ImeTextUpdateScope {
        switch value {
        case 0: return .DOCUMENT_WINDOW
        case 1: return .TRANSIENT_INPUT
        default: return .DOCUMENT_WINDOW
        }
    }
}

public struct ImeCommandMessage {
    public var kind: ImeCommandKind = .SET_SELECTION
    public var context_id: Int64 = 0
    public var context_revision: Int32 = 0
    public var document_start_offset: Int32 = 0
    public var range: ImeOffsetRange = ImeOffsetRange()
    public var selection: ImeOffsetRange = ImeOffsetRange()
    public var text: String = ""
    public var cursor_offset: Int32 = 1
    public var delete_before: Int32 = 0
    public var delete_after: Int32 = 0
    public var text_unit: ImeTextUnit = .GRAPHEME
    public var marked_role: ImeMarkedRangeRole = .NONE
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(kind: ImeCommandKind = .SET_SELECTION, context_id: Int64 = 0, context_revision: Int32 = 0, document_start_offset: Int32 = 0, range: ImeOffsetRange = ImeOffsetRange(), selection: ImeOffsetRange = ImeOffsetRange(), text: String = "", cursor_offset: Int32 = 1, delete_before: Int32 = 0, delete_after: Int32 = 0, text_unit: ImeTextUnit = .GRAPHEME, marked_role: ImeMarkedRangeRole = .NONE, script_class: ImeScriptClass = .UNKNOWN) {
        self.kind = kind
        self.context_id = context_id
        self.context_revision = context_revision
        self.document_start_offset = document_start_offset
        self.range = range
        self.selection = selection
        self.text = text
        self.cursor_offset = cursor_offset
        self.delete_before = delete_before
        self.delete_after = delete_after
        self.text_unit = text_unit
        self.marked_role = marked_role
        self.script_class = script_class
    }
}

public struct ImeInputContext {
    public var id: Int64 = 0
    public var revision: Int32 = 0
    public var document_start_offset: Int32 = 0
    public var text: String = ""
    public var selection: ImeOffsetRange = ImeOffsetRange()
    public var has_composition: Bool = false
    public var composition: ImeOffsetRange = ImeOffsetRange()
    public var has_system_mark_range: Bool = false
    public var system_mark_range: ImeOffsetRange = ImeOffsetRange()
    public var kind: ImeInputContextKind = .NONE

    public init(id: Int64 = 0, revision: Int32 = 0, document_start_offset: Int32 = 0, text: String = "", selection: ImeOffsetRange = ImeOffsetRange(), has_composition: Bool = false, composition: ImeOffsetRange = ImeOffsetRange(), has_system_mark_range: Bool = false, system_mark_range: ImeOffsetRange = ImeOffsetRange(), kind: ImeInputContextKind = .NONE) {
        self.id = id
        self.revision = revision
        self.document_start_offset = document_start_offset
        self.text = text
        self.selection = selection
        self.has_composition = has_composition
        self.composition = composition
        self.has_system_mark_range = has_system_mark_range
        self.system_mark_range = system_mark_range
        self.kind = kind
    }
}

public struct ImeMarkedRange {
    public var role: ImeMarkedRangeRole = .NONE
    public var range: ImeOffsetRange = ImeOffsetRange()

    public init(role: ImeMarkedRangeRole = .NONE, range: ImeOffsetRange = ImeOffsetRange()) {
        self.role = role
        self.range = range
    }
}

public struct ImeOffsetRange {
    public var start: Int32 = 0
    public var end: Int32 = 0

    public init(start: Int32 = 0, end: Int32 = 0) {
        self.start = start
        self.end = end
    }
}

public struct ImeSyncSnapshot {
    public var cursor: TextPosition = TextPosition()
    public var selection: TextRange = TextRange()
    public var has_selection: Bool = false
    public var has_composing_session: Bool = false
    public var has_visible_composition_range: Bool = false
    public var visible_composition_range: TextRange = TextRange()
    public var has_system_mark_range: Bool = false
    public var system_mark_range: TextRange = TextRange()
    public var preedit_storage: ImePreeditStorage = .NONE
    public var context_policy: ImeContextPolicy = .NONE
    public var clear_system_mark: Bool = false

    public init(cursor: TextPosition = TextPosition(), selection: TextRange = TextRange(), has_selection: Bool = false, has_composing_session: Bool = false, has_visible_composition_range: Bool = false, visible_composition_range: TextRange = TextRange(), has_system_mark_range: Bool = false, system_mark_range: TextRange = TextRange(), preedit_storage: ImePreeditStorage = .NONE, context_policy: ImeContextPolicy = .NONE, clear_system_mark: Bool = false) {
        self.cursor = cursor
        self.selection = selection
        self.has_selection = has_selection
        self.has_composing_session = has_composing_session
        self.has_visible_composition_range = has_visible_composition_range
        self.visible_composition_range = visible_composition_range
        self.has_system_mark_range = has_system_mark_range
        self.system_mark_range = system_mark_range
        self.preedit_storage = preedit_storage
        self.context_policy = context_policy
        self.clear_system_mark = clear_system_mark
    }
}

public struct ImeTextPatch {
    public var range: ImeOffsetRange = ImeOffsetRange()
    public var text: String = ""

    public init(range: ImeOffsetRange = ImeOffsetRange(), text: String = "") {
        self.range = range
        self.text = text
    }
}

public struct ImeTextUpdateMessage {
    public var kind: ImeTextUpdateKind = .SNAPSHOT
    public var scope: ImeTextUpdateScope = .DOCUMENT_WINDOW
    public var context_id: Int64 = 0
    public var context_revision: Int32 = 0
    public var document_start_offset: Int32 = 0
    public var text: String = ""
    public var patch: ImeTextPatch = ImeTextPatch()
    public var selection: ImeOffsetRange = ImeOffsetRange()
    public var marked_range: ImeMarkedRange = ImeMarkedRange()
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(kind: ImeTextUpdateKind = .SNAPSHOT, scope: ImeTextUpdateScope = .DOCUMENT_WINDOW, context_id: Int64 = 0, context_revision: Int32 = 0, document_start_offset: Int32 = 0, text: String = "", patch: ImeTextPatch = ImeTextPatch(), selection: ImeOffsetRange = ImeOffsetRange(), marked_range: ImeMarkedRange = ImeMarkedRange(), script_class: ImeScriptClass = .UNKNOWN) {
        self.kind = kind
        self.scope = scope
        self.context_id = context_id
        self.context_revision = context_revision
        self.document_start_offset = document_start_offset
        self.text = text
        self.patch = patch
        self.selection = selection
        self.marked_range = marked_range
        self.script_class = script_class
    }
}
