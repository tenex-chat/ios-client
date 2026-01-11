# iOS Feature Gap Analysis
## Svelte Web Client vs iOS Client Comparison

**Analysis Date:** January 2026
**Scope:** Features added to Svelte client in the past 3 weeks vs iOS implementation status

---

## SVELTE NEW FEATURES (past 3 weeks) vs iOS STATUS

### 1. AI Image Generation with Provider Integration
**Svelte:** OpenRouter image generation with Blossom upload integration for AI-generated images.

| Status | Notes |
|--------|-------|
| :x: Missing | iOS has OpenRouter model discovery (`OpenRouterModelsResponse.swift`, `ModelDiscoveryService.swift`) but no image generation capability. No Blossom upload integration exists. |

**Implementation needed:**
- Add image generation request to OpenRouter API
- Implement Blossom upload client
- Create UI for image generation in chat

---

### 2. Multi-Question Ask Events (Poll/Survey)
**Svelte:** Tabbed multi-question UI with single/multi-select options for ask tool responses.

| Status | Notes |
|--------|-------|
| :x: Missing | iOS has basic `hasAskTag` detection in `Message.swift` and handles ask events in inbox priority sorting (`DataStore.swift`), but no multi-question parsing or tabbed UI. |

**Implementation needed:**
- Parse ask tool multi-question format from event tags
- Create tabbed question UI component
- Implement single/multi-select answer input
- Update InboxRow to display multi-question previews

---

### 3. Drag & Drop Image Attachments to Chat
**Svelte:** Visual drag-drop with upload progress for image attachments.

| Status | Notes |
|--------|-------|
| :x: Missing | No drag-drop (`onDrop`, `dropDestination`) or image attachment handling found in `ChatInputView.swift` or related files. |

**Implementation needed:**
- Add `onDrop` modifier to chat input area
- Implement image upload progress UI
- Integrate with Blossom for image hosting
- Handle image insertion in message content

---

### 4. Long-Press to Open Conversations in Detached Window
**Svelte:** UX enhancement for opening conversations in separate windows.

| Status | Notes |
|--------|-------|
| :warning: Partial | iOS has `DetachedConversationWindow.swift` and `WindowManagerStore.swift` for window management, but long-press gesture handling needs verification. |

**Implementation needed:**
- Verify long-press gesture on conversation rows triggers detached window
- Ensure consistent behavior across iPad/Mac Catalyst

---

### 5. Hierarchical Nesting for Delegated Conversations
**Svelte:** Visual hierarchy in thread list showing parent-child delegation relationships.

| Status | Notes |
|--------|-------|
| :warning: Partial | iOS has excellent delegation support: `DelegateToolRenderer.swift`, `DelegationPreview.swift` with progress tracking, todo items, and navigation. But no hierarchical nesting in thread list view. |

**Implementation needed:**
- Add parent-child delegation tracking to `ThreadSummary`
- Implement indented/nested display in `ThreadListView`
- Visual indicators for delegation depth

---

### 6. Conversation ID Search in Global Search
**Svelte:** 64-char hex event ID lookup in global search.

| Status | Notes |
|--------|-------|
| :x: Missing | `FeedSearchBar.swift` and `FeedTabViewModel.swift` search by content, title, hashtags only. No hex event ID detection or lookup. |

**Implementation needed:**
- Detect 64-char hex pattern in search input
- Fetch event by ID when pattern detected
- Navigate to conversation when found

---

### 7. Detached Window State Persistence
**Svelte:** Window positions/sizes restored on app relaunch.

| Status | Notes |
|--------|-------|
| :warning: Partial | `WindowManagerStore.swift` exists but window position/size persistence needs verification. |

**Implementation needed:**
- Verify window frame persistence in UserDefaults/AppStorage
- Restore window positions on app launch

---

### 8. Document Version Diff View
**Svelte:** Fade animation and version comparison for documents.

| Status | Notes |
|--------|-------|
| :x: Missing | `DocumentDetailView.swift` shows single document view with markdown rendering, author info, hashtags. No version history or diff functionality. |

**Implementation needed:**
- Fetch document version history (by dTag)
- Implement diff algorithm for content comparison
- Create visual diff UI with fade/highlight animations
- Add version selector in document view

---

### 9. Swimlane Delegation Visualization
**Svelte:** D3-based flow diagrams for delegation visualization.

| Status | Notes |
|--------|-------|
| :x: Missing | `DelegationPreview.swift` shows card-based delegation status but no flow diagram. Voice visualizations exist (`VoiceVisualizerView.swift`) but are unrelated. |

**Implementation needed:**
- Design SwiftUI-based flow diagram component
- Map delegation relationships to swimlane layout
- Animate delegation flow and status changes

---

### 10. Lessons Feature with Comments
**Svelte:** Full lesson management with commenting system.

| Status | Notes |
|--------|-------|
| :x: Missing | No lesson-related files found in iOS codebase. |

**Implementation needed:**
- Define Lesson model and event type
- Create LessonsTabView and LessonDetailView
- Implement comment subscription and publishing
- Add lesson CRUD operations

---

### 11. Blossom Image Upload in Chat
**Svelte:** Native image hosting via Blossom protocol.

| Status | Notes |
|--------|-------|
| :x: Missing | No Blossom integration found. |

**Implementation needed:**
- Implement Blossom upload client
- Add image picker to chat input
- Handle upload progress and error states
- Insert image URL in message content

---

### 12. "Only by Me" Global Filter
**Svelte:** Filter by current user across views.

| Status | Notes |
|--------|-------|
| :white_check_mark: Implemented | `ThreadFiltersStore.swift` has `onlyByMeFilters` with `isOnlyByMeEnabled()` and `toggleOnlyByMe()`. `RecentConversationsFilterStore.swift` has dedicated "Only by me" filter. Fully implemented. |

---

### 13. "Send in New Conversation" Message Action
**Svelte:** Copy message to start a new thread.

| Status | Notes |
|--------|-------|
| :x: Missing | `MessageRow.swift` context menu has Reply, Quote, Copy Content, Copy Raw Event, Copy ID, View Raw Event - but no "Send in New Conversation" action. |

**Implementation needed:**
- Add context menu item "Send in New Conversation"
- Extract message content and start new thread with it
- Navigate to new thread after creation

---

### 14. Image Attachment Preview Component
**Svelte:** Attachment preview system before sending.

| Status | Notes |
|--------|-------|
| :x: Missing | No attachment preview in `ChatInputView.swift`. No image handling in chat input flow. |

**Implementation needed:**
- Create AttachmentPreviewView component
- Show image thumbnail with remove button
- Display upload state (pending/uploading/complete)

---

### 15. Inline Image Lightbox Viewer
**Svelte:** Fullscreen zoom/download for inline images.

| Status | Notes |
|--------|-------|
| :x: Missing | `NDKMarkdown` renders content but no custom image tap handling for lightbox. |

**Implementation needed:**
- Intercept image taps in markdown content
- Create fullscreen image viewer overlay
- Add zoom, pan, and download functionality

---

## SVELTE ARCHITECTURAL CHANGES vs iOS

### 1. Centralized Store Pattern
**Svelte:** ProjectsStore, ReportsStore, ConversationMetadataStore, OperationsStatusStore

| Status | Notes |
|--------|-------|
| :white_check_mark: Implemented | iOS has comprehensive centralized store: `DataStore.swift` manages projects, agents, tools, projectStatuses, nudges, recentConversationReplies, inboxMessages, activeOperations. `ProjectConversationStore.swift` handles per-project conversations. `ThreadFiltersStore.swift`, `RecentConversationsFilterStore.swift` for filters. Strong centralized pattern. |

---

### 2. NDK Subscription Callback Modernization
**Svelte:** onEvent/onEvents pattern for subscription callbacks.

| Status | Notes |
|--------|-------|
| :white_check_mark: Implemented | iOS uses async `for await events in subscription.events` pattern throughout `DataStore.swift`. CLAUDE.md documents this pattern extensively with clear anti-patterns. Modern async/await approach. |

---

### 3. Loading State Anti-Pattern Removal
**Svelte:** Event-driven, no EOSE-based loading states.

| Status | Notes |
|--------|-------|
| :white_check_mark: Implemented | `DataStore.swift` uses simple `isLoadingProjects`, `isLoadingAgents` flags set at subscription start, cleared with `defer`. No EOSE-based loading. Event-driven updates via subscription streams. |

---

### 4. Global Status Dashboard
**Svelte:** Kanban-style status grouping for project status.

| Status | Notes |
|--------|-------|
| :x: Missing | `ProjectStatusDebugView.swift` shows debug info. `ProjectStatus` model exists with agent status tracking. No Kanban-style dashboard UI. |

**Implementation needed:**
- Create StatusDashboardView with Kanban columns
- Group projects/conversations by status
- Drag-drop for status changes (if applicable)

---

## BACKEND API CHANGES Requiring iOS Updates

### 1. Ask Tool Multi-Question Format
**Backend:** New tag structure for multi-question asks.

| Status | Notes |
|--------|-------|
| :x: Missing | `Message.swift` detects `hasAskTag` but doesn't parse multi-question structure. |

**Implementation needed:**
- Parse question array from ask tool tags
- Handle single-select vs multi-select response types
- Store and display question metadata

---

### 2. Delegation Tag Addition
**Backend:** Parent-child tracking via delegation tags.

| Status | Notes |
|--------|-------|
| :warning: Partial | `DelegationPreview.swift` tracks delegation by event reference, shows agent, progress, status. May need verification of new tag format. |

**Implementation needed:**
- Verify parsing of new delegation tag format
- Update `ProjectConversationStore` for parent-child indexing

---

### 3. conversation_get Tool Results Optional
**Backend:** includeToolResults parameter for fetching conversation content.

| Status | Notes |
|--------|-------|
| :x: Missing | No tool result filtering found. iOS fetches full events. |

**Implementation needed:**
- If iOS calls conversation_get, add includeToolResults parameter
- Handle optional tool results in response parsing

---

### 4. Cross-Agent Report Access
**Backend:** Project-scoped reports accessible across agents.

| Status | Notes |
|--------|-------|
| :x: Missing | No reports feature found in iOS. |

**Implementation needed:**
- Define Report model
- Add reports subscription to DataStore
- Create ReportsTabView with cross-agent visibility

---

### 5. Multimodal Image URL Support
**Backend:** Image URLs in messages for multimodal AI.

| Status | Notes |
|--------|-------|
| :x: Missing | `Message.swift` and `MessagePublisher.swift` handle text content. No imeta tags or image URL extraction. |

**Implementation needed:**
- Parse imeta tags for image metadata
- Display inline images in message content
- Send image URLs with messages for multimodal context

---

### 6. fs_glob & fs_grep Tool Support
**Backend:** Replacing codebase_search with new tools.

| Status | Notes |
|--------|-------|
| :warning: Partial | `CodebaseSearchToolRenderer.swift` renders codebase_search. `ToolDisplayUtils.swift` categorizes Glob, Grep under search. Tool renderers exist for search category but specific fs_glob/fs_grep renderers may be needed. |

**Implementation needed:**
- Verify fs_glob and fs_grep display in existing search renderer
- Add specific parameter handling if needed (pattern, path, etc.)

---

### 7. LLM Usage Tracking
**Backend:** Token/cost in tool events.

| Status | Notes |
|--------|-------|
| :x: Missing | No LLM token/cost tracking found. |

**Implementation needed:**
- Parse usage data from tool result events
- Create usage display component (per-message or aggregated)
- Optional: Add cost breakdown in settings/debug view

---

## PRIORITY MATRIX

### High Priority (Core Functionality Gaps)
1. Blossom Image Upload (enables image features)
2. Multi-Question Ask Events (user interaction)
3. Document Version Diff View (document management)
4. Lessons Feature (new content type)
5. Multimodal Image URL Support (AI capability)

### Medium Priority (UX Improvements)
6. Image Attachment Preview
7. Inline Image Lightbox
8. Drag & Drop Image Attachments
9. "Send in New Conversation" Action
10. Conversation ID Search

### Lower Priority (Visual Enhancements)
11. Swimlane Delegation Visualization
12. Global Status Dashboard (Kanban)
13. Hierarchical Nesting in Thread List

### Already Implemented
- "Only by Me" Global Filter
- Centralized Store Pattern
- NDK Subscription Modernization
- Loading State Anti-Pattern Removal
- Delegation Preview/Tracking (partial)
- Detached Window Support (partial)
- fs_glob/fs_grep Display (partial)

---

## LEGEND

| Symbol | Meaning |
|--------|---------|
| :white_check_mark: | Fully implemented in iOS |
| :warning: | Partially implemented - needs enhancement |
| :x: | Missing from iOS - needs implementation |
