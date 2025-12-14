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
            mainContent
                .navigationTitle("New Document")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .onAppear { loadDraft() }
                .onChange(of: title) { _, _ in saveDraft() }
                .onChange(of: content) { _, _ in saveDraft() }
                .onChange(of: hashtags) { _, _ in saveDraft() }
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

    @ToolbarContentBuilder private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .principal) {
            if hasDraft {
                Text("Draft saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        ToolbarItem(placement: .confirmationAction) {
            publishButton
        }
    }

    private var canPublish: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasDraft: Bool {
        !title.isEmpty || !content.isEmpty || !hashtags.isEmpty
    }

    private var draftKey: String {
        "doc-draft-\(projectID)"
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if restoredFromDraft {
                draftRestoredBanner
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    titleField
                    hashtagsSection
                    contentField
                }
                .padding()
            }
        }
    }

    private var publishButton: some View {
        Button("Publish") {
            Task { await publishDocument() }
        }
        .disabled(!canPublish || isPublishing)
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("Title", text: $title, axis: .vertical)
                .font(.title2.weight(.semibold))
                .textFieldStyle(.plain)
        }
    }

    private var hashtagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            existingHashtags
            hashtagInputField
        }
    }

    @ViewBuilder private var existingHashtags: some View {
        if !hashtags.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(Array(hashtags.enumerated()), id: \.offset) { index, tag in
                    editableHashtagPill(tag: tag, index: index)
                }
            }
        }
    }

    @ViewBuilder private var hashtagInputField: some View {
        if hashtags.count < maxHashtags {
            HStack(spacing: 8) {
                Image(systemName: "number")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                hashtagTextField
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var hashtagTextField: some View {
        TextField("Add up to \(maxHashtags) tags...", text: $hashtagInput)
            .font(.system(size: 14))
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .onSubmit { addHashtag() }
            .onChange(of: hashtagInput) { _, newValue in
                if newValue.hasSuffix(",") || newValue.hasSuffix(" ") {
                    hashtagInput = String(newValue.dropLast())
                    addHashtag()
                }
            }
    }

    private var contentField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $content)
                .font(.system(size: 16))
                .frame(minHeight: 300)
                .scrollContentBackground(.hidden)

            if content.isEmpty {
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
                clearDraft()
                title = ""
                content = ""
                hashtags = []
                restoredFromDraft = false
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
            Button { hashtags.remove(at: index) } label: {
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
        let tag = hashtagInput
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
            .lowercased()

        guard !tag.isEmpty,
              hashtags.count < maxHashtags,
              !hashtags.contains(tag)
        else {
            hashtagInput = ""
            return
        }

        hashtags.append(tag)
        hashtagInput = ""
    }

    private func saveDraft() {
        let draft = DocumentDraft(
            title: title,
            content: content,
            hashtags: hashtags
        )

        if let data = try? JSONEncoder().encode(draft) {
            UserDefaults.standard.set(data, forKey: draftKey)
        }
    }

    private func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(DocumentDraft.self, from: data)
        else {
            return
        }

        if !draft.title.isEmpty || !draft.content.isEmpty || !draft.hashtags.isEmpty {
            title = draft.title
            content = draft.content
            hashtags = draft.hashtags
            restoredFromDraft = true
        }
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }

    private func publishDocument() async {
        guard canPublish else {
            return
        }

        isPublishing = true
        defer { isPublishing = false }

        let identifier = "\(projectID.replacingOccurrences(of: ":", with: "-"))-\(Int(Date().timeIntervalSince1970))"
        let summaryText = String(content.prefix(160)).trimmingCharacters(in: .whitespacesAndNewlines)

        var tags: [[String]] = [
            ["d", identifier],
            ["title", title.trimmingCharacters(in: .whitespacesAndNewlines)],
            ["a", projectID],
            ["summary", summaryText],
            ["published_at", String(Int(Date().timeIntervalSince1970))],
        ]

        for hashtag in hashtags {
            tags.append(["t", hashtag])
        }

        do {
            let event = try await NDKEventBuilder(ndk: ndk)
                .kind(30_023)
                .setTags(tags)
                .content(content)
                .build()

            try await ndk.publish(event)
            clearDraft()
            dismiss()
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
