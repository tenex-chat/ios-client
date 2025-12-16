//
// DetachedConversationWindow.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AppKit
import NDKSwiftCore
import os
import SwiftUI

// MARK: - DetachedWindowHeader

/// Header for the detached conversation window
///
/// This view displays the conversation title, project subtitle, and control buttons
/// (reattach, close) for managing the detached window.
private struct DetachedWindowHeader: View {
    // MARK: Lifecycle

    init(
        title: String,
        projectName: String?,
        onReattach: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.projectName = projectName
        self.onReattach = onReattach
        self.onClose = onClose
    }

    // MARK: Internal

    let title: String
    let projectName: String?
    let onReattach: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerContent
            Divider()
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Private

    private var headerContent: some View {
        HStack(spacing: 12) {
            titleSection
            Spacer()
            reattachButton
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)
                .lineLimit(1)

            if let projectName {
                Text(projectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var reattachButton: some View {
        Button(action: onReattach) {
            Image(systemName: "arrow.down.backward.square")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Reattach to Main Window")
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Close")
    }
}

// MARK: - DetachedConversationWindow

/// Detached conversation window that displays in a separate macOS window
///
/// This view displays a conversation thread in a standalone window. It includes:
/// - A header with navigation controls (reattach, close)
/// - The ChatView component showing the conversation
///
/// The window loads the thread event on-demand and reuses the existing ChatView component.
/// It shares the WindowManagerStore via environment to synchronize state across all windows.
public struct DetachedConversationWindow: View {
    // MARK: Lifecycle

    public init(
        windowID: String,
        ndk: NDK,
        authManager: NDKAuthManager,
        dataStore: DataStore
    ) {
        self.windowID = windowID
        self.ndk = ndk
        self.authManager = authManager
        self.dataStore = dataStore
    }

    // MARK: Public

    public var body: some View {
        if let window = windowManager.window(for: windowID) {
            VStack(spacing: 0) {
                windowHeader(for: window)
                contentView(for: window)
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .task {
                await loadThreadEvent(for: window)
            }
        } else {
            missingWindowView
        }
    }

    // MARK: Private

    private let windowID: String
    private let ndk: NDK
    private let authManager: NDKAuthManager
    private let dataStore: DataStore

    @Environment(WindowManagerStore.self) private var windowManager
    @Environment(\.dismiss) private var dismiss

    @State private var threadEvent: NDKEvent?
    @State private var isLoading = true

    private var missingWindowView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Window Not Found")
                .font(.headline)

            Text("This window's data could not be located")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Close") {
                dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectName(for window: ConversationWindow) -> String? {
        dataStore.projects.first { $0.coordinate == window.projectID }?.title
    }

    private func windowHeader(for window: ConversationWindow) -> some View {
        DetachedWindowHeader(
            title: window.title,
            projectName: projectName(for: window),
            onReattach: {
                windowManager.attach(window.id)
                dismiss()
            },
            onClose: {
                windowManager.close(window.id)
                dismiss()
            }
        )
    }

    @ViewBuilder
    private func contentView(for window: ConversationWindow) -> some View {
        if let threadEvent, let userPubkey = authManager.currentUser?.hexadecimalPublicKey {
            ChatView(
                threadEvent: threadEvent,
                projectReference: window.projectID,
                currentUserPubkey: userPubkey
            )
        } else if isLoading {
            loadingView
        } else {
            errorView(for: window)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)

            Text("Loading conversation...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(for window: ConversationWindow) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Unable to load conversation")
                .font(.headline)

            Text("The thread could not be found")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Close") {
                windowManager.close(window.id)
                dismiss()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadThreadEvent(for window: ConversationWindow) async {
        isLoading = true
        let filter = NDKFilter(ids: [window.threadID])
        let subscription = ndk.subscribe(filter: filter)

        do {
            let events = try await subscription.collect(timeout: 5.0, limit: 1)
            threadEvent = events.first
        } catch {
            Logger().error("Failed to load thread event: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
