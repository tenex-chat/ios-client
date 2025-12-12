//
// NavigationRouterTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
@testable import TENEXFeatures
import Testing

@Suite("Navigation Router Tests")
struct NavigationRouterTests {
    // MARK: - Route Parsing Tests

    @Test("Parse project list route from deep link")
    func parseProjectListRoute() throws {
        let router = NavigationRouter()
        guard let url = URL(string: "tenex://projects") else {
            Issue.record("Failed to create URL")
            return
        }
        let route = try router.parse(url: url)
        #expect(route == .projectList)
    }

    @Test("Parse specific project route from deep link")
    func parseProjectRoute() throws {
        let router = NavigationRouter()
        let projectID = "test-project-123"
        guard let url = URL(string: "tenex://projects/\(projectID)") else {
            Issue.record("Failed to create URL")
            return
        }
        let route = try router.parse(url: url)

        if case let .project(id) = route {
            #expect(id == projectID)
        } else {
            Issue.record("Expected .project route")
        }
    }

    @Test("Parse thread list route from deep link")
    func parseThreadListRoute() throws {
        let router = NavigationRouter()
        let projectID = "test-project-123"
        guard let url = URL(string: "tenex://projects/\(projectID)/threads") else {
            Issue.record("Failed to create URL")
            return
        }
        let route = try router.parse(url: url)

        if case let .threadList(id) = route {
            #expect(id == projectID)
        } else {
            Issue.record("Expected .threadList route")
        }
    }

    @Test("Parse specific thread route from deep link")
    func parseThreadRoute() throws {
        let router = NavigationRouter()
        let projectID = "test-project-123"
        let threadID = "thread-456"
        guard let url = URL(string: "tenex://projects/\(projectID)/threads/\(threadID)") else {
            Issue.record("Failed to create URL")
            return
        }
        let route = try router.parse(url: url)

        if case let .thread(pid, tid) = route {
            #expect(pid == projectID)
            #expect(tid == threadID)
        } else {
            Issue.record("Expected .thread route")
        }
    }

    @Test("Throw error for invalid deep link")
    func throwErrorForInvalidDeepLink() {
        let router = NavigationRouter()
        guard let url = URL(string: "tenex://invalid") else {
            Issue.record("Failed to create URL")
            return
        }
        #expect(throws: NavigationError.self) {
            try router.parse(url: url)
        }
    }

    // MARK: - Navigation Stack Management Tests

    @Test("Initialize with empty navigation path")
    func initializeWithEmptyPath() {
        let router = NavigationRouter()
        #expect(router.path.isEmpty)
    }

    @Test("Navigate to route updates path")
    func navigateToRouteUpdatesPath() {
        let router = NavigationRouter()
        router.navigate(to: .projectList)
        #expect(router.path.count == 1)
        #expect(router.path.first == .projectList)
    }

    @Test("Navigate to multiple routes maintains stack")
    func navigateToMultipleRoutesMaintainsStack() {
        let router = NavigationRouter()
        let projectID = "project-123"

        router.navigate(to: .projectList)
        router.navigate(to: .project(id: projectID))

        #expect(router.path.count == 2)
        #expect(router.path[0] == .projectList)
        #expect(router.path[1] == .project(id: projectID))
    }

    @Test("Navigate back removes last route")
    func navigateBackRemovesLastRoute() {
        let router = NavigationRouter()

        router.navigate(to: .projectList)
        router.navigate(to: .project(id: "test"))
        #expect(router.path.count == 2)

        router.navigateBack()
        #expect(router.path.count == 1)
        #expect(router.path.first == .projectList)
    }

    @Test("Navigate back on empty path does nothing")
    func navigateBackOnEmptyPathDoesNothing() {
        let router = NavigationRouter()
        #expect(router.path.isEmpty)

        router.navigateBack()
        #expect(router.path.isEmpty)
    }

    @Test("Pop to root clears entire path")
    func popToRootClearsEntirePath() {
        let router = NavigationRouter()

        router.navigate(to: .projectList)
        router.navigate(to: .project(id: "test"))
        router.navigate(to: .threadList(projectID: "test"))
        #expect(router.path.count == 3)

        router.popToRoot()
        #expect(router.path.isEmpty)
    }

    // MARK: - State Restoration Tests

    @Test("Encode navigation state")
    func encodeNavigationState() throws {
        let router = NavigationRouter()
        router.navigate(to: .projectList)
        router.navigate(to: .project(id: "project-123"))

        let data = try router.encodeState()
        #expect(!data.isEmpty)
    }

    @Test("Decode navigation state restores path")
    func decodeNavigationStateRestoresPath() throws {
        let router = NavigationRouter()
        router.navigate(to: .projectList)
        router.navigate(to: .project(id: "project-123"))

        let data = try router.encodeState()

        let newRouter = NavigationRouter()
        try newRouter.restoreState(from: data)

        #expect(newRouter.path.count == 2)
        #expect(newRouter.path[0] == .projectList)
        #expect(newRouter.path[1] == .project(id: "project-123"))
    }

    @Test("Decode empty data leaves path empty")
    func decodeEmptyDataLeavesPathEmpty() throws {
        let router = NavigationRouter()
        let emptyData = try JSONEncoder().encode([AppRoute]())

        try router.restoreState(from: emptyData)
        #expect(router.path.isEmpty)
    }

    @Test("Decode invalid data throws error")
    func decodeInvalidDataThrowsError() {
        let router = NavigationRouter()
        let invalidData = Data([0xFF, 0xFF, 0xFF])

        #expect(throws: Error.self) {
            try router.restoreState(from: invalidData)
        }
    }

    // MARK: - Deep Link Handling Tests

    @Test("Handle deep link navigates to correct route")
    func handleDeepLinkNavigatesToCorrectRoute() throws {
        let router = NavigationRouter()
        guard let url = URL(string: "tenex://projects/project-123") else {
            Issue.record("Failed to create URL")
            return
        }

        try router.handleDeepLink(url)

        #expect(router.path.count == 1)
        #expect(router.path[0] == .project(id: "project-123"))
    }

    @Test("Handle deep link clears existing path")
    func handleDeepLinkClearsExistingPath() throws {
        let router = NavigationRouter()
        router.navigate(to: .projectList)
        router.navigate(to: .project(id: "old-project"))

        guard let url = URL(string: "tenex://projects/new-project") else {
            Issue.record("Failed to create URL")
            return
        }
        try router.handleDeepLink(url)

        #expect(router.path.count == 1)
        #expect(router.path[0] == .project(id: "new-project"))
    }
}
