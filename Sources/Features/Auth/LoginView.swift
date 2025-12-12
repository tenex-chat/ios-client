//
// LoginView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - LoginView

/// Login screen for private key (nsec) authentication
public struct LoginView: View {
    // MARK: Lifecycle

    /// Initialize the login view
    /// - Parameter viewModel: The view model to use for login logic
    public init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }

    // MARK: Public

    public var body: some View {
        VStack(spacing: 32) {
            Spacer()
            brandingSection
            signInForm
            Spacer()
            helpText
        }
        .background(Color(red: 1.0, green: 1.0, blue: 1.0))
    }

    // MARK: Private

    @Bindable private var viewModel: LoginViewModel

    private var brandingSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("TENEX")
                .font(.system(size: 48, weight: .bold))

            Text("AI Agent Orchestration")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 24)
    }

    private var signInForm: some View {
        VStack(spacing: 16) {
            nsecInputField
            errorMessage
            signInButton
        }
        .padding(.horizontal, 32)
    }

    private var nsecInputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Private Key")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            SecureField("nsec1...", text: $viewModel.nsecInput)
                .textContentType(.password)
            #if os(iOS)
                .textInputAutocapitalization(.never)
            #endif
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .padding()
                .background(Color(red: 0.95, green: 0.95, blue: 0.97))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            viewModel.errorMessage != nil ? Color.red : Color.clear,
                            lineWidth: 1
                        )
                )
        }
    }

    @ViewBuilder private var errorMessage: some View {
        if let errorMessage = viewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)

                Text(errorMessage)
                    .font(.caption)
            }
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var signInButton: some View {
        Button {
            Task {
                await viewModel.signIn()
            }
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }

                Text(viewModel.isLoading ? "Signing In..." : "Sign In")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isValidInput && !viewModel.isLoading ? Color.blue : Color.gray)
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(!viewModel.isValidInput || viewModel.isLoading)
    }

    private var helpText: some View {
        VStack(spacing: 8) {
            Text("Don't have a private key?")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("You can generate one using a Nostr client or key manager.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 24)
    }
}
