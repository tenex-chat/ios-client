//
// StatusFeedView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

/// Displays a feed of conversation status updates (kind:513 metadata events)
/// This shows real-time activity across all conversations
public struct StatusFeedView: View {
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
        .navigationTitle("Status")
    }

    // MARK: Private

    @Environment(DataStore.self) private var dataStore
    @Environment(NDKAuthManager.self) private var authManager
    @Environment(\.ndk) private var ndk

    @State private var viewModel: StatusFeedViewModel?
    @State private var selectedThreadID: String?

    // MARK: - Private Views

    @ViewBuilder
    private func macOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = viewModel ?? StatusFeedViewModel(dataStore: dataStore, ndk: ndk)

        NavigationSplitView {
            statusList(viewModel: vm)
        } detail: {
            if let selectedThreadID,
               let metadata = vm.items.first(where: { $0.threadID == selectedThreadID }) {
                destinationView(for: metadata, viewModel: vm)
            } else {
                ContentUnavailableView(
                    "Select a Conversation",
                    systemImage: "waveform",
                    description: Text("Choose a conversation from the status feed")
                )
            }
        }
        .task {
            if self.viewModel == nil {
                self.viewModel = vm
                vm.startSubscription()
            }
        }
        .onDisappear {
            vm.stopSubscription()
        }
    }

    @ViewBuilder
    private func iOSBody(ndk: NDK, dataStore: DataStore) -> some View {
        let vm = self.viewModel ?? StatusFeedViewModel(dataStore: dataStore, ndk: ndk)

        List {
            if vm.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if vm.items.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "waveform",
                    description: Text("Conversation status updates will appear here")
                )
            } else {
                ForEach(vm.items) { metadata in
                    NavigationLink {
                        self.destinationView(for: metadata, viewModel: vm)
                    } label: {
                        StatusFeedRow(
                            metadata: metadata,
                            project: vm.getProject(for: metadata)
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
                vm.startSubscription()
            }
        }
        .onDisappear {
            vm.stopSubscription()
        }
    }

    @ViewBuilder
    private func statusList(viewModel: StatusFeedViewModel) -> some View {
        List(selection: $selectedThreadID) {
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            } else if viewModel.items.isEmpty {
                ContentUnavailableView(
                    "No Activity Yet",
                    systemImage: "waveform",
                    description: Text("Conversation status updates will appear here")
                )
            } else {
                ForEach(viewModel.items) { metadata in
                    Button {
                        selectedThreadID = metadata.threadID
                    } label: {
                        StatusFeedRow(
                            metadata: metadata,
                            project: viewModel.getProject(for: metadata)
                        )
                    }
                    .buttonStyle(.plain)
                    .tag(metadata.threadID)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func destinationView(for metadata: ConversationMetadata, viewModel: StatusFeedViewModel) -> some View {
        if let threadEvent = viewModel.getThreadEvent(for: metadata),
           let userPubkey = authManager.activePubkey {
            let projectCoordinate = metadata.projectCoordinate ?? ""
            ChatView(
                threadEvent: threadEvent,
                projectReference: projectCoordinate,
                currentUserPubkey: userPubkey
            )
        } else {
            ProgressView("Loading thread...")
                .task {
                    viewModel.fetchThreadEventIfNeeded(for: metadata.threadID)
                }
        }
    }
}
