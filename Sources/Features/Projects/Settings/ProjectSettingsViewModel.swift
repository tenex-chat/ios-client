//
// ProjectSettingsViewModel.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import Observation
import TENEXCore

// MARK: - ProjectSettingsViewModel

/// View model for project settings
/// Manages state and publishes updates to Nostr
@MainActor
@Observable
public final class ProjectSettingsViewModel {
    // MARK: Lifecycle

    /// Initialize the project settings view model
    /// - Parameters:
    ///   - project: The project to edit
    ///   - ndk: The NDK instance
    public init(project: Project, ndk: NDK) {
        originalProject = project
        self.ndk = ndk

        // Initialize from project
        title = project.title
        description = project.description ?? ""
        repoURL = project.repoURL ?? ""
        selectedAgentIDs = Set(project.agentIDs)
        selectedToolIDs = Set(project.mcpToolIDs)

        // Set primary agent if any agents exist
        if let firstAgent = project.agentIDs.first {
            primaryAgentID = firstAgent
        }
    }

    // MARK: Public

    /// General settings
    /// Project title
    public var title: String
    /// Project description
    public var description: String
    /// Repository URL
    public var repoURL: String

    /// Agents settings
    /// Selected agent IDs
    public var selectedAgentIDs: Set<String>
    /// Primary agent ID
    public var primaryAgentID: String?

    /// Tools settings
    /// Selected MCP tool IDs
    public var selectedToolIDs: Set<String>

    /// State
    /// Whether the save operation is in progress
    public var isSaving = false
    /// Error message from save operation
    public var saveError: String?

    /// Whether there are unsaved changes
    public var hasUnsavedChanges: Bool {
        title != originalProject.title ||
            description != (originalProject.description ?? "") ||
            repoURL != (originalProject.repoURL ?? "") ||
            selectedAgentIDs != Set(originalProject.agentIDs) ||
            selectedToolIDs != Set(originalProject.mcpToolIDs)
    }

    /// Save changes to Nostr
    public func save() async throws {
        guard !isSaving else {
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await publishUpdatedProject()
            saveError = nil
        } catch {
            saveError = error.localizedDescription
            throw error
        }
    }

    /// Delete the project
    public func deleteProject() async throws {
        // Create deletion event (kind:5 with project coordinate)
        let tags = [["a", originalProject.coordinate]]
        let event = NDKEvent(pubkey: "", kind: 5, tags: tags, content: "")
        try await ndk.publish(event)
    }

    // MARK: Private

    private let ndk: NDK
    private let originalProject: Project

    private func publishUpdatedProject() async throws {
        var tags: [[String]] = [
            ["d", originalProject.id],
            ["title", title],
        ]

        if !repoURL.isEmpty {
            tags.append(["repo", repoURL])
        }

        // Add agent tags (preserve order, primary first if set)
        var agentIDsList = Array(selectedAgentIDs)
        if let primaryID = primaryAgentID, let index = agentIDsList.firstIndex(of: primaryID) {
            agentIDsList.remove(at: index)
            agentIDsList.insert(primaryID, at: 0)
        }

        for agentID in agentIDsList {
            tags.append(["agent", agentID])
        }

        // Add MCP tool tags
        for toolID in selectedToolIDs {
            tags.append(["mcp", toolID])
        }

        let content: String
        if !description.isEmpty {
            let json = ["description": description]
            let data = try JSONSerialization.data(withJSONObject: json)
            content = String(data: data, encoding: .utf8) ?? "{}"
        } else {
            content = "{}"
        }

        let event = NDKEvent(pubkey: "", kind: 31_933, tags: tags, content: content)
        try await ndk.publish(event)
    }
}
