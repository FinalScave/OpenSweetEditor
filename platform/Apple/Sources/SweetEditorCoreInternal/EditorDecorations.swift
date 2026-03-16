import Foundation

public struct EditorFoldRegion {
    public let startLine: Int
    public let endLine: Int
    public let collapsed: Bool

    public init(startLine: Int, endLine: Int, collapsed: Bool) {
        self.startLine = startLine
        self.endLine = endLine
        self.collapsed = collapsed
    }
}

public struct EditorDiagnosticItem {
    public let column: Int32
    public let length: Int32
    public let severity: Int32
    public let color: Int32

    public init(column: Int32, length: Int32, severity: Int32, color: Int32) {
        self.column = column
        self.length = length
        self.severity = severity
        self.color = color
    }
}

public struct EditorLineDiagnostics {
    public let line: Int
    public let items: [EditorDiagnosticItem]

    public init(line: Int, items: [EditorDiagnosticItem]) {
        self.line = line
        self.items = items
    }
}

public struct EditorTextInlay {
    public let line: Int
    public let column: Int
    public let text: String

    public init(line: Int, column: Int, text: String) {
        self.line = line
        self.column = column
        self.text = text
    }
}

public struct EditorColorInlay {
    public let line: Int
    public let column: Int
    public let color: Int32

    public init(line: Int, column: Int, color: Int32) {
        self.line = line
        self.column = column
        self.color = color
    }
}

public struct EditorPhantomText {
    public let line: Int
    public let column: Int
    public let text: String

    public init(line: Int, column: Int, text: String) {
        self.line = line
        self.column = column
        self.text = text
    }
}

public struct EditorResolvedDecorations {
    public let foldRegions: [EditorFoldRegion]
    public let diagnostics: [EditorLineDiagnostics]
    public let textInlays: [EditorTextInlay]
    public let colorInlays: [EditorColorInlay]
    public let phantomTexts: [EditorPhantomText]

    public init(
        foldRegions: [EditorFoldRegion] = [],
        diagnostics: [EditorLineDiagnostics] = [],
        textInlays: [EditorTextInlay] = [],
        colorInlays: [EditorColorInlay] = [],
        phantomTexts: [EditorPhantomText] = []
    ) {
        self.foldRegions = foldRegions
        self.diagnostics = diagnostics
        self.textInlays = textInlays
        self.colorInlays = colorInlays
        self.phantomTexts = phantomTexts
    }
}

public extension EditorResolvedDecorations {
    static let empty = EditorResolvedDecorations()
}
