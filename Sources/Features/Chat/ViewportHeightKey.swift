//
// ViewportHeightKey.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ViewportHeightKey

struct ViewportHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat = 800 // Fallback value
}

extension EnvironmentValues {
    var viewportHeight: CGFloat {
        get { self[ViewportHeightKey.self] }
        set { self[ViewportHeightKey.self] = newValue }
    }
}
