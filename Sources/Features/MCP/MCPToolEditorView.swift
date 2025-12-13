//
// MCPToolEditorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

public struct MCPToolEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var command = ""
    @State private var parametersJson = "{}"

    @State private var isPublishing = false
    @State private var error: String?

    public let ndk: NDK

    public init(ndk: NDK) {
        self.ndk = ndk
    }

    public var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                TextField("Command", text: $command)
            }

            Section(header: Text("Description")) {
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section(header: Text("Parameters (JSON)")) {
                TextEditor(text: $parametersJson)
                    .font(.monospaced(.body)())
                    .frame(minHeight: 100)
            }
        }
        .navigationTitle("New MCP Tool")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Create") {
                    Task {
                        await createTool()
                    }
                }
                .disabled(name.isEmpty || command.isEmpty || isPublishing)
            }
        }
    }

    private func createTool() async {
        isPublishing = true
        defer { isPublishing = false }

        // Tags
        var tags: [[String]] = [
            ["name", name],
            ["command", command],
        ]

        if let data = parametersJson.data(using: .utf8),
           let _ = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
             // Valid JSON, add tag
             tags.append(["params", parametersJson])
        }

        let content = description

        let event = NDKEvent(kind: 4200, tags: tags, content: content, ndk: ndk)

        do {
            try await event.publish()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
