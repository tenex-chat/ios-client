//
// FormattingUtilities.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI

/// Namespace for formatting utilities
public enum FormattingUtilities {
    // MARK: - Date Formatting

    /// Format a date as a timestamp (HH:mm:ss.SSS)
    public static func timestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    /// Format a date with short date and medium time
    public static func shortDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    /// Format a date as relative time (e.g., "2h ago")
    public static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Format a date as relative time with appropriate granularity
    /// - Returns "just now" for messages less than 60 seconds old
    /// - Returns time in minutes/hours/days for older messages
    /// This prevents constant UI updates while still showing relative time
    public static func relativeDiscrete(_ date: Date) -> String {
        let secondsAgo = Date().timeIntervalSince(date)

        if secondsAgo < 60 {
            return "just now"
        } else if secondsAgo < 3600 {
            let minutes = Int(secondsAgo / 60)
            return "\(minutes)m ago"
        } else if secondsAgo < 86_400 {
            let hours = Int(secondsAgo / 3600)
            return "\(hours)h ago"
        } else if secondsAgo < 604_800 {
            let days = Int(secondsAgo / 86_400)
            return "\(days)d ago"
        } else if secondsAgo < 2_592_000 {
            let weeks = Int(secondsAgo / 604_800)
            return "\(weeks)w ago"
        } else if secondsAgo < 31_536_000 {
            let months = Int(secondsAgo / 2_592_000)
            return "\(months)mo ago"
        } else {
            let years = Int(secondsAgo / 31_536_000)
            return "\(years)y ago"
        }
    }

    // MARK: - Byte Formatting

    /// Format bytes as human-readable string
    public static func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Duration Formatting

    /// Format duration in seconds to human-readable string
    public static func formatDuration(_ seconds: Double) -> String {
        if seconds < 0.001 {
            return String(format: "%.0fμs", seconds * 1_000_000)
        } else if seconds < 1 {
            return String(format: "%.0fms", seconds * 1000)
        } else if seconds < 60 {
            return String(format: "%.1fs", seconds)
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }

    // MARK: - Percentage Formatting

    /// Format percentage with one decimal place
    public static func formatPercentage(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    // MARK: - Number Formatting

    /// Format large numbers with K/M/B suffixes
    public static func formatCount(_ count: Int) -> String {
        if count >= 1_000_000_000 {
            String(format: "%.1fB", Double(count) / 1_000_000_000)
        } else if count >= 1_000_000 {
            String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1000 {
            String(format: "%.1fK", Double(count) / 1000)
        } else {
            "\(count)"
        }
    }
}
