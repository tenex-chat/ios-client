//
// ProjectSettingsView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI
import TENEXCore

// MARK: - ProjectSettingsView

/// Main settings container with section navigation
public struct ProjectSettingsView: View {
    // MARK: Lifecycle

    /// Initialize the project settings view
    /// - Parameter project: The project to edit
    public init(project: Project) {
        self.project = project
    }

    // MARK: Public

    public var body: some View {
        if let ndk {
            settingsNavigationStack
        } else {
            Text("Error: NDK not available")
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @Environment(\.dismiss) private var dismiss

    private let project: Project

    private var viewModel: ProjectSettingsViewModel {
        guard let ndk else {
            fatalError("NDK not available")
        }
        return ProjectSettingsViewModel(project: project, ndk: ndk)
    }

    private var settingsNavigationStack: some View {
        NavigationStack {
            settingsList
                .navigationTitle("Project Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    private var settingsList: some View {
        List {
            generalSection
            projectConfigurationSection
            advancedSection
            dangerZoneSection
        }
    }

    private var generalSection: some View {
        Section("General") {
            NavigationLink {
                GeneralSettingsView(viewModel: viewModel)
            } label: {
                SettingsRow(
                    icon: "gear",
                    title: "General",
                    subtitle: "Name, description, basic info",
                    color: .gray
                )
            }
        }
    }

    private var projectConfigurationSection: some View {
        Section("Project Configuration") {
            NavigationLink {
                AgentsSettingsView(viewModel: viewModel)
            } label: {
                SettingsRow(
                    icon: "person.2",
                    title: "Agents",
                    subtitle: "Manage AI agents",
                    color: .blue
                )
            }

            NavigationLink {
                ToolsSettingsView(viewModel: viewModel)
            } label: {
                SettingsRow(
                    icon: "wrench.and.screwdriver",
                    title: "Tools",
                    subtitle: "MCP tools configuration",
                    color: .orange
                )
            }
        }
    }

    private var advancedSection: some View {
        Section("Advanced") {
            NavigationLink {
                AdvancedSettingsView()
            } label: {
                SettingsRow(
                    icon: "slider.horizontal.3",
                    title: "Advanced",
                    subtitle: "Relays and advanced settings",
                    color: .purple
                )
            }
        }
    }

    private var dangerZoneSection: some View {
        Section {
            NavigationLink {
                DangerZoneView(viewModel: viewModel)
            } label: {
                SettingsRow(
                    icon: "exclamationmark.triangle",
                    title: "Danger Zone",
                    subtitle: "Delete or archive project",
                    color: .red
                )
            }
        }
    }
}
