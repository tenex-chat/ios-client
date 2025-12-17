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

    public var body: some View {
        #if os(macOS)
        macOSBody
        #else
        iOSBody
        #endif
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var viewModel: InboxViewModel?
    @State private var threadCache: [String: NDKEvent] = [:]
    @State private var selectedMessageID: String?

    private let logger = Logger(subsystem: "com.tenex.ios", category: "Inbox")

    // MARK: - Private Views

    @ViewBuilder
    private var macOSBody: some View {
        let vm = viewModel ?? InboxViewModel(dataStore: dataStore)

        NavigationSplitView {
            messageList(viewModel: vm)
        } detail: {
            if let selectedMessageID,
               let message = vm.inboxMessages.first(where: { $0.id == selectedMessageID }) {
                destinationView(for: message)
            } else {
                ContentUnavailableView(
                    "Select a Notification",
                    systemImage: "tray",
                    description: Text("Choose a notification from the list")
                )
            }
        }
        .navigationTitle("Inbox")
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
        .onAppear {
            vm.markAllRead()
        }
    }

    @ViewBuilder
    private var iOSBody: some View {
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
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
        .listStyle(.plain)
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
    }

    @ViewBuilder
    private func messageList(viewModel: InboxViewModel) -> some View {
        List(selection: $selectedMessageID) {
            if viewModel.inboxMessages.isEmpty {
                ContentUnavailableView(
                    "No Notifications",
                    systemImage: "tray",
                    description: Text("Agent escalations will appear here")
                )
            } else {
                ForEach(viewModel.inboxMessages) { message in
                    Button {
                        selectedMessageID = message.id
                    } label: {
                        InboxRow(
                            message: message,
                            isUnread: viewModel.isUnread(message),
                            agentName: viewModel.agentName(for: message.pubkey)
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(message.id)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
        .listStyle(.plain)
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
                    await fetchThread(id: message.threadID)
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
        for await events in subscription.events.prefix(1) {
            guard let event = events.first else { continue }
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
