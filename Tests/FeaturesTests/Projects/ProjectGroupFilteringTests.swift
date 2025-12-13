//
// ProjectGroupFilteringTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
@testable import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - ProjectGroupFilteringTests

@Suite("Project Group Filtering Tests")
@MainActor
struct ProjectGroupFilteringTests {
    @Test("ViewModel creates new group")
    func testCreateGroup() {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let groupStorage = InMemoryProjectGroupStorage()

        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: InMemoryArchiveStorage(),
            groupStorage: groupStorage
        )

        #expect(viewModel.groups.isEmpty)

        viewModel.createGroup(name: "Work", projectIDs: ["proj1", "proj2"])

        #expect(viewModel.groups.count == 1)
        #expect(viewModel.groups.first?.name == "Work")
        #expect(viewModel.groups.first?.projectIDs == ["proj1", "proj2"])
    }

    @Test("ViewModel updates existing group")
    func testUpdateGroup() {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let groupStorage = InMemoryProjectGroupStorage()

        var group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        groupStorage.saveGroup(group)

        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: InMemoryArchiveStorage(),
            groupStorage: groupStorage
        )

        group.name = "Work Projects"
        group.projectIDs = ["proj1", "proj2"]
        viewModel.updateGroup(group)

        #expect(viewModel.groups.count == 1)
        #expect(viewModel.groups.first?.name == "Work Projects")
        #expect(viewModel.groups.first?.projectIDs == ["proj1", "proj2"])
    }

    @Test("ViewModel deletes group")
    func testDeleteGroup() {
        let ndk = NDK(relayURLs: [])
        let dataStore = DataStore(ndk: ndk)
        let groupStorage = InMemoryProjectGroupStorage()

        let group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        groupStorage.saveGroup(group)

        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: InMemoryArchiveStorage(),
            groupStorage: groupStorage
        )

        #expect(viewModel.groups.count == 1)

        viewModel.deleteGroup(id: group.id)

        #expect(viewModel.groups.isEmpty)
    }
}
