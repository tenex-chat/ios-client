//
// DocumentDiffView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI
import TENEXCore

// MARK: - DocumentDiffView

/// Visual diff view comparing two document versions
public struct DocumentDiffView: View {
    // MARK: Lifecycle

    public init(oldDocument: Document, newDocument: Document) {
        self.oldDocument = oldDocument
        self.newDocument = newDocument
    }

    // MARK: Public

    public var body: some View {
        Group {
            if isLoading {
                loadingView
            } else {
                diffContent
            }
        }
        .task(id: "\(oldDocument.id)-\(newDocument.id)") {
            await computeDiff()
        }
    }

    // MARK: Private

    private let oldDocument: Document
    private let newDocument: Document

    @State private var diffLines: [DiffLine] = []
    @State private var stats: DiffStats?
    @State private var isLoading = true

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Computing diff...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var diffContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            statsHeader
            Divider()
            diffScrollView
        }
    }

    @ViewBuilder
    private var statsHeader: some View {
        if let stats {
            HStack(spacing: 16) {
                Label("\(stats.additions)", systemImage: "plus.circle.fill")
                    .foregroundStyle(.green)

                Label("\(stats.deletions)", systemImage: "minus.circle.fill")
                    .foregroundStyle(.red)

                Spacer()

                Text("\(stats.totalChanges) changes")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding()
            .background(Color(.secondarySystemBackground))
        }
    }

    private var diffScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diffLines) { line in
                    DiffLineView(line: line)
                }
            }
        }
    }

    private func computeDiff() async {
        isLoading = true
        defer { isLoading = false }

        diffLines = await DocumentDiff.computeAsync(
            old: oldDocument.content,
            new: newDocument.content
        )
        stats = DocumentDiff.stats(from: diffLines)
    }
}

// MARK: - DiffLineView

/// Single line in the diff view
private struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 0) {
            lineNumbers
            prefixText
            contentText
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(backgroundColor)
    }

    private var lineNumbers: some View {
        HStack(spacing: 0) {
            Text(line.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 32, alignment: .trailing)
                .foregroundStyle(.secondary)

            Text(line.newLineNumber.map { String($0) } ?? "")
                .frame(width: 32, alignment: .trailing)
                .foregroundStyle(.secondary)
        }
        .font(.caption.monospaced())
        .padding(.trailing, 8)
    }

    private var prefixText: some View {
        Text(prefix)
            .font(.body.monospaced())
            .foregroundStyle(prefixColor)
            .frame(width: 16)
    }

    private var contentText: some View {
        Text(line.content)
            .font(.body.monospaced())
            .lineLimit(1)
    }

    private var prefix: String {
        switch line.type {
        case .added:
            "+"
        case .removed:
            "-"
        case .unchanged:
            " "
        }
    }

    private var prefixColor: Color {
        switch line.type {
        case .added:
            .green
        case .removed:
            .red
        case .unchanged:
            .primary
        }
    }

    private var backgroundColor: Color {
        switch line.type {
        case .added:
            Color.green.opacity(0.15)
        case .removed:
            Color.red.opacity(0.15)
        case .unchanged:
            .clear
        }
    }
}

// MARK: - DocumentVersionPickerView

/// Picker for selecting a version to compare against
public struct DocumentVersionPickerView: View {
    // MARK: Lifecycle

    public init(
        versions: [Document],
        selectedVersion: Binding<Document?>,
        currentVersion: Document
    ) {
        self.versions = versions
        self._selectedVersion = selectedVersion
        self.currentVersion = currentVersion
    }

    // MARK: Public

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compare with previous version:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(previousVersions) { version in
                        versionButton(version)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: Private

    private let versions: [Document]
    private let currentVersion: Document
    @Binding private var selectedVersion: Document?

    private var previousVersions: [Document] {
        versions.filter { $0.id != currentVersion.id }
    }

    private func versionButton(_ version: Document) -> some View {
        let isSelected = selectedVersion?.id == version.id

        return Button {
            if isSelected {
                selectedVersion = nil
            } else {
                selectedVersion = version
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(version.createdAt, style: .date)
                    .font(.subheadline.weight(.medium))

                Text(version.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.tertiarySystemBackground))
            .foregroundStyle(isSelected ? .white : .primary)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
