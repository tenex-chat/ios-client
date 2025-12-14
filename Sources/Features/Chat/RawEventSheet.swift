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
            contentView
                .navigationTitle("Raw Event")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { toolbarContent }
        }
    }

    private var contentView: some View {
        ScrollView {
            if let rawEventJSON {
                Text(rawEventJSON)
                    .font(.system(size: 12, design: .monospaced))
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
                isPresented = false
            }
        }
        if rawEventJSON != nil {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }

    private func copyToClipboard() {
        #if os(iOS)
            UIPasteboard.general.string = rawEventJSON
        #else
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(rawEventJSON ?? "", forType: .string)
        #endif
    }
}
