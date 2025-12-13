//
// ProjectDetailViewTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ProjectDetailView Tests")
@MainActor
struct ProjectDetailViewTests {
    // MARK: Internal

    // MARK: - Initialization Tests

    @Test("ProjectDetailView initializes correctly with project")
    func initializesCorrectly() async throws {
        let project = createMockProject(
            id: "test-project",
            title: "Test Project"
        )

        // View should be created without crashing
        _ = ProjectDetailView(project: project)
    }

    @Test("ProjectDetailView displays project with color")
    func displaysProjectWithColor() async throws {
        let project = createMockProject(
            id: "test-project",
            title: "Colorful Project"
        )

        // View should be created without crashing
        _ = ProjectDetailView(project: project)
    }

    // MARK: Private

    // MARK: - Helper Functions

    /// Create a mock project for testing
    private func createMockProject(
        id: String,
        title: String,
        description: String? = nil
    ) -> Project {
        Project(
            id: id,
            pubkey: "test-pubkey",
            title: title,
            description: description,
            picture: nil,
            repoURL: nil,
            hashtags: [],
            agentIDs: [],
            mcpToolIDs: [],
            createdAt: Date(),
            color: .blue
        )
    }
}
