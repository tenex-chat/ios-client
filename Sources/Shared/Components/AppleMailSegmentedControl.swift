//
// AppleMailSegmentedControl.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AppleMailSegmentedControl

/// A segmented control styled like Apple Mail's segment picker
/// Features rounded capsule buttons with smooth selection animations
public struct AppleMailSegmentedControl<SelectionValue: Hashable>: View {
    // MARK: Lifecycle

    public init(
        selection: Binding<SelectionValue>,
        content: () -> SegmentedControlContent<SelectionValue>
    ) {
        _selection = selection
        self.segments = content().segments
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(segments, id: \.value) { segment in
                SegmentButton(
                    title: segment.title,
                    icon: segment.icon,
                    badge: segment.badge,
                    isSelected: selection == segment.value
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = segment.value
                    }
                }
            }
        }
        .padding(4)
        .background {
            #if os(macOS)
            Color(nsColor: .controlBackgroundColor)
                .opacity(0.5)
            #else
            Color(uiColor: .secondarySystemBackground)
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: Private

    @Binding private var selection: SelectionValue
    private let segments: [Segment<SelectionValue>]
}

// MARK: - Segment

/// Represents a single segment in the control
public struct Segment<Value: Hashable> {
    let title: String
    let icon: String?
    let badge: Int?
    let value: Value

    /// Creates a segment
    /// - Parameters:
    ///   - title: The segment title
    ///   - value: The segment value
    ///   - icon: Optional SF Symbol icon name
    ///   - badge: Optional badge count
    public init(title: String, value: Value, icon: String? = nil, badge: Int? = nil) {
        self.title = title
        self.icon = icon
        self.badge = badge
        self.value = value
    }
}

// MARK: - SegmentedControlContent

/// Builder for segments
public struct SegmentedControlContent<SelectionValue: Hashable> {
    var segments: [Segment<SelectionValue>] = []

    /// Creates an empty content builder
    public init() {}

    /// Adds a segment to the control
    /// - Parameters:
    ///   - title: The segment title
    ///   - value: The segment value
    ///   - icon: Optional SF Symbol icon name
    ///   - badge: Optional badge count
    public mutating func segment(
        _ title: String,
        value: SelectionValue,
        icon: String? = nil,
        badge: Int? = nil
    ) {
        segments.append(Segment(title: title, value: value, icon: icon, badge: badge))
    }
}

// MARK: - SegmentButton

/// A single button in the segmented control
private struct SegmentButton: View {
    let title: String
    let icon: String?
    let badge: Int?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            buttonContent
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering && !isSelected
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
            }

            Text(title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .medium))

            if let badge, badge > 0 {
                badgeView(count: badge)
            }
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            buttonBackground
        }
    }

    @ViewBuilder
    private var buttonBackground: some View {
        if isSelected {
            selectedBackground
        } else if isHovered {
            hoveredBackground
        }
    }

    private var selectedBackground: some View {
        #if os(macOS)
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(nsColor: .controlBackgroundColor))
            .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
        #else
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color(uiColor: .systemBackground))
            .shadow(color: .black.opacity(0.1), radius: 1, y: 0.5)
        #endif
    }

    private var hoveredBackground: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(.primary.opacity(0.05))
    }

    private func badgeView(count: Int) -> some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule()
                    .fill(Color.accentColor)
            }
    }
}

// MARK: - Convenience Initializer

public extension AppleMailSegmentedControl {
    /// Convenience initializer for simple text-only segments
    init(
        selection: Binding<SelectionValue>,
        segments: [(title: String, value: SelectionValue)]
    ) where SelectionValue: Hashable {
        _selection = selection
        self.segments = segments.map { Segment(title: $0.title, value: $0.value) }
    }
}
