//
// FeedTabViewFactory.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import NDKSwiftCore
import SwiftUI

// MARK: - FeedTabViewFactory

/// Factory for creating FeedTabView with all required dependencies
/// This makes it easier to instantiate the view hierarchy without exposing internal dependencies
@MainActor
public enum FeedTabViewFactory {
    // MARK: Public

    /// Create a FeedTabView with all dependencies properly configured
    /// - Parameters:
    ///   - ndk: The NDK instance for network operations
    ///   - projectID: The project identifier
    ///   - onEventClick: Optional callback when an event is tapped
    /// - Returns: A configured FeedTabView
    public static func create(
        ndk: NDK,
        projectID: String,
        onEventClick: ((NDKEvent) -> Void)? = nil
    ) -> FeedTabView {
        // Create service layer
        let service = FeedService(ndk: ndk)

        // Create view model
        let viewModel = FeedTabViewModel(service: service, projectID: projectID)

        // Create and return view
        return FeedTabView(viewModel: viewModel, onEventClick: onEventClick)
    }

    /// Create a FeedTabView with a mock service for testing/previews
    /// - Parameters:
    ///   - projectID: The project identifier
    ///   - mockEvents: Mock events to display
    ///   - shouldFail: Whether the mock service should simulate failure
    ///   - onEventClick: Optional callback when an event is tapped
    /// - Returns: A configured FeedTabView with mock data
    public static func createMock(
        projectID: String,
        mockEvents: [NDKEvent] = [],
        shouldFail: Bool = false,
        onEventClick: ((NDKEvent) -> Void)? = nil
    ) -> FeedTabView {
        // Create mock service
        let mockService = MockFeedService()
        mockService.shouldFail = shouldFail
        mockService.mockEvents = mockEvents

        // Create view model
        let viewModel = FeedTabViewModel(service: mockService, projectID: projectID)

        // Create and return view
        return FeedTabView(viewModel: viewModel, onEventClick: onEventClick)
    }
}
