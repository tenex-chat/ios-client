//
// CreateProjectViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Combine
import Foundation
import NDKSwiftCore
import SwiftUI

@MainActor
public final class CreateProjectViewModel: ObservableObject {
    // MARK: Lifecycle

    public init(ndk: NDK) {
        self.ndk = ndk
        // Initialize fetchers
        fetchAgents()
        fetchMCPTools()
    }

    // MARK: Public

    public let ndk: NDK

    // Wizard State
    @Published public var currentStep: Int = 0
    @Published public var isPublishing = false
    @Published public var error: String?

    // Step 1: Details
    @Published public var projectName: String = ""
    @Published public var projectDescription: String = ""
    @Published public var projectTags: String = "" // Space/Comma separated
    @Published public var projectImageUrl: String = ""
    @Published public var projectRepoUrl: String = ""

    // Step 2: Agents
    @Published public var availableAgents: [AgentDefinition] = []
    @Published public var selectedAgentIds: Set<String> = []
    @Published public var isLoadingAgents = false

    // Step 3: MCP Tools
    @Published public var availableTools: [MCPTool] = []
    @Published public var selectedToolIds: Set<String> = []
    @Published public var isLoadingTools = false

    public var canProceed: Bool {
        switch currentStep {
        case 0:
            return !projectName.isEmpty && !projectDescription.isEmpty
        case 1:
            return true // Agent selection is optional
        case 2:
            return true // Tool selection is optional
        case 3:
            return !isPublishing
        default:
            return false
        }
    }

    public func nextStep() {
        if currentStep < 3 {
            currentStep += 1
        }
    }

    public func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    public func createProject() async -> Bool {
        guard !projectName.isEmpty else { return false }

        isPublishing = true
        defer { isPublishing = false }

        // Tags
        var tags: [[String]] = [
            ["d", projectName.lowercased().replacingOccurrences(of: " ", with: "-")],
            ["title", projectName],
        ]

        if !projectImageUrl.isEmpty {
            tags.append(["picture", projectImageUrl])
        }

        if !projectRepoUrl.isEmpty {
            tags.append(["repo", projectRepoUrl])
        }

        // Hashtags
        let hashtags = projectTags.split(separator: " ").map { String($0).trimmingCharacters(in: .punctuationCharacters) }
        for tag in hashtags {
            tags.append(["t", tag])
        }

        // Agents
        for agentId in selectedAgentIds {
            tags.append(["agent", agentId])
        }

        // MCP Tools
        for toolId in selectedToolIds {
            tags.append(["mcp", toolId])
        }

        // Content (JSON description)
        let contentDict: [String: Any] = ["description": projectDescription]
        guard let contentData = try? JSONSerialization.data(withJSONObject: contentDict),
              let content = String(data: contentData, encoding: .utf8) else {
            error = "Failed to serialize description"
            return false
        }

        let event = NDKEvent(kind: 31933, tags: tags, content: content, ndk: ndk)

        do {
            try await event.publish()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: Private

    private func fetchAgents() {
        isLoadingAgents = true

        let filter = NDKFilter(kinds: [4199], limit: 100)

        Task {
            do {
                let events = try await ndk.fetchEvents(filters: [filter])
                let agents = events.compactMap { AgentDefinition.from(event: $0) }

                await MainActor.run {
                    self.availableAgents = agents
                    self.isLoadingAgents = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoadingAgents = false
                }
            }
        }
    }

    private func fetchMCPTools() {
        isLoadingTools = true

        let filter = NDKFilter(kinds: [4200], limit: 100)

        Task {
            do {
                let events = try await ndk.fetchEvents(filters: [filter])
                let tools = events.compactMap { MCPTool.from(event: $0) }

                await MainActor.run {
                    self.availableTools = tools
                    self.isLoadingTools = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoadingTools = false
                }
            }
        }
    }
}
