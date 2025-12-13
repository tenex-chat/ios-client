//
// AppRoute.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation

// MARK: - AppRoute

/// Defines all possible navigation destinations in the app
public enum AppRoute: Hashable, Codable {
    case projectList
    case project(id: String)
    case threadList(projectID: String)
    case thread(projectID: String, threadID: String)
    case settings
}

// MARK: - NavigationError

/// Errors that can occur during navigation
public enum NavigationError: Error, Equatable {
    case invalidURL
    case invalidScheme
    case invalidPath
    case missingPathComponent
}
