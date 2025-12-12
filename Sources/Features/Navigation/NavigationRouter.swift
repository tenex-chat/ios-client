//
// NavigationRouter.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI

// MARK: - NavigationRouter

/// Manages app navigation state and handles deep linking
@Observable
public final class NavigationRouter {
    // MARK: Lifecycle

    /// Initialize the navigation router with an empty navigation stack
    public init() {
        path = []
    }

    // MARK: Public

    /// The current navigation path
    public var path: [AppRoute]

    // MARK: - Navigation Methods

    /// Navigate to a specific route by pushing it onto the stack
    public func navigate(to route: AppRoute) {
        path.append(route)
    }

    /// Navigate back by removing the last route from the stack
    public func navigateBack() {
        guard !path.isEmpty else {
            return
        }
        path.removeLast()
    }

    /// Pop to root by clearing the entire navigation stack
    public func popToRoot() {
        path.removeAll()
    }

    // MARK: - Deep Link Handling

    /// Parse a URL into an AppRoute
    public func parse(url: URL) throws -> AppRoute {
        guard url.scheme == "tenex" else {
            throw NavigationError.invalidScheme
        }

        guard let host = url.host() else {
            throw NavigationError.invalidURL
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch (host, pathComponents.count) {
        case ("projects", 0):
            return .projectList

        case ("projects", 1):
            return .project(id: pathComponents[0])

        case ("projects", 2) where pathComponents[1] == "threads":
            return .threadList(projectID: pathComponents[0])

        case ("projects", 3) where pathComponents[1] == "threads":
            return .thread(projectID: pathComponents[0], threadID: pathComponents[2])

        default:
            throw NavigationError.invalidPath
        }
    }

    /// Handle a deep link by parsing it and navigating to the resulting route
    public func handleDeepLink(_ url: URL) throws {
        let route = try parse(url: url)
        path = [route]
    }

    // MARK: - State Restoration

    /// Encode the current navigation state to Data
    public func encodeState() throws -> Data {
        try JSONEncoder().encode(path)
    }

    /// Restore navigation state from encoded Data
    public func restoreState(from data: Data) throws {
        path = try JSONDecoder().decode([AppRoute].self, from: data)
    }
}
