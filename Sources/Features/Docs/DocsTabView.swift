//
// DocsTabView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - DocsTabView

/// View displaying the list of project documents (kind 30023)
public struct DocsTabView: View {
    // MARK: Lifecycle

    /// Initialize the docs tab view
    /// - Parameters:
    ///   - projectID: The project identifier
    ///   - onDocumentClick: Optional callback when a document is tapped
    public init(projectID: String, onDocumentClick: ((NDKEvent) -> Void)? = nil) {
        self.projectID = projectID
        self.onDocumentClick = onDocumentClick
    }

    // MARK: Public

    public var body: some View {
        Group {
            if let ndk {
                contentView(ndk: ndk)
            } else {
                Text("NDK not available")
            }
        }
    }

    // MARK: Private

    @Environment(\.ndk) private var ndk
    @State private var viewModel: DocsTabViewModel?
    @State private var selectedDocument: NDKEvent?
    @State private var showingCreateSheet = false

    private let projectID: String
    private let onDocumentClick: ((NDKEvent) -> Void)?

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No documents yet")
                .font(.headline)

            Text("Create your first document to get started")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No results found")
                .font(.headline)

            Text("Try adjusting your search terms")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if let vm = viewModel {
                Button("Clear search") {
                    vm.searchQuery = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private func contentView(ndk: NDK) -> some View {
        let vm = viewModel ?? DocsTabViewModel(ndk: ndk, projectID: projectID)

        VStack(spacing: 0) {
            // Search bar - only show when there are documents
            if !vm.documents.isEmpty {
                DocsSearchBar(
                    searchQuery: Binding(
                        get: { vm.searchQuery },
                        set: { vm.searchQuery = $0 }
                    )
                )
            }

            // Document list or empty states
            if vm.documents.isEmpty {
                emptyView
                    .frame(maxHeight: .infinity)
            } else if vm.filteredDocuments.isEmpty {
                noResultsView
                    .frame(maxHeight: .infinity)
            } else {
                documentList(viewModel: vm, ndk: ndk)
            }
        }
        .task {
            if viewModel == nil {
                viewModel = vm
            }
            vm.subscribe()
        }
        .sheet(item: $selectedDocument) { document in
            DocumentDetailView(document: document, ndk: ndk)
        }
        .sheet(isPresented: $showingCreateSheet) {
            DocumentCreateView(ndk: ndk, projectID: projectID)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
    }

    private func documentList(viewModel: DocsTabViewModel, ndk: NDK) -> some View {
        List {
            ForEach(viewModel.filteredDocuments, id: \.id) { document in
                DocumentRow(document: document, ndk: ndk)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let callback = onDocumentClick {
                            callback(document)
                        } else {
                            selectedDocument = document
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - DocsSearchBar

/// Search bar for filtering documents
private struct DocsSearchBar: View {
    @Binding var searchQuery: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search documents...", text: $searchQuery)
                .textFieldStyle(.plain)

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

// MARK: - NDKEvent + @retroactive Identifiable

extension NDKEvent: @retroactive Identifiable {}
