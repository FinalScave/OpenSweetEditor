import Foundation

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

public enum ImePreeditStorage: Int32 {
    case NONE = 0
    case VISIBLE_DOCUMENT_COMPOSITION = 1
    case SHADOW_ONLY = 2

    public static func fromValue(_ value: Int32) -> ImePreeditStorage {
        switch value {
        case 0: return .NONE
        case 1: return .VISIBLE_DOCUMENT_COMPOSITION
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

public enum ImeTextModelMode: Int32 {
    case DOCUMENT_WINDOW = 0
    case TRANSIENT_INPUT = 1

    public static func fromValue(_ value: Int32) -> ImeTextModelMode {
        switch value {
        case 0: return .DOCUMENT_WINDOW
        case 1: return .TRANSIENT_INPUT
        default: return .DOCUMENT_WINDOW
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

public struct ImeDocumentTextReplacement {
    public var start_offset: Int32 = 0
    public var end_offset: Int32 = 0
    public var text: String = ""
    public var cursor_offset: Int32 = 1
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(start_offset: Int32 = 0, end_offset: Int32 = 0, text: String = "", cursor_offset: Int32 = 1, script_class: ImeScriptClass = .UNKNOWN) {
        self.start_offset = start_offset
        self.end_offset = end_offset
        self.text = text
        self.cursor_offset = cursor_offset
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
    public var kind: ImeInputContextKind = .NONE

    public init(id: Int64 = 0, revision: Int32 = 0, document_start_offset: Int32 = 0, text: String = "", selection: ImeOffsetRange = ImeOffsetRange(), has_composition: Bool = false, composition: ImeOffsetRange = ImeOffsetRange(), kind: ImeInputContextKind = .NONE) {
        self.id = id
        self.revision = revision
        self.document_start_offset = document_start_offset
        self.text = text
        self.selection = selection
        self.has_composition = has_composition
        self.composition = composition
        self.kind = kind
    }
}

public struct ImeInputContextTextReplacement {
    public var start_offset: Int32 = 0
    public var end_offset: Int32 = 0
    public var text: String = ""
    public var cursor_offset: Int32 = 1
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(start_offset: Int32 = 0, end_offset: Int32 = 0, text: String = "", cursor_offset: Int32 = 1, script_class: ImeScriptClass = .UNKNOWN) {
        self.start_offset = start_offset
        self.end_offset = end_offset
        self.text = text
        self.cursor_offset = cursor_offset
        self.script_class = script_class
    }
}

public struct ImeInputStateTextReplacement {
    public var context_id: Int64 = 0
    public var document_start_offset: Int32 = 0
    public var start_offset: Int32 = 0
    public var end_offset: Int32 = 0
    public var text: String = ""
    public var cursor_offset: Int32 = 1
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(context_id: Int64 = 0, document_start_offset: Int32 = 0, start_offset: Int32 = 0, end_offset: Int32 = 0, text: String = "", cursor_offset: Int32 = 1, script_class: ImeScriptClass = .UNKNOWN) {
        self.context_id = context_id
        self.document_start_offset = document_start_offset
        self.start_offset = start_offset
        self.end_offset = end_offset
        self.text = text
        self.cursor_offset = cursor_offset
        self.script_class = script_class
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
    public var has_platform_marked_range: Bool = false
    public var platform_marked_range: TextRange = TextRange()
    public var preedit_storage: ImePreeditStorage = .NONE
    public var context_policy: ImeContextPolicy = .NONE
    public var clear_platform_preedit: Bool = false

    public init(cursor: TextPosition = TextPosition(), selection: TextRange = TextRange(), has_selection: Bool = false, has_composing_session: Bool = false, has_visible_composition_range: Bool = false, visible_composition_range: TextRange = TextRange(), has_platform_marked_range: Bool = false, platform_marked_range: TextRange = TextRange(), preedit_storage: ImePreeditStorage = .NONE, context_policy: ImeContextPolicy = .NONE, clear_platform_preedit: Bool = false) {
        self.cursor = cursor
        self.selection = selection
        self.has_selection = has_selection
        self.has_composing_session = has_composing_session
        self.has_visible_composition_range = has_visible_composition_range
        self.visible_composition_range = visible_composition_range
        self.has_platform_marked_range = has_platform_marked_range
        self.platform_marked_range = platform_marked_range
        self.preedit_storage = preedit_storage
        self.context_policy = context_policy
        self.clear_platform_preedit = clear_platform_preedit
    }
}

public struct ImeTextModelDelta {
    public var mode: ImeTextModelMode = .DOCUMENT_WINDOW
    public var context_id: Int64 = 0
    public var document_start_offset: Int32 = 0
    public var old_text: String = ""
    public var delta: ImeOffsetRange = ImeOffsetRange()
    public var delta_text: String = ""
    public var selection: ImeOffsetRange = ImeOffsetRange()
    public var composition: ImeOffsetRange = ImeOffsetRange()
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(mode: ImeTextModelMode = .DOCUMENT_WINDOW, context_id: Int64 = 0, document_start_offset: Int32 = 0, old_text: String = "", delta: ImeOffsetRange = ImeOffsetRange(), delta_text: String = "", selection: ImeOffsetRange = ImeOffsetRange(), composition: ImeOffsetRange = ImeOffsetRange(), script_class: ImeScriptClass = .UNKNOWN) {
        self.mode = mode
        self.context_id = context_id
        self.document_start_offset = document_start_offset
        self.old_text = old_text
        self.delta = delta
        self.delta_text = delta_text
        self.selection = selection
        self.composition = composition
        self.script_class = script_class
    }
}

public struct ImeTextModelState {
    public var mode: ImeTextModelMode = .DOCUMENT_WINDOW
    public var context_id: Int64 = 0
    public var document_start_offset: Int32 = 0
    public var text: String = ""
    public var selection: ImeOffsetRange = ImeOffsetRange()
    public var composition: ImeOffsetRange = ImeOffsetRange()
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(mode: ImeTextModelMode = .DOCUMENT_WINDOW, context_id: Int64 = 0, document_start_offset: Int32 = 0, text: String = "", selection: ImeOffsetRange = ImeOffsetRange(), composition: ImeOffsetRange = ImeOffsetRange(), script_class: ImeScriptClass = .UNKNOWN) {
        self.mode = mode
        self.context_id = context_id
        self.document_start_offset = document_start_offset
        self.text = text
        self.selection = selection
        self.composition = composition
        self.script_class = script_class
    }
}

public struct ImeTextReplacement {
    public var range: TextRange = TextRange()
    public var text: String = ""
    public var script_class: ImeScriptClass = .UNKNOWN

    public init(range: TextRange = TextRange(), text: String = "", script_class: ImeScriptClass = .UNKNOWN) {
        self.range = range
        self.text = text
        self.script_class = script_class
    }
}
