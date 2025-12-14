//
// DocumentCreateView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import SwiftUI

// MARK: - DocumentCreateView

/// View for creating a new document (kind 30023)
public struct DocumentCreateView: View {
    // MARK: Lifecycle

    public init(ndk: NDK, projectID: String) {
        self.ndk = ndk
        self.projectID = projectID
    }

    // MARK: Public

    public var body: some View {
        NavigationStack {
            self.mainContent
                .navigationTitle("New Document")
            #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar { self.toolbarItems }
                .onAppear { self.loadDraft() }
                .task(id: self.draftState) {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    self.saveDraft()
                }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var hashtags: [String] = []
    @State private var hashtagInput = ""
    @State private var isPublishing = false
    @State private var restoredFromDraft = false

    private let ndk: NDK
    private let projectID: String
    private let maxHashtags = 5

    /// Combined state hash for debouncing
    private var draftState: Int {
        var hasher = Hasher()
        hasher.combine(self.title)
        hasher.combine(self.content)
        hasher.combine(self.hashtags)
        return hasher.finalize()
    }

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { self.dismiss() }
        }
        ToolbarItem(placement: .principal) {
            if self.hasDraft {
                Text("Draft saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            self.publishButton
        }
    }

    private var canPublish: Bool {
        !self.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !self.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasDraft: Bool {
        !self.title.isEmpty || !self.content.isEmpty || !self.hashtags.isEmpty
    }

    private var draftKey: String {
        "doc-draft-\(self.projectID)"
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if self.restoredFromDraft {
                self.draftRestoredBanner
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    self.titleField
                    self.hashtagsSection
                    self.contentField
                }
                .padding()
            }
        }
    }

    private var publishButton: some View {
        Button("Publish") {
            Task { await self.publishDocument() }
        }
        .disabled(!self.canPublish || self.isPublishing)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title", text: self.$title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
        }
    }

    private var hashtagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.existingHashtags
            self.hashtagInputField
        }
    }

    @ViewBuilder private var existingHashtags: some View {
        if !self.hashtags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(Array(self.hashtags.enumerated()), id: \.offset) { index, tag in
                    self.editableHashtagPill(tag: tag, index: index)
                }
            }
        }
    }

    @ViewBuilder private var hashtagInputField: some View {
        if self.hashtags.count < self.maxHashtags {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                self.hashtagTextField
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var hashtagTextField: some View {
        TextField("Add up to \(self.maxHashtags) tags...", text: self.$hashtagInput)
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
        #if !os(macOS)
            .textInputAutocapitalization(.never)
        #endif
            .onSubmit { self.addHashtag() }
            .onChange(of: self.hashtagInput) { _, newValue in
                if newValue.hasSuffix(",") || newValue.hasSuffix(" ") {
                    self.hashtagInput = String(newValue.dropLast())
                    self.addHashtag()
                }
            }
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: self.$content)
                .font(.system(size: 16))
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)

            if self.content.isEmpty {
                Text("""
                Write your content here...

                Markdown supported:
                # Heading 1
                ## Heading 2
                **bold**, *italic*
                - Lists
                > Quotes
                [links](url)
                `code`
                """)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .allowsHitTesting(false)
                .padding(.top, -280)
            }
        }
    }

    private var draftRestoredBanner: some View {
        HStack {
            Image(systemName: "arrow.counterclockwise")
            Text("Restored from draft")
            Spacer()
            Button("Start fresh") {
                self.clearDraft()
                self.title = ""
                self.content = ""
                self.hashtags = []
                self.restoredFromDraft = false
            }
            .font(.system(size: 13, weight: .medium))
        }
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.blue.opacity(0.1))
    }

    private func editableHashtagPill(tag: String, index: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "number").font(.system(size: 10))
            Text(tag).font(.system(size: 12))
            Button { self.hashtags.remove(at: index) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(16)
    }

    private func addHashtag() {
        let tag = self.hashtagInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()

        guard !tag.isEmpty,
              self.hashtags.count < self.maxHashtags,
              !self.hashtags.contains(tag)
        else {
            self.hashtagInput = ""
            return
        }

        self.hashtags.append(tag)
        self.hashtagInput = ""
    }

    private func saveDraft() {
        let draft = DocumentDraft(
            title: title,
            content: content,
            hashtags: hashtags
        )

        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: self.draftKey)
        }
    }

    private func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(DocumentDraft.self, from: data)
        else {
            return
        }

        if !draft.title.isEmpty || !draft.content.isEmpty || !draft.hashtags.isEmpty {
            self.title = draft.title
            self.content = draft.content
            self.hashtags = draft.hashtags
            self.restoredFromDraft = true
        }
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: self.draftKey)
    }

    private func publishDocument() async {
        guard self.canPublish else {
            return
        }

        self.isPublishing = true
        defer { isPublishing = false }

        let identifier = "\(projectID.replacingOccurrences(of: ":", with: "-"))-\(Int(Date().timeIntervalSince1970))"
        let summaryText = String(content.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines)

        var tags: [[String]] = [
            ["d", identifier],
            ["title", title.trimmingCharacters(in: .whitespacesAndNewlines)],
            ["a", self.projectID],
            ["summary", summaryText],
            ["published_at", String(Int(Date().timeIntervalSince1970))],
        ]

        for hashtag in self.hashtags {
            tags.append(["t", hashtag])
        }

        do {
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(30_023)
                .setTags(tags)
                .content(self.content)
                .build()

            try await self.ndk.publish(event)
            self.clearDraft()
            self.dismiss()
        } catch {
            // Publishing failed - keep the draft for retry
        }
    }
}

// MARK: - DocumentDraft

/// Draft document stored in UserDefaults
private struct DocumentDraft: Codable {
    let title: String
    let content: String
    let hashtags: [String]
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
