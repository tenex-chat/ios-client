//
// SettingsRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - SettingsRow

/// Reusable row component for settings list
struct SettingsRow: View {
    // MARK: Lifecycle

    init(icon: String, title: String, subtitle: String, color: Color? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.color = color
    }

    // MARK: Internal

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color ?? .blue)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: Private

    private let icon: String
    private let title: String
    private let subtitle: String
    private let color: Color?
}
