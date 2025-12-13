//
// AgentEditorView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

public struct AgentEditorView: View {
    // MARK: Lifecycle

    public init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: Public

    public let ndk: NDK

    public var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Role", text: $role)
                TextField("Model", text: $model)
                TextField("Picture URL", text: $picture)
            }

            Section(header: Text("Instructions")) {
                TextField("Instructions", text: $instructions, axis: .vertical)
                    .lineLimit(5 ... 10)
            }
        }
        .navigationTitle("New Agent")
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
                        await createAgent()
                    }
                }
                .disabled(name.isEmpty || isPublishing)
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var role = "assistant"
    @State private var instructions = ""
    @State private var model = ""
    @State private var picture = ""

    @State private var isPublishing = false
    @State private var error: String?

    private func createAgent() async {
        isPublishing = true
        defer { isPublishing = false }

        // Tags
        var tags: [[String]] = [
            ["d", name.lowercased().replacingOccurrences(of: " ", with: "-")],
            ["title", name],
            ["role", role],
        ]

        if !description.isEmpty {
            tags.append(["description", description])
        }

        if !model.isEmpty {
            tags.append(["model", model])
        }

        if !picture.isEmpty {
            tags.append(["picture", picture])
        }

        let content = instructions

        do {
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(4199)
                .setTags(tags)
                .content(content)
                .build()

            try await ndk.publish(event)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
