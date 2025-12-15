//
// DocumentDetailView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI

// MARK: - DocumentDetailView

/// Full-screen view for reading a document with markdown rendering
public struct DocumentDetailView: View {
    // MARK: Lifecycle

    public init(document: NDKEvent, ndk: NDK) {
        self.document = document
        self.ndk = ndk
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.headerSection
                    Divider()
                    self.contentSection
                }
                .padding()
            }
            .navigationTitle(self.title)
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            self.dismiss()
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(
                            item: self.shareText,
                            subject: Text(self.title),
                            message: Text(self.summary ?? "")
                        )
                    }
                }
        }
        .task {
            await self.loadAuthorMetadata()
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var metadata: NDKUserMetadata?

    private let document: NDKEvent
    private let ndk: NDK

    private var title: String {
        self.document.tagValue("title") ?? self.document.tagValue("name") ?? "Untitled"
    }

    private var summary: String? {
        self.document.tagValue("summary")
    }

    private var authorName: String {
        if let displayName = metadata?.displayName, !displayName.isEmpty {
            return displayName
        }
        if let name = metadata?.name, !name.isEmpty {
            return name
        }
        return String(self.document.pubkey.prefix(8)) + "..."
    }

    private var hashtags: [String] {
        self.document.tags(withName: "t")
            .compactMap { $0[safe: 1] }
            .map { String($0) }
    }

    private var readingTime: String {
        let words = self.document.content
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .count
        let minutes = max(1, Int(ceil(Double(words) / 200.0)))
        return "\(minutes) min read"
    }

    private var shareText: String {
        if let encoded = try? document.encode() {
            return "nostr:\(encoded)"
        }
        return "nostr:nevent1\(self.document.id)"
    }

    private var markdownText: AttributedString {
        do {
            return try AttributedString(markdown: self.document.content)
        } catch {
            return AttributedString(self.document.content)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            self.authorInfoRow
            self.summaryText
            self.hashtagsRow
        }
    }

    private var authorInfoRow: some View {
        HStack(spacing: 10) {
            NDKUIProfilePicture(ndk: self.ndk, pubkey: self.document.pubkey, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(self.authorName)
                    .font(.subheadline.weight(.medium))
                self.authorMetadataRow
            }
        }
    }

    private var authorMetadataRow: some View {
        HStack(spacing: 8) {
            Text(Date(timeIntervalSince1970: TimeInterval(self.document.createdAt)), style: .date)
            Text("·")
            Text(self.readingTime)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder private var summaryText: some View {
        if let summary, !summary.isEmpty {
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .italic()
        }
    }

    @ViewBuilder private var hashtagsRow: some View {
        if !self.hashtags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(self.hashtags, id: \.self) { tag in
                    self.hashtagPill(tag)
                }
            }
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if self.document.content.contains("```") {
                self.codeBlockContent
            } else {
                Text(self.markdownText)
                    .font(.callout)
                    .lineSpacing(6)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var codeBlockContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(self.splitByCodeBlocks(), id: \.offset) { item in
                if item.isCode {
                    self.codeBlock(item.text)
                } else if !item.text.isEmpty {
                    Text(self.parseMarkdown(item.text))
                        .font(.callout)
                        .lineSpacing(6)
                        .foregroundStyle(.primary)
                }
            }
        }
        .textSelection(.enabled)
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

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.subheadline.monospaced())
            .foregroundStyle(.primary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
    }

    private func parseMarkdown(_ text: String) -> AttributedString {
        do {
            return try AttributedString(markdown: text)
        } catch {
            return AttributedString(text)
        }
    }

    private func splitByCodeBlocks() -> [(text: String, isCode: Bool, offset: Int)] {
        let pattern = "```[^`]*```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else {
            return [(self.document.content, false, 0)]
        }

        let content = self.document.content
        let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.utf16.count))

        var result: [(String, Bool, Int)] = []
        var lastIndex = content.startIndex

        for (offset, match) in matches.enumerated() {
            guard let matchRange = Range(match.range, in: content) else {
                continue
            }

            if lastIndex < matchRange.lowerBound {
                let text = String(content[lastIndex ..< matchRange.lowerBound])
                result.append((text, false, offset * 2))
            }

            let codeBlock = String(content[matchRange])
            let cleanCode = codeBlock
                .replacingOccurrences(of: "^```[a-zA-Z]*\n?", with: "", options: .regularExpression)
                .replacingOccurrences(of: "\n?```$", with: "", options: .regularExpression)
            result.append((cleanCode, true, offset * 2 + 1))

            lastIndex = matchRange.upperBound
        }

        if lastIndex < content.endIndex {
            let text = String(content[lastIndex ..< content.endIndex])
            result.append((text, false, matches.count * 2))
        }

        return result
    }

    private func loadAuthorMetadata() async {
        for await meta in await self.ndk.profileManager.subscribe(for: self.document.pubkey) {
            self.metadata = meta
        }
    }
}

// MARK: - FlowLayout

/// A flow layout that wraps items to the next line when they don't fit
private struct FlowLayout: Layout {
    // MARK: Internal

    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = self.arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = self.arrangeSubviews(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            let position = CGPoint(
                x: bounds.minX + frame.origin.x,
                y: bounds.minY + frame.origin.y
            )
            subviews[index].place(at: position, proposal: ProposedViewSize(frame.size))
        }
    }

    // MARK: Private

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
                // Move to next line
                currentX = 0
                currentY += lineHeight + self.spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            currentX += size.width + self.spacing
            lineHeight = max(lineHeight, size.height)
            totalHeight = currentY + lineHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), frames)
    }
}
