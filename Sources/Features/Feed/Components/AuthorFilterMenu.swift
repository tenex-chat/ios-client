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
            groupThreadsToggle
            Divider()
            allAuthorsButton
            authorsScrollView
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
        Toggle("Group threads", isOn: $groupThreads)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
    }

    private var allAuthorsButton: some View {
        Button {
            selectedAuthor = nil
        } label: {
            HStack {
                Text("All Authors")
                    .font(.system(size: 14))

                Spacer()

                if selectedAuthor == nil {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
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
        if !uniqueAuthors.isEmpty {
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(uniqueAuthors, id: \.self) { pubkey in
                        AuthorFilterItem(
                            pubkey: pubkey,
                            isSelected: selectedAuthor == pubkey,
                            isCurrentUser: false,
                            ndk: ndk
                        ) {
                            selectedAuthor = pubkey
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
            onSelect()
        } label: {
            HStack(spacing: 10) {
                NDKUIProfilePicture(ndk: ndk, pubkey: pubkey, size: 20)

                Text(displayName)
                    .font(.system(size: 14))
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .task {
            await loadMetadata()
        }
    }

    // MARK: Private

    @State private var metadata: NDKUserMetadata?

    private let pubkey: String
    private let isSelected: Bool
    private let isCurrentUser: Bool
    private let ndk: NDK
    private let onSelect: () -> Void

    private var displayName: String {
        if isCurrentUser {
            return "You"
        }

        if let displayName = metadata?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = metadata?.name, !name.isEmpty {
            return name
        }
        return String(pubkey.prefix(8)) + "..."
    }

    private func loadMetadata() async {
        for await meta in await ndk.profileManager.subscribe(for: pubkey) {
            metadata = meta
        }
    }
}
