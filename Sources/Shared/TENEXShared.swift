//
//  TENEXShared.swift
//  TENEX
//

import Foundation
import SwiftUI

// MARK: - TENEXShared

/// TENEXShared module provides shared utilities and components.
///
/// This module contains:
/// - Reusable UI components
/// - Swift extensions
/// - Utility functions
/// - Design system definitions
public enum TENEXShared {
    /// Current version of the TENEXShared module
    public static let version = "0.1.0"
}

// MARK: - Design System Colors

public extension Color {
    /// Generate a deterministic HSL color from a string (e.g., project name)
    /// - Parameter string: The string to hash
    /// - Returns: A Color with hue based on the string hash
    static func deterministicColor(for string: String) -> Color {
        let hash = string.utf8.reduce(0) { ($0 &+ Int($1)) &* 31 }
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.45)
    }
}

// MARK: - Phase Colors

public enum ConversationPhase: String, CaseIterable {
    case chat
    case brainstorm
    case plan
    case execute
    case verification
    case review
    case chores
    case reflection

    // MARK: Public

    public var color: Color {
        switch self {
        case .chat:
            .blue
        case .brainstorm:
            .purple
        case .plan:
            .purple
        case .execute:
            .green
        case .verification:
            .orange
        case .review:
            .yellow
        case .chores:
            .gray
        case .reflection:
            .cyan
        }
    }
}
