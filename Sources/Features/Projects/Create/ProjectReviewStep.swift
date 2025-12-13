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
                if !viewModel.projectRepoUrl.isEmpty {
                    LabeledContent("Repo", value: viewModel.projectRepoUrl)
                }
            }

            Section(header: Text("Selected Agents")) {
                if viewModel.selectedAgentIds.isEmpty {
                    Text("No agents selected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.availableAgents.filter { viewModel.selectedAgentIds.contains($0.id) }) { agent in
                        Text(agent.name)
                    }
                }
            }

            Section(header: Text("Selected Tools")) {
                if viewModel.selectedToolIds.isEmpty {
                    Text("No tools selected")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.availableTools.filter { viewModel.selectedToolIds.contains($0.id) }) { tool in
                        Text(tool.name)
                    }
                }
            }
        }
    }
}
