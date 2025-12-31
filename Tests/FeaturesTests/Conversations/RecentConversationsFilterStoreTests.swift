//
// RecentConversationsFilterStoreTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
@testable import TENEXFeatures
import Testing

@Suite("RecentConversationsFilterStore Tests")
@MainActor
struct RecentConversationsFilterStoreTests {
    // MARK: - Initial State Tests

    @Test("FilterStore starts with filter disabled by default")
    func startsWithFilterDisabled() async throws {
        // Clear any saved state first
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        #expect(store.onlyByMe == false)
    }

    // MARK: - Toggle Tests

    @Test("Toggle enables filter when disabled")
    func toggleEnablesFilter() async throws {
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        #expect(store.onlyByMe == false)

        store.toggleOnlyByMe()
        #expect(store.onlyByMe == true)
    }

    @Test("Toggle disables filter when enabled")
    func toggleDisablesFilter() async throws {
        UserDefaults.standard.set(true, forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        #expect(store.onlyByMe == true)

        store.toggleOnlyByMe()
        #expect(store.onlyByMe == false)
    }

    // MARK: - Explicit Set Tests

    @Test("SetOnlyByMe explicitly enables filter")
    func setOnlyByMeEnables() async throws {
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        store.setOnlyByMe(true)
        #expect(store.onlyByMe == true)
    }

    @Test("SetOnlyByMe explicitly disables filter")
    func setOnlyByMeDisables() async throws {
        UserDefaults.standard.set(true, forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        store.setOnlyByMe(false)
        #expect(store.onlyByMe == false)
    }

    // MARK: - Persistence Tests

    @Test("Filter state persists across store instances")
    func persistsAcrossInstances() async throws {
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")

        // Create first store and enable filter
        let store1 = RecentConversationsFilterStore()
        store1.setOnlyByMe(true)

        // Create second store and verify state is preserved
        let store2 = RecentConversationsFilterStore()
        #expect(store2.onlyByMe == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")
    }

    @Test("Toggle persists state to UserDefaults")
    func togglePersistsState() async throws {
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")

        let store = RecentConversationsFilterStore()
        store.toggleOnlyByMe()

        // Verify directly in UserDefaults
        let savedValue = UserDefaults.standard.bool(forKey: "recent-conversations-only-by-me")
        #expect(savedValue == true)

        // Clean up
        UserDefaults.standard.removeObject(forKey: "recent-conversations-only-by-me")
    }
}
