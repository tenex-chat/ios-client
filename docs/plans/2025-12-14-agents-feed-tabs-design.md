# Agents and Feed Tabs Implementation Design

**Date:** 2025-12-14
**Status:** Approved

## Overview

Implement the Agents and Feed tabs in ProjectDetailView to complete the project's tabbed interface. The Agents tab shows online agents from ProjectStatus events, and the Feed tab shows all project events with search and filtering capabilities.

## Architecture

### Component Structure
```
ProjectDetailView (existing)
├── Threads Tab (existing - ThreadListView)
├── Docs Tab (coming soon placeholder)
├── Agents Tab → AgentsTabView (existing, wire up)
└── Feed Tab → FeedTabView (new)
    └── FeedTabViewModel (new)
```

### Offline-First Pattern

Following TENEX's offline-first architecture (per CLAUDE.md):
- No loading spinners or isLoading state
- Show cached data or empty state immediately
- Update arrays incrementally as events arrive
- Use seenEventIDs for deduplication
- Pattern: `if viewModel.events.isEmpty { emptyView } else { list }`

## Agents Tab

**Implementation:** Wire up existing AgentsTabView into ProjectDetailView.

**Change Required:**
- Replace "Coming Soon" placeholder in ProjectDetailView with AgentsTabView
- Pass project coordinate and NDK instance

**AgentsTabView Features (already implemented):**
- Shows online agents from kind:24010 ProjectStatus events
- Displays agent name, model, tools, and global badge
- Real-time subscription to status updates
- Empty state for no agents

## Feed Tab

### Data Model

**No wrapper model needed** - work directly with `NDKEvent` like Svelte implementation.

**Tag Value Extraction:**
```swift
// Title
let title = event.tagValue("title")

// Hashtags
let hashtags = event.tags(withName: "t").compactMap { $0[safe: 1] }

// Thread ID (for grouping)
let threadID = event.tagValue("E")
```

### FeedTabViewModel

**Observable Properties:**
```swift
@Observable
public final class FeedTabViewModel {
    // Event data
    public private(set) var events: [NDKEvent] = []

    // Search & Filter state
    public var searchQuery: String = ""
    public var selectedAuthor: String? = nil
    public var groupThreads: Bool = false

    // Derived computed properties
    public var filteredEvents: [NDKEvent]
    public var uniqueAuthors: [String]

    private var seenEventIDs: Set<String> = []
}
```

**Event Filtering:**
```swift
private func shouldIncludeEvent(_ event: NDKEvent) -> Bool {
    let kind = event.kind

    // Filter out kind 0 (metadata)
    if kind == 0 { return false }

    // Filter out ephemeral events (20000-29999)
    if kind >= 20_000 && kind <= 29_999 { return false }

    return true
}
```

**Subscription:**
```swift
func subscribe() async {
    let filter = NDKFilter(tags: ["a": [projectID]])
    let subscription = ndk.subscribeToEvents(filters: [filter])

    for try await event in subscription {
        guard !seenEventIDs.contains(event.id) else { continue }
        seenEventIDs.insert(event.id)

        if shouldIncludeEvent(event) {
            events.append(event)
            // SwiftUI reacts automatically
        }
    }
}
```

**Filtering Pipeline:**
1. Raw events from subscription
2. Filter by kind (exclude 0, 20000-29999)
3. Apply thread grouping if enabled (deduplicate by E tag, keep most recent)
4. Apply author filter if selected
5. Apply search query if not empty
6. Sort by created_at (newest first)

**Search Implementation:**
- Search event content (case-insensitive)
- Search article titles (kind 30023)
- Search thread titles (kind 11)
- Search hashtags (t tags)

**Thread Grouping:**
- When enabled, deduplicate by uppercase "E" tag value
- Keep only the most recent event per thread
- Events without E tags are not grouped

**Unique Authors:**
- Extract unique pubkeys from all events
- Limit to 15 authors
- Current user appears first if present

### FeedTabView UI

**View Structure:**
```
FeedTabView
├── Search Bar (only when events.isNotEmpty)
│   ├── Search TextField
│   ├── Clear button (when searchQuery.isNotEmpty)
│   └── Filter button (author picker + thread grouping toggle)
├── Event List (ScrollView with LazyVStack)
│   └── FeedEventRow components
└── Empty States
    ├── No events yet
    └── No search results
```

**Search Bar:**
- Search icon on left, clear button on right
- Filter button shows selected author avatar or filter icon
- Dropdown menu for author selection + thread grouping checkbox

**FeedEventRow:**
Displays based on event kind:
- **Kind 11 (thread):** Show thread title from title tag
- **Kind 30023 (article):** Show article title from title tag
- **Kind 1111 (message):** Show message content
- **Other kinds:** Show content
- All rows show: author avatar, name, timestamp, hashtags

**Empty States:**
- "No events yet" when events array is empty
- "No results found" when search returns nothing with clear search button

## File Structure

**New Files:**
```
Sources/Features/Feed/
├── FeedTabView.swift
├── FeedTabViewModel.swift
└── Components/
    ├── FeedSearchBar.swift
    ├── FeedEventRow.swift
    └── AuthorFilterMenu.swift

Tests/FeaturesTests/Feed/
├── FeedTabViewModelTests.swift
└── FeedEventRowTests.swift
```

**Modified Files:**
```
Sources/Features/Threads/ProjectDetailView.swift
```

## TDD Implementation Order

1. **FeedTabViewModelTests - Event Subscription**
   - Test subscribing to events with project a-tag
   - Test event deduplication by ID

2. **FeedTabViewModel - Basic Subscription**
   - Implement subscription logic
   - Implement deduplication

3. **FeedTabViewModelTests - Event Filtering**
   - Test filtering out kind 0
   - Test filtering out ephemeral events (20000-29999)
   - Test including valid kinds (11, 1111, 30023)

4. **FeedTabViewModel - Filtering Logic**
   - Implement shouldIncludeEvent()

5. **FeedTabViewModelTests - Search**
   - Test search matches content
   - Test search matches titles
   - Test search matches hashtags
   - Test case-insensitive matching

6. **FeedTabViewModel - Search Implementation**
   - Implement search filtering
   - Implement computed filteredEvents

7. **FeedTabViewModelTests - Author Filtering**
   - Test author filter works
   - Test unique authors extraction
   - Test authors limited to 15
   - Test current user appears first

8. **FeedTabViewModel - Author Filtering**
   - Implement author filtering
   - Implement uniqueAuthors computed property

9. **FeedTabViewModelTests - Thread Grouping**
   - Test grouping by E tag
   - Test keeping most recent per thread
   - Test preserving events without E tag

10. **FeedTabViewModel - Thread Grouping**
    - Implement thread deduplication logic

11. **FeedEventRowTests**
    - Test row displays title for kind 11
    - Test row displays title for kind 30023
    - Test row displays content for other kinds

12. **UI Components**
    - Create FeedTabView with empty state
    - Create FeedEventRow component
    - Create FeedSearchBar component
    - Create AuthorFilterMenu component

13. **Integration**
    - Wire up AgentsTabView in ProjectDetailView
    - Wire up FeedTabView in ProjectDetailView

14. **Manual Testing**
    - Test search functionality
    - Test author filtering
    - Test thread grouping toggle
    - Test navigation to threads/articles

## Test Coverage

**FeedTabViewModelTests:**
- ✓ Subscribe to events with project a-tag
- ✓ Deduplicate by event ID
- ✓ Filter out kind 0 (metadata)
- ✓ Filter out ephemeral events (20000-29999)
- ✓ Include valid event kinds
- ✓ Search matches event content
- ✓ Search matches article titles (kind 30023)
- ✓ Search matches thread titles (kind 11)
- ✓ Search matches hashtags (case-insensitive)
- ✓ Author filter works correctly
- ✓ Filtered events sorted by created_at (newest first)
- ✓ Unique authors limited to 15
- ✓ Current user appears first in author list
- ✓ Thread grouping keeps most recent per E tag
- ✓ Thread grouping preserves events without E tag

**FeedEventRowTests:**
- ✓ Displays thread title for kind 11
- ✓ Displays article title for kind 30023
- ✓ Displays content for kind 1111
- ✓ Displays content for other kinds
- ✓ Displays hashtags
- ✓ Displays author info
- ✓ Displays timestamp

## Git Workflow

1. Create git worktree for feature branch
2. Implement using TDD (tests first, then implementation)
3. Commit changes
4. Create pull request
5. Merge to master

## References

- Svelte implementation: `/Users/pablofernandez/10x/TENEX-Web-Svelte-ow3jsn/main/src/lib/components/feed/FeedTab.svelte`
- NDKSwift tagValue: `/Users/pablofernandez/10x/NDKSwift-z94ws0/master/Sources/NDKSwiftCore/Models/NDKEvent.swift`
- Existing AgentsTabView: `Sources/Features/Agents/AgentsTabView.swift`
