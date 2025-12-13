//
// ProjectGroupStorageTests.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import TENEXCore
@testable import TENEXFeatures
import Testing

@Suite("ProjectGroupStorage Tests")
struct ProjectGroupStorageTests {
    // MARK: - InMemoryProjectGroupStorage Tests

    @Test("InMemoryProjectGroupStorage - Save and retrieve groups")
    func inMemorySaveAndRetrieve() {
        let storage = InMemoryProjectGroupStorage()

        let group1 = ProjectGroup(name: "Work", projectIDs: ["proj1", "proj2"])
        let group2 = ProjectGroup(name: "Personal", projectIDs: ["proj3"])

        storage.saveGroup(group1)
        storage.saveGroup(group2)

        let groups = storage.getAllGroups()
        #expect(groups.count == 2)
        #expect(groups.contains { $0.id == group1.id && $0.name == "Work" })
        #expect(groups.contains { $0.id == group2.id && $0.name == "Personal" })
    }

    @Test("InMemoryProjectGroupStorage - Update group")
    func inMemoryUpdateGroup() {
        let storage = InMemoryProjectGroupStorage()

        var group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        storage.saveGroup(group)

        group.name = "Work Projects"
        group.projectIDs = ["proj1", "proj2"]
        storage.updateGroup(group)

        let groups = storage.getAllGroups()
        #expect(groups.count == 1)
        #expect(groups.first?.name == "Work Projects")
        #expect(groups.first?.projectIDs == ["proj1", "proj2"])
    }

    @Test("InMemoryProjectGroupStorage - Delete group")
    func inMemoryDeleteGroup() {
        let storage = InMemoryProjectGroupStorage()

        let group1 = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        let group2 = ProjectGroup(name: "Personal", projectIDs: ["proj2"])

        storage.saveGroup(group1)
        storage.saveGroup(group2)

        storage.deleteGroup(id: group1.id)

        let groups = storage.getAllGroups()
        #expect(groups.count == 1)
        #expect(groups.first?.id == group2.id)
    }

    @Test("InMemoryProjectGroupStorage - Delete clears selection")
    func inMemoryDeleteClearsSelection() {
        let storage = InMemoryProjectGroupStorage()

        let group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        storage.saveGroup(group)
        storage.setSelectedGroupID(group.id)

        #expect(storage.getSelectedGroupID() == group.id)

        storage.deleteGroup(id: group.id)

        #expect(storage.getSelectedGroupID() == nil)
    }

    @Test("InMemoryProjectGroupStorage - Selected group ID persistence")
    func inMemorySelectedGroupID() {
        let storage = InMemoryProjectGroupStorage()

        #expect(storage.getSelectedGroupID() == nil)

        storage.setSelectedGroupID("group123")
        #expect(storage.getSelectedGroupID() == "group123")

        storage.setSelectedGroupID(nil)
        #expect(storage.getSelectedGroupID() == nil)
    }

    @Test("InMemoryProjectGroupStorage - Groups sorted by creation date")
    func inMemoryGroupsSorted() async {
        let storage = InMemoryProjectGroupStorage()

        let group1 = ProjectGroup(name: "First", projectIDs: [])
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
        let group2 = ProjectGroup(name: "Second", projectIDs: [])

        storage.saveGroup(group2)
        storage.saveGroup(group1)

        let groups = storage.getAllGroups()
        // Sorted ascending by createdAt - oldest first
        #expect(groups.first?.name == "First")
        #expect(groups.last?.name == "Second")
    }

    // MARK: - UserDefaultsProjectGroupStorage Tests

    @Test("UserDefaultsProjectGroupStorage - Save and retrieve groups")
    func userDefaultsSaveAndRetrieve() {
        guard let userDefaults = UserDefaults(suiteName: "test.projectgroups.save") else {
            return
        }
        userDefaults.removePersistentDomain(forName: "test.projectgroups.save")

        let storage = UserDefaultsProjectGroupStorage(
            userDefaults: userDefaults,
            groupsKey: "test_groups",
            selectedKey: "test_selected"
        )

        let group1 = ProjectGroup(name: "Work", projectIDs: ["proj1", "proj2"])
        let group2 = ProjectGroup(name: "Personal", projectIDs: ["proj3"])

        storage.saveGroup(group1)
        storage.saveGroup(group2)

        let groups = storage.getAllGroups()
        #expect(groups.count == 2)
        #expect(groups.contains { $0.id == group1.id && $0.name == "Work" })
        #expect(groups.contains { $0.id == group2.id && $0.name == "Personal" })
    }

    @Test("UserDefaultsProjectGroupStorage - Persistence across instances")
    func userDefaultsPersistence() {
        guard let userDefaults = UserDefaults(suiteName: "test.projectgroups.persistence") else {
            return
        }
        userDefaults.removePersistentDomain(forName: "test.projectgroups.persistence")

        let storage1 = UserDefaultsProjectGroupStorage(
            userDefaults: userDefaults,
            groupsKey: "test_groups",
            selectedKey: "test_selected"
        )

        let group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        storage1.saveGroup(group)

        // Create new instance pointing to same UserDefaults
        let storage2 = UserDefaultsProjectGroupStorage(
            userDefaults: userDefaults,
            groupsKey: "test_groups",
            selectedKey: "test_selected"
        )

        let groups = storage2.getAllGroups()
        #expect(groups.count == 1)
        #expect(groups.first?.id == group.id)
    }

    @Test("UserDefaultsProjectGroupStorage - Update group")
    func userDefaultsUpdateGroup() {
        guard let userDefaults = UserDefaults(suiteName: "test.projectgroups.update") else {
            return
        }
        userDefaults.removePersistentDomain(forName: "test.projectgroups.update")

        let storage = UserDefaultsProjectGroupStorage(
            userDefaults: userDefaults,
            groupsKey: "test_groups",
            selectedKey: "test_selected"
        )

        var group = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        storage.saveGroup(group)

        group.name = "Work Projects"
        group.projectIDs = ["proj1", "proj2"]
        storage.updateGroup(group)

        let groups = storage.getAllGroups()
        #expect(groups.count == 1)
        #expect(groups.first?.name == "Work Projects")
        #expect(groups.first?.projectIDs == ["proj1", "proj2"])
    }

    @Test("UserDefaultsProjectGroupStorage - Delete group")
    func userDefaultsDeleteGroup() {
        guard let userDefaults = UserDefaults(suiteName: "test.projectgroups.delete") else {
            return
        }
        userDefaults.removePersistentDomain(forName: "test.projectgroups.delete")

        let storage = UserDefaultsProjectGroupStorage(
            userDefaults: userDefaults,
            groupsKey: "test_groups",
            selectedKey: "test_selected"
        )

        let group1 = ProjectGroup(name: "Work", projectIDs: ["proj1"])
        let group2 = ProjectGroup(name: "Personal", projectIDs: ["proj2"])

        storage.saveGroup(group1)
        storage.saveGroup(group2)

        storage.deleteGroup(id: group1.id)

        let groups = storage.getAllGroups()
        #expect(groups.count == 1)
        #expect(groups.first?.id == group2.id)
    }
}
