# Message Truncation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add message truncation for content exceeding 50vh with fade gradient and expandable sheet view.

**Architecture:** Wrap MessageContentView with TruncatedContentView that measures height and applies truncation. ExpandedMessageSheet presents full message with author context in modal.

**Tech Stack:** SwiftUI, GeometryReader, PreferenceKey, Sheet presentation

---

## Task 1: Create ContentHeightPreferenceKey

**Files:**
- Create: `Sources/Features/Chat/TruncatedContentView.swift`

**Step 1: Create file with preference key**

Create the preference key for measuring content height:

```swift
//
// TruncatedContentView.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import SwiftUI

// MARK: - ContentHeightPreferenceKey

/// Preference key for measuring content height
struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

**Step 2: Commit**

```bash
git add Sources/Features/Chat/TruncatedContentView.swift
git commit -m "feat: add preference key for content height measurement"
```

---

## Task 2: Implement TruncatedContentView

**Files:**
- Modify: `Sources/Features/Chat/TruncatedContentView.swift`

**Step 1: Add TruncatedContentView struct**

Add the main truncation wrapper view:

```swift
// MARK: - TruncatedContentView

/// Wraps content and truncates it with fade gradient if exceeds maxHeight
struct TruncatedContentView<Content: View>: View {
    // MARK: Lifecycle

    init(content: Content, maxHeight: CGFloat) {
        self.content = content
        self.maxHeight = maxHeight
    }

    // MARK: Internal

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxHeight: isTruncated ? maxHeight : nil, alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    if isTruncated {
                        fadeGradient
                    }
                }
                .background(heightReader)
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    contentHeight = height
                }

            if isTruncated {
                showMoreButton
            }
        }
    }

    // MARK: Private

    private let content: Content
    private let maxHeight: CGFloat

    @State private var contentHeight: CGFloat = 0
    @State private var isShowingSheet = false

    private var isTruncated: Bool {
        contentHeight > maxHeight
    }

    private var fadeGradient: some View {
        LinearGradient(
            colors: [.clear, Color(uiColor: .systemBackground)],
            startPoint: .init(x: 0.5, y: 0.7),
            endPoint: .bottom
        )
        .frame(height: maxHeight * 0.3)
        .allowsHitTesting(false)
    }

    private var heightReader: some View {
        GeometryReader { geo in
            Color.clear.preference(
                key: ContentHeightPreferenceKey.self,
                value: geo.size.height
            )
        }
    }

    private var showMoreButton: some View {
        Button {
            isShowingSheet = true
        } label: {
            Text("Show more")
                .font(.subheadline)
                .foregroundStyle(.blue)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(uiColor: .systemBackground))
                .cornerRadius(8)
        }
        .padding(.bottom, 8)
    }
}
```

**Step 2: Build to verify compilation**

```bash
tuist generate
xcodebuild -workspace TENEXClient.xcworkspace -scheme TENEXClient -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add Sources/Features/Chat/TruncatedContentView.swift
git commit -m "feat: implement TruncatedContentView with height measurement and fade gradient"
```

---

## Task 3: Create ExpandedMessageSheet

**Files:**
- Create: `Sources/Features/Chat/ExpandedMessageSheet.swift`

**Step 1: Create sheet view file**

Create the expanded message modal sheet:

```swift
//
// ExpandedMessageSheet.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//

import NDKSwiftCore
import NDKSwiftUI
import SwiftUI
import TENEXCore

// MARK: - ExpandedMessageSheet

/// Modal sheet displaying full message content with author context
struct ExpandedMessageSheet: View {
    // MARK: Lifecycle

    init(message: Message) {
        self.message = message
    }

    // MARK: Internal

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    messageHeader

                    Divider()

                    MessageContentView(message: message)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: Private

    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk

    private let message: Message

    private var messageHeader: some View {
        HStack(spacing: 12) {
            if let ndk {
                NDKUIProfilePicture(ndk: ndk, pubkey: message.pubkey, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                if let ndk {
                    NDKUIDisplayName(ndk: ndk, pubkey: message.pubkey)
                        .font(.headline)
                }
                Text(message.createdAt.formatted())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top)
    }
}
```

**Step 2: Build to verify compilation**

```bash
xcodebuild -workspace TENEXClient.xcworkspace -scheme TENEXClient -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: Build succeeds with no errors

**Step 3: Commit**

```bash
git add Sources/Features/Chat/ExpandedMessageSheet.swift
git commit -m "feat: add ExpandedMessageSheet for full message viewing"
```

---

## Task 4: Integrate TruncatedContentView with MessageRow

**Files:**
- Modify: `Sources/Features/Chat/MessageRow.swift`

**Step 1: Read MessageRow to find MessageContentView usage**

Look for the line with `MessageContentView(message: self.message)` in the `messageContent` computed property.

**Step 2: Wrap MessageContentView with TruncatedContentView**

In `MessageRow.swift`, find this line (around line 89):

```swift
MessageContentView(message: self.message)
```

Replace it with:

```swift
TruncatedContentView(
    content: MessageContentView(message: self.message),
    maxHeight: UIScreen.main.bounds.height * 0.5
)
```

**Step 3: Build to verify compilation**

```bash
xcodebuild -workspace TENEXClient.xcworkspace -scheme TENEXClient -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: Build succeeds with no errors

**Step 4: Commit**

```bash
git add Sources/Features/Chat/MessageRow.swift
git commit -m "feat: integrate TruncatedContentView with MessageRow"
```

---

## Task 5: Connect ExpandedMessageSheet to TruncatedContentView

**Files:**
- Modify: `Sources/Features/Chat/TruncatedContentView.swift`

**Step 1: Add message parameter to TruncatedContentView**

The TruncatedContentView needs to know about the message to pass to the sheet. Update the struct:

```swift
struct TruncatedContentView<Content: View>: View {
    // MARK: Lifecycle

    init(content: Content, maxHeight: CGFloat, message: Message) {
        self.content = content
        self.maxHeight = maxHeight
        self.message = message
    }

    // ... existing code ...

    // MARK: Private

    private let content: Content
    private let maxHeight: CGFloat
    private let message: Message  // Add this

    // ... rest of existing code ...
}
```

**Step 2: Add sheet presentation**

Update the `body` to include sheet:

```swift
var body: some View {
    ZStack(alignment: .bottom) {
        content
            .frame(maxHeight: isTruncated ? maxHeight : nil, alignment: .top)
            .clipped()
            .overlay(alignment: .bottom) {
                if isTruncated {
                    fadeGradient
                }
            }
            .background(heightReader)
            .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                contentHeight = height
            }

        if isTruncated {
            showMoreButton
        }
    }
    .sheet(isPresented: $isShowingSheet) {
        ExpandedMessageSheet(message: message)
    }
}
```

**Step 3: Update MessageRow to pass message**

In `MessageRow.swift`, update the TruncatedContentView call:

```swift
TruncatedContentView(
    content: MessageContentView(message: self.message),
    maxHeight: UIScreen.main.bounds.height * 0.5,
    message: self.message
)
```

**Step 4: Add import for TENEXCore**

At the top of `TruncatedContentView.swift`, add:

```swift
import TENEXCore
```

**Step 5: Build to verify compilation**

```bash
xcodebuild -workspace TENEXClient.xcworkspace -scheme TENEXClient -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

Expected: Build succeeds with no errors

**Step 6: Commit**

```bash
git add Sources/Features/Chat/TruncatedContentView.swift Sources/Features/Chat/MessageRow.swift
git commit -m "feat: connect ExpandedMessageSheet to TruncatedContentView"
```

---

## Task 6: Manual Testing

**Files:**
- None (testing only)

**Step 1: Generate and run app**

```bash
tuist generate
```

Open the workspace and run on simulator:
- Select iPhone 16 Pro simulator
- Build and run (Cmd+R)

**Step 2: Test short message (no truncation)**

Navigate to a conversation with short messages:
- Verify no "Show more" button appears
- Verify no fade gradient visible
- Messages display normally

**Step 3: Test long message (with truncation)**

Find or create a message longer than 50vh:
- Verify fade gradient appears at bottom
- Verify "Show more" button is visible
- Tap "Show more"
- Verify sheet opens with full message
- Verify author avatar and name appear
- Verify timestamp appears
- Verify full content is scrollable
- Tap "Done" to dismiss
- Verify returns to chat view

**Step 4: Test different message types**

Test truncation with:
- Regular markdown text
- Code blocks (triple backticks)
- Reasoning blocks
- Tool calls

Verify all types truncate consistently.

**Step 5: Test orientation change**

- Rotate simulator (Cmd+Left/Right)
- Verify truncation threshold adjusts (50vh changes with screen height)
- Messages that were truncated may become not truncated (or vice versa)

**Step 6: Document test results**

Create test results file:

```bash
cat > docs/plans/2025-12-16-message-truncation-test-results.md << 'EOF'
# Message Truncation Test Results

Date: 2025-12-16

## Short Messages
- ✅ No truncation UI shown
- ✅ Messages display normally

## Long Messages
- ✅ Fade gradient appears
- ✅ "Show more" button visible
- ✅ Sheet opens with full content
- ✅ Author context displayed
- ✅ Content scrollable
- ✅ Dismisses correctly

## Message Types
- ✅ Markdown text
- ✅ Code blocks
- ✅ Reasoning blocks
- ✅ Tool calls

## Orientation
- ✅ Threshold adjusts with screen height
- ✅ Truncation updates on rotation

## Issues Found
None

EOF
```

**Step 7: Commit test results**

```bash
git add docs/plans/2025-12-16-message-truncation-test-results.md
git commit -m "docs: add manual test results for message truncation"
```

---

## Task 7: Create Pull Request

**Files:**
- None (git operations only)

**Step 1: Push branch**

```bash
git push -u origin feature/message-truncation
```

**Step 2: Create PR using gh CLI**

```bash
gh pr create --title "feat: add message truncation with expandable sheet" --body "$(cat <<'EOF'
## Summary

Adds truncation for messages exceeding 50vh with fade gradient and expandable sheet view.

**Changes:**
- ✅ TruncatedContentView wraps message content
- ✅ Fade gradient indicates truncated content
- ✅ "Show more" button opens full message sheet
- ✅ ExpandedMessageSheet shows author context + full content
- ✅ All message types supported

**Testing:**
- ✅ Manual testing on iPhone 16 Pro simulator
- ✅ Verified short/long messages
- ✅ Verified all message types
- ✅ Verified orientation changes

**Design:** See `docs/plans/2025-12-16-message-truncation-design.md`

**Test Results:** See `docs/plans/2025-12-16-message-truncation-test-results.md`
EOF
)"
```

**Step 3: Verify PR created**

```bash
gh pr view --web
```

Expected: PR opens in browser with all details

---

## Completion Checklist

- [ ] ContentHeightPreferenceKey created
- [ ] TruncatedContentView implemented
- [ ] ExpandedMessageSheet created
- [ ] Integration with MessageRow complete
- [ ] Sheet connected to truncation view
- [ ] Manual testing complete
- [ ] Test results documented
- [ ] PR created and ready for review

## Notes for Engineer

**Architecture decisions:**
- 50vh threshold = `UIScreen.main.bounds.height * 0.5`
- GeometryReader used only for measurement, not rendering
- Fade gradient is last 30% of visible content
- Sheet uses NavigationView for toolbar/title
- All message types handled uniformly

**Common issues:**
- If fade doesn't show: Check Color(uiColor: .systemBackground) matches your theme
- If height wrong: Verify GeometryReader in background, not overlay
- If button hidden: Check ZStack alignment and padding
- If sheet doesn't open: Verify @State and sheet modifier present

**Code style:**
- Follow existing MessageRow patterns
- Use MARK comments for organization
- Import only what's needed
- Use computed properties for complex views
