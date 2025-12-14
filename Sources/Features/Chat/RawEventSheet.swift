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
        // swiftlint:disable:next closure_body_length
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
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            isPresented = false
                        }
                    }
                    if rawEventJSON != nil {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                #if os(macOS)
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(rawEventJSON ?? "", forType: .string)
                                #else
                                    UIPasteboard.general.string = rawEventJSON
                                #endif
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
        }
    }
}
