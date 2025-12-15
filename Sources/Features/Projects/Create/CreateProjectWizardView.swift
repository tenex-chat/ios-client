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

    public init(ndk: NDK, dataStore: DataStore) {
        _viewModel = State(wrappedValue: CreateProjectViewModel(ndk: ndk, dataStore: dataStore))
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            self.wizardContent
                .navigationTitle("New Project")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            self.dismiss()
                        }
                    }
                }
        }
    }

    // MARK: Private

    @State private var viewModel: CreateProjectViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk

    private var wizardContent: some View {
        VStack {
            self.stepIndicator
            self.stepTabView
            self.footerButtons
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 4) {
            StepIndicator(step: 0, currentStep: self.viewModel.currentStep, icon: "doc.text")
            StepConnector(isActive: self.viewModel.currentStep > 0)
            StepIndicator(step: 1, currentStep: self.viewModel.currentStep, icon: "person.2")
            StepConnector(isActive: self.viewModel.currentStep > 1)
            StepIndicator(
                step: 2,
                currentStep: self.viewModel.currentStep,
                icon: "hammer"
            )
            StepConnector(isActive: self.viewModel.currentStep > 2)
            StepIndicator(step: 3, currentStep: self.viewModel.currentStep, icon: "checkmark.circle")
        }
        .padding()
    }

    private var stepTabView: some View {
        TabView(selection: self.$viewModel.currentStep) {
            ProjectDetailsStep(viewModel: self.viewModel)
                .tag(0)
            AgentSelectionStep(viewModel: self.viewModel)
                .tag(1)
            MCPToolSelectionStep(viewModel: self.viewModel)
                .tag(2)
            ProjectReviewStep(viewModel: self.viewModel)
                .tag(3)
        }
        #if os(iOS)
        .tabViewStyle(.page(indexDisplayMode: .never))
        #endif
    }

    private var footerButtons: some View {
        HStack {
            if self.viewModel.currentStep > 0 {
                Button("Back") {
                    withAnimation {
                        self.viewModel.previousStep()
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            if self.viewModel.currentStep == 3 {
                Button("Create Project") {
                    Task {
                        if await self.viewModel.createProject() {
                            self.dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(self.viewModel.isPublishing)
            } else {
                Button("Next") {
                    withAnimation {
                        self.viewModel.nextStep()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!self.viewModel.canProceed)
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

    var isActive: Bool { self.currentStep >= self.step }
    var isCurrent: Bool { self.currentStep == self.step }

    var body: some View {
        ZStack {
            Circle()
                .fill(self.isActive ? Color.accentColor : Color.gray.opacity(0.3))
                .frame(width: 32, height: 32)

            Image(systemName: self.icon)
                .font(.headline.weight(.bold))
                .foregroundColor(self.isActive ? .white : .gray)
        }
    }
}

// MARK: - StepConnector

struct StepConnector: View {
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(self.isActive ? Color.accentColor : Color.gray.opacity(0.3))
            .frame(height: 2)
            .frame(maxWidth: .infinity)
    }
}
