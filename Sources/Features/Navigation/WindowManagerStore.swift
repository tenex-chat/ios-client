//
// WindowManagerStore.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import Foundation
import SwiftUI

// MARK: - ConversationWindow

/// Represents a conversation window (drawer or detached)
public struct ConversationWindow: Identifiable, Codable, Hashable {
    // MARK: Lifecycle

    public init(
        projectID: String,
        threadID: String,
        title: String,
        id: String = UUID().uuidString,
        isDetached: Bool = false,
        position: CGPoint? = nil,
        size: CGSize? = nil,
        zIndex: Int = 0
    ) {
        self.id = id
        self.projectID = projectID
        self.threadID = threadID
        self.title = title
        self.isDetached = isDetached
        self.position = position
        self.size = size
        self.zIndex = zIndex
    }

    // MARK: Public

    /// Unique identifier for the window
    public let id: String

    /// Project this conversation belongs to
    public let projectID: String

    /// Thread ID for the conversation
    public let threadID: String

    /// Display title for the window
    public let title: String

    /// Whether this window is detached (separate macOS window) or drawer
    public var isDetached: Bool

    /// Window position (for detached windows only)
    public var position: CGPoint?

    /// Window size (for detached windows only)
    public var size: CGSize?

    /// Z-index for focus/stacking order (higher = on top)
    public var zIndex: Int
}

// MARK: - WindowManagerStore

/// Manages conversation windows (drawer + detached)
@MainActor
@Observable
public final class WindowManagerStore {
    // MARK: Lifecycle

    /// Initialize the store and load persisted state
    public init() {
        let loadedWindows = Self.loadFromUserDefaults()
        windows = loadedWindows
        nextZIndex = (loadedWindows.map(\.zIndex).max() ?? 0) + 1
    }

    // MARK: Public

    /// All conversation windows (drawer + detached)
    public private(set) var windows: [ConversationWindow] {
        didSet {
            Self.saveToUserDefaults(windows.filter { $0.isDetached })
        }
    }

    /// Drawer width in points (persisted separately)
    public var drawerWidth: CGFloat {
        get {
            UserDefaults.standard.object(forKey: Self.drawerWidthKey) as? CGFloat ?? 600
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.drawerWidthKey)
        }
    }

    // MARK: - Computed Properties

    /// The active drawer window (highest z-index non-detached window)
    public var activeDrawer: ConversationWindow? {
        windows
            .filter { !$0.isDetached }
            .max { $0.zIndex < $1.zIndex }
    }

    /// All detached windows
    public var detachedWindows: [ConversationWindow] {
        windows.filter { $0.isDetached }
    }

    // MARK: - Operations

    /// Open a conversation in the drawer
    /// - Parameters:
    ///   - projectID: The project ID
    ///   - threadID: The thread ID
    ///   - title: Display title
    /// - Returns: The window ID
    @discardableResult
    public func openDrawer(projectID: String, threadID: String, title: String) -> String {
        // If already open as drawer, bring to front
        if let existing = windows.first(where: { $0.threadID == threadID && !$0.isDetached }) {
            focus(existing.id)
            return existing.id
        }

        // If open as detached window, don't open drawer
        if windows.contains(where: { $0.threadID == threadID && $0.isDetached }) {
            return ""
        }

        let window = ConversationWindow(
            projectID: projectID,
            threadID: threadID,
            title: title,
            isDetached: false,
            zIndex: nextZIndex
        )
        nextZIndex += 1
        windows.append(window)
        return window.id
    }

    /// Close a window (drawer or detached)
    /// - Parameter windowID: The window ID to close
    public func close(_ windowID: String) {
        windows.removeAll { $0.id == windowID }
    }

    /// Detach a drawer to a separate window
    /// - Parameter windowID: The window ID to detach
    public func detach(_ windowID: String) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else {
            return
        }

        var window = windows[index]
        window.isDetached = true
        window.position = CGPoint(x: 100, y: 100) // Default position
        window.size = CGSize(width: 800, height: 600) // Default size
        windows[index] = window
    }

    /// Attach a detached window back to the drawer
    /// - Parameter windowID: The window ID to attach
    public func attach(_ windowID: String) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else {
            return
        }

        var window = windows[index]
        window.isDetached = false
        window.position = nil
        window.size = nil
        window.zIndex = nextZIndex
        nextZIndex += 1
        windows[index] = window
    }

    /// Focus a window (bring to front)
    /// - Parameter windowID: The window ID to focus
    public func focus(_ windowID: String) {
        guard let index = windows.firstIndex(where: { $0.id == windowID }) else {
            return
        }

        windows[index].zIndex = nextZIndex
        nextZIndex += 1
    }

    /// Update window position (for detached windows)
    /// - Parameters:
    ///   - windowID: The window ID
    ///   - position: New position
    public func updatePosition(_ windowID: String, position: CGPoint) {
        guard let index = windows.firstIndex(where: { $0.id == windowID && $0.isDetached }) else {
            return
        }

        windows[index].position = position
    }

    /// Update window size (for detached windows)
    /// - Parameters:
    ///   - windowID: The window ID
    ///   - size: New size
    public func updateSize(_ windowID: String, size: CGSize) {
        guard let index = windows.firstIndex(where: { $0.id == windowID && $0.isDetached }) else {
            return
        }

        windows[index].size = size
    }

    /// Get a window by ID
    /// - Parameter windowID: The window ID
    /// - Returns: The window, if found
    public func window(for windowID: String) -> ConversationWindow? {
        windows.first { $0.id == windowID }
    }

    // MARK: Private

    private var nextZIndex: Int

    // MARK: - Persistence

    private static let userDefaultsKey = "tenex.conversationWindows"
    private static let drawerWidthKey = "tenex.drawerWidth"

    /// Load detached windows from UserDefaults
    private static func loadFromUserDefaults() -> [ConversationWindow] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let windows = try? JSONDecoder().decode([ConversationWindow].self, from: data)
        else {
            return []
        }
        // Only restore detached windows (drawers are ephemeral)
        return windows.filter { $0.isDetached }
    }

    /// Save detached windows to UserDefaults
    private static func saveToUserDefaults(_ windows: [ConversationWindow]) {
        // Only persist detached windows
        let detachedWindows = windows.filter { $0.isDetached }
        if let data = try? JSONEncoder().encode(detachedWindows) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

// MARK: - CGPoint + Codable

extension CGPoint: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// MARK: - CGSize + Codable

extension CGSize: @retroactive Codable {
    enum CodingKeys: String, CodingKey {
        case width
        case height
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let width = try container.decode(CGFloat.self, forKey: .width)
        let height = try container.decode(CGFloat.self, forKey: .height)
        self.init(width: width, height: height)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
    }
}
