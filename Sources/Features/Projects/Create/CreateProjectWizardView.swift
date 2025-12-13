//
// CreateProjectWizardView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - CreateProjectWizardView

public struct CreateProjectWizardView: View {
    // MARK: Lifecycle

    public init() {
        _viewModel = StateObject(wrappedValue: CreateProjectViewModel(ndk: NDK()))
    }

    init(ndk: NDK? = nil) {
        if let ndk {
            _viewModel = StateObject(wrappedValue: CreateProjectViewModel(ndk: ndk))
        } else {
            _viewModel = StateObject(
                wrappedValue: CreateProjectViewModel(ndk: NDK())
            )
        }
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            wizardContent
                .navigationTitle("New Project")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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

    private var wizardContent: some View {
        VStack {
            stepIndicator
            stepTabView
            footerButtons
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            StepIndicator(step: 0, currentStep: viewModel.currentStep, icon: "doc.text")
            StepConnector(isActive: viewModel.currentStep > 0)
            StepIndicator(step: 1, currentStep: viewModel.currentStep, icon: "person.2")
            StepConnector(isActive: viewModel.currentStep > 1)
            StepIndicator(
                step: 2,
                currentStep: viewModel.currentStep,
                icon: "hammer"
            )
            StepConnector(isActive: viewModel.currentStep > 2)
            StepIndicator(step: 3, currentStep: viewModel.currentStep, icon: "checkmark.circle")
        }
        .padding()
    }

    private var stepTabView: some View {
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
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private var footerButtons: some View {
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
