//
// RecentConversationsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

public struct RecentConversationsView: View {
    // MARK: Lifecycle

    public init() {}

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                #if os(macOS)
                macOSBody(ndk: ndk, dataStore: dataStore)
                #else
                iOSBody(ndk: ndk, dataStore: dataStore)
                #endif
            } else {
                ProgressView("Loading...")
            }
        }
        .navigationTitle("Recent")
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var viewModel: RecentConversationsViewModel?
    @State private var selectedThreadID: String?

    // MARK: - Private Views

    @ViewBuilder
    private func macOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = viewModel ?? RecentConversationsViewModel(dataStore: dataStore, ndk: ndk)

        NavigationSplitView {
            conversationList(viewModel: vm)
        } detail: {
            if let selectedThreadID {
                destinationView(threadID: selectedThreadID, viewModel: vm)
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Choose a conversation from the list")
                )
            }
        }
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
            }
        }
    }

    @ViewBuilder
    private func iOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = self.viewModel ?? RecentConversationsViewModel(dataStore: dataStore, ndk: ndk)

        List {
            if vm.sortedThreadIDs.isEmpty {
                ContentUnavailableView(
                    "No Recent Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Recent conversations across all projects will appear here")
                )
            } else {
                ForEach(vm.sortedThreadIDs, id: \.self) { threadID in
                    if let latestMessage = vm.latestMessage(for: threadID) {
                        NavigationLink {
                            self.destinationView(
                                threadID: threadID,
                                viewModel: vm
                            )
                        } label: {
                            RecentConversationRow(
                                threadID: threadID,
                                thread: vm.getThread(id: threadID),
                                project: vm.getProject(for: threadID),
                                latestMessage: latestMessage,
                                conversationMetadata: vm.getConversationMetadata(for: threadID)
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
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
    private func conversationList(viewModel: RecentConversationsViewModel) -> some View {
        List(selection: $selectedThreadID) {
            if viewModel.sortedThreadIDs.isEmpty {
                ContentUnavailableView(
                    "No Recent Conversations",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Recent conversations across all projects will appear here")
                )
            } else {
                ForEach(viewModel.sortedThreadIDs, id: \.self) { threadID in
                    if let latestMessage = viewModel.latestMessage(for: threadID) {
                        Button {
                            selectedThreadID = threadID
                        } label: {
                            RecentConversationRow(
                                threadID: threadID,
                                thread: viewModel.getThread(id: threadID),
                                project: viewModel.getProject(for: threadID),
                                latestMessage: latestMessage,
                                conversationMetadata: viewModel.getConversationMetadata(for: threadID)
                            )
                        }
                        .buttonStyle(.plain)
                        .tag(threadID)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(threadID: String, viewModel: RecentConversationsViewModel) -> some View {
        if let threadEvent = viewModel.getThreadEvent(id: threadID),
           let project = viewModel.getProject(for: threadID),
           let userPubkey = authManager.activePubkey {
            ChatView(
                threadEvent: threadEvent,
                projectReference: project.coordinate,
                currentUserPubkey: userPubkey
            )
        } else {
            ProgressView("Loading thread...")
                .task {
                    _ = viewModel.getThread(id: threadID)
                }
        }
    }
}
