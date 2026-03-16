import Foundation
import SweetEditorMacOS

public enum DemoSampleSupport {
    public static let fallbackText = """
    // SweetEditor Demo - Cross-platform Code Editor
    // Try editing this text, scrolling, and selecting!

    #include <iostream>
    #include <vector>
    #include <string>
    #include <algorithm>

    namespace sweeteditor {

    /// A simple 2D point structure
    struct Point {
        float x = 0;
        float y = 0;

        float distance(const Point& other) const {
            float dx = x - other.x;
            float dy = y - other.y;
            return std::sqrt(dx * dx + dy * dy);
        }

        Point operator+(const Point& other) const {
            return {x + other.x, y + other.y};
        }

        Point operator*(float scalar) const {
            return {x * scalar, y * scalar};
        }
    };

    /// Rectangle defined by origin and size
    struct Rect {
        Point origin;
        float width = 0;
        float height = 0;

        bool contains(const Point& p) const {
            return p.x >= origin.x && p.x <= origin.x + width
                && p.y >= origin.y && p.y <= origin.y + height;
        }

        float area() const { return width * height; }
    };

    /// Simple text buffer implementation
    class TextBuffer {
    public:
        TextBuffer() = default;

        explicit TextBuffer(const std::string& content) {
            std::string line;
            for (char ch : content) {
                if (ch == '\\n') {
                    lines_.push_back(line);
                    line.clear();
                } else {
                    line += ch;
                }
            }
            if (!line.empty()) {
                lines_.push_back(line);
            }
        }

        size_t lineCount() const { return lines_.size(); }

        const std::string& getLine(size_t index) const {
            static const std::string empty;
            if (index >= lines_.size()) return empty;
            return lines_[index];
        }

        void insertText(size_t line, size_t column, const std::string& text) {
            if (line >= lines_.size()) return;
            auto& target = lines_[line];
            if (column > target.size()) column = target.size();
            target.insert(column, text);
        }

        void deleteLine(size_t line) {
            if (line < lines_.size()) {
                lines_.erase(lines_.begin() + line);
            }
        }

    private:
        std::vector<std::string> lines_;
    };

    } // namespace sweeteditor

    int main() {
        using namespace sweeteditor;

        TextBuffer buffer("Hello, World!\\nThis is a test.\\nLine three here.");

        std::cout << "Line count: " << buffer.lineCount() << std::endl;
        for (size_t i = 0; i < buffer.lineCount(); ++i) {
            std::cout << "[" << i << "] " << buffer.getLine(i) << std::endl;
        }

        Point a{3.0f, 4.0f};
        Point b{6.0f, 8.0f};
        std::cout << "Distance: " << a.distance(b) << std::endl;

        Rect rect{{0, 0}, 10, 10};
        std::cout << "Contains (5,5): " << rect.contains({5, 5}) << std::endl;
        std::cout << "Area: " << rect.area() << std::endl;

        return 0;
    }
    """

    public static func loadSampleText() -> String {
        if let text = loadSampleTextFromAvailableBundles() {
            return text
        }
        return fallbackText
    }

    public static func resolve(lines: [String]) -> EditorResolvedDecorations {
        EditorResolvedDecorations(
            foldRegions: resolveFoldRegions(lines: lines),
            diagnostics: resolveDiagnostics(lines: lines),
            textInlays: resolveTextInlays(lines: lines),
            colorInlays: resolveColorInlays(lines: lines),
            phantomTexts: resolvePhantomTexts(lines: lines)
        )
    }

    private static func resolveFoldRegions(lines: [String]) -> [EditorFoldRegion] {
        let foldTargets: [(anchor: String, collapsed: Bool)] = [
            ("struct Point {", false),
            ("float distance(const Point& other) const {", false),
            ("Point operator+(const Point& other) const {", true),
            ("Point operator*(float scalar) const {", true),
            ("struct Rect {", false),
            ("bool contains(const Point& p) const {", false),
            ("class TextBuffer {", false),
            ("explicit TextBuffer(const std::string& content) {", true),
            ("if (ch == '\\n') {", false),
            ("void insertText(size_t line, size_t column, const std::string& text) {", false),
            ("void deleteLine(size_t line) {", false),
            ("namespace sweeteditor {", false),
            ("int main() {", false),
        ]

        return foldTargets.compactMap { target in
            guard let startLine = findLine(containing: target.anchor, in: lines),
                  let endLine = findBlockEnd(startingAt: startLine, in: lines) else {
                return nil
            }
            return EditorFoldRegion(startLine: startLine, endLine: endLine, collapsed: target.collapsed)
        }
    }

    private static func resolveDiagnostics(lines: [String]) -> [EditorLineDiagnostics] {
        var diagnosticsByLine: [Int: [EditorDiagnosticItem]] = [:]

        if let line = findLine(containing: "float x = 0;", in: lines),
           let column = findColumn(of: "0", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: 1, severity: 1, color: 0))
        }

        if let line = findLine(containing: "float distance(const Point& other) const {", in: lines),
           let column = findColumn(of: "distance", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: Int32("distance".count), severity: 3, color: 0))
        }

        if let line = findLine(containing: "void insertText(size_t line, size_t column, const std::string& text) {", in: lines),
           let column = findColumn(of: "insertText", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: Int32("insertText".count), severity: 0, color: 0))
        }

        if let line = findLine(containing: "target.insert(column, text);", in: lines),
           let column = findColumn(of: "insert", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: Int32("insert".count), severity: 0, color: 0))
        }

        if let line = findLine(containing: "TextBuffer buffer(\"Hello, World!\\nThis is a test.\\nLine three here.\");", in: lines),
           let column = findColumn(of: "\"Hello, World!\\nThis is a test.\\nLine three here.\"", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: Int32("\"Hello, World!\\nThis is a test.\\nLine three here.\"".count), severity: 2, color: 0))
        }

        if let line = findLine(containing: "Point a{", in: lines),
           let column = findColumn(of: "a{", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(column), length: 1, severity: 1, color: Int32(bitPattern: 0xFFFF8C00)))
        }

        if let line = findLine(containing: "Rect rect{{0, 0}, 10, 10};", in: lines),
           let rectColumn = findColumn(of: "rect", in: lines[line]),
           let initColumn = findColumn(of: "{0, 0}", in: lines[line]) {
            diagnosticsByLine[line, default: []].append(.init(column: Int32(rectColumn), length: Int32("rect".count), severity: 3, color: 0))
            diagnosticsByLine[line, default: []].append(.init(column: Int32(initColumn), length: Int32("{0, 0}".count), severity: 1, color: 0))
        }

        return diagnosticsByLine.keys.sorted().map {
            EditorLineDiagnostics(line: $0, items: diagnosticsByLine[$0] ?? [])
        }
    }

    private static func resolveTextInlays(lines: [String]) -> [EditorTextInlay] {
        guard let line = findLine(containing: "target.insert(column, text);", in: lines) else {
            return []
        }

        var items: [EditorTextInlay] = []
        if let columnColumn = findColumn(of: "column", in: lines[line]) {
            items.append(.init(line: line, column: columnColumn, text: "column: "))
        }
        if let textColumn = findColumn(of: "text", in: lines[line]) {
            items.append(.init(line: line, column: textColumn, text: "text: "))
        }
        return items
    }

    private static func resolveColorInlays(lines: [String]) -> [EditorColorInlay] {
        var items: [EditorColorInlay] = []

        if let line = findLine(containing: "Point a{", in: lines),
           let column = findColumn(of: "Point", in: lines[line]) {
            items.append(.init(line: line, column: column, color: Int32(bitPattern: 0xFFF44336)))
        }

        if let line = findLine(containing: "Point b{", in: lines),
           let column = findColumn(of: "Point", in: lines[line]) {
            items.append(.init(line: line, column: column, color: Int32(bitPattern: 0xFF2196F3)))
        }

        return items
    }

    private static func resolvePhantomTexts(lines: [String]) -> [EditorPhantomText] {
        let phantomTargets: [(anchor: String, text: String)] = [
            ("struct Point {", " // end struct Point"),
            ("struct Rect {", " // end struct Rect"),
            ("class TextBuffer {", " // end class TextBuffer"),
        ]

        return phantomTargets.compactMap { target in
            guard let startLine = findLine(containing: target.anchor, in: lines),
                  let endLine = findBlockEnd(startingAt: startLine, in: lines) else {
                return nil
            }
            return EditorPhantomText(line: endLine, column: 2, text: target.text)
        }
    }

    private static func findLine(containing needle: String, in lines: [String]) -> Int? {
        lines.firstIndex { $0.contains(needle) }
    }

    private static func findColumn(of needle: String, in line: String) -> Int? {
        guard let range = line.range(of: needle) else { return nil }
        return line.distance(from: line.startIndex, to: range.lowerBound)
    }

    private static func findBlockEnd(startingAt startLine: Int, in lines: [String]) -> Int? {
        guard startLine >= 0 && startLine < lines.count else { return nil }

        var depth = 0
        var sawOpeningBrace = false

        for lineIndex in startLine..<lines.count {
            for char in lines[lineIndex] {
                if char == "{" {
                    depth += 1
                    sawOpeningBrace = true
                } else if char == "}" {
                    depth -= 1
                    if sawOpeningBrace && depth == 0 {
                        return lineIndex
                    }
                }
            }
        }

        return nil
    }

    private static func loadSampleTextFromAvailableBundles() -> String? {
        var seenBundlePaths = Set<String>()
        let directCandidates = [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks

        for bundle in directCandidates {
            let bundlePath = bundle.bundlePath
            guard seenBundlePaths.insert(bundlePath).inserted else { continue }
            if let url = bundle.url(forResource: "sample", withExtension: "cpp"),
               let text = try? String(contentsOf: url, encoding: .utf8) {
                return text
            }
        }

        guard let resourceURL = Bundle.main.resourceURL,
              let enumerator = FileManager.default.enumerator(
                at: resourceURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
              ) else {
            return nil
        }

        for case let url as URL in enumerator where url.pathExtension == "bundle" {
            let bundlePath = url.path
            guard seenBundlePaths.insert(bundlePath).inserted else { continue }
            guard let bundle = Bundle(url: url) else { continue }
            if let sampleURL = bundle.url(forResource: "sample", withExtension: "cpp"),
               let text = try? String(contentsOf: sampleURL, encoding: .utf8) {
                return text
            }
        }

        return nil
    }
}
