//
//  TENEXApp.swift
//  TENEX
//

import SwiftUI

// MARK: - TENEXApp

@main
struct TENEXApp: App {
    // MARK: Internal

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }

    // MARK: Private

    // MARK: - State

    @State private var appState = AppState()
}

// MARK: - AppState

@Observable
final class AppState {
    struct User {
        let publicKey: String
        let displayName: String?
    }

    var isAuthenticated = false
    var currentUser: User?
}

// MARK: - ContentView

struct ContentView: View {
    // MARK: Internal

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                AuthenticationView()
            }
        }
    }

    // MARK: Private

    @Environment(AppState.self) private var appState
}

// MARK: - MainView

struct MainView: View {
    var body: some View {
        NavigationStack {
            Text("TENEX")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

// MARK: - AuthenticationView

struct AuthenticationView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("TENEX")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("AI Agent Orchestration")
                .foregroundStyle(.secondary)
        }
    }
}
