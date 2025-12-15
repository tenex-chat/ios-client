//
// InboxView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import os
import SwiftUI
import TENEXCore

public struct InboxView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    // MARK: - Body

    public var body: some View {
        self.contentView(dataStore: self.dataStore)
            .navigationTitle("Inbox")
            .onAppear {
                self.viewModel?.markAllRead()
            }
    }

    // MARK: Private

    // MARK: - Environment

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    // MARK: - State

    @State private var viewModel: InboxViewModel?
    @State private var threadCache: [String: NDKEvent] = [:]

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.tenex.ios", category: "Inbox")

    // MARK: - Private Views

    @ViewBuilder
    private func contentView(dataStore: DataStore) -> some View {
        let vm = self.viewModel ?? InboxViewModel(dataStore: dataStore)

        List {
            if vm.inboxMessages.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "tray",
                    description: Text("Agent escalations will appear here")
                )
            } else {
                ForEach(vm.inboxMessages) { message in
                    NavigationLink {
                        self.destinationView(for: message)
                    } label: {
                        InboxRow(
                            message: message,
                            isUnread: vm.isUnread(message),
                            agentName: vm.agentName(for: message.pubkey)
                        )
                    }
                }
            }
        }
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
    }

    @ViewBuilder
    private func destinationView(for message: Message) -> some View {
        if let threadEvent = threadCache[message.threadID],
           let projectCoordinate = message.projectCoordinate,
           let userPubkey = authManager.activePubkey {
            ChatView(
                threadEvent: threadEvent,
                projectReference: projectCoordinate,
                currentUserPubkey: userPubkey
            )
        } else {
            ProgressView("Loading thread...")
                .task {
                    await self.fetchThread(id: message.threadID)
                }
        }
    }

    private func fetchThread(id: String) async {
        guard let ndk else {
            self.logger.error("NDK not available for fetching thread: \(id)")
            return
        }

        self.logger.debug("Fetching thread for inbox: \(id)")

        let filter = NDKFilter(ids: [id], kinds: [11])
        let subscription = ndk.subscribe(filter: filter)

        var eventFound = false
        for await event in subscription.events.prefix(1) {
            eventFound = true
            self.threadCache[id] = event
            self.logger.debug("Successfully cached thread for inbox: \(id)")

            // Apply cache size limit (keep last 50 threads for inbox)
            if self.threadCache.count > 50 {
                let keysToRemove = self.threadCache.keys.prefix(self.threadCache.count - 50)
                for key in keysToRemove {
                    self.threadCache.removeValue(forKey: key)
                }
                self.logger.debug("Evicted \(keysToRemove.count) threads from inbox cache")
            }
        }

        if !eventFound {
            self.logger.warning("Thread not found for inbox: \(id)")
        }
    }
}
