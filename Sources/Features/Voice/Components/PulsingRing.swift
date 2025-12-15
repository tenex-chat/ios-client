//
// PulsingRing.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - PulsingRing

struct PulsingRing: View {
    // MARK: Lifecycle

    init(delay: Double, color: Color, size: CGFloat = 70) {
        self.delay = delay
        self.color = color
        self.size = size
    }

    // MARK: Internal

    @State var scale: CGFloat = 0.8
    @State var opacity = 0.3

    let delay: Double
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .stroke(self.color.opacity(self.opacity), lineWidth: 2)
            .frame(width: self.size, height: self.size)
            .scaleEffect(self.scale)
            .onAppear {
                if !self.reduceMotion {
                    withAnimation(
                        .easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: false)
                            .delay(self.delay)
                    ) {
                        self.scale = 1.2
                        self.opacity = 0
                    }
                } else {
                    self.opacity = 0.15
                }
            }
    }

    // MARK: Private

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
}

// MARK: - PulsingRings

struct PulsingRings: View {
    // MARK: Lifecycle

    init(color: Color, size: CGFloat = 70) {
        self.color = color
        self.size = size
    }

    // MARK: Internal

    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            PulsingRing(delay: 0.0, color: self.color, size: self.size + 30)
            PulsingRing(delay: 0.5, color: self.color, size: self.size + 60)
            PulsingRing(delay: 1.0, color: self.color, size: self.size + 90)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()

        VStack(spacing: 100) {
            ZStack {
                PulsingRings(color: .blue)

                Circle()
                    .fill(Color.blue)
                    .frame(width: 70, height: 70)
            }

            ZStack {
                PulsingRings(color: .green, size: 100)

                Circle()
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
            }
        }
    }
}
