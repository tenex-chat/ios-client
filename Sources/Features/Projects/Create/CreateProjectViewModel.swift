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
    @Published public var currentStep = 0
    @Published public var isPublishing = false
    @Published public var error: String?

    // Step 1: Details
    @Published public var projectName = ""
    @Published public var projectDescription = ""
    @Published public var projectTags = "" // Space/Comma separated
    @Published public var projectImageURL = ""
    @Published public var projectRepoURL = ""

    // Step 2: Agents
    @Published public var availableAgents: [AgentDefinition] = []
    @Published public var selectedAgentIDs: Set<String> = []
    @Published public var isLoadingAgents = false

    // Step 3: MCP Tools
    @Published public var availableTools: [MCPTool] = []
    @Published public var selectedToolIDs: Set<String> = []
    @Published public var isLoadingTools = false

    public var canProceed: Bool {
        switch currentStep {
        case 0:
            !projectName.isEmpty && !projectDescription.isEmpty
        case 1:
            true // Agent selection is optional
        case 2:
            true // Tool selection is optional
        case 3:
            !isPublishing
        default:
            false
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
        guard !projectName.isEmpty else {
            return false
        }

        isPublishing = true
        defer { isPublishing = false }

        // Tags
        var tags: [[String]] = [
            ["d", projectName.lowercased().replacingOccurrences(of: " ", with: "-")],
            ["title", projectName],
        ]

        if !projectImageURL.isEmpty {
            tags.append(["picture", projectImageURL])
        }

        if !projectRepoURL.isEmpty {
            tags.append(["repo", projectRepoURL])
        }

        // Hashtags
        let hashtags = projectTags.split(separator: " ").map {
            String($0).trimmingCharacters(in: .punctuationCharacters)
        }
        for tag in hashtags {
            tags.append(["t", tag])
        }

        // Agents
        for agentID in selectedAgentIDs {
            tags.append(["agent", agentID])
        }

        // MCP Tools
        for toolID in selectedToolIDs {
            tags.append(["mcp", toolID])
        }

        // Content (JSON description)
        let contentDict: [String: Any] = ["description": projectDescription]
        guard let contentData = try? JSONSerialization.data(withJSONObject: contentDict),
              let content = String(data: contentData, encoding: .utf8)
        else {
            error = "Failed to serialize description"
            return false
        }

        let event = NDKEvent(kind: 31_933, tags: tags, content: content, ndk: ndk)

        do {
            try await ndk.publish(event)
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
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var collectedAgents: [AgentDefinition] = []

                for try await event in subscription {
                    if let agent = AgentDefinition.from(event: event) {
                        collectedAgents.append(agent)
                    }
                }

                await MainActor.run {
                    self.availableAgents = collectedAgents
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
                let subscription = ndk.subscribeToEvents(filters: [filter])
                var collectedTools: [MCPTool] = []

                for try await event in subscription {
                    if let tool = MCPTool.from(event: event) {
                        collectedTools.append(tool)
                    }
                }

                await MainActor.run {
                    self.availableTools = collectedTools
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
