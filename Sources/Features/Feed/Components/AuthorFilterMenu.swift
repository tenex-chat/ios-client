//
// AuthorFilterMenu.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - AuthorFilterMenu

/// Dropdown menu for filtering feed by author and grouping threads
struct AuthorFilterMenu: View {
    // MARK: Lifecycle

    init(
        selectedAuthor: Binding<String?>,
        groupThreads: Binding<Bool>,
        uniqueAuthors: [String],
        ndk: NDK
    ) {
        _selectedAuthor = selectedAuthor
        _groupThreads = groupThreads
        self.uniqueAuthors = uniqueAuthors
        self.ndk = ndk
    }

    // MARK: Internal

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            self.groupThreadsToggle
            Divider()
            self.allAuthorsButton
            self.authorsScrollView
        }
        .frame(width: 200)
        .background(.background)
    }

    // MARK: Private

    @Binding private var selectedAuthor: String?
    @Binding private var groupThreads: Bool

    private let uniqueAuthors: [String]
    private let ndk: NDK

    private var groupThreadsToggle: some View {
        Toggle("Group threads", isOn: self.$groupThreads)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var allAuthorsButton: some View {
        Button {
            self.selectedAuthor = nil
        } label: {
            HStack {
                Text("All Authors")
                    .font(.subheadline)

                Spacer()

                if self.selectedAuthor == nil {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var authorsScrollView: some View {
        if !self.uniqueAuthors.isEmpty {
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(self.uniqueAuthors, id: \.self) { pubkey in
                        AuthorFilterItem(
                            pubkey: pubkey,
                            isSelected: self.selectedAuthor == pubkey,
                            isCurrentUser: false,
                            ndk: self.ndk
                        ) {
                            self.selectedAuthor = pubkey
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
    }
}

// MARK: - AuthorFilterItem

/// Individual author item in the filter menu
struct AuthorFilterItem: View {
    // MARK: Lifecycle

    init(
        pubkey: String,
        isSelected: Bool,
        isCurrentUser: Bool,
        ndk: NDK,
        onSelect: @escaping () -> Void
    ) {
        self.pubkey = pubkey
        self.isSelected = isSelected
        self.isCurrentUser = isCurrentUser
        self.ndk = ndk
        self.onSelect = onSelect
    }

    // MARK: Internal

    var body: some View {
        Button {
            self.onSelect()
        } label: {
            HStack(spacing: 10) {
                NDKUIProfilePicture(ndk: self.ndk, pubkey: self.pubkey, size: 20)

                if self.isCurrentUser {
                    Text("You")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                } else {
                    NDKUIDisplayName(ndk: self.ndk, pubkey: self.pubkey)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }

                Spacer()

                if self.isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: Private

    private let pubkey: String
    private let isSelected: Bool
    private let isCurrentUser: Bool
    private let ndk: NDK
    private let onSelect: () -> Void
}
