import XCTest
import AppKit
@testable import SweetEditorMacOS
@testable import SweetEditorCoreInternal

final class SweetEditorMacOSCompositionTests: XCTestCase {
    func testViewEnablesComposition() {
        let view = SweetEditorViewMacOS(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        let mirror = Mirror(reflecting: view)
        let editorCoreAny = mirror.children.first(where: { $0.label == "editorCore" })?.value
        let editorCore = unwrapOptional(editorCoreAny) as? SweetEditorCore

        XCTAssertNotNil(editorCore)
        XCTAssertEqual(editorCore?.isCompositionEnabled(), true)
    }

    private func unwrapOptional(_ value: Any?) -> Any? {
        guard let value else { return nil }
        let mirror = Mirror(reflecting: value)
        guard mirror.displayStyle == .optional else { return value }
        return mirror.children.first?.value
    }
}
