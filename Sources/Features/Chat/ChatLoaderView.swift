//
// ChatLoaderView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ChatLoaderView

/// A view that fetches the thread event and then displays the ChatView.
/// Used when we only have the thread ID (e.g., from deep links or navigation state).
public struct ChatLoaderView: View {
    // MARK: Lifecycle

    public init(
        threadID: String,
        project: Project,
        currentUserPubkey: String
    ) {
        self.threadID = threadID
        self.project = project
        self.currentUserPubkey = currentUserPubkey
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                if let threadEvent {
                    ChatView(
                        threadEvent: threadEvent,
                        projectReference: project.coordinate,
                        currentUserPubkey: currentUserPubkey
                    )
                } else if isLoading {
                    ProgressView("Loading thread...")
                } else if let errorMessage {
                    errorView(message: errorMessage)
                } else {
                    // Should not happen if loading logic is correct, but fallback
                    ProgressView("Loading thread...")
                }
            } else {
                Text("NDK not available")
            }
        }
        .task {
            await loadThreadEvent()
        }
        .onChange(of: threadID) { _ in
            // Reload when thread ID changes
            Task {
                await loadThreadEvent()
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var threadEvent: NDKEvent?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let threadID: String
    private let project: Project
    private let currentUserPubkey: String

    private func loadThreadEvent() async {
        guard let ndk else { return }

        // Check if we already have the event and it matches the ID
        if threadEvent?.id == threadID {
            return
        }

        isLoading = true
        errorMessage = nil
        threadEvent = nil

        defer { isLoading = false }

        do {
            // Fetch the thread event (kind: 11) by ID
            let filter = NDKFilter(ids: [threadID], kinds: [11])
            let events = try await ndk.fetchEvents(filters: [filter])

            if let event = events.first {
                threadEvent = event
            } else {
                errorMessage = "Thread not found"
            }
        } catch {
            errorMessage = "Failed to load thread: \(error.localizedDescription)"
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await loadThreadEvent()
                }
            }
        }
        .padding()
    }
}
