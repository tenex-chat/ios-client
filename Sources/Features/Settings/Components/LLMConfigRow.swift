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
                    .fill(providerColor.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: providerIcon)
                    .foregroundStyle(providerColor)
                    .font(.system(size: 18))
            }

            // Config info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(config.name)
                        .font(.headline)

                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    }
                }

                Text("\(config.provider.displayName) • \(config.model)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSetActive()
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
    }

    // MARK: Private

    private var providerIcon: String {
        switch config.provider {
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
        switch config.provider {
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
