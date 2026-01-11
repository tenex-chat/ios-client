//
// DocumentDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - DocumentDetailView

/// Full-screen view for reading a document with markdown rendering and version history
public struct DocumentDetailView: View {
    // MARK: Lifecycle

    public init(document: NDKEvent, ndk: NDK) {
        self.event = document
        self.ndk = ndk
        self.document = Document.from(event: document)
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showDiff, let selectedVersion, let document {
                    diffView(comparing: selectedVersion, to: document)
                } else {
                    documentContent
                }
            }
            .navigationTitle(title)
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { toolbarItems }
                .sheet(isPresented: $showVersionHistory) {
                    versionHistorySheet
                }
                .task {
                    await loadVersions()
                }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss

    private let event: NDKEvent
    private let ndk: NDK
    private let document: Document?

    @State private var versionStore: DocumentVersionStore?
    @State private var selectedVersion: Document?
    @State private var showVersionHistory = false
    @State private var showDiff = false

    private var title: String {
        document?.title ?? event.tagValue("title") ?? event.tagValue("name") ?? "Untitled"
    }

    private var summary: String? {
        document?.summary ?? event.tagValue("summary")
    }

    private var hashtags: [String] {
        document?.hashtags ?? event.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .map { String($0) }
    }

    private var readingTime: String {
        if let document {
            return "\(document.readingTimeMinutes) min read"
        }
        let words = event.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .count
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(minutes) min read"
    }

    private var shareText: String {
        if let encoded = try? event.encode() {
            return "nostr:\(encoded)"
        }
        return "nostr:nevent1\(event.id)"
    }

    private var hasVersions: Bool {
        versionStore?.hasMultipleVersions ?? false
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") {
                dismiss()
            }
        }

        ToolbarItem(placement: .primaryAction) {
            Menu {
                ShareLink(
                    item: shareText,
                    subject: Text(title),
                    message: Text(summary ?? "")
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                if hasVersions {
                    Button {
                        showVersionHistory = true
                    } label: {
                        Label("Version History", systemImage: "clock.arrow.circlepath")
                    }
                }

                if showDiff {
                    Button {
                        withAnimation {
                            showDiff = false
                            selectedVersion = nil
                        }
                    } label: {
                        Label("Hide Changes", systemImage: "eye.slash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private var documentContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection
                versionIndicator
                Divider()
                contentSection
            }
            .padding()
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorInfoRow
            summaryText
            hashtagsRow
        }
    }

    private var authorInfoRow: some View {
        HStack(spacing: 10) {
            NDKUIProfilePicture(ndk: ndk, pubkey: event.pubkey, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(ndk.profile(for: event.pubkey).displayName)
                    .font(.subheadline.weight(.medium))
                authorMetadataRow
            }
        }
    }

    private var authorMetadataRow: some View {
        HStack(spacing: 8) {
            Text(Date(timeIntervalSince1970: TimeInterval(event.createdAt)), style: .date)
            Text("·")
            Text(readingTime)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var versionIndicator: some View {
        if let versionStore, versionStore.hasMultipleVersions {
            Button {
                showVersionHistory = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                    Text("\(versionStore.versionCount) versions")
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var summaryText: some View {
        if let summary, !summary.isEmpty {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
        }
    }

    @ViewBuilder
    private var hashtagsRow: some View {
        if !hashtags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(hashtags, id: \.self) { tag in
                    hashtagPill(tag)
                }
            }
        }
    }

    private var contentSection: some View {
        NDKMarkdown(content: event.content)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hashtagPill(_ tag: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "number")
                .font(.caption)
            Text(tag)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func diffView(comparing oldVersion: Document, to newVersion: Document) -> some View {
        VStack(spacing: 0) {
            diffHeader(oldVersion: oldVersion, newVersion: newVersion)
            Divider()
            DocumentDiffView(oldDocument: oldVersion, newDocument: newVersion)
        }
    }

    private func diffHeader(oldVersion: Document, newVersion: Document) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Comparing versions")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    withAnimation {
                        showDiff = false
                        selectedVersion = nil
                    }
                }
                .font(.subheadline)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("From")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(oldVersion.createdAt, style: .date)
                        .font(.subheadline)
                }

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("To")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(newVersion.createdAt, style: .date)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    private var versionHistorySheet: some View {
        NavigationStack {
            versionHistoryList
                .navigationTitle("Version History")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            showVersionHistory = false
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var versionHistoryList: some View {
        if let versionStore {
            List {
                ForEach(versionStore.versions) { version in
                    versionRow(version)
                }
            }
        } else {
            ContentUnavailableView(
                "No Versions",
                systemImage: "clock.arrow.circlepath",
                description: Text("Version history is not available")
            )
        }
    }

    private func versionRow(_ version: Document) -> some View {
        let isCurrent = version.id == document?.id

        return Button {
            if !isCurrent, let document {
                selectedVersion = version
                showDiff = true
                showVersionHistory = false
            }
        } label: {
            versionRowContent(version: version, isCurrent: isCurrent)
        }
        .buttonStyle(.plain)
        .disabled(isCurrent)
    }

    private func versionRowContent(version: Document, isCurrent: Bool) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(version.createdAt, style: .date)
                        .font(.subheadline.weight(.medium))
                    if isCurrent {
                        currentVersionBadge
                    }
                }
                Text(version.createdAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let summary = version.summary, !summary.isEmpty {
                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            if !isCurrent {
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var currentVersionBadge: some View {
        Text("Current")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(4)
    }

    private func loadVersions() async {
        guard let document else {
            return
        }

        let store = DocumentVersionStore(ndk: ndk, document: document)
        versionStore = store
        await store.fetchVersions()
    }
}

// MARK: - FlowLayout

/// A flow layout that wraps items to the next line when they don't fit
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            let position = CGPoint(
                x: bounds.minX + frame.origin.x,
                y: bounds.minY + frame.origin.y
            )
            subviews[index].place(at: position, proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
