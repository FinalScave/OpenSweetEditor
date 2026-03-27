import XCTest
@testable import SweetEditoriOS
@testable import SweetEditorCoreInternal
#if os(iOS)
import UIKit
#endif

final class SweetEditoriOSTests: XCTestCase {
    func testModuleCompiles() {
        XCTAssertTrue(true)
    }

    func testIOSScrollbarPolicyProvidesTransientDefaults() {
        let policy = IOSScrollbarPolicy()

        XCTAssertEqual(policy.defaultThickness, 8.0, accuracy: 0.001)
        XCTAssertEqual(policy.defaultMinThumb, 48.0, accuracy: 0.001)
        XCTAssertEqual(policy.defaultThumbHitPadding, 16.0, accuracy: 0.001)
    }

    #if os(iOS)
    func testIOSViewExposesCentralizedEditorSettings() {
        let view = SweetEditorViewiOS(frame: .zero)

        XCTAssertNotNil(view.settings)
    }

    func testIOSSettingsDefaultsFollowMacOSParityContract() {
        let view = SweetEditorViewiOS(frame: .zero)
        let settings = view.settings

        XCTAssertEqual(settings.editorTextSize, 14.0, accuracy: 0.001)
        XCTAssertEqual(settings.scale, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.foldArrowMode, .always)
        XCTAssertEqual(settings.wrapMode, .none)
        XCTAssertEqual(settings.lineSpacingAdd, 0.0, accuracy: 0.001)
        XCTAssertEqual(settings.lineSpacingMult, 1.0, accuracy: 0.001)
        XCTAssertEqual(settings.contentStartPadding, 0.0, accuracy: 0.001)
        XCTAssertTrue(settings.showSplitLine)
        XCTAssertEqual(settings.currentLineRenderMode, .background)
        XCTAssertEqual(settings.autoIndentMode, .keepIndent)
        XCTAssertFalse(settings.readOnly)
        XCTAssertEqual(settings.maxGutterIcons, 0)
    }

    func testIOSSettingsCanMutateEditorConfiguration() {
        let view = SweetEditorViewiOS(frame: .zero)
        let settings = view.settings

        settings.setScale(1.2)
        settings.setFoldArrowMode(.hidden)
        settings.setWrapMode(.wordBreak)
        settings.setLineSpacing(add: 1.5, mult: 1.3)
        settings.setContentStartPadding(10)
        settings.setShowSplitLine(false)
        settings.setCurrentLineRenderMode(.border)
        settings.setAutoIndentMode(.none)
        settings.setReadOnly(true)
        settings.setMaxGutterIcons(2)

        XCTAssertEqual(settings.scale, 1.2, accuracy: 0.001)
        XCTAssertEqual(settings.foldArrowMode, .hidden)
        XCTAssertEqual(settings.wrapMode, .wordBreak)
        XCTAssertEqual(settings.lineSpacingAdd, 1.5, accuracy: 0.001)
        XCTAssertEqual(settings.lineSpacingMult, 1.3, accuracy: 0.001)
        XCTAssertEqual(settings.contentStartPadding, 10, accuracy: 0.001)
        XCTAssertFalse(settings.showSplitLine)
        XCTAssertEqual(settings.currentLineRenderMode, .border)
        XCTAssertEqual(settings.autoIndentMode, .none)
        XCTAssertTrue(settings.readOnly)
        XCTAssertEqual(settings.maxGutterIcons, 2)
    }

    func testIOSDrawStrategyKeepsTopOriginCoordinatesAndOnlyFlipsText() {
        XCTAssertFalse(IOSEditorView.usesFullContextFlipForRendering)
        XCTAssertEqual(
            IOSEditorView.textMatrixForTopOriginDrawing,
            CGAffineTransform(scaleX: 1.0, y: -1.0)
        )
    }
    #endif
}
