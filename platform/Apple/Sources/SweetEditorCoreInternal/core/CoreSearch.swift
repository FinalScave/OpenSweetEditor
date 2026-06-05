import Foundation

public enum SearchStatus: Int32 {
    case INACTIVE = 0
    case SEARCHING = 1
    case READY = 2
    case STALE = 3
    case FAILED = 4

    public static func fromValue(_ value: Int32) -> SearchStatus {
        switch value {
        case 0: return .INACTIVE
        case 1: return .SEARCHING
        case 2: return .READY
        case 3: return .STALE
        case 4: return .FAILED
        default: return .INACTIVE
        }
    }
}

public struct SearchOptions {
    public var case_sensitive: Bool = false
    public var whole_word: Bool = false
    public var use_regex: Bool = false
    public var wrap_around: Bool = true
    public var max_matches: Int32 = 10000

    public init(case_sensitive: Bool = false, whole_word: Bool = false, use_regex: Bool = false, wrap_around: Bool = true, max_matches: Int32 = 10000) {
        self.case_sensitive = case_sensitive
        self.whole_word = whole_word
        self.use_regex = use_regex
        self.wrap_around = wrap_around
        self.max_matches = max_matches
    }
}

public struct SearchReplaceRequest {
    public var replacement: String = ""

    public init(replacement: String = "") {
        self.replacement = replacement
    }
}

public struct SearchRequest {
    public var pattern: String = ""
    public var options: SearchOptions = SearchOptions()

    public init(pattern: String = "", options: SearchOptions = SearchOptions()) {
        self.pattern = pattern
        self.options = options
    }
}

public struct SearchState {
    public var status: SearchStatus = .INACTIVE
    public var pattern: String = ""
    public var options: SearchOptions = SearchOptions()
    public var generation: Int64 = 0
    public var document_revision: Int64 = 0
    public var match_count: Int32 = 0
    public var current_index: Int32 = -1
    public var has_current_match: Bool = false
    public var current_range: TextRange = TextRange()
    public var error_message: String = ""

    public init(status: SearchStatus = .INACTIVE, pattern: String = "", options: SearchOptions = SearchOptions(), generation: Int64 = 0, document_revision: Int64 = 0, match_count: Int32 = 0, current_index: Int32 = -1, has_current_match: Bool = false, current_range: TextRange = TextRange(), error_message: String = "") {
        self.status = status
        self.pattern = pattern
        self.options = options
        self.generation = generation
        self.document_revision = document_revision
        self.match_count = match_count
        self.current_index = current_index
        self.has_current_match = has_current_match
        self.current_range = current_range
        self.error_message = error_message
    }
}
