//
// AgentSettingsRow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - AgentSettingsRow

/// Display agent with primary badge and remove button
struct AgentSettingsRow: View {
    // MARK: Lifecycle

    init(
        agentID: String,
        isPrimary: Bool,
        onSetPrimary: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.agentID = agentID
        self.isPrimary = isPrimary
        self.onSetPrimary = onSetPrimary
        self.onRemove = onRemove
    }

    // MARK: Internal

    var body: some View {
        HStack {
            agentInfo
            Spacer()
            actionButtons
        }
    }

    // MARK: Private

    private let agentID: String
    private let isPrimary: Bool
    private let onSetPrimary: () -> Void
    private let onRemove: () -> Void

    private var agentInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Agent")
                    .font(.body)

                if isPrimary {
                    Text("PRIMARY")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue)
                        .cornerRadius(4)
                }
            }

            Text(agentID.prefix(16) + "...")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }

    private var actionButtons: some View {
        HStack {
            if !isPrimary {
                Button(action: onSetPrimary) {
                    Text("Set Primary")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.borderless)
            }

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
    }
}
