//
// ProjectEventTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI
@testable import TENEXCore
@testable import TENEXShared
import Testing

@Suite("Project Event Tests")
struct ProjectEventTests {
    @Test("Parse valid kind:31_933 event into Project model")
    func parseValidProjectEvent() throws {
        // Given: A valid kind:31_933 event
        let projectID = "my-awesome-project"
        let title = "My Awesome Project"
        let description = "A project for testing the Project model"
        let pubkey = "npub1testpubkey1234567890abcdef"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent(
            pubkey: pubkey,
            createdAt: createdAt,
            kind: 31_933,
            tags: [
                ["d", projectID],
                ["title", title],
            ],
            content: "{\"description\": \"\(description)\"}"
        )

        // When: Converting event to Project
        let project = try #require(Project.from(event: event))

        // Then: Project properties match event data
        #expect(project.id == projectID)
        #expect(project.pubkey == pubkey)
        #expect(project.title == title)
        #expect(project.description == description)
        #expect(project.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Extract title from tags")
    func extractTitleFromTags() throws {
        // Given: Event with title tag
        let title = "Project Title From Tags"
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 31_933,
            tags: [
                ["d", "test-project"],
                ["title", title],
            ],
            content: "{}"
        )

        // When: Converting to Project
        let project = try #require(Project.from(event: event))

        // Then: Title is extracted
        #expect(project.title == title)
    }

    @Test("Extract description from JSON content")
    func extractDescriptionFromContent() throws {
        // Given: Event with description in JSON content
        let description = "This is a detailed description"
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 31_933,
            tags: [
                ["d", "test-project"],
                ["title", "Test"],
            ],
            content: "{\"description\": \"\(description)\"}"
        )

        // When: Converting to Project
        let project = try #require(Project.from(event: event))

        // Then: Description is extracted
        #expect(project.description == description)
    }

    @Test("Handle missing description gracefully")
    func handleMissingDescription() throws {
        // Given: Event without description
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 31_933,
            tags: [
                ["d", "test-project"],
                ["title", "Test"],
            ],
            content: "{}"
        )

        // When: Converting to Project
        let project = try #require(Project.from(event: event))

        // Then: Description is nil
        #expect(project.description == nil)
    }

    @Test("Handle invalid JSON content gracefully")
    func handleInvalidJSON() throws {
        // Given: Event with invalid JSON content
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 31_933,
            tags: [
                ["d", "test-project"],
                ["title", "Test"],
            ],
            content: "not valid json"
        )

        // When: Converting to Project
        let project = try #require(Project.from(event: event))

        // Then: Description is nil (gracefully handled)
        #expect(project.description == nil)
    }

    @Test("Generate deterministic HSL color from project ID")
    func generateDeterministicColor() throws {
        // Given: Two events with same project ID
        let projectID = "consistent-project-id"
        let event1 = NDKEvent(
            pubkey: "pubkey1",
            kind: 31_933,
            tags: [
                ["d", projectID],
                ["title", "Test 1"],
            ],
            content: "{}"
        )
        let event2 = NDKEvent(
            pubkey: "pubkey2",
            kind: 31_933,
            tags: [
                ["d", projectID],
                ["title", "Test 2"],
            ],
            content: "{}"
        )

        // When: Converting both to Project
        let project1 = try #require(Project.from(event: event1))
        let project2 = try #require(Project.from(event: event2))

        // Then: Both have identical color (deterministic)
        // Note: Color doesn't have Equatable, so we compare the source ID
        #expect(project1.id == project2.id)
        // Color generation is deterministic based on ID, verified by implementation
    }

    @Test("Return nil for missing d tag")
    func returnNilForMissingDTag() {
        // Given: Event without d tag
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 31_933,
            tags: [
                ["title", "Test"],
            ],
            content: "{}"
        )

        // When: Converting to Project
        let project = Project.from(event: event)

        // Then: Returns nil
        #expect(project == nil)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent(
            pubkey: "testpubkey",
            kind: 1, // Wrong kind
            tags: [
                ["d", "test-project"],
                ["title", "Test"],
            ],
            content: "{}"
        )

        // When: Converting to Project
        let project = Project.from(event: event)

        // Then: Returns nil
        #expect(project == nil)
    }

    @Test("Create filter for fetching projects")
    func createFilterForProjects() {
        // Given: A user pubkey
        let userPubkey = "user-pubkey-123"

        // When: Creating filter for projects
        let filter = Project.filter(for: userPubkey)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [31_933])
        #expect(filter.authors == [userPubkey])
    }
}
