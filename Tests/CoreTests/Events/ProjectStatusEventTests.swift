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
        // Given: A valid kind:24_010 event with agent tags
        let projectCoordinate = "31933:pubkeyabc:my-awesome-project"
        let pubkey = "npub1testpubkey1234567890abcdef"
        let createdAt = Timestamp(Date().timeIntervalSince1970)

        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", projectCoordinate],
                ["agent", "agent1pubkey", "Claude"],
                ["agent", "agent2pubkey", "GPT-4"],
            ],
            pubkey: pubkey,
            createdAt: createdAt
        )

        // When: Converting event to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: ProjectStatus properties match event data
        #expect(status.projectCoordinate == projectCoordinate)
        #expect(status.pubkey == pubkey)
        #expect(status.agents.count == 2)
        #expect(status.createdAt.timeIntervalSince1970 == TimeInterval(createdAt))
    }

    @Test("Parse agents with name and pubkey from tags")
    func parseAgentsFromTags() throws {
        // Given: Event with agent tags containing pubkey and name
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"],
                ["agent", "def456", "GPT-4"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Agents have correct pubkey and name
        #expect(status.agents.count == 2)
        let claude = status.agents.first { $0.name == "Claude" }
        let gpt = status.agents.first { $0.name == "GPT-4" }
        #expect(claude?.pubkey == "abc123")
        #expect(gpt?.pubkey == "def456")
    }

    @Test("Parse global agents from tags")
    func parseGlobalAgents() throws {
        // Given: Event with global and non-global agents
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude", "global"],
                ["agent", "def456", "GPT-4"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Global flag is correctly parsed
        let claude = status.agents.first { $0.name == "Claude" }
        let gpt = status.agents.first { $0.name == "GPT-4" }
        #expect(claude?.isGlobal == true)
        #expect(gpt?.isGlobal == false)
    }

    @Test("Associate models with agents by name")
    func associateModelsWithAgents() throws {
        // Given: Event with agent and model tags
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"],
                ["agent", "def456", "GPT-4"],
                ["model", "claude-sonnet-4", "Claude"],
                ["model", "gpt-4-turbo", "GPT-4"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Models are associated with correct agents
        let claude = status.agents.first { $0.name == "Claude" }
        let gpt = status.agents.first { $0.name == "GPT-4" }
        #expect(claude?.model == "claude-sonnet-4")
        #expect(gpt?.model == "gpt-4-turbo")
    }

    @Test("Associate tools with agents by name")
    func associateToolsWithAgents() throws {
        // Given: Event with agent and tool tags
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"],
                ["agent", "def456", "GPT-4"],
                ["tool", "web-search", "Claude", "GPT-4"],
                ["tool", "code-interpreter", "Claude"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Tools are associated with correct agents
        let claude = status.agents.first { $0.name == "Claude" }
        let gpt = status.agents.first { $0.name == "GPT-4" }
        #expect(claude?.tools.count == 2)
        #expect(claude?.tools.contains("web-search") == true)
        #expect(claude?.tools.contains("code-interpreter") == true)
        #expect(gpt?.tools.count == 1)
        #expect(gpt?.tools.contains("web-search") == true)
    }

    @Test("Handle no online agents gracefully")
    func handleNoOnlineAgents() throws {
        // Given: Event without agent tags
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Agents array is empty
        #expect(status.agents.isEmpty)
    }

    @Test("Skip malformed agent tags")
    func skipMalformedAgentTags() throws {
        // Given: Event with valid and malformed agent tags
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"], // Valid
                ["agent", "def456"], // Missing name - should skip
                ["agent", "", "Ghost"], // Empty pubkey - should skip
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: Only valid agent is parsed
        #expect(status.agents.count == 1)
        #expect(status.agents[0].name == "Claude")
    }

    @Test("Return nil for wrong kind")
    func returnNilForWrongKind() {
        // Given: Event with wrong kind
        let event = NDKEvent.test(
            kind: 1, // Wrong kind
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "agent1", "Claude"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = ProjectStatus.from(event: event)

        // Then: Returns nil
        #expect(status == nil)
    }

    @Test("Return nil for missing a tag")
    func returnNilForMissingATag() {
        // Given: Event without a tag (project reference)
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["agent", "agent1", "Claude"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = ProjectStatus.from(event: event)

        // Then: Returns nil
        #expect(status == nil)
    }

    @Test("Create filter for fetching project statuses by user pubkey")
    func createFilterForProjectStatus() {
        // Given: A user pubkey
        let userPubkey = "userpubkey123abc"

        // When: Creating filter for project status
        let filter = ProjectStatus.filter(for: userPubkey)

        // Then: Filter has correct parameters (filters by p-tag)
        #expect(filter.kinds == [24_010])
        #expect(filter.tags?["p"] == Set([userPubkey]))
    }

    @Test("Extract project dTag from coordinate")
    func extractDTagFromCoordinate() throws {
        // Given: A status with coordinate
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:ownerpubkey:my-project-dtag"],
            ],
            pubkey: "testpubkey"
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: dTag is correctly extracted
        #expect(status.projectDTag == "my-project-dtag")
    }

    @Test("isOnline returns true for recent status")
    func isOnlineForRecentStatus() throws {
        // Given: A status created just now
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"],
            ],
            pubkey: "testpubkey",
            createdAt: Timestamp(Date().timeIntervalSince1970)
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: isOnline returns true
        #expect(status.isOnline == true)
    }

    @Test("isOnline returns false for stale status")
    func isOnlineForStaleStatus() throws {
        // Given: A status created 10 minutes ago (beyond 5 min threshold)
        let staleDate = Date().addingTimeInterval(-10 * 60)
        let event = NDKEvent.test(
            kind: 24_010,
            content: "",
            tags: [
                ["a", "31933:owner:test-project"],
                ["agent", "abc123", "Claude"],
            ],
            pubkey: "testpubkey",
            createdAt: Timestamp(staleDate.timeIntervalSince1970)
        )

        // When: Converting to ProjectStatus
        let status = try #require(ProjectStatus.from(event: event))

        // Then: isOnline returns false
        #expect(status.isOnline == false)
    }
}
