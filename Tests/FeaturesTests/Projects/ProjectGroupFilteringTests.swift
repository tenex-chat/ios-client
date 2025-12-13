//
// ProjectGroupFilteringTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import TENEXCore
@testable import TENEXFeatures
import Testing

// MARK: - ProjectGroupFilteringTests

@Suite("Project Group Filtering Tests")
@MainActor
struct ProjectGroupFilteringTests {
    // MARK: Internal

    @Test("ViewModel filters projects by selected group")
    func groupFiltering() async {
        // Create mock data store
        let dataStore = DataStore()

        // Create test projects
        let project1 = createMockProject(id: "proj1", title: "Project 1")
        let project2 = createMockProject(id: "proj2", title: "Project 2")
        let project3 = createMockProject(id: "proj3", title: "Project 3")

        // Manually add projects to dataStore.projects
        // Note: In real app, these would come from Nostr events
        dataStore.addMockProjects([project1, project2, project3])

        // Create storage with test group
        let groupStorage = InMemoryProjectGroupStorage()
        let group = ProjectGroup(name: "Work", projectIDs: ["proj1", "proj3"])
        groupStorage.saveGroup(group)

        // Create view model
        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: InMemoryArchiveStorage(),
            groupStorage: groupStorage
        )

        // Initially, no group selected - should show all projects
        #expect(viewModel.projects.count == 3)

        // Select group - should filter to only group projects
        viewModel.selectGroup(group.id)
        #expect(viewModel.selectedGroupID == group.id)
        #expect(viewModel.projects.count == 2)
        #expect(viewModel.projects.contains { $0.id == "proj1" })
        #expect(viewModel.projects.contains { $0.id == "proj3" })
        #expect(!viewModel.projects.contains { $0.id == "proj2" })

        // Deselect group - should show all projects again
        viewModel.selectGroup(nil)
        #expect(viewModel.selectedGroupID == nil)
        #expect(viewModel.projects.count == 3)
    }

    @Test("ViewModel respects both archive and group filters")
    func archiveAndGroupFiltering() async {
        let dataStore = DataStore()

        let project1 = createMockProject(id: "proj1", title: "Project 1")
        let project2 = createMockProject(id: "proj2", title: "Project 2")
        let project3 = createMockProject(id: "proj3", title: "Project 3")

        dataStore.addMockProjects([project1, project2, project3])

        let archiveStorage = InMemoryArchiveStorage()
        archiveStorage.archive(projectID: "proj2")

        let groupStorage = InMemoryProjectGroupStorage()
        let group = ProjectGroup(name: "Work", projectIDs: ["proj1", "proj2", "proj3"])
        groupStorage.saveGroup(group)

        let viewModel = ProjectListViewModel(
            dataStore: dataStore,
            archiveStorage: archiveStorage,
            groupStorage: groupStorage
        )

        // Select group - should show projects in group, excluding archived
        viewModel.selectGroup(group.id)
        #expect(viewModel.projects.count == 2) // proj1 and proj3 (proj2 is archived)
        #expect(!viewModel.projects.contains { $0.id == "proj2" })
    }

    @Test("ViewModel creates new group")
    func testCreateGroup() {
        let dataStore = DataStore()
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
        let dataStore = DataStore()
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
        let dataStore = DataStore()
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

    // MARK: Private

    // MARK: - Helper Methods

    private func createMockProject(id: String, title: String) -> Project {
        Project(
            id: id,
            pubkey: "testpubkey",
            title: title,
            description: nil,
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

// MARK: - DataStore Extension for Testing

extension DataStore {
    func addMockProjects(_ projects: [Project]) {
        // This is a test helper - in real implementation,
        // projects would be added via Nostr events
        // For testing, we directly set the projects array
        self.projects = projects
    }
}
