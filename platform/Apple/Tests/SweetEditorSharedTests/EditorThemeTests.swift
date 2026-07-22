import CoreGraphics
import XCTest
@testable import SweetEditorShared

final class EditorThemeTests: XCTestCase {
    func testXcodeDarkUsesDefaultSourcePalette() {
        let theme = EditorTheme.xcodeDark()

        XCTAssertColor(theme.backgroundColor, red: 0x1F, green: 0x1F, blue: 0x24, alpha: 0xFF)
        XCTAssertEqual(
            theme.textStyles[EditorTheme.styleKeyword]?.color,
            Int32(bitPattern: 0xFFFC5FA3)
        )
        XCTAssertEqual(
            theme.textStyles[EditorTheme.styleString]?.color,
            Int32(bitPattern: 0xFFFC6A5D)
        )
    }

    func testXcodeLightUsesDefaultSourcePalette() {
        let theme = EditorTheme.xcodeLight()

        XCTAssertColor(theme.backgroundColor, red: 0xFF, green: 0xFF, blue: 0xFF, alpha: 0xFF)
        XCTAssertEqual(
            theme.textStyles[EditorTheme.styleKeyword]?.color,
            Int32(bitPattern: 0xFF9B2393)
        )
        XCTAssertEqual(
            theme.textStyles[EditorTheme.styleString]?.color,
            Int32(bitPattern: 0xFFC41A16)
        )
    }

    private func XCTAssertColor(
        _ color: CGColor,
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let components = color.components, components.count == 4 else {
            XCTFail("Expected an RGBA color", file: file, line: line)
            return
        }
        XCTAssertEqual(components[0], CGFloat(red) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components[1], CGFloat(green) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components[2], CGFloat(blue) / 255, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(components[3], CGFloat(alpha) / 255, accuracy: 0.0001, file: file, line: line)
    }
}
