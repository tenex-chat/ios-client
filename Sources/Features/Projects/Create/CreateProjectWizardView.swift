//
// CreateProjectWizardView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - CreateProjectWizardView

public struct CreateProjectWizardView: View {
    // MARK: Lifecycle

    public init() {
        _viewModel = StateObject(wrappedValue: CreateProjectViewModel(ndk: NDK(
            publicKey: "",
            privateKey: nil,
            relays: []
        )))
    }

    init(ndk: NDK? = nil) {
        if let ndk {
            _viewModel = StateObject(wrappedValue: CreateProjectViewModel(ndk: ndk))
        } else {
            _viewModel = StateObject(
                wrappedValue: CreateProjectViewModel(ndk: NDK(publicKey: "", privateKey: nil, relays: []))
            )
        }
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            VStack {
                // Step Indicator
                HStack(spacing: 4) {
                    StepIndicator(step: 0, currentStep: viewModel.currentStep, icon: "doc.text")
                    StepConnector(isActive: viewModel.currentStep > 0)
                    StepIndicator(step: 1, currentStep: viewModel.currentStep, icon: "person.2")
                    StepConnector(isActive: viewModel.currentStep > 1)
                    StepIndicator(step: 2, currentStep: viewModel.currentStep,
                                  icon: "hammer") // Using hammer as wrench alternative
                    StepConnector(isActive: viewModel.currentStep > 2)
                    StepIndicator(step: 3, currentStep: viewModel.currentStep, icon: "checkmark.circle")
                }
                .padding()

                // Content
                TabView(selection: $viewModel.currentStep) {
                    ProjectDetailsStep(viewModel: viewModel)
                        .tag(0)
                    AgentSelectionStep(viewModel: viewModel)
                        .tag(1)
                    MCPToolSelectionStep(viewModel: viewModel)
                        .tag(2)
                    ProjectReviewStep(viewModel: viewModel)
                        .tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // Disable swipe gesture to enforce button navigation if needed,
                // but standard swipe is often fine.

                // Footer
                HStack {
                    if viewModel.currentStep > 0 {
                        Button("Back") {
                            withAnimation {
                                viewModel.previousStep()
                            }
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if viewModel.currentStep == 3 {
                        Button("Create Project") {
                            Task {
                                if await viewModel.createProject() {
                                    dismiss()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isPublishing)
                    } else {
                        Button("Next") {
                            withAnimation {
                                viewModel.nextStep()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!viewModel.canProceed)
                    }
                }
                .padding()
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @StateObject private var viewModel: CreateProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk
}

// MARK: - StepIndicator

struct StepIndicator: View {
    let step: Int
    let currentStep: Int
    let icon: String

    var isActive: Bool { currentStep >= step }
    var isCurrent: Bool { currentStep == step }

    var body: some View {
        ZStack {
            Circle()
                .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)

            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(isActive ? .white : .gray)
        }
    }
}

// MARK: - StepConnector

struct StepConnector: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}
