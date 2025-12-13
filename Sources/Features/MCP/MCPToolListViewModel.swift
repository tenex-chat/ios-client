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
    @Published public var isLoading = false
    @Published public var error: String?

    public func fetchTools() {
        isLoading = true

        let filter = NDKFilter(kinds: [4200], limit: 100)

        Task {
            do {
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var collectedTools: [MCPTool] = []

                for try await event in subscription {
                    if let tool = MCPTool.from(event: event) {
                        collectedTools.append(tool)
                    }
                }

                self.tools = collectedTools
                self.isLoading = false
            } catch {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
