//
// LLMConfigRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - LLMConfigRow

/// Row view for displaying an LLM configuration
struct LLMConfigRow: View {
    // MARK: Internal

    let config: LLMConfig
    let isActive: Bool
    let onSetActive: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Provider icon with color
            ZStack {
                Circle()
                    .fill(self.providerColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: self.providerIcon)
                    .foregroundStyle(self.providerColor)
                    .font(.title3)
            }

            // Config info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(self.config.name)
                        .font(.headline)

                    if self.isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text("\(self.config.provider.displayName) • \(self.config.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            self.onSetActive()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                self.onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                self.onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: Private

    private var providerIcon: String {
        switch self.config.provider {
        case .openai:
            "brain"
        case .anthropic:
            "sparkles"
        case .google:
            "magnifyingglass"
        case .openrouter:
            "arrow.triangle.branch"
        case .ollama:
            "server.rack"
        case .appleIntelligence:
            "apple.logo"
        }
    }

    private var providerColor: Color {
        switch self.config.provider {
        case .openai:
            .green
        case .anthropic:
            .orange
        case .google:
            .blue
        case .openrouter:
            .purple
        case .ollama:
            .gray
        case .appleIntelligence:
            .pink
        }
    }
}
