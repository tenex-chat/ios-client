//
// ProjectStatusEventTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
import Testing

@Suite("ProjectStatus Event Tests")
struct ProjectStatusEventTests {
    @Test("Parse valid kind:24_010 event into ProjectStatus model")
    func parseValidProjectStatusEvent() throws {
        // Given: A valid kind:24_010 event
        let projectID = "my-awesome-project"
        let pubkey = "npub1testpubkey1234567890abcdef"
        let agent1 = "agent1pubkey"
        let agent2 = "agent2pubkey"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", projectID],
                ["agent", agent1],
                ["agent", agent2],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: ProjectStatus properties match event data
        #expect(status.projectID == projectID)
        #expect(status.pubkey == pubkey)
        #expect(status.onlineAgents.count == 2)
        #expect(status.onlineAgents.contains(agent1))
        #expect(status.onlineAgents.contains(agent2))
        #expect(status.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Extract online agents from tags")
    func extractOnlineAgentsFromTags() throws {
        // Given: Event with multiple agent tags
        let agent1 = "agent1"
        let agent2 = "agent2"
        let agent3 = "agent3"
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", agent1],
                ["agent", agent2],
                ["agent", agent3],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: All agents are extracted
        #expect(status.onlineAgents.count == 3)
        #expect(status.onlineAgents.contains(agent1))
        #expect(status.onlineAgents.contains(agent2))
        #expect(status.onlineAgents.contains(agent3))
    }

    @Test("Handle no online agents gracefully")
    func handleNoOnlineAgents() throws {
        // Given: Event without agent tags
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["d", "test-project"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Online agents array is empty
        #expect(status.onlineAgents.isEmpty)
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent.test(
            kind: 1, // Wrong kind
            content: "",
            tags: [
                ["d", "test-project"],
                ["agent", "agent1"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = ProjectStatus.from(event: event)

        // Then: Returns nil
        #expect(status == nil)
    }

    @Test("Return nil for missing d tag")
    func returnNilForMissingDTag() {
        // Given: Event without d tag
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["agent", "agent1"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = ProjectStatus.from(event: event)

        // Then: Returns nil
        #expect(status == nil)
    }

    @Test("Create filter for fetching project status")
    func createFilterForProjectStatus() {
        // Given: A project ID
        let projectID = "test-project-123"

        // When: Creating filter for project status
        let filter = ProjectStatus.filter(for: projectID)

        // Then: Filter has correct parameters
        #expect(filter.kinds == [24_010])
        #expect(filter.tags?["d"] == Set([projectID]))
    }
}
