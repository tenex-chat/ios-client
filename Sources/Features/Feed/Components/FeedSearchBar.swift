//
// FeedSearchBar.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - FeedSearchBar

/// Search bar component for the feed tab with author filtering
struct FeedSearchBar: View {
    // MARK: Lifecycle

    init(
        searchQuery: Binding<String>,
        selectedAuthor: Binding<String?>,
        groupThreads: Binding<Bool>,
        uniqueAuthors: [String],
        ndk: NDK
    ) {
        _searchQuery = searchQuery
        _selectedAuthor = selectedAuthor
        _groupThreads = groupThreads
        self.uniqueAuthors = uniqueAuthors
        self.ndk = ndk
    }

    // MARK: Internal

    var body: some View {
        HStack(spacing: 8) {
            searchTextField
            filterButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.background)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: Private

    @Binding private var searchQuery: String
    @Binding private var selectedAuthor: String?
    @Binding private var groupThreads: Bool
    @State private var showFilterMenu = false

    private let uniqueAuthors: [String]
    private let ndk: NDK

    private var searchTextField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            TextField("Search events, titles, subjects, hashtags...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 15))

            clearSearchButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.12))
        .cornerRadius(10)
    }

    @ViewBuilder private var clearSearchButton: some View {
        if !searchQuery.isEmpty {
            Button {
                searchQuery = ""
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var filterButton: some View {
        Button {
            showFilterMenu = true
        } label: {
            filterButtonContent
        }
        .frame(width: 36, height: 36)
        .background(selectedAuthor != nil ? Color.clear : Color.gray.opacity(0.12))
        .cornerRadius(8)
        .popover(isPresented: $showFilterMenu) {
            AuthorFilterMenu(
                selectedAuthor: $selectedAuthor,
                groupThreads: $groupThreads,
                uniqueAuthors: uniqueAuthors,
                ndk: ndk
            )
            .presentationCompactAdaptation(.popover)
        }
    }

    @ViewBuilder private var filterButtonContent: some View {
        if let author = selectedAuthor {
            NDKUIProfilePicture(ndk: ndk, pubkey: author, size: 28)
        } else {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 20))
                .foregroundStyle(.blue)
        }
    }
}
