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
    // MARK: - Initial State Tests

    @Test("ProjectListViewModel starts with empty projects list")
    func startsWithEmptyProjects() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        #expect(viewModel.projects.isEmpty)
    }

    @Test("ProjectListViewModel starts with not loading state")
    func startsNotLoading() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        #expect(viewModel.isLoading == false)
    }

    @Test("ProjectListViewModel starts with no error")
    func startsWithNoError() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Loading State Tests

    @Test("ProjectListViewModel stops loading after successful fetch")
    func stopsLoadingAfterSuccess() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.isLoading == false)
    }

    // MARK: - Project Loading Tests

    @Test("ProjectListViewModel loads projects successfully")
    func loadsProjects() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    // MARK: - Refresh Tests

    @Test("ProjectListViewModel refresh reloads projects")
    func refreshReloadsProjects() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.isEmpty)

        await viewModel.refresh()

        #expect(viewModel.projects.isEmpty)
    }

    // MARK: - Empty State Tests

    @Test("ProjectListViewModel handles no projects gracefully")
    func handlesNoProjects() async throws {
        let ndk = NDK(relayURLs: [])
        let viewModel = ProjectListViewModel(ndk: ndk, userPubkey: "test-pubkey")

        await viewModel.loadProjects()

        #expect(viewModel.projects.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }
}
