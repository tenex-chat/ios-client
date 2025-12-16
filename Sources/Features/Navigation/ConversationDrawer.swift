//
// ConversationDrawer.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import AppKit
import NDKSwiftCore
import os
import SwiftUI

// MARK: - ResizeHandle

/// Resize handle for the conversation drawer
///
/// This view provides a draggable left edge that allows users to resize the drawer.
/// It includes visual feedback (blue highlight during resize) and cursor changes.
private struct ResizeHandle: View {
    // MARK: Lifecycle

    init(drawerWidth: Binding<CGFloat>, isResizing: Binding<Bool>) {
        self._drawerWidth = drawerWidth
        self._isResizing = isResizing
    }

    // MARK: Internal

    var body: some View {
        Rectangle()
            .fill(isResizing ? Color.blue.opacity(0.3) : Color.clear)
            .frame(width: 8)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .onContinuousHover { phase in
                switch phase {
                case .active:
                    guard NSCursor.current != .resizeLeftRight else {
                        return
                    }
                    NSCursor.resizeLeftRight.push()
                case .ended:
                    NSCursor.pop()
                }
            }
    }

    // MARK: Private

    @Binding private var drawerWidth: CGFloat
    @Binding private var isResizing: Bool
    @State private var dragStart: CGFloat = 0

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isResizing {
                    dragStart = drawerWidth
                    isResizing = true
                }

                let delta = -value.translation.width
                let newWidth = dragStart + delta
                drawerWidth = max(300, min(1200, newWidth))
            }
            .onEnded { _ in
                isResizing = false
            }
    }
}

// MARK: - DrawerHeader

/// Header for the conversation drawer
///
/// This view displays the conversation title, project subtitle, and control buttons
/// (back, detach, close) for managing the drawer.
private struct DrawerHeader: View {
    // MARK: Lifecycle

    init(
        title: String,
        projectName: String?,
        onBack: @escaping () -> Void,
        onDetach: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.projectName = projectName
        self.onBack = onBack
        self.onDetach = onDetach
        self.onClose = onClose
    }

    // MARK: Internal

    let title: String
    let projectName: String?
    let onBack: () -> Void
    let onDetach: () -> Void
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
            backButton
            titleSection
            Spacer()
            detachButton
            closeButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Back")
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

    private var detachButton: some View {
        Button(action: onDetach) {
            Image(systemName: "arrow.up.forward.square")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Detach to Window")
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

// MARK: - ConversationDrawer

/// Conversation drawer that slides in from the right edge
///
/// This view displays a conversation thread in a resizable drawer. It includes:
/// - A resize handle on the left edge for adjusting drawer width
/// - A header with navigation controls (back, detach, close)
/// - The ChatView component showing the conversation
///
/// The drawer loads the thread event on-demand and reuses the existing ChatView component.
public struct ConversationDrawer: View {
    // MARK: Lifecycle

    public init(window: ConversationWindow) {
        self.window = window
    }

    // MARK: Public

    public var body: some View {
        HStack(spacing: 0) {
            ResizeHandle(drawerWidth: $windowManager.drawerWidth, isResizing: $isResizing)

            VStack(spacing: 0) {
                drawerHeader
                contentView
            }
        }
        .frame(width: windowManager.drawerWidth)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .shadow(color: .black.opacity(0.2), radius: 8, x: -2, y: 0)
        .animation(isResizing ? .none : .default, value: windowManager.drawerWidth)
        .task {
            await loadThreadEvent()
        }
    }

    // MARK: Private

    private let window: ConversationWindow

    @Environment(WindowManagerStore.self) private var windowManager
    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var threadEvent: NDKEvent?
    @State private var isLoading = true
    @State private var isResizing = false

    private var projectName: String? {
        dataStore.projects.first { $0.coordinate == window.projectID }?.title
    }

    private var drawerHeader: some View {
        DrawerHeader(
            title: window.title,
            projectName: projectName,
            onBack: { windowManager.close(window.id) },
            onDetach: { windowManager.detach(window.id) },
            onClose: { windowManager.close(window.id) }
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if let threadEvent, let userPubkey = authManager.currentUser?.hexadecimalPublicKey {
            ChatView(
                threadEvent: threadEvent,
                projectReference: window.projectID,
                currentUserPubkey: userPubkey
            )
        } else if isLoading {
            loadingView
        } else {
            errorView
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

    private var errorView: some View {
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadThreadEvent() async {
        guard let ndk else {
            isLoading = false
            return
        }

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
