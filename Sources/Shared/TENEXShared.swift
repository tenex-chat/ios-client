//
// TENEXShared.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
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
    /// Uses the same algorithm as the Svelte reference implementation
    /// - Parameter string: The string to hash
    /// - Parameter saturation: HSL saturation (0-100), default 65
    /// - Parameter lightness: HSL lightness (0-100), default 55
    /// - Returns: A Color with hue based on the string hash
    static func deterministicColor(
        for string: String,
        saturation: Double = 65,
        lightness: Double = 55
    ) -> Color {
        guard !string.isEmpty else {
            return self.fromHSL(hue: 220, saturation: saturation, lightness: lightness)
        }

        // djb2 hash - matches Svelte implementation exactly
        var hash = 0
        for char in string.unicodeScalars {
            // (hash << 5) - hash + char === hash * 31 + char
            hash = (hash << 5) &- hash &+ Int(char.value)
            hash = hash & hash // Convert to 32-bit int
        }

        let hue = abs(hash) % 360
        return Self.fromHSL(hue: Double(hue), saturation: saturation, lightness: lightness)
    }

    /// Convert HSL to RGB color
    /// - Parameters:
    ///   - hue: Hue in degrees (0-360)
    ///   - saturation: Saturation percentage (0-100)
    ///   - lightness: Lightness percentage (0-100)
    /// - Returns: A Color in RGB space
    static func fromHSL(hue: Double, saturation: Double, lightness: Double) -> Color {
        let hueNormalized = hue / 360.0
        let saturationNormalized = saturation / 100.0
        let lightnessNormalized = lightness / 100.0

        let chroma = (1 - abs(2 * lightnessNormalized - 1)) * saturationNormalized
        let intermediate = chroma * (1 - abs(fmod(hueNormalized * 6, 2) - 1))
        let matchValue = lightnessNormalized - chroma / 2

        var red: Double = 0, green: Double = 0, blue: Double = 0

        switch hueNormalized * 6 {
        case 0 ..< 1:
            (red, green, blue) = (chroma, intermediate, 0)
        case 1 ..< 2:
            (red, green, blue) = (intermediate, chroma, 0)
        case 2 ..< 3:
            (red, green, blue) = (0, chroma, intermediate)
        case 3 ..< 4:
            (red, green, blue) = (0, intermediate, chroma)
        case 4 ..< 5:
            (red, green, blue) = (intermediate, 0, chroma)
        default:
            (red, green, blue) = (chroma, 0, intermediate)
        }

        return Color(red: red + matchValue, green: green + matchValue, blue: blue + matchValue)
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
