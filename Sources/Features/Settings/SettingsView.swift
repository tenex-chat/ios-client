//
// SettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwift
import SwiftUI

// MARK: - SettingsView

/// Main settings screen
public struct SettingsView: View {
    // MARK: Lifecycle

    public init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: Public

    public var body: some View {
        List {
            Section("Developer") {
                NavigationLink(destination: DeveloperToolsView(ndk: ndk)) {
                    SettingsRow(
                        icon: "wrench.and.screwdriver",
                        title: "Developer Tools",
                        subtitle: "Debugging and diagnostics",
                        color: .gray
                    )
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    // MARK: Private

    private let ndk: NDK
}

// MARK: - SettingsRow

struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(color)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
