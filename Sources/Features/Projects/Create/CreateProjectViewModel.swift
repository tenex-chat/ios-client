//
// CreateProjectViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import SwiftUI
import TENEXCore

/// View model for the create project wizard
@MainActor
@Observable
public final class CreateProjectViewModel {
    // MARK: Lifecycle

    /// Initialize the create project view model
    /// - Parameters:
    ///   - ndk: The NDK instance for publishing projects
    ///   - dataStore: The centralized data store
    public init(ndk: NDK, dataStore: DataStore) {
        self.ndk = ndk
        self.dataStore = dataStore
    }

    // MARK: Public

    // MARK: - Wizard State

    /// Current wizard step (0-3)
    public var currentStep = 0

    /// Whether the project is being published
    public var isPublishing = false

    /// Error message if publish fails
    public var error: String?

    // MARK: - Project Details

    /// Project name
    public var projectName = ""

    /// Project description
    public var projectDescription = ""

    /// Project hashtags (space/comma separated)
    public var projectTags = ""

    /// Project image URL
    public var projectImageURL = ""

    /// Project repository URL
    public var projectRepoURL = ""

    // MARK: - Agent Selection

    /// Selected agent IDs
    public var selectedAgentIDs: Set<String> = []

    // MARK: - Tool Selection

    /// Selected tool IDs
    public var selectedToolIDs: Set<String> = []

    /// Available agents from DataStore
    public var availableAgents: [AgentDefinition] {
        dataStore.agents
    }

    /// Whether agents are currently loading
    public var isLoadingAgents: Bool {
        dataStore.isLoadingAgents
    }

    /// Available MCP tools from DataStore
    public var availableTools: [MCPTool] {
        dataStore.tools
    }

    /// Whether tools are currently loading
    public var isLoadingTools: Bool {
        dataStore.isLoadingTools
    }

    // MARK: - Navigation

    /// Whether the user can proceed to the next step
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

    /// Advance to the next wizard step
    public func nextStep() {
        if currentStep < 3 {
            currentStep += 1
        }
    }

    /// Go back to the previous wizard step
    public func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    /// Create and publish the project to Nostr
    /// - Returns: True if successful, false otherwise
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

        do {
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(31_933)
                .setTags(tags)
                .content(content)
                .build()

            try await ndk.publish(event)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: Private

    @ObservationIgnored private let ndk: NDK

    @ObservationIgnored private let dataStore: DataStore
}
