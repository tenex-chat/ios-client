//
//  TENEXUITests.swift
//  TENEX
//

import XCTest

final class TENEXUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testAppLaunches() throws {
        // Verify the app launches and shows the main UI
        XCTAssertTrue(app.staticTexts["TENEX"].exists)
    }
}
