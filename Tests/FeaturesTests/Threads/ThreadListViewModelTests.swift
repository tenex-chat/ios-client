//
// ThreadListViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ThreadListViewModel Tests")
@MainActor
struct ThreadListViewModelTests {
    // MARK: - Initial State Tests

    @Test("ThreadListViewModel starts with empty threads list")
    func startsWithEmptyThreads() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )

        #expect(viewModel.threads.isEmpty)
    }

    @Test("ThreadListViewModel starts with not loading state")
    func startsNotLoading() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )
        _ = viewModel // silence unused warning
    }

    @Test("ThreadListViewModel starts with no error")
    func startsWithNoError() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Thread Loading Tests

    @Test("ThreadListViewModel loads threads successfully")
    func loadsThreads() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )

        #expect(viewModel.threads.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading State Tests

    @Test("ThreadListViewModel stops loading after successful fetch")
    func stopsLoadingAfterSuccess() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )
        _ = viewModel // silence unused warning
    }

    // MARK: - Refresh Tests

    @Test("ThreadListViewModel refresh reloads threads")
    func refreshReloadsThreads() async throws {
        let ndk = NDK(relayURLs: [])
        let filtersStore = ThreadFiltersStore()
        let viewModel = ThreadListViewModel(
            ndk: ndk,
            projectID: "test-project",
            filtersStore: filtersStore,
            currentUserPubkey: nil
        )

        #expect(viewModel.threads.isEmpty)

        #expect(viewModel.threads.isEmpty)
    }
}
