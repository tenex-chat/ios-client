//
// ConversationSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

struct ConversationSettingsView: View {
    @Binding var settings: ConversationSettings

    var body: some View {
        Form {
            Section(header: Text("Conversation Display")) {
                Toggle("Show reasoning blocks", isOn: self.$settings.showReasoning)
                Toggle("Show tool calls", isOn: self.$settings.showToolCalls)
            }
        }
        .navigationTitle("Conversation Settings")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
