import CoreGraphics

public struct TextChangedEvent {
    public let changes: [TextChange]
    public let kind: TextChangeKind
    public let source: EditorActionSource

    public init(changes: [TextChange], kind: TextChangeKind, source: EditorActionSource) {
        self.changes = changes
        self.kind = kind
        self.source = source
    }
}

public struct CursorChangedEvent {
    public let cursorPosition: TextPosition

    public init(cursorPosition: TextPosition) {
        self.cursorPosition = cursorPosition
    }
}

public struct SelectionChangedEvent {
    public let hasSelection: Bool
    public let selection: TextRange?
    public let cursorPosition: TextPosition

    public init(hasSelection: Bool, selection: TextRange?, cursorPosition: TextPosition) {
        self.hasSelection = hasSelection
        self.selection = selection
        self.cursorPosition = cursorPosition
    }
}

public struct ScrollChangedEvent {
    public let scrollX: Float
    public let scrollY: Float

    public init(scrollX: Float, scrollY: Float) {
        self.scrollX = scrollX
        self.scrollY = scrollY
    }
}

public struct ScaleChangedEvent {
    public let scale: Float

    public init(scale: Float) {
        self.scale = scale
    }
}

public struct DocumentLoadedEvent {
    public init() {}
}

public struct LongPressEvent {
    public let cursorPosition: TextPosition
    public let locationInView: CGPoint

    public init(cursorPosition: TextPosition, locationInView: CGPoint) {
        self.cursorPosition = cursorPosition
        self.locationInView = locationInView
    }
}

public struct DoubleTapEvent {
    public let cursorPosition: TextPosition
    public let hasSelection: Bool
    public let selection: TextRange?
    public let locationInView: CGPoint

    public init(
        cursorPosition: TextPosition,
        hasSelection: Bool,
        selection: TextRange?,
        locationInView: CGPoint
    ) {
        self.cursorPosition = cursorPosition
        self.hasSelection = hasSelection
        self.selection = selection
        self.locationInView = locationInView
    }
}

public struct ContextMenuEvent {
    public let cursorPosition: TextPosition
    public let locationInView: CGPoint

    public init(cursorPosition: TextPosition, locationInView: CGPoint) {
        self.cursorPosition = cursorPosition
        self.locationInView = locationInView
    }
}

public struct CodeLensClickEvent {
    public let line: Int
    public let column: Int
    public let commandId: Int32
    public let locationInView: CGPoint

    public init(line: Int, column: Int, commandId: Int32, locationInView: CGPoint) {
        self.line = line
        self.column = column
        self.commandId = commandId
        self.locationInView = locationInView
    }
}

public struct FoldToggleEvent {
    public let line: Int
    public let isGutter: Bool
    public let locationInView: CGPoint

    public init(line: Int, isGutter: Bool, locationInView: CGPoint) {
        self.line = line
        self.isGutter = isGutter
        self.locationInView = locationInView
    }
}

public struct GutterIconClickEvent {
    public let line: Int
    public let iconId: Int32
    public let locationInView: CGPoint

    public init(line: Int, iconId: Int32, locationInView: CGPoint) {
        self.line = line
        self.iconId = iconId
        self.locationInView = locationInView
    }
}

public enum InlayHintKind {
    case text
    case icon
    case color
}

public struct InlayHintClickEvent {
    public let line: Int
    public let column: Int
    public let kind: InlayHintKind
    public let iconId: Int32
    public let colorValue: Int32
    public let locationInView: CGPoint

    public init(
        line: Int,
        column: Int,
        kind: InlayHintKind,
        iconId: Int32,
        colorValue: Int32,
        locationInView: CGPoint
    ) {
        self.line = line
        self.column = column
        self.kind = kind
        self.iconId = iconId
        self.colorValue = colorValue
        self.locationInView = locationInView
    }
}

public struct LinkClickEvent {
    public let line: Int
    public let column: Int
    public let target: String
    public let locationInView: CGPoint

    public init(line: Int, column: Int, target: String, locationInView: CGPoint) {
        self.line = line
        self.column = column
        self.target = target
        self.locationInView = locationInView
    }
}
