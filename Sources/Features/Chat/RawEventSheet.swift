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
            .navigationTitle("Raw Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        isPresented = false
                    }
                }
                if rawEventJSON != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            UIPasteboard.general.string = rawEventJSON
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                }
            }
        }
    }
}
