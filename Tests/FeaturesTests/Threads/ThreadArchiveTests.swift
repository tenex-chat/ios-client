//
// ThreadArchiveTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("Thread Archive Tests")
@MainActor
struct ThreadArchiveTests {
    // MARK: - Archive Storage Tests

    @Test("InMemoryThreadArchiveStorage archives thread")
    func inMemoryStorageArchivesThread() async throws {
        let storage = InMemoryThreadArchiveStorage()

        #expect(!storage.isArchived(threadID: "test-thread"))

        storage.archive(threadID: "test-thread")

        #expect(storage.isArchived(threadID: "test-thread"))
        #expect(storage.archivedThreadIDs().contains("test-thread"))
    }

    @Test("InMemoryThreadArchiveStorage unarchives thread")
    func inMemoryStorageUnarchivesThread() async throws {
        let storage = InMemoryThreadArchiveStorage()

        storage.archive(threadID: "test-thread")
        #expect(storage.isArchived(threadID: "test-thread"))

        storage.unarchive(threadID: "test-thread")

        #expect(!storage.isArchived(threadID: "test-thread"))
        #expect(!storage.archivedThreadIDs().contains("test-thread"))
    }

    @Test("UserDefaultsThreadArchiveStorage persists archived threads")
    func userDefaultsStoragePersists() async throws {
        guard let defaults = UserDefaults(suiteName: "test.thread.archive") else {
            Issue.record("Failed to create UserDefaults with test suite name")
            return
        }
        defaults.removePersistentDomain(forName: "test.thread.archive")

        let storage = UserDefaultsThreadArchiveStorage(
            userDefaults: defaults,
            key: "test_archived_thread_ids"
        )

        storage.archive(threadID: "thread-1")
        storage.archive(threadID: "thread-2")

        // Create new instance to verify persistence
        let storage2 = UserDefaultsThreadArchiveStorage(
            userDefaults: defaults,
            key: "test_archived_thread_ids"
        )

        #expect(storage2.isArchived(threadID: "thread-1"))
        #expect(storage2.isArchived(threadID: "thread-2"))
        #expect(storage2.archivedThreadIDs().count == 2)
    }
}
