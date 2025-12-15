//
// BranchColor.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXShared

/// Utility for generating deterministic colors from branch names
enum BranchColor {
    /// Generate a deterministic color from a branch name
    /// Uses the same algorithm as the Svelte reference implementation
    /// - Parameter branchName: The branch name to generate a color for
    /// - Returns: A Color with consistent hue based on the branch name hash
    static func color(for branchName: String) -> Color {
        Color.deterministicColor(for: branchName)
    }
}
