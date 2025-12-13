//
// NavigationShell.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - NavigationShell

/// Main navigation container for the app
/// Wraps AdaptiveNavigationShell to handle different device sizes
public struct NavigationShell: View {
    public init() {}

    public var body: some View {
        AdaptiveNavigationShell()
    }
}
