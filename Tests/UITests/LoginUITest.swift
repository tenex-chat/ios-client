//
// LoginUITest.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import XCTest

final class LoginUITest: XCTestCase {
    // MARK: Private

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!
    private let testNsec = ProcessInfo.processInfo.environment["TENEX_UI_TEST_NSEC"]

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Tests

    func testLoginWithNsec() throws {
        let testNsec = try XCTUnwrap(testNsec, "Set TENEX_UI_TEST_NSEC to run login UI tests")

        app.launch()

        // Wait for app to load
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        // Handle notification permission dialog if present
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }

        // Wait for login screen
        let nsecField = app.secureTextFields["nsec1..."]
        XCTAssertTrue(nsecField.waitForExistence(timeout: 5), "nsec field should exist")

        // Enter nsec
        nsecField.tap()
        nsecField.typeText(testNsec)

        // Tap Sign In button
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.exists, "Sign In button should exist")
        signInButton.tap()

        // Wait for login to complete - should see main view
        // Give it some time to connect to relay and load projects
        sleep(10)
    }
}
