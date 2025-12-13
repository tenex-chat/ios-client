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
        // Verify the app launches successfully
        // Just verify the app is running - specific UI element checks are fragile
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    // MARK: Private

    private var app: XCUIApplication?
}
