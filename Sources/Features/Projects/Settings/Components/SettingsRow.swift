//
// SettingsRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - SettingsRow

/// Reusable row component for settings navigation
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            // Icon with colored background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(self.color.gradient)
                    .frame(width: 32, height: 32)

                Image(systemName: self.icon)
                    .foregroundStyle(.white)
                    .font(.callout.weight(.semibold))
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(self.title)
                    .font(.body)

                Text(self.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}
