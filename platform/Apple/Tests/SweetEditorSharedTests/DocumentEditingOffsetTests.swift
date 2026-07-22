import XCTest
@testable import SweetEditorShared

final class DocumentEditingOffsetTests: XCTestCase {
    func testEditingOffsetsLogicalizeMixedLineEndings() {
        let document = Document(text: "a\r\nbb\rc\n")

        XCTAssertEqual(document.editingUTF16Length, 7)
        XCTAssertEqual(document.editingLocation(forUTF16Offset: 0).line, 0)
        XCTAssertEqual(document.editingLocation(forUTF16Offset: 2).line, 1)
        XCTAssertEqual(document.editingLocation(forUTF16Offset: 5).line, 2)
        XCTAssertEqual(document.editingUTF16Offset(line: 2, column: 1), 6)
    }
}
