//
// TENEXUITests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import XCTest

final class TENEXUITests: XCTestCase {
    // MARK: Internal

    override func setUpWithError() throws {
        continueAfterFailure = false
        let application = XCUIApplication()
        application.launch()
        app = application
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunches() throws {
        guard let app else {
            return
        }
        // Verify the app launches and shows the main UI
        XCTAssertTrue(app.staticTexts["TENEX"].exists)
    }

    // MARK: Private

    private var app: XCUIApplication?
}
