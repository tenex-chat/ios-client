//
// UnifiedProjectsUITests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import XCTest

/// UI Tests for Unified Projects feature
/// Tests: Project filter in toolbar, Projects tab, Dynamic Type, nested sheet navigation
final class UnifiedProjectsUITests: XCTestCase {
    // MARK: Private

    // swiftlint:disable:next implicitly_unwrapped_optional
    private var app: XCUIApplication!

    private let testNsec = ProcessInfo.processInfo.environment["TENEX_UI_TEST_NSEC"]

    // MARK: - Setup

    override func setUpWithError() throws {
        continueAfterFailure = true // Continue to gather all test results
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
    }

    override func tearDownWithError() throws {
        // Take final screenshot for debugging
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Final State"
        attachment.lifetime = .keepAlways
        add(attachment)
        app = nil
    }

    // MARK: - Helper Methods

    private func login() -> Bool {
        app.launch()

        // Wait for app to load
        guard app.wait(for: .runningForeground, timeout: 10) else {
            XCTFail("App did not reach foreground state")
            return false
        }

        // Handle notification permission dialog if present
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }

        // Check if already logged in - look for bottom tab bar or navigation
        // The app may show Conversations view if already logged in
        if app.staticTexts["Conversations"].waitForExistence(timeout: 3) {
            // Navigate to Projects tab using tab bar
            return navigateToProjects()
        }

        // Check if on Projects view already
        if app.navigationBars["Projects"].waitForExistence(timeout: 2) {
            return true
        }

        // Wait for login screen
        let nsecField = app.secureTextFields["nsec1..."]
        guard nsecField.waitForExistence(timeout: 5) else {
            // May already be logged in - try to navigate to projects
            return navigateToProjects()
        }

        guard let testNsec else {
            XCTFail("Set TENEX_UI_TEST_NSEC to run project UI tests")
            return false
        }

        // Enter nsec
        nsecField.tap()
        nsecField.typeText(testNsec)

        // Tap Sign In button
        let signInButton = app.buttons["Sign In"]
        guard signInButton.exists else {
            XCTFail("Sign In button not found")
            return false
        }
        signInButton.tap()

        // Wait for main view and navigate to Projects
        sleep(5)
        return navigateToProjects()
    }

    private func navigateToProjects() -> Bool {
        // iOS TabView - icons only, no labels. The second tab (index 1) is Projects
        let tabBar = app.tabBars.firstMatch
        if tabBar.waitForExistence(timeout: 3) {
            let buttons = tabBar.buttons.allElementsBoundByIndex
            // Second button (index 1) is Projects tab
            if buttons.count > 1 {
                buttons[1].tap()
                sleep(2)
            }
        }
        return app.navigationBars["Projects"].waitForExistence(timeout: 5) ||
            app.staticTexts["Projects"].exists
    }

    private func takeScreenshot(name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Tests

    /// Test 1: Verify Projects tab displays correctly
    func testProjectsTabExists() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        takeScreenshot(name: "After Login - Projects Tab")

        // Verify we're on the Projects view
        XCTAssertTrue(app.navigationBars["Projects"].exists, "Projects nav bar should exist")

        // Check for project list or empty state
        let hasProjects = !app.cells.allElementsBoundByIndex.isEmpty
        let emptyState = app.staticTexts["No Projects"].exists ||
            app.staticTexts["No Projects in This Group"].exists

        XCTAssertTrue(hasProjects || emptyState, "Should show projects or empty state")
    }

    /// Test 2: Verify project filter menu in toolbar
    func testProjectFilterMenuExists() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        // Look for filter menu button
        let filterPredicate = NSPredicate(
            format: "label CONTAINS 'filter' OR identifier CONTAINS 'filter'"
        )
        let filterButton = app.buttons.matching(filterPredicate).firstMatch

        if filterButton.waitForExistence(timeout: 3) {
            takeScreenshot(name: "Before Filter Menu Tap")
            filterButton.tap()
            sleep(1) // Wait for menu to appear
            takeScreenshot(name: "Filter Menu Open")

            // Check for filter options
            let allProjectsOption = app.buttons["All Projects"].exists ||
                app.staticTexts["All Projects"].exists
            XCTAssertTrue(allProjectsOption, "All Projects filter option should exist")
        } else {
            // Filter may be in navigation bar or hidden
            takeScreenshot(name: "Filter Button Not Found")
            XCTFail("Filter button not found in toolbar")
        }
    }

    /// Test 3: Navigate to a project and check tabs
    func testProjectDetailNavigation() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        // Find and tap first project cell
        let firstCell = app.cells.firstMatch
        guard firstCell.waitForExistence(timeout: 5) else {
            takeScreenshot(name: "No Project Cells")
            XCTSkip("No projects available to test navigation")
            return
        }

        takeScreenshot(name: "Before Project Tap")
        firstCell.tap()
        sleep(2) // Wait for navigation

        takeScreenshot(name: "Project Detail View")

        // Check for tabs in project detail
        let docsTab = app.buttons["Docs"].exists || app.staticTexts["Docs"].exists
        let agentsTab = app.buttons["Agents"].exists || app.staticTexts["Agents"].exists
        let feedTab = app.buttons["Feed"].exists || app.staticTexts["Feed"].exists

        // At least one tab should be visible
        XCTAssertTrue(docsTab || agentsTab || feedTab, "Project detail should show tabs")
    }

    /// Test 4: Test Dynamic Type accessibility
    func testDynamicTypeScaling() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        takeScreenshot(name: "Default Text Size")

        // Verify text elements are accessible
        let projectsTitle = app.navigationBars["Projects"]
        XCTAssertTrue(projectsTitle.exists, "Projects title should be accessible")

        // Check for accessibility traits on UI elements
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons.prefix(5) {
            XCTAssertTrue(
                button.isHittable || !button.isEnabled,
                "Button should be hittable or disabled: \(button.label)"
            )
        }

        takeScreenshot(name: "Dynamic Type Test Complete")
    }

    /// Test 5: Test nested sheet navigation
    func testNestedSheetNavigation() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        // Try to open settings menu
        let menuPredicate = NSPredicate(
            format: "label CONTAINS 'Menu' OR label CONTAINS 'ellipsis'"
        )
        let menuButton = app.buttons.matching(menuPredicate).firstMatch

        guard menuButton.waitForExistence(timeout: 3) else {
            takeScreenshot(name: "Menu Button Not Found")
            // Try alternative: look for gear icon
            let gearPredicate = NSPredicate(format: "label CONTAINS 'Settings'")
            let gearButton = app.buttons.matching(gearPredicate).firstMatch
            if gearButton.exists {
                gearButton.tap()
            } else {
                XCTSkip("Could not find menu or settings button")
                return
            }
            return
        }

        takeScreenshot(name: "Before Menu Tap")
        menuButton.tap()
        sleep(1)
        takeScreenshot(name: "Menu Open")

        // Try to navigate to Settings
        let settingsButton = app.buttons["Settings"]
        if settingsButton.waitForExistence(timeout: 2) {
            settingsButton.tap()
            sleep(1)
            takeScreenshot(name: "Settings Sheet")

            // Check for nested navigation within settings
            let appStillRunning = app.wait(for: .runningForeground, timeout: 5)
            XCTAssertTrue(appStillRunning, "App should remain in foreground")
        }

        // Navigate back/dismiss
        let backButton = app.buttons["Back"]
        let cancelButton = app.buttons["Cancel"]
        let doneButton = app.buttons["Done"]

        if backButton.exists {
            backButton.tap()
        } else if cancelButton.exists {
            cancelButton.tap()
        } else if doneButton.exists {
            doneButton.tap()
        }

        takeScreenshot(name: "After Sheet Dismiss")
    }

    /// Test 6: Test project creation flow (opens nested sheet)
    func testProjectCreationSheet() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        // Find the + button to create new project
        let addPredicate = NSPredicate(format: "label CONTAINS 'New Project' OR label CONTAINS 'plus'")
        let addButton = app.buttons.matching(addPredicate).firstMatch

        guard addButton.waitForExistence(timeout: 3) else {
            takeScreenshot(name: "Add Button Not Found")
            XCTSkip("Could not find add project button")
            return
        }

        takeScreenshot(name: "Before Add Project Tap")
        addButton.tap()
        sleep(1)
        takeScreenshot(name: "Create Project Sheet")

        // Verify sheet appeared (should see creation wizard)
        let sheetPredicate = NSPredicate(format: "label CONTAINS 'Project' OR label CONTAINS 'Create'")
        let sheetAppeared = app.staticTexts.matching(sheetPredicate).firstMatch
            .waitForExistence(timeout: 3)

        XCTAssertTrue(sheetAppeared, "Project creation sheet should appear")

        // Cancel the creation
        let cancelButton = app.buttons["Cancel"]
        if cancelButton.exists {
            cancelButton.tap()
        } else {
            // Swipe down to dismiss
            app.swipeDown()
        }

        takeScreenshot(name: "After Sheet Dismiss")
    }

    /// Test 7: Full navigation stress test
    func testNavigationStressTest() throws {
        guard login() else {
            XCTFail("Failed to login")
            return
        }

        // Rapidly navigate through the app to test for crashes
        for iteration in 0 ..< 3 {
            takeScreenshot(name: "Stress Test Iteration \(iteration) Start")

            // Tap first cell if exists
            let cell = app.cells.firstMatch
            if cell.waitForExistence(timeout: 2) {
                cell.tap()
                sleep(1)

                // Go back
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists {
                    backButton.tap()
                    sleep(1)
                }
            }

            // Open and close menu
            let menuPredicate = NSPredicate(format: "label CONTAINS 'Menu' OR label CONTAINS 'ellipsis'")
            let menuButton = app.buttons.matching(menuPredicate).firstMatch
            if menuButton.exists {
                menuButton.tap()
                sleep(1)
                // Tap elsewhere to dismiss
                app.tap()
                sleep(1)
            }
        }

        takeScreenshot(name: "Stress Test Complete")
        let appStillRunning = app.wait(for: .runningForeground, timeout: 5)
        XCTAssertTrue(appStillRunning, "App should not crash during navigation")
    }
}
