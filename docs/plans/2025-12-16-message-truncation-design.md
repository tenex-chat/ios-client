# Message Truncation Design

**Date:** 2025-12-16
**Status:** Approved for Implementation

## Overview

Add message truncation to the chat interface for messages exceeding 50vh in height, with expandable full-message view in a modal sheet.

## Requirements

- Messages longer than 50vh should be visually truncated
- Fade gradient indicates truncated content
- "Show more" button opens full message in sheet
- Sheet displays author context (avatar, name, timestamp) + full content
- Sheet is read-only (dismiss only, no actions)
- All message types support truncation (text, code blocks, reasoning, tool calls)

## Architecture

### Components

1. **TruncatedContentView** - Generic wrapper that measures content height and applies truncation
2. **ExpandedMessageSheet** - Modal sheet showing full message with author context
3. **MessageRow** - Modified to wrap MessageContentView with TruncatedContentView

### Design Principles

- Non-invasive: Wraps existing MessageContentView without internal changes
- Reusable: TruncatedContentView works with any content
- Clean separation: Truncation logic isolated from message rendering
- Maintains patterns: Fits naturally into current MessageRow structure

## Implementation Details

### TruncatedContentView

Wraps any SwiftUI content and handles truncation:

```swift
struct TruncatedContentView<Content: View>: View {
    let content: Content
    let maxHeight: CGFloat
    @State private var contentHeight: CGFloat = 0
    @State private var isShowingSheet = false

    var isTruncated: Bool {
        contentHeight > maxHeight
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            content
                .frame(maxHeight: isTruncated ? maxHeight : nil, alignment: .top)
                .clipped()
                .overlay(alignment: .bottom) {
                    if isTruncated {
                        LinearGradient(
                            colors: [.clear, Color(uiColor: .systemBackground)],
                            startPoint: .init(x: 0.5, y: 0.7),
                            endPoint: .bottom
                        )
                        .frame(height: maxHeight * 0.3)
                        .allowsHitTesting(false)
                    }
                }
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: geo.size.height
                        )
                    }
                )
                .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                    contentHeight = height
                }

            if isTruncated {
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
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
```

### ExpandedMessageSheet

Modal sheet with author context and full content:

```swift
struct ExpandedMessageSheet: View {
    let message: Message
    @Environment(\.dismiss) private var dismiss
    @Environment(\.ndk) private var ndk

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Message header with author context
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

                    Divider()

                    // Full message content (no truncation)
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
}
```

### Integration with MessageRow

In `MessageRow.swift`, wrap `MessageContentView`:

```swift
// Replace:
MessageContentView(message: self.message)

// With:
TruncatedContentView(
    content: MessageContentView(message: self.message),
    maxHeight: UIScreen.main.bounds.height * 0.5
)
```

## Height Calculation

Using `UIScreen.main.bounds.height * 0.5` provides 50vh equivalent:
- Simple and direct
- Works across all device sizes
- Respects orientation changes
- No complex GeometryReader propagation

## Edge Cases

1. **Streaming messages**: Height measured continuously, truncation applies when threshold exceeded
2. **Code blocks**: Wrapped and measured like any content
3. **Reasoning blocks**: Same treatment as regular content
4. **Consecutive messages**: Each message measured independently
5. **Sheet presentation**: Standard SwiftUI sheet with automatic dismiss gestures

## Performance

- **GeometryReader**: Only for height measurement, not rendering path
- **Lazy rendering**: LazyVStack still works, truncation per-message
- **Sheet laziness**: ExpandedMessageSheet created only when needed
- **Gradient overlay**: Lightweight, GPU-accelerated

## File Changes

- **New**: `Sources/Features/Chat/TruncatedContentView.swift`
- **New**: `Sources/Features/Chat/ExpandedMessageSheet.swift`
- **Modified**: `Sources/Features/Chat/MessageRow.swift`

## Testing Considerations

- Test with messages of varying lengths (short, exactly 50vh, >50vh)
- Test all message types (text, code blocks, reasoning, tool calls)
- Test orientation changes
- Test streaming messages becoming truncated
- Test sheet presentation/dismissal
