//
// RawEventSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - RawEventSheet

/// Sheet for displaying raw event JSON
public struct RawEventSheet: View {
    let rawEventJSON: String?
    @Binding var isPresented: Bool

    public var body: some View {
        NavigationView {
            self.contentView
                .navigationTitle("Raw Event")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { self.toolbarContent }
        }
    }

    private var contentView: some View {
        ScrollView {
            if let rawEventJSON {
                Text(rawEventJSON)
                    .font(.caption.monospaced())
                    .padding()
                    .textSelection(.enabled)
            } else {
                Text("No raw event data available")
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                self.isPresented = false
            }
        }
        if self.rawEventJSON != nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    self.copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func copyToClipboard() {
        #if os(iOS)
            UIPasteboard.general.string = self.rawEventJSON
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(self.rawEventJSON ?? "", forType: .string)
        #endif
    }
}
