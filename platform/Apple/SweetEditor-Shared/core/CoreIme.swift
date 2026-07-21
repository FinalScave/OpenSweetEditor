import Foundation

public enum ImeCommandKind: Int32 {
    case SET_SELECTION = 0
    case BEGIN_COMPOSITION = 1
    case UPDATE_COMPOSITION = 2
    case COMMIT_TEXT = 3
    case FINISH_COMPOSITION = 4
    case CANCEL_COMPOSITION = 5
    case DELETE_SURROUNDING = 6

    public static func fromValue(_ value: Int32) -> ImeCommandKind? {
        switch value {
        case 0: return .SET_SELECTION
        case 1: return .BEGIN_COMPOSITION
        case 2: return .UPDATE_COMPOSITION
        case 3: return .COMMIT_TEXT
        case 4: return .FINISH_COMPOSITION
        case 5: return .CANCEL_COMPOSITION
        case 6: return .DELETE_SURROUNDING
        default: return nil
        }
    }
}

public enum ImeCoordinateSpace: Int32 {
    case DOCUMENT = 0
    case EDITING_BUFFER = 1
    case CONTEXT_SLICE = 2
    case COMPOSITION = 3

    public static func fromValue(_ value: Int32) -> ImeCoordinateSpace? {
        switch value {
        case 0: return .DOCUMENT
        case 1: return .EDITING_BUFFER
        case 2: return .CONTEXT_SLICE
        case 3: return .COMPOSITION
        default: return nil
        }
    }
}

public enum ImeHostAction: Int32 {
    case NONE = 0
    case CLOSE_SESSION = 1
    case RESTART_SESSION = 2

    public static func fromValue(_ value: Int32) -> ImeHostAction? {
        switch value {
        case 0: return .NONE
        case 1: return .CLOSE_SESSION
        case 2: return .RESTART_SESSION
        default: return nil
        }
    }
}

public enum ImeMutationModel: Int32 {
    case COMMAND = 0
    case TEXT_UPDATE = 1

    public static func fromValue(_ value: Int32) -> ImeMutationModel? {
        switch value {
        case 0: return .COMMAND
        case 1: return .TEXT_UPDATE
        default: return nil
        }
    }
}

public enum ImeResultCode: Int32 {
    case OK = 0
    case SESSION_MISMATCH = 1
    case REJECTED = 2
    case READ_ONLY = 3

    public static func fromValue(_ value: Int32) -> ImeResultCode? {
        switch value {
        case 0: return .OK
        case 1: return .SESSION_MISMATCH
        case 2: return .REJECTED
        case 3: return .READ_ONLY
        default: return nil
        }
    }
}

public enum ImeTextSource: Int32 {
    case EDITING = 0
    case COMMITTED = 1
    case EDITING_BUFFER = 2

    public static func fromValue(_ value: Int32) -> ImeTextSource? {
        switch value {
        case 0: return .EDITING
        case 1: return .COMMITTED
        case 2: return .EDITING_BUFFER
        default: return nil
        }
    }
}

public enum ImeTextUnit: Int32 {
    case UTF16_CODE_UNIT = 0
    case UNICODE_CODE_POINT = 1

    public static func fromValue(_ value: Int32) -> ImeTextUnit? {
        switch value {
        case 0: return .UTF16_CODE_UNIT
        case 1: return .UNICODE_CODE_POINT
        default: return nil
        }
    }
}

public struct ImeCommand {
    public var kind: ImeCommandKind = .SET_SELECTION
    public var target_range: ImeOffsetRange = ImeOffsetRange()
    public var selection_after: ImeSelection = ImeSelection()
    public var text: String = ""
    public var delete_before: Int64 = 0
    public var delete_after: Int64 = 0
    public var text_unit: ImeTextUnit = .UTF16_CODE_UNIT

    public init(kind: ImeCommandKind = .SET_SELECTION, target_range: ImeOffsetRange = ImeOffsetRange(), selection_after: ImeSelection = ImeSelection(), text: String = "", delete_before: Int64 = 0, delete_after: Int64 = 0, text_unit: ImeTextUnit = .UTF16_CODE_UNIT) {
        self.kind = kind
        self.target_range = target_range
        self.selection_after = selection_after
        self.text = text
        self.delete_before = delete_before
        self.delete_after = delete_after
        self.text_unit = text_unit
    }
}

public struct ImeCommandBatch {
    public var session_id: Int64 = 0
    public var commands: [ImeCommand] = []

    public init(session_id: Int64 = 0, commands: [ImeCommand] = []) {
        self.session_id = session_id
        self.commands = commands
    }
}

public struct ImeOffsetRange {
    public var coordinate_space: ImeCoordinateSpace = .DOCUMENT
    public var start_utf16: Int64 = -1
    public var end_utf16: Int64 = -1

    public init(coordinate_space: ImeCoordinateSpace = .DOCUMENT, start_utf16: Int64 = -1, end_utf16: Int64 = -1) {
        self.coordinate_space = coordinate_space
        self.start_utf16 = start_utf16
        self.end_utf16 = end_utf16
    }
}

public struct ImeSelection {
    public var coordinate_space: ImeCoordinateSpace = .DOCUMENT
    public var anchor_utf16: Int64 = -1
    public var active_utf16: Int64 = -1
    public var affinity: CaretAffinity = .DOWNSTREAM

    public init(coordinate_space: ImeCoordinateSpace = .DOCUMENT, anchor_utf16: Int64 = -1, active_utf16: Int64 = -1, affinity: CaretAffinity = .DOWNSTREAM) {
        self.coordinate_space = coordinate_space
        self.anchor_utf16 = anchor_utf16
        self.active_utf16 = active_utf16
        self.affinity = affinity
    }
}

public struct ImeState {
    public var result_code: ImeResultCode = .OK
    public var session_id: Int64 = 0
    public var state_revision: Int64 = 0
    public var selection: ImeSelection = ImeSelection()
    public var composition_range: ImeOffsetRange = ImeOffsetRange()

    public init(result_code: ImeResultCode = .OK, session_id: Int64 = 0, state_revision: Int64 = 0, selection: ImeSelection = ImeSelection(), composition_range: ImeOffsetRange = ImeOffsetRange()) {
        self.result_code = result_code
        self.session_id = session_id
        self.state_revision = state_revision
        self.selection = selection
        self.composition_range = composition_range
    }
}

public struct ImeTextContext {
    public var result_code: ImeResultCode = .OK
    public var slice_start_utf16: Int64 = 0
    public var total_length_utf16: Int64 = 0
    public var text: String = ""
    public var selection: ImeSelection = ImeSelection()
    public var composition_range: ImeOffsetRange = ImeOffsetRange()

    public init(result_code: ImeResultCode = .OK, slice_start_utf16: Int64 = 0, total_length_utf16: Int64 = 0, text: String = "", selection: ImeSelection = ImeSelection(), composition_range: ImeOffsetRange = ImeOffsetRange()) {
        self.result_code = result_code
        self.slice_start_utf16 = slice_start_utf16
        self.total_length_utf16 = total_length_utf16
        self.text = text
        self.selection = selection
        self.composition_range = composition_range
    }
}

public struct ImeTextUpdateBatch {
    public var session_id: Int64 = 0
    public var expected_state_revision: Int64 = 0
    public var steps: [ImeTextUpdateStep] = []

    public init(session_id: Int64 = 0, expected_state_revision: Int64 = 0, steps: [ImeTextUpdateStep] = []) {
        self.session_id = session_id
        self.expected_state_revision = expected_state_revision
        self.steps = steps
    }
}

public struct ImeTextUpdateStep {
    public var old_text: String = ""
    public var patch_range: ImeOffsetRange = ImeOffsetRange()
    public var replacement_text: String = ""
    public var selection_after: ImeSelection = ImeSelection()
    public var composition_after: ImeOffsetRange = ImeOffsetRange()

    public init(old_text: String = "", patch_range: ImeOffsetRange = ImeOffsetRange(), replacement_text: String = "", selection_after: ImeSelection = ImeSelection(), composition_after: ImeOffsetRange = ImeOffsetRange()) {
        self.old_text = old_text
        self.patch_range = patch_range
        self.replacement_text = replacement_text
        self.selection_after = selection_after
        self.composition_after = composition_after
    }
}
