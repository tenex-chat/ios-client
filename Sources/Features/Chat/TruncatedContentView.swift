//
// TruncatedContentView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ContentHeightPreferenceKey

/// Preference key for measuring content height
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - TruncatedContentView

/// Wraps content and truncates it with fade gradient if exceeds maxHeight
struct TruncatedContentView<Content: View>: View {
    // MARK: Lifecycle

    init(content: Content, maxHeight: CGFloat) {
        self.content = content
        self.maxHeight = maxHeight
    }

    // MARK: Internal

    var body: some View {
        ZStack(alignment: .bottom) {
            self.content
                .frame(maxHeight: self.isTruncated ? self.maxHeight : nil, alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    if self.isTruncated {
                        self.fadeGradient
                    }
                }
                .background(self.heightReader)
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    self.contentHeight = height
                }

            if self.isTruncated {
                self.showMoreButton
            }
        }
    }

    // MARK: Private

    @State private var contentHeight: CGFloat = 0
    @State private var isShowingSheet = false

    private let content: Content
    private let maxHeight: CGFloat

    private var isTruncated: Bool {
        self.contentHeight > self.maxHeight
    }

    private var fadeGradient: some View {
        LinearGradient(
            colors: [.clear, Color(uiColor: .systemBackground)],
            startPoint: .init(x: 0.5, y: 0.7),
            endPoint: .bottom
        )
        .frame(height: self.maxHeight * 0.3)
        .allowsHitTesting(false)
    }

    private var heightReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ContentHeightPreferenceKey.self,
                value: geo.size.height
            )
        }
    }

    private var showMoreButton: some View {
        Button {
            self.isShowingSheet = true
        } label: {
            Text("Show more")
                .font(.subheadline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(8)
        }
        .padding(.bottom, 8)
    }
}
