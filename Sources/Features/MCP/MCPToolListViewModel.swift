//
// MCPToolListViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Combine
import Foundation
import NDKSwiftCore

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
                let events = try await ndk.fetchEvents(filters: [filter])
                let tools = events.compactMap { MCPTool.from(event: $0) }

                await MainActor.run {
                    self.tools = tools
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}
