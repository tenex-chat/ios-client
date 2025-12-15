//
// ExpandedMessageSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - ExpandedMessageSheet

/// Modal sheet displaying full message content with author context
struct ExpandedMessageSheet: View {
    // MARK: Lifecycle

    init(message: Message) {
        self.message = message
    }

    // MARK: Internal

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.messageHeader

                    Divider()

                    MessageContentView(message: self.message)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        self.dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk

    private let message: Message

    private var messageHeader: some View {
        HStack(spacing: 12) {
            if let ndk {
                NDKUIProfilePicture(ndk: ndk, pubkey: self.message.pubkey, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let ndk {
                    NDKUIDisplayName(ndk: ndk, pubkey: self.message.pubkey)
                        .font(.headline)
                }
                Text(self.message.createdAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
}
