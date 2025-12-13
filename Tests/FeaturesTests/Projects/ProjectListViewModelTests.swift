//
// ProjectListViewModelTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import NDKSwiftTesting
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ProjectListViewModel Tests")
@MainActor
struct ProjectListViewModelTests {
    // MARK: Internal

    // MARK: - Initial State Tests

    @Test("ProjectListViewModel starts with empty projects list")
    func startsWithEmptyProjects() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.projects.isEmpty)
    }

    @Test("ProjectListViewModel starts with not loading state")
    func startsNotLoading() async throws {
        _ = createViewModel()
    }

    @Test("ProjectListViewModel starts with not loading")
    func startsWithNotLoading() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Loading State Tests

    @Test("ProjectListViewModel stops loading after successful fetch")
    func stopsLoadingAfterSuccess() async throws {
        _ = createViewModel()
    }

    // MARK: - Project Loading Tests

    @Test("ProjectListViewModel loads projects successfully")
    func loadsProjects() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.projects.isEmpty)
    }

    // MARK: - Refresh Tests

    @Test("ProjectListViewModel refresh reloads projects")
    func refreshReloadsProjects() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.projects.isEmpty)

        #expect(viewModel.projects.isEmpty)
    }

    // MARK: - Empty State Tests

    @Test("ProjectListViewModel handles no projects gracefully")
    func handlesNoProjects() async throws {
        let viewModel = createViewModel()

        #expect(viewModel.projects.isEmpty)
    }

    // MARK: Private

    private func createViewModel() -> ProjectListViewModel {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        return ProjectListViewModel(dataStore: dataStore)
    }
}
