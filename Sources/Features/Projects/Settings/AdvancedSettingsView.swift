//
// AdvancedSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - AdvancedSettingsView

/// Advanced settings placeholder (relays, etc.)
struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            Section {
                ContentUnavailableView(
                    "Advanced Settings",
                    systemImage: "slider.horizontal.3",
                    description: Text("Relay configuration and advanced options will be available here")
                )
            }
        }
        .navigationTitle("Advanced")
    }
}
