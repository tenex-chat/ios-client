//
// ProjectReviewStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct ProjectReviewStep: View {
    @ObservedObject var viewModel: CreateProjectViewModel

    var body: some View {
        List {
            Section(header: Text("Project Details")) {
                LabeledContent("Name", value: viewModel.projectName)
                LabeledContent("Description", value: viewModel.projectDescription)
                if !viewModel.projectTags.isEmpty {
                    LabeledContent("Tags", value: viewModel.projectTags)
                }
                if !viewModel.projectRepoURL.isEmpty {
                    LabeledContent("Repo", value: viewModel.projectRepoURL)
                }
            }

            Section(header: Text("Selected Agents")) {
                if viewModel.selectedAgentIDs.isEmpty {
                    Text("No agents selected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.availableAgents.filter { viewModel.selectedAgentIDs.contains($0.id) }) { agent in
                        Text(agent.name)
                    }
                }
            }

            Section(header: Text("Selected Tools")) {
                if viewModel.selectedToolIDs.isEmpty {
                    Text("No tools selected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.availableTools.filter { viewModel.selectedToolIDs.contains($0.id) }) { tool in
                        Text(tool.name)
                    }
                }
            }
        }
    }
}
