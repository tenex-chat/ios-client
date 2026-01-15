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

/// A small pill for displaying tags with deterministic colors based on tag name
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
            .background(tagColor.opacity(0.15))
            .foregroundStyle(tagColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    // MARK: Private

    private let tag: String

    /// Generate a consistent color from the tag text using a stable hash
    private var tagColor: Color {
        // Use a simple deterministic hash based on character values
        var hash: UInt64 = 5381
        for char in tag.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(char)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.7)
    }
}

// MARK: - ActivityIndicator

/// An indicator showing current activity
public struct ActivityIndicator: View {
    // MARK: Lifecycle

    public init(activity: String) {
        self.activity = activity
    }

    // MARK: Public

    public var body: some View {
        Text(activity)
            .font(.caption)
            .foregroundStyle(.green)
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

// MARK: - FlowLayout

/// A layout that arranges views in a flowing grid, wrapping to new lines as needed
public struct FlowLayout: Layout {
    // MARK: Lifecycle

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    // MARK: Public

    public var spacing: CGFloat = 8

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    public func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache _: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)

        for (index, placement) in result.placements.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + placement.x, y: bounds.minY + placement.y),
                proposal: ProposedViewSize(placement.size)
            )
        }
    }

    // MARK: Private

    private struct LayoutResult {
        var size: CGSize
        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)]
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity

        var placements: [(x: CGFloat, y: CGFloat, size: CGSize)] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            placements.append((x: currentX, y: currentY, size: size))

            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalWidth = max(totalWidth, currentX - spacing)
        }

        totalHeight = currentY + lineHeight

        return LayoutResult(
            size: CGSize(width: totalWidth, height: totalHeight),
            placements: placements
        )
    }
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
