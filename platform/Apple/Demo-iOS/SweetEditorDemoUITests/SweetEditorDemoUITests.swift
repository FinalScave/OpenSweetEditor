//
//  SweetEditorDemoUITests.swift
//  SweetEditorDemoUITests
//
//  Created by xiue233 on 2026/3/27.
//

import XCTest

final class SweetEditorDemoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Loaded example.java"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testEditorFocusesOnlyAfterTextInteraction() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Loaded example.java"].waitForExistence(timeout: 10))

        let dragStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let dragEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        dragStart.press(forDuration: 0.05, thenDragTo: dragEnd)

        XCTAssertFalse(app.keyboards.firstMatch.waitForExistence(timeout: 1))

        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
