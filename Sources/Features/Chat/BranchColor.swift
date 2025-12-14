//
// BranchColor.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

/// Utility for generating deterministic colors from branch names
enum BranchColor {
    /// Generate a deterministic color from a branch name
    /// - Parameter branchName: The branch name to generate a color for
    /// - Returns: A Color with consistent hue based on the branch name hash
    static func color(for branchName: String) -> Color {
        // djb2 hash with wrapping arithmetic to prevent overflow crashes
        var hash = 0
        for char in branchName.unicodeScalars {
            hash = hash &* 31 &+ Int(char.value)
        }

        // Convert to hue (0-360)
        let hue = abs(hash % 360)

        // Use HSL for better color consistency
        // Saturation 65% and lightness 45% for good visibility in both light/dark modes
        return Color(
            hue: Double(hue) / 360.0,
            saturation: 0.65,
            brightness: 0.45
        )
    }
}
