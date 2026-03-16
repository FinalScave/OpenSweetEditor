import XCTest
import AppKit
@testable import SweetEditorMacDemo

final class SweetEditorMacDemoThemeTests: XCTestCase {
    func testWindowAppearanceUsesDarkAquaInDarkTheme() {
        let appearance = demoWindowAppearance(isDark: true)
        XCTAssertEqual(appearance?.name, .darkAqua)
    }

    func testWindowAppearanceUsesAquaInLightTheme() {
        let appearance = demoWindowAppearance(isDark: false)
        XCTAssertEqual(appearance?.name, .aqua)
    }

    func testChromeBackgroundColorUsesDarkEditorToneInDarkTheme() {
        let color = demoChromeBackgroundColor(isDark: true)
        let components = sRGBComponents(of: color)

        XCTAssertEqual(components.red, 0x1E / 255.0, accuracy: 0.001)
        XCTAssertEqual(components.green, 0x1E / 255.0, accuracy: 0.001)
        XCTAssertEqual(components.blue, 0x1E / 255.0, accuracy: 0.001)
    }

    func testChromeBackgroundColorUsesWindowBackgroundInLightTheme() {
        let lightAppearance = NSAppearance(named: .aqua)
        let actual = resolvedColor(demoChromeBackgroundColor(isDark: false), appearance: lightAppearance)
        let expected = resolvedColor(.windowBackgroundColor, appearance: lightAppearance)

        let actualComponents = sRGBComponents(of: actual)
        let expectedComponents = sRGBComponents(of: expected)

        XCTAssertEqual(actualComponents.red, expectedComponents.red, accuracy: 0.001)
        XCTAssertEqual(actualComponents.green, expectedComponents.green, accuracy: 0.001)
        XCTAssertEqual(actualComponents.blue, expectedComponents.blue, accuracy: 0.001)
    }

    private func resolvedColor(_ color: NSColor, appearance: NSAppearance?) -> NSColor {
        var resolved = color
        appearance?.performAsCurrentDrawingAppearance {
            resolved = color.usingColorSpace(.sRGB) ?? color
        }
        return resolved
    }

    private func sRGBComponents(of color: NSColor) -> (red: CGFloat, green: CGFloat, blue: CGFloat) {
        let resolved = color.usingColorSpace(.sRGB) ?? color
        return (resolved.redComponent, resolved.greenComponent, resolved.blueComponent)
    }
}
