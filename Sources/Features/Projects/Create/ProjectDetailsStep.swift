//
// ProjectDetailsStep.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct ProjectDetailsStep: View {
    @Bindable var viewModel: CreateProjectViewModel

    var body: some View {
        Form {
            Section(header: Text("Project Details")) {
                TextField("Project Name", text: $viewModel.projectName)
                TextField("Description", text: $viewModel.projectDescription, axis: .vertical)
                    .lineLimit(3 ... 6)
            }

            Section(header: Text("Optional")) {
                TextField("Tags (space separated)", text: $viewModel.projectTags)
                TextField("Image URL", text: $viewModel.projectImageURL)
                #if os(iOS)
                    .keyboardType(.URL)
                #endif
                TextField("Repository URL", text: $viewModel.projectRepoURL)
                #if os(iOS)
                    .keyboardType(.URL)
                #endif
            }
        }
    }
}
