//
// MCPToolListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Combine
import Foundation
import NDKSwiftCore
import TENEXCore

@MainActor
public final class MCPToolListViewModel: ObservableObject {
    // MARK: Lifecycle

    public init(ndk: NDK) {
        self.ndk = ndk
        fetchTools()
    }

    // MARK: Public

    public let ndk: NDK

    @Published public var tools: [MCPTool] = []
    @Published public var error: String?

    public func fetchTools() {
        let filter = NDKFilter(kinds: [4200], limit: 100)

        Task {
            do {
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var seenIDs: Set<String> = []

                for try await event in subscription {
                    // Deduplicate
                    guard !seenIDs.contains(event.id) else { continue }
                    seenIDs.insert(event.id)

                    if let tool = MCPTool.from(event: event) {
                        // Update UI immediately as events arrive
                        tools.append(tool)
                    }
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
