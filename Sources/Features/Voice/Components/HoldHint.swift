//
// HoldHint.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

struct HoldHint: View {
    // MARK: Lifecycle

    init(isVisible: Bool) {
        self.isVisible = isVisible
    }

    // MARK: Internal

    let isVisible: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.fill")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))

            Text("Release when done")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
        .opacity(self.isVisible ? 1 : 0)
        .scaleEffect(self.isVisible ? 1 : 0.8)
        .animation(.easeIn(duration: 0.2), value: self.isVisible)
    }
}

#Preview {
    VStack(spacing: 40) {
        HoldHint(isVisible: false)
        HoldHint(isVisible: true)
    }
    .padding()
    .background(Color.black)
}
