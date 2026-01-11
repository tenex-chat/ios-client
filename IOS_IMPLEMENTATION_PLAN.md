# iOS Feature Implementation Plan

## Based on IOS_FEATURE_GAP_ANALYSIS.md
**Created:** January 2026

This document provides a phased implementation plan for bringing the iOS client to feature parity with the Svelte web client. Each phase builds on the previous one, with clear dependencies and verification criteria.

---

## PHASE 1: Core Infrastructure (Enable All Image Features)

This phase establishes the foundation required for all image-related features in subsequent phases.

### 1.1 Blossom Upload Client Implementation

**Priority:** Critical (blocks Phase 2)

**Files to Create:**
- `/Sources/Core/Blossom/BlossomClient.swift` - Core upload/download client
- `/Sources/Core/Blossom/BlossomSettings.swift` - Server configuration storage
- `/Sources/Core/Blossom/BlossomUploadConfig.swift` - Upload configuration (max size, compression, EXIF stripping)

**Files to Modify:**
- `/Sources/Core/Storage/SecureStorage.swift` - Add Blossom server credentials if needed
- `/Sources/Features/Settings/AISettingsView.swift` - Add Blossom server configuration UI

**Dependencies:** None (foundational)

**Svelte Reference:**
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/stores/blossomSettings.svelte.ts` - Settings store pattern
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/settings/BlossomSettings.svelte` - Settings UI

**Key Implementation Details:**
```swift
// BlossomClient.swift
@MainActor
@Observable
public final class BlossomClient {
    public struct UploadResult {
        let url: String
        let sha256: String
        let size: Int64
        let mimeType: String
    }

    public enum UploadState {
        case idle
        case compressing
        case uploading(progress: Double)
        case complete(UploadResult)
        case failed(Error)
    }

    public private(set) var uploadState: UploadState = .idle

    /// Upload image data to Blossom server
    /// - Parameters:
    ///   - data: Image data (will be compressed if configured)
    ///   - mimeType: MIME type of the image
    ///   - serverURL: Blossom server URL
    /// - Returns: Upload result with URL and metadata
    public func upload(data: Data, mimeType: String, serverURL: String) async throws -> UploadResult

    /// Check server status
    public func checkServerStatus(url: String) async -> Bool
}
```

**Verification Criteria:**
- [ ] Can add/remove Blossom servers in settings
- [ ] Server status check shows online/offline
- [ ] Can upload test image and receive URL
- [ ] Image compression works when enabled
- [ ] EXIF stripping works when enabled
- [ ] Upload progress updates correctly

---

### 1.2 Image Picker Integration in ChatInputView

**Priority:** Critical (blocks Phase 2)

**Files to Modify:**
- `/Sources/Features/Chat/ChatInputView.swift` - Add image picker button and state
- `/Sources/Features/Chat/ChatInputViewModel.swift` - Add attachment handling

**Files to Create:**
- `/Sources/Features/Chat/Components/ImageAttachmentButton.swift` - Image picker trigger button

**Dependencies:** 1.1 (Blossom Upload Client)

**Svelte Reference:**
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/chat/ChatInput.svelte` - Attachment button at line 555-570

**Key Implementation Details:**
```swift
// In ChatInputViewModel.swift
public struct PendingAttachment: Identifiable {
    let id = UUID()
    let image: UIImage  // or NSImage for macOS
    let uploadState: BlossomClient.UploadState
    var uploadedURL: String?
}

@Observable
public final class ChatInputViewModel {
    public private(set) var pendingAttachments: [PendingAttachment] = []

    public func addImage(_ image: UIImage) async {
        // Add to pending, start upload
    }

    public func removeAttachment(_ id: UUID) {
        // Remove from pending
    }
}
```

Add to `ChatInputView.swift` alongside existing `plusMenuButton`:
- PhotosPicker for iOS 16+
- Camera capture option
- File picker for documents

**Verification Criteria:**
- [ ] Image picker appears in chat input menu
- [ ] Can select images from photo library
- [ ] Can take photo with camera (iOS)
- [ ] Selected images start uploading immediately
- [ ] Upload progress visible in UI

---

## PHASE 2: Image Features

### 2.1 Image Attachment Preview

**Priority:** High

**Files to Create:**
- `/Sources/Features/Chat/Components/AttachmentPreviewView.swift` - Preview component with upload state
- `/Sources/Features/Chat/Components/AttachmentPreviewRow.swift` - Horizontal scrolling row of attachments

**Files to Modify:**
- `/Sources/Features/Chat/ChatInputView.swift` - Add preview row above input

**Dependencies:** Phase 1 (complete)

**Svelte Reference:**
- Attachment preview is embedded in ChatInput.svelte

**Key Implementation Details:**
```swift
// AttachmentPreviewView.swift
struct AttachmentPreviewView: View {
    let attachment: PendingAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Thumbnail image
            Image(uiImage: attachment.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Upload state overlay
            switch attachment.uploadState {
            case .uploading(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(.circular)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            case .complete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            default:
                EmptyView()
            }

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
            }
        }
    }
}
```

**Verification Criteria:**
- [ ] Thumbnails display for pending attachments
- [ ] Upload progress indicator shows during upload
- [ ] Success/failure states visible
- [ ] Remove button removes attachment from queue
- [ ] Multiple attachments scroll horizontally

---

### 2.2 Inline Image Lightbox Viewer

**Priority:** High

**Files to Create:**
- `/Sources/Features/Chat/Components/ImageLightboxView.swift` - Fullscreen image viewer
- `/Sources/Features/Chat/Components/ImageLightboxOverlay.swift` - Overlay presentation

**Files to Modify:**
- `/Sources/Features/Chat/MessageContentView.swift` - Add tap handler for images in markdown

**Dependencies:** None (can be done in parallel with 2.1)

**Key Implementation Details:**
```swift
// ImageLightboxView.swift
struct ImageLightboxView: View {
    let imageURL: URL
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: imageURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { scale = $0 }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { offset = $0.translation }
                    )
            } placeholder: {
                ProgressView()
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Download") {
                    downloadImage()
                }
            }
        }
        .onTapGesture(count: 2) {
            withAnimation { scale = scale == 1.0 ? 2.0 : 1.0 }
        }
    }
}
```

For intercepting image taps in NDKMarkdown, add a custom image renderer or use the tap gesture on markdown images.

**Verification Criteria:**
- [ ] Tapping image in message opens lightbox
- [ ] Pinch-to-zoom works
- [ ] Double-tap zooms in/out
- [ ] Drag to pan when zoomed
- [ ] Download button saves to photo library
- [ ] Tap outside or swipe down dismisses

---

### 2.3 Drag & Drop Image Attachments (iPad/Mac)

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Chat/ChatInputView.swift` - Add drop destination modifier
- `/Sources/Features/Chat/ChatView.swift` - Add drop zone overlay

**Dependencies:** Phase 1 (Blossom client)

**Key Implementation Details:**
```swift
// In ChatInputView.swift or ChatView.swift
.dropDestination(for: Data.self) { items, location in
    for item in items {
        if let image = UIImage(data: item) {
            Task {
                await viewModel.addImage(image)
            }
        }
    }
    return true
}
.dropDestination(for: URL.self) { urls, location in
    for url in urls {
        if let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            Task {
                await viewModel.addImage(image)
            }
        }
    }
    return true
}
```

Add visual drop indicator:
```swift
@State private var isTargeted = false

// Overlay when dragging
if isTargeted {
    RoundedRectangle(cornerRadius: 12)
        .stroke(Color.accentColor, lineWidth: 3)
        .background(Color.accentColor.opacity(0.1))
}
```

**Verification Criteria:**
- [ ] Drop zone highlighted when dragging over chat
- [ ] Images dropped start uploading
- [ ] Works on iPad with drag from Photos
- [ ] Works on Mac Catalyst with Finder drag
- [ ] Multiple images can be dropped at once

---

### 2.4 AI Image Generation

**Priority:** Medium

**Files to Create:**
- `/Sources/Core/AI/ImageGeneration/ImageGenerationService.swift` - OpenRouter image generation
- `/Sources/Features/Chat/Components/ImageGenerationSheet.swift` - Prompt input UI
- `/Sources/Features/Chat/Components/GeneratedImagePreview.swift` - Preview before sending

**Files to Modify:**
- `/Sources/Features/Chat/ChatInputView.swift` - Add image generation option to menu
- `/Sources/Core/AI/Discovery/APIModels/OpenRouterModelsResponse.swift` - May need image model support

**Dependencies:** Phase 1 (Blossom for uploading generated images)

**Key Implementation Details:**
```swift
// ImageGenerationService.swift
@MainActor
@Observable
public final class ImageGenerationService {
    public enum GenerationState {
        case idle
        case generating
        case complete(UIImage)
        case failed(Error)
    }

    public private(set) var state: GenerationState = .idle

    /// Generate image from text prompt via OpenRouter
    public func generate(prompt: String, model: String, apiKey: String) async throws -> UIImage {
        state = .generating
        // Call OpenRouter image generation API
        // Return generated image
    }
}
```

**Verification Criteria:**
- [ ] Image generation option in chat input menu
- [ ] Can enter text prompt
- [ ] Generation progress indicator shows
- [ ] Generated image previews before sending
- [ ] Can regenerate with same prompt
- [ ] Generated image uploads to Blossom and inserts in message

---

## PHASE 3: Multi-Question Ask Events

### 3.1 Parse Multi-Question Tag Structure

**Priority:** High

**Files to Modify:**
- `/Sources/Core/Events/Message.swift` - Add ask question parsing

**Files to Create:**
- `/Sources/Core/Events/AskQuestion.swift` - Question model with options

**Dependencies:** None

**Svelte Reference:**
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/events/NDKTask.ts` - Task/Ask event handling

**Key Implementation Details:**
```swift
// AskQuestion.swift
public struct AskQuestion: Identifiable, Sendable {
    public let id: String
    public let question: String
    public let options: [AskOption]
    public let allowMultiple: Bool
    public let required: Bool
}

public struct AskOption: Identifiable, Sendable {
    public let id: String
    public let label: String
    public let value: String
}

// In Message.swift, add:
public var askQuestions: [AskQuestion] {
    guard hasAskTag else { return [] }
    // Parse from "ask" tags:
    // ["ask", "question-id", "question-text", "single|multi", "required|optional"]
    // ["ask-option", "question-id", "option-id", "label", "value"]
    return parseAskQuestions(from: rawEventJSON)
}
```

**Verification Criteria:**
- [ ] Single question ask events parse correctly
- [ ] Multi-question ask events parse correctly
- [ ] Options extracted for each question
- [ ] Single/multi-select type detected
- [ ] Required/optional flag detected

---

### 3.2 Create Tabbed Question UI

**Priority:** High

**Files to Create:**
- `/Sources/Features/Chat/Components/AskEventView.swift` - Container for ask UI
- `/Sources/Features/Chat/Components/AskQuestionTab.swift` - Individual question tab
- `/Sources/Features/Chat/Components/AskOptionRow.swift` - Option selection row

**Files to Modify:**
- `/Sources/Features/Chat/MessageContentView.swift` - Render AskEventView for ask messages

**Dependencies:** 3.1

**Key Implementation Details:**
```swift
// AskEventView.swift
struct AskEventView: View {
    let message: Message
    let onAnswer: ([String: [String]]) -> Void  // questionId -> selected option ids

    @State private var selectedTab: String?
    @State private var answers: [String: Set<String>] = [:]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar for multiple questions
            if message.askQuestions.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(message.askQuestions) { question in
                            TabButton(
                                title: "Q\(question.index + 1)",
                                isSelected: selectedTab == question.id,
                                hasAnswer: !answers[question.id, default: []].isEmpty
                            ) {
                                selectedTab = question.id
                            }
                        }
                    }
                }
            }

            // Question content
            if let question = currentQuestion {
                AskQuestionTab(
                    question: question,
                    selectedOptions: answers[question.id, default: []],
                    onSelect: { optionId in
                        toggleOption(questionId: question.id, optionId: optionId)
                    }
                )
            }

            // Submit button
            Button("Submit Answer") {
                submitAnswers()
            }
            .disabled(!canSubmit)
        }
    }
}
```

**Verification Criteria:**
- [ ] Tabs appear for multi-question asks
- [ ] Can navigate between questions
- [ ] Selected tab highlighted
- [ ] Question text displays clearly
- [ ] Completion indicator on tabs

---

### 3.3 Single/Multi-Select Answer Input

**Priority:** High

**Files to Create:**
- `/Sources/Features/Chat/Components/AskSingleSelectView.swift` - Radio button style
- `/Sources/Features/Chat/Components/AskMultiSelectView.swift` - Checkbox style

**Files to Modify:**
- `/Sources/Core/Events/MessagePublisher.swift` - Add ask response publishing

**Dependencies:** 3.2

**Key Implementation Details:**
```swift
// AskSingleSelectView.swift
struct AskSingleSelectView: View {
    let options: [AskOption]
    @Binding var selectedOption: String?

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options) { option in
                Button {
                    selectedOption = option.id
                } label: {
                    HStack {
                        Image(systemName: selectedOption == option.id ? "circle.inset.filled" : "circle")
                        Text(option.label)
                        Spacer()
                    }
                    .padding()
                    .background(selectedOption == option.id ? Color.accentColor.opacity(0.1) : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// In MessagePublisher.swift
public func publishAskResponse(
    ndk: NDK,
    askEventId: String,
    projectRef: String,
    answers: [String: [String]]  // questionId -> selected option values
) async throws
```

**Verification Criteria:**
- [ ] Single-select shows radio buttons
- [ ] Multi-select shows checkboxes
- [ ] Selection updates immediately
- [ ] Can change selection before submit
- [ ] Submit publishes response event
- [ ] Response tags formatted correctly

---

### 3.4 Update InboxRow for Ask Previews

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Inbox/InboxRow.swift` (or equivalent) - Show ask preview
- `/Sources/Features/Data/DataStore.swift` - Priority sorting for asks in inbox

**Dependencies:** 3.1

**Key Implementation Details:**
- Show question count badge on ask messages
- Preview first question text
- Indicate if response is pending
- Sort ask messages higher in inbox

**Verification Criteria:**
- [ ] Ask messages show distinctive styling in inbox
- [ ] Question count visible
- [ ] First question previews
- [ ] Unanswered asks sort to top

---

## PHASE 4: Document Features

### 4.1 Document Version History Subscription

**Priority:** High

**Files to Create:**
- `/Sources/Features/Docs/DocumentVersionStore.swift` - Version history management

**Files to Modify:**
- `/Sources/Features/Docs/DocumentDetailView.swift` - Add version selector
- `/Sources/Features/Data/DataStore.swift` - Add document version subscription method

**Dependencies:** None

**Key Implementation Details:**
```swift
// DocumentVersionStore.swift
@MainActor
@Observable
public final class DocumentVersionStore {
    private let ndk: NDK
    private let documentDTag: String

    public private(set) var versions: [NDKEvent] = []
    public private(set) var isLoading = false

    /// Subscribe to all versions of a document by d-tag
    public func subscribe() async {
        isLoading = true
        defer { isLoading = false }

        let filter = NDKFilter(
            kinds: [30023],  // Long-form content
            tags: ["d": Set([documentDTag])]
        )

        let subscription = ndk.subscribe(filter: filter)
        for await event in subscription.events {
            // Sort by created_at descending
            versions = (versions + [event]).sorted { $0.createdAt > $1.createdAt }
        }
    }

    public var currentVersion: NDKEvent? { versions.first }
    public var previousVersions: [NDKEvent] { Array(versions.dropFirst()) }
}
```

**Verification Criteria:**
- [ ] All versions of document load
- [ ] Versions sorted by date (newest first)
- [ ] Can select any version to view
- [ ] Loading indicator while fetching

---

### 4.2 Version Diff Algorithm

**Priority:** High

**Files to Create:**
- `/Sources/Features/Docs/DocumentDiff.swift` - Diff computation
- `/Sources/Features/Docs/DiffLine.swift` - Diff result model

**Dependencies:** 4.1

**Key Implementation Details:**
```swift
// DocumentDiff.swift
public struct DiffLine: Identifiable {
    public enum DiffType {
        case unchanged
        case added
        case removed
        case modified
    }

    public let id = UUID()
    public let lineNumber: Int
    public let content: String
    public let type: DiffType
}

public struct DocumentDiff {
    /// Compute line-by-line diff between two versions
    public static func compute(old: String, new: String) -> [DiffLine] {
        // Use Myers diff algorithm or simple LCS
        // Return array of diff lines with type annotations
    }
}
```

Consider using a Swift diff library or implementing Myers algorithm.

**Verification Criteria:**
- [ ] Added lines identified correctly
- [ ] Removed lines identified correctly
- [ ] Unchanged lines preserved
- [ ] Performance acceptable for large documents

---

### 4.3 Visual Diff UI Component

**Priority:** High

**Files to Create:**
- `/Sources/Features/Docs/Components/DocumentDiffView.swift` - Side-by-side or unified diff view
- `/Sources/Features/Docs/Components/DiffLineView.swift` - Single diff line rendering

**Files to Modify:**
- `/Sources/Features/Docs/DocumentDetailView.swift` - Add diff view toggle

**Dependencies:** 4.2

**Key Implementation Details:**
```swift
// DocumentDiffView.swift
struct DocumentDiffView: View {
    let oldVersion: NDKEvent
    let newVersion: NDKEvent

    @State private var diffLines: [DiffLine] = []

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(diffLines) { line in
                    DiffLineView(line: line)
                }
            }
        }
        .task {
            diffLines = DocumentDiff.compute(
                old: oldVersion.content,
                new: newVersion.content
            )
        }
    }
}

// DiffLineView.swift
struct DiffLineView: View {
    let line: DiffLine

    var body: some View {
        HStack(spacing: 8) {
            Text("\(line.lineNumber)")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 40, alignment: .trailing)

            Text(line.content)
                .font(.body.monospaced())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
        .background(backgroundColor)
    }

    var backgroundColor: Color {
        switch line.type {
        case .added: return Color.green.opacity(0.2)
        case .removed: return Color.red.opacity(0.2)
        case .modified: return Color.yellow.opacity(0.2)
        case .unchanged: return Color.clear
        }
    }
}
```

**Verification Criteria:**
- [ ] Diff view shows added lines in green
- [ ] Removed lines shown in red
- [ ] Line numbers displayed
- [ ] Smooth fade animation when switching versions
- [ ] Can toggle between diff and full document view

---

## PHASE 5: Lessons Feature

### 5.1 Lesson Model and Event Kind Definition

**Priority:** High

**Files to Create:**
- `/Sources/Core/Events/AgentLesson.swift` - Lesson model

**Files to Modify:**
- `/Sources/Core/Events/` - Add new event kind constant

**Dependencies:** None

**Svelte Reference:**
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/events/NDKAgentLesson.ts`
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/kinds.ts` - Kind 4129

**Key Implementation Details:**
```swift
// AgentLesson.swift
public struct AgentLesson: Identifiable, Sendable {
    public let id: String
    public let pubkey: String
    public let createdAt: Date
    public let agentDefinitionId: String?

    // Content
    public let title: String?
    public let lesson: String  // Main content

    // Metadata tags
    public let metacognition: String?
    public let reasoning: String?
    public let reflection: String?
    public let detailed: String?
    public let category: String?
    public let hashtags: [String]

    public static let kind: UInt32 = 4129

    public static func from(event: NDKEvent) -> Self? {
        guard event.kind == Self.kind else { return nil }
        return Self(
            id: event.id,
            pubkey: event.pubkey,
            createdAt: Date(timeIntervalSince1970: TimeInterval(event.createdAt)),
            agentDefinitionId: event.tagValue("e"),
            title: event.tagValue("title"),
            lesson: event.content,
            metacognition: event.tagValue("metacognition"),
            reasoning: event.tagValue("reasoning"),
            reflection: event.tagValue("reflection"),
            detailed: event.tagValue("detailed"),
            category: event.tagValue("category"),
            hashtags: event.tags(withName: "t").compactMap { $0[safe: 1] }
        )
    }

    public static func filter(forAgent pubkey: String) -> NDKFilter {
        NDKFilter(
            kinds: [kind],
            authors: [pubkey],
            limit: 50
        )
    }
}
```

**Verification Criteria:**
- [ ] Lesson events parse correctly
- [ ] All metadata fields extracted
- [ ] Hashtags parsed into array
- [ ] Agent definition reference extracted

---

### 5.2 LessonsTabView and LessonDetailView

**Priority:** High

**Files to Create:**
- `/Sources/Features/Agents/Components/AgentLessonsTab.swift` - Tab content for agent profile
- `/Sources/Features/Agents/Components/LessonCard.swift` - Lesson list item
- `/Sources/Features/Agents/LessonDetailView.swift` - Full lesson view

**Files to Modify:**
- `/Sources/Features/Agents/AgentProfileView.swift` - Add lessons tab

**Dependencies:** 5.1

**Svelte Reference:**
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/agents/AgentLessonsTab.svelte`
- `/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/agents/LessonCard.svelte`

**Key Implementation Details:**
```swift
// AgentLessonsTab.swift
struct AgentLessonsTab: View {
    let agentPubkey: String
    let ndk: NDK

    @State private var lessons: [AgentLesson] = []
    @State private var isLoading = true

    var body: some View {
        Group {
            if lessons.isEmpty && !isLoading {
                emptyState
            } else {
                lessonList
            }
        }
        .task {
            await loadLessons()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No lessons yet")
                .font(.headline)
            Text("This agent hasn't learned any lessons yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var lessonList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(lessons) { lesson in
                    NavigationLink(value: AppRoute.lesson(lesson.id)) {
                        LessonCard(lesson: lesson)
                    }
                }
            }
            .padding()
        }
    }
}
```

**Verification Criteria:**
- [ ] Lessons tab appears in agent profile
- [ ] Lessons load for agent
- [ ] Empty state shows when no lessons
- [ ] Lesson cards display title and preview
- [ ] Tapping lesson navigates to detail

---

### 5.3 Comment Subscription and Publishing

**Priority:** Medium

**Files to Create:**
- `/Sources/Features/Agents/Components/LessonCommentsView.swift` - Comments section
- `/Sources/Features/Agents/Components/LessonCommentRow.swift` - Single comment

**Files to Modify:**
- `/Sources/Features/Agents/LessonDetailView.swift` - Add comments section
- `/Sources/Core/Events/MessagePublisher.swift` - Add lesson comment publishing

**Dependencies:** 5.2

**Key Implementation Details:**
- Comments are kind:1 events with e-tag referencing lesson
- Use existing message subscription pattern
- Add comment input at bottom of lesson detail

**Verification Criteria:**
- [ ] Comments load for lesson
- [ ] Can post new comment
- [ ] Comments appear in real-time
- [ ] Author profile pictures display

---

## PHASE 6: Message Actions & Search

### 6.1 "Send in New Conversation" Context Menu Action

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Chat/MessageRow.swift` - Add context menu item
- `/Sources/Features/Navigation/NavigationRouter.swift` - Add route for new conversation with content

**Dependencies:** None

**Key Implementation Details:**
```swift
// In MessageRow.swift contextMenuContent
Button {
    sendInNewConversation()
} label: {
    Label("Send in New Conversation", systemImage: "plus.message")
}

private func sendInNewConversation() {
    // Navigate to new conversation with message content pre-filled
    // Could use NavigationRouter or callback
    // Pass message.content and message.projectCoordinate
}
```

**Verification Criteria:**
- [ ] Context menu item appears
- [ ] Tapping opens new conversation view
- [ ] Message content pre-filled in input
- [ ] Project context preserved

---

### 6.2 Conversation ID Search (64-char Hex)

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Feed/Components/FeedSearchBar.swift` - Add hex detection
- `/Sources/Features/Feed/FeedTabViewModel.swift` - Add event ID lookup

**Dependencies:** None

**Key Implementation Details:**
```swift
// In FeedSearchBar or FeedTabViewModel
private func isEventId(_ query: String) -> Bool {
    query.count == 64 && query.allSatisfy { $0.isHexDigit }
}

private func searchEventById(_ eventId: String) async {
    let filter = NDKFilter(ids: [eventId])
    let subscription = ndk.subscribe(filter: filter)

    // Use collect with timeout
    if let event = try? await subscription.collect(timeout: 5000, limit: 1).first {
        // Navigate to conversation
        navigateToConversation(event)
    }
}

// Modify search handler
func handleSearch(_ query: String) {
    if isEventId(query) {
        Task { await searchEventById(query) }
    } else {
        // Existing text search
    }
}
```

**Verification Criteria:**
- [ ] 64-char hex detected as event ID
- [ ] Event fetched from relays
- [ ] Navigation to conversation on match
- [ ] Error message if not found
- [ ] Regular search still works

---

### 6.3 LLM Usage Tracking Display

**Priority:** Low

**Files to Create:**
- `/Sources/Features/Chat/Components/UsageIndicator.swift` - Token/cost display
- `/Sources/Core/Models/LLMUsage.swift` - Usage data model

**Files to Modify:**
- `/Sources/Core/Events/Message.swift` - Parse usage from tool events
- `/Sources/Features/Chat/MessageRow.swift` - Add usage indicator

**Dependencies:** None (backend sends usage in events)

**Key Implementation Details:**
```swift
// LLMUsage.swift
public struct LLMUsage: Sendable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int
    public let estimatedCost: Double?  // In USD
}

// Parse from event tags or tool-args
// Display as subtle badge on agent messages
```

**Verification Criteria:**
- [ ] Usage data parsed from events
- [ ] Token count displays on messages
- [ ] Cost estimate shows (if available)
- [ ] Aggregate stats in settings/debug view

---

## PHASE 7: Advanced Visualization

### 7.1 Hierarchical Nesting in Thread List

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Feed/FeedTabView.swift` - Add nesting support
- `/Sources/Features/Data/ProjectConversationStore.swift` - Track parent-child relationships

**Files to Create:**
- `/Sources/Features/Feed/Components/NestedThreadRow.swift` - Indented thread row

**Dependencies:** Delegation tags from backend

**Key Implementation Details:**
```swift
// In ProjectConversationStore, track delegation hierarchy
public struct ThreadWithChildren {
    let thread: NDKEvent
    let children: [NDKEvent]  // Delegated conversations
    let depth: Int
}

// Build tree from delegation tags
// Display with indentation based on depth
```

**Verification Criteria:**
- [ ] Child threads indented under parent
- [ ] Delegation relationship visible
- [ ] Can collapse/expand parent threads
- [ ] Depth limited to prevent excessive nesting

---

### 7.2 Swimlane Delegation Visualization

**Priority:** Low

**Files to Create:**
- `/Sources/Features/Chat/Components/DelegationFlowView.swift` - Swimlane diagram
- `/Sources/Features/Chat/Components/DelegationNodeView.swift` - Node in flow
- `/Sources/Features/Chat/Components/DelegationEdgeView.swift` - Connection line

**Dependencies:** 7.1 (hierarchical data)

**Key Implementation Details:**
- Use SwiftUI canvas or custom layout
- Each agent gets a swimlane (horizontal row)
- Delegations shown as nodes in agent's lane
- Lines connect delegating event to delegated conversation
- Animate status changes

**Verification Criteria:**
- [ ] Swimlanes show for each agent
- [ ] Delegation nodes positioned in correct lane
- [ ] Connections drawn between related items
- [ ] Status colors match (working/done)
- [ ] Can tap node to navigate

---

### 7.3 Global Status Dashboard (Kanban)

**Priority:** Low

**Files to Create:**
- `/Sources/Features/Dashboard/StatusDashboardView.swift` - Kanban board
- `/Sources/Features/Dashboard/StatusColumnView.swift` - Single status column
- `/Sources/Features/Dashboard/StatusCardView.swift` - Conversation card

**Files to Modify:**
- `/Sources/Features/Navigation/AppRoute.swift` - Add dashboard route

**Dependencies:** Project status subscription (already exists)

**Svelte Reference:**
- Kanban-style grouping in project status views

**Key Implementation Details:**
```swift
// StatusDashboardView.swift
struct StatusDashboardView: View {
    @Environment(DataStore.self) private var dataStore

    enum StatusColumn: String, CaseIterable {
        case waiting = "Waiting"
        case working = "Working"
        case needsResponse = "Needs Response"
        case done = "Done"
    }

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(StatusColumn.allCases, id: \.self) { column in
                    StatusColumnView(
                        title: column.rawValue,
                        conversations: conversationsFor(column)
                    )
                }
            }
            .padding()
        }
    }
}
```

**Verification Criteria:**
- [ ] Columns for each status
- [ ] Conversations grouped correctly
- [ ] Real-time updates when status changes
- [ ] Can tap card to navigate to conversation
- [ ] Drag-drop to change status (optional)

---

## PHASE 8: Backend API Alignment

### 8.1 Multimodal Image URL Support

**Priority:** High

**Files to Modify:**
- `/Sources/Core/Events/Message.swift` - Parse imeta tags
- `/Sources/Core/Events/MessagePublisher.swift` - Add imeta tags when sending images
- `/Sources/Features/Chat/MessageContentView.swift` - Render imeta images

**Dependencies:** Phase 1 & 2 (image features)

**Key Implementation Details:**
```swift
// In Message.swift
public var imageURLs: [String] {
    // Parse from imeta tags: ["imeta", "url <url>", "m <mimetype>", "x <sha256>"]
    // or from content markdown images
}

// In MessagePublisher
// When sending message with image attachment:
// Add ["imeta", "url \(blossomURL)", "m image/jpeg", "x \(sha256)"]
```

**Verification Criteria:**
- [ ] Imeta tags parsed correctly
- [ ] Images from imeta display in messages
- [ ] Uploaded images include imeta tags
- [ ] Backend receives images for multimodal processing

---

### 8.2 fs_glob/fs_grep Tool Renderers

**Priority:** Medium

**Files to Create:**
- `/Sources/Features/Chat/ToolRenderers/GlobToolRenderer.swift`
- `/Sources/Features/Chat/ToolRenderers/GrepToolRenderer.swift`

**Files to Modify:**
- `/Sources/Features/Chat/ToolRenderers/ToolCallView.swift` - Route to new renderers
- `/Sources/Features/Chat/ToolRenderers/ToolDisplayUtils.swift` - Update categorization

**Dependencies:** None

**Key Implementation Details:**
```swift
// GlobToolRenderer.swift
struct GlobToolRenderer: View {
    let toolCall: ToolCall

    var pattern: String { toolCall.string(for: "pattern") ?? "" }
    var path: String { toolCall.displayPath(for: "path") }
    var matchCount: Int { /* parse from result */ }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Glob Search")
                    .fontWeight(.medium)
            }

            Text("Pattern: \(pattern)")
                .font(.caption.monospaced())

            if !path.isEmpty {
                Text("Path: \(path)")
                    .font(.caption.monospaced())
            }

            Text("\(matchCount) files matched")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

**Verification Criteria:**
- [ ] fs_glob tool renders with pattern and path
- [ ] fs_grep tool renders with pattern and match context
- [ ] Match count displayed
- [ ] File list expandable (if included in result)

---

### 8.3 Delegation Tag Format Verification

**Priority:** Medium

**Files to Modify:**
- `/Sources/Features/Chat/Components/DelegationPreview.swift` - Update tag parsing
- `/Sources/Features/Data/ProjectConversationStore.swift` - Update delegation indexing

**Dependencies:** None (verification task)

**Key Implementation Details:**
- Verify current parsing matches backend format
- Check for both old and new tag formats
- Update if backend has changed delegation tag structure
- Test with actual delegation events

**Verification Criteria:**
- [ ] Delegation parent-child relationships detected
- [ ] All delegation previews load correctly
- [ ] Navigation to delegated conversations works
- [ ] Status (working/done) displays correctly

---

## Appendix: File Reference Quick Index

### New Files to Create

| Phase | File Path | Purpose |
|-------|-----------|---------|
| 1.1 | `/Sources/Core/Blossom/BlossomClient.swift` | Image upload client |
| 1.1 | `/Sources/Core/Blossom/BlossomSettings.swift` | Server configuration |
| 1.2 | `/Sources/Features/Chat/Components/ImageAttachmentButton.swift` | Picker trigger |
| 2.1 | `/Sources/Features/Chat/Components/AttachmentPreviewView.swift` | Upload preview |
| 2.2 | `/Sources/Features/Chat/Components/ImageLightboxView.swift` | Fullscreen viewer |
| 2.4 | `/Sources/Core/AI/ImageGeneration/ImageGenerationService.swift` | AI image gen |
| 3.1 | `/Sources/Core/Events/AskQuestion.swift` | Ask question model |
| 3.2 | `/Sources/Features/Chat/Components/AskEventView.swift` | Ask UI container |
| 4.1 | `/Sources/Features/Docs/DocumentVersionStore.swift` | Version history |
| 4.2 | `/Sources/Features/Docs/DocumentDiff.swift` | Diff algorithm |
| 4.3 | `/Sources/Features/Docs/Components/DocumentDiffView.swift` | Diff display |
| 5.1 | `/Sources/Core/Events/AgentLesson.swift` | Lesson model |
| 5.2 | `/Sources/Features/Agents/Components/AgentLessonsTab.swift` | Lessons tab |
| 6.3 | `/Sources/Core/Models/LLMUsage.swift` | Usage tracking |
| 7.2 | `/Sources/Features/Chat/Components/DelegationFlowView.swift` | Swimlane viz |
| 7.3 | `/Sources/Features/Dashboard/StatusDashboardView.swift` | Kanban board |
| 8.2 | `/Sources/Features/Chat/ToolRenderers/GlobToolRenderer.swift` | fs_glob render |

### Key Files to Modify (Most Impacted)

| File | Phases |
|------|--------|
| `/Sources/Features/Chat/ChatInputView.swift` | 1.2, 2.1, 2.3, 2.4 |
| `/Sources/Features/Chat/ChatInputViewModel.swift` | 1.2, 2.1 |
| `/Sources/Features/Chat/MessageRow.swift` | 6.1, 6.3 |
| `/Sources/Features/Chat/MessageContentView.swift` | 2.2, 3.2, 8.1 |
| `/Sources/Core/Events/Message.swift` | 3.1, 6.3, 8.1 |
| `/Sources/Core/Events/MessagePublisher.swift` | 3.3, 5.3, 8.1 |
| `/Sources/Features/Docs/DocumentDetailView.swift` | 4.1, 4.3 |
| `/Sources/Features/Agents/AgentProfileView.swift` | 5.2 |
| `/Sources/Features/Feed/Components/FeedSearchBar.swift` | 6.2 |

---

## Estimated Timeline

| Phase | Estimated Effort | Dependencies |
|-------|------------------|--------------|
| Phase 1 | 2-3 days | None |
| Phase 2 | 3-4 days | Phase 1 |
| Phase 3 | 2-3 days | None |
| Phase 4 | 2-3 days | None |
| Phase 5 | 2-3 days | None |
| Phase 6 | 1-2 days | None |
| Phase 7 | 3-4 days | Phase 3, Phase 4 |
| Phase 8 | 1-2 days | Phase 1, Phase 2 |

**Recommended Order:** Phases 1 & 2 first (enables image features), then 3-6 in parallel based on priority, then 7-8.

**Total Estimated Effort:** 16-24 days for a single developer

---

## Notes

- All Svelte references are at `/Users/pablofernandez/10x/TENEX-Web-Svelte-ow3jsn/main/src/`
- iOS codebase is at `/Users/pablofernandez/Work/TENEX-iOS-Client-cawc6h/`
- Follow existing patterns in CLAUDE.md for NDK subscriptions
- Use `@MainActor @Observable` pattern for view models
- Prefer feature-based organization as specified in CLAUDE.md
