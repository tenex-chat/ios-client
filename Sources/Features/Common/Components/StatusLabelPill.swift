//
// StatusLabelPill.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

/// A pill-shaped label for displaying status text with dynamic coloring
/// The color is automatically generated based on the label text for consistency
public struct StatusLabelPill: View {
    // MARK: Lifecycle

    public init(label: String) {
        self.label = label
    }

    // MARK: Public

    public var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.2))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: Private

    private let label: String

    /// Generate a consistent color from the label text
    private var statusColor: Color {
        let hash = abs(label.hashValue)
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
}

// MARK: - TagPill

/// A small pill for displaying tags
public struct TagPill: View {
    // MARK: Lifecycle

    public init(tag: String) {
        self.tag = tag
    }

    // MARK: Public

    public var body: some View {
        Text(tag)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.green.opacity(0.15))
            .foregroundStyle(.green)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Private

    private let tag: String
}

// MARK: - ActivityIndicator

/// An animated indicator showing current activity
public struct ActivityIndicator: View {
    // MARK: Lifecycle

    public init(activity: String) {
        self.activity = activity
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "waveform")
                .foregroundStyle(.green)
                .symbolEffect(.variableColor.iterative)
                .font(.caption)

            Text(activity)
                .font(.caption)
                .foregroundStyle(.green)
        }
    }

    // MARK: Private

    private let activity: String
}

// MARK: - ProjectIndicator

/// A colored dot with project name
public struct ProjectIndicator: View {
    // MARK: Lifecycle

    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    // MARK: Private

    private let title: String
    private let color: Color
}

// MARK: - Previews

#if DEBUG
    #Preview("StatusLabelPill") {
        VStack(spacing: 8) {
            StatusLabelPill(label: "In Progress")
            StatusLabelPill(label: "Completed")
            StatusLabelPill(label: "Pending Review")
            StatusLabelPill(label: "Blocked")
        }
        .padding()
    }

    #Preview("TagPill") {
        HStack(spacing: 4) {
            TagPill(tag: "feature")
            TagPill(tag: "ui")
            TagPill(tag: "bug-fix")
        }
        .padding()
    }

    #Preview("ActivityIndicator") {
        ActivityIndicator(activity: "Writing integration tests...")
            .padding()
    }

    #Preview("ProjectIndicator") {
        ProjectIndicator(title: "TENEX iOS", color: .blue)
            .padding()
    }
#endif
