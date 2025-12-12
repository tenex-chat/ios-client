//
//  TENEXApp.swift
//  TENEX
//

import SwiftUI
import TENEXCore
import TENEXFeatures

@main
struct TENEXApp: App {

    // MARK: - State

    @State private var appState = AppState()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
    }
}

// MARK: - App State

@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?

    struct User {
        let publicKey: String
        let displayName: String?
    }
}

// MARK: - Content View

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainView()
            } else {
                AuthenticationView()
            }
        }
    }
}

// MARK: - Placeholder Views

struct MainView: View {
    var body: some View {
        NavigationStack {
            Text("TENEX")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
    }
}

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
