# TENEX iOS/macOS Implementation Plan

> **Last Updated:** 2025-12-12
> **Current Milestone:** 0 - Foundation
> **Status:** Setting up project infrastructure

## Overview

TENEX is a professional, production-grade iOS and macOS client for the TENEX decentralized AI agent orchestration platform built on Nostr. This plan provides comprehensive milestones for building the app using TDD, with clear deliverables, testing requirements, and subagent coordination.

## Architecture Principles

### Non-Negotiables
- **TDD First**: Write tests before implementation. Red → Green → Refactor.
- **Feature-based organization**: Code organized by feature, not by type.
- **Strict concurrency**: Full Swift 6 concurrency checking enabled.
- **No backwards compatibility hacks**: Clean, modern code only.
- **Direct NDK usage**: No unnecessary wrappers around NDKSwift.
- **Offline-first**: Leverage NDKSwift's local-first architecture with NostrDB cache.
- **NostrDB over SQLite**: Use NDKSwiftNostrDB adapter for local caching.

### Module Structure
```
Sources/
├── App/                    # App entry, lifecycle, dependency injection
├── Core/                   # Infrastructure (NDK, Auth, Cache, Events)
├── Features/               # Feature modules (Projects, Chat, Voice, etc.)
└── Shared/                 # Reusable components, extensions, utilities
```

### Testing Strategy
| Layer | Tool | Purpose |
|-------|------|---------|
| Unit | Swift Testing | Business logic, view models, data transformations |
| Integration | Swift Testing | NDK integration, event handling, subscriptions |
| UI (E2E) | Maestro | Full user flows, regression testing |
| Snapshot | swift-snapshot-testing | UI component visual regression |

---

## Milestone Status Tracking

### How to Update This Plan

When working on this codebase (whether human or agent), follow this protocol:

1. **Before starting work:**
   - Read this entire PLAN.md
   - Check the "Current Status" section for the active milestone
   - Review "Known Issues & Blockers" for anything affecting your work

2. **During work:**
   - Update the status log in the current milestone section
   - Note any deviations from the plan with reasoning
   - Document any new issues discovered

3. **After completing work:**
   - Mark completed tasks with ✅ and date
   - Update "Current Milestone" and "Status" in the header
   - Add entry to "Change Log" at the bottom
   - Commit this file with your changes

### Status Log Format
```
[YYYY-MM-DD HH:MM] <agent-id or name>
- What was done
- Deviations from plan (if any)
- Blockers encountered (if any)
- Next recommended action
```

---

## Milestone 0: Foundation

**Goal:** Establish bulletproof project infrastructure with quality gates.

**Duration:** 1-2 days

### Deliverables

#### 0.1 Project Setup ✅
- [x] Initialize git repository
- [x] Create Tuist project structure
- [x] Configure multi-platform targets (iOS 17+, macOS 14+)
- [x] Set up module structure (Core, Features, Shared)
- [ ] Verify Tuist generates valid Xcode project

#### 0.2 Quality Gates
- [ ] SwiftLint configuration with strict rules
- [ ] SwiftFormat configuration matching project style
- [ ] Git hooks (pre-commit) for linting and formatting
- [ ] Git hooks (pre-push) for running tests
- [ ] Branch protection rules documented

#### 0.3 CI/CD Pipeline
- [ ] GitHub Actions workflow for PR checks
- [ ] Automated test running on all PRs
- [ ] Build verification for iOS and macOS
- [ ] Maestro test integration in CI

#### 0.4 Testing Infrastructure
- [ ] Swift Testing framework configured
- [ ] Test helper utilities created
- [ ] Mock/stub infrastructure for NDK
- [ ] Maestro flows directory structure
- [ ] First Maestro smoke test (app launches)

#### 0.5 NDKSwift Integration
- [ ] NDKSwift package resolved and building (using NDKSwiftNostrDB adapter)
- [ ] Basic NDK instance creation test with NostrDB cache
- [ ] Verify relay connection works
- [ ] Document NDKSwift patterns we'll use

> **Note:** Use `NDKSwiftNostrDB` adapter (not SQLite) for the local cache. NostrDB is more performant and purpose-built for Nostr events.

### Tests Required
```
Tests/CoreTests/
├── NDKIntegrationTests.swift      # Verify NDK connects to relays
└── CacheTests.swift               # Verify caching layer works

Maestro/flows/
└── 00_app_launches.yaml           # App launches without crash
```

### Acceptance Criteria
- [ ] `tuist generate` produces valid Xcode project
- [ ] `tuist test` runs all unit tests
- [ ] Git hooks prevent commits with lint errors
- [ ] CI pipeline runs on every PR
- [ ] App builds for both iOS Simulator and macOS

### Status Log
```
[2025-12-12 14:30] claude-opus
- Created initial project structure with Tuist
- Set up module hierarchy (Core, Features, Shared)
- Created PLAN.md with comprehensive milestones
- Next: Complete quality gates setup
```

---

## Milestone 1: Authentication & Project List

**Goal:** Users can sign in and see their projects.

**Duration:** 3-4 days

**Depends on:** Milestone 0

### Deliverables

#### 1.1 Authentication
- [ ] Auth manager with session persistence (Keychain)
- [ ] Private key (nsec) sign-in flow
- [ ] NIP-46 Bunker sign-in flow
- [ ] Biometric unlock (Face ID / Touch ID)
- [ ] Sign-out functionality
- [ ] Session restoration on app launch

#### 1.2 Project List
- [ ] Project model matching kind:31933 schema
- [ ] Project subscription with NDKSwift
- [ ] Project list view (iPhone layout)
- [ ] Deterministic HSL color generation for projects
- [ ] Unread message badge
- [ ] Online agent indicator
- [ ] Pull-to-refresh
- [ ] Swipe-to-archive gesture

#### 1.3 Navigation Shell
- [ ] Navigation stack for iPhone
- [ ] Tab bar (if needed) or navigation-based
- [ ] Deep linking foundation
- [ ] State restoration

### Tests Required
```
Tests/CoreTests/
├── Auth/
│   ├── AuthManagerTests.swift         # Session management
│   ├── KeychainStorageTests.swift     # Secure storage
│   └── NIP46BunkerTests.swift         # Remote signing
└── Events/
    └── ProjectEventTests.swift        # Project parsing

Tests/FeaturesTests/Projects/
├── ProjectListViewModelTests.swift    # List logic
├── ProjectColorTests.swift            # HSL generation
└── ProjectSubscriptionTests.swift     # NDK subscription

Maestro/flows/
├── 01_login_nsec.yaml                 # Sign in with nsec
├── 01_login_bunker.yaml               # Sign in with bunker
├── 01_logout.yaml                     # Sign out
└── 01_project_list.yaml               # View project list
```

### UI Specifications
Reference: `/Users/pablofernandez/10x/tenex-ios-mockups/iphone.html` (Screen 1: Project List)

- List with `.insetGrouped` style
- Project avatar: 56pt, 12pt corner radius, HSL color
- Online indicator: 16pt green dot with 3pt border
- Title: 17pt semibold
- Subtitle: 15pt secondary color
- Unread badge: Blue pill, 12pt text

### Acceptance Criteria
- [ ] Can sign in with nsec and see projects
- [ ] Projects load from Nostr relays
- [ ] Tapping project navigates to thread list (placeholder)
- [ ] App remembers login between launches
- [ ] All unit tests pass
- [ ] Maestro flows pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 2: Thread List & Basic Navigation

**Goal:** Users can view threads within a project with the icon toolbar.

**Duration:** 3-4 days

**Depends on:** Milestone 1

### Deliverables

#### 2.1 Thread List
- [ ] Thread model matching kind:11 schema
- [ ] Thread subscription per project
- [ ] Thread list view with tabs (Threads/Docs/Agents/Feed)
- [ ] Icon toolbar matching web app design
- [ ] Project header with colored tint
- [ ] Thread row with collapsed reply preview
- [ ] Avatar stack for reply participants
- [ ] Phase indicator pills
- [ ] Swipe-to-archive

#### 2.2 Project Status Integration
- [ ] Subscribe to kind:24010 (ProjectStatus) events
- [ ] Parse online agents from status
- [ ] Display agent count in header

#### 2.3 Tab Content (Placeholder)
- [ ] Docs tab placeholder
- [ ] Agents tab placeholder
- [ ] Feed tab placeholder

### Tests Required
```
Tests/CoreTests/Events/
├── ThreadEventTests.swift             # Thread parsing
└── ProjectStatusEventTests.swift      # Status parsing

Tests/FeaturesTests/Threads/
├── ThreadListViewModelTests.swift     # List logic
├── ThreadSubscriptionTests.swift      # NDK subscription
└── ReplyPreviewTests.swift            # Collapsed replies

Maestro/flows/
├── 02_thread_list.yaml                # View thread list
├── 02_tab_navigation.yaml             # Switch between tabs
└── 02_swipe_archive.yaml              # Archive a thread
```

### UI Specifications
Reference: `/Users/pablofernandez/10x/tenex-ios-mockups/iphone.html` (Screen 2: Thread List)

- Project header with gradient tint (15% opacity of project HSL)
- Icon toolbar: 20pt icons, 8pt padding, active state with fill background
- Thread row: Title 14pt semibold, preview 13pt secondary
- Reply preview: "X replies" in blue, avatar stack 18pt each

### Acceptance Criteria
- [ ] Thread list loads for selected project
- [ ] Icon toolbar switches between tabs
- [ ] Online agent count displays correctly
- [ ] Tapping thread navigates to chat (placeholder)
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 3: Chat View & Messages

**Goal:** Users can view and send messages in Slack-style chat.

**Duration:** 4-5 days

**Depends on:** Milestone 2

### Deliverables

#### 3.1 Message Display
- [ ] Message model matching kind:1111 schema
- [ ] Message subscription per thread
- [ ] Slack-style message layout (left-aligned)
- [ ] User and agent message differentiation
- [ ] Avatar, name, timestamp display
- [ ] Markdown rendering in messages
- [ ] Code block display with syntax highlighting
- [ ] Streaming response support (kind:21111)
- [ ] Typing indicators (kind:24111/24112)

#### 3.2 Thread Replies (Collapsed)
- [ ] Build thread tree from messages
- [ ] Collapsed reply display ("X replies" + avatar stack + preview)
- [ ] Expand inline or open sheet
- [ ] Reply depth limiting (max 5)

#### 3.3 Chat Input
- [ ] Multi-line text input with auto-grow
- [ ] Agent selector pill (bottom, under input)
- [ ] Branch selector pill (bottom, under input)
- [ ] Attachment button (placeholder)
- [ ] Mic button (navigates to voice mode - placeholder)
- [ ] Send button with enabled/disabled states

#### 3.4 Message Sending
- [ ] Create kind:1111 reply events
- [ ] Proper e-tag and p-tag construction
- [ ] Optimistic UI updates
- [ ] Error handling for failed sends

### Tests Required
```
Tests/CoreTests/Events/
├── MessageEventTests.swift            # Message parsing
├── StreamingEventTests.swift          # Delta accumulation
└── ThreadBuilderTests.swift           # Tree construction

Tests/FeaturesTests/Chat/
├── ChatViewModelTests.swift           # Chat logic
├── MessageListTests.swift             # Display logic
├── ThreadCollapseTests.swift          # Collapse/expand
├── MessageSendingTests.swift          # Event creation
└── AgentSelectorTests.swift           # Agent selection

Maestro/flows/
├── 03_view_messages.yaml              # View chat messages
├── 03_send_message.yaml               # Send a message
├── 03_expand_thread.yaml              # Expand collapsed replies
└── 03_select_agent.yaml               # Change agent
```

### UI Specifications
Reference: `/Users/pablofernandez/10x/tenex-ios-mockups/iphone.html` (Screen 3: Chat View)

- Message avatar: 36pt circle
- Author name: 15pt semibold (blue for agents)
- Timestamp: 12pt tertiary
- Message text: 16pt primary, 1.4 line height
- Code block: Secondary background, SF Mono 13pt
- Input area: 20pt corner radius, auto-grow to 120pt max
- Selector pills: 14pt corner radius, 12pt text

### Acceptance Criteria
- [ ] Messages display in Slack-style layout
- [ ] Threaded replies collapse correctly
- [ ] Can send messages to selected agent
- [ ] Streaming responses animate in
- [ ] Agent/branch selectors work
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 4: Agent Integration

**Goal:** Full agent interaction with @mentions and agent list.

**Duration:** 3-4 days

**Depends on:** Milestone 3

### Deliverables

#### 4.1 Agent Models
- [ ] Agent definition model (kind:4199)
- [ ] Parse agent capabilities, instructions, tools
- [ ] Agent subscription for project

#### 4.2 Agent Selector
- [ ] Agent picker sheet/popover
- [ ] Show online agents with status
- [ ] Display model info per agent
- [ ] Remember last selected agent per thread

#### 4.3 @Mention Autocomplete
- [ ] Detect @ in input
- [ ] Filter online agents by name
- [ ] Autocomplete overlay above input
- [ ] Insert agent p-tag on selection

#### 4.4 Agents Tab
- [ ] Agent list/grid view
- [ ] Agent detail card
- [ ] Online/offline status
- [ ] Model and tool information

### Tests Required
```
Tests/CoreTests/Events/
└── AgentEventTests.swift              # Agent parsing

Tests/FeaturesTests/Agents/
├── AgentSelectorViewModelTests.swift  # Selection logic
├── MentionAutocompleteTests.swift     # @ detection
└── AgentListViewModelTests.swift      # List logic

Maestro/flows/
├── 04_select_agent.yaml               # Select agent from picker
├── 04_mention_agent.yaml              # @mention in message
└── 04_agents_tab.yaml                 # View agents tab
```

### Acceptance Criteria
- [ ] Can select agents from picker
- [ ] @mention autocomplete works
- [ ] Agents tab shows all project agents
- [ ] Messages route to correct agent
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 5: Voice Mode

**Goal:** Full voice conversation with agents using on-device speech.

**Duration:** 5-6 days

**Depends on:** Milestone 4

### Deliverables

#### 5.1 Speech Recognition
- [ ] SpeechAnalyzer integration (iOS 26+)
- [ ] WhisperKit fallback for older devices
- [ ] Device capability detection
- [ ] Microphone permission handling
- [ ] Real-time transcription

#### 5.2 Text-to-Speech
- [ ] AVSpeechSynthesizer integration
- [ ] Neural voice selection
- [ ] Per-agent voice configuration
- [ ] Speech queue management
- [ ] Interrupt handling

#### 5.3 Voice UI
- [ ] Full-screen voice mode view
- [ ] Agent avatar with pulse animation
- [ ] Audio waveform visualizer
- [ ] Live transcription display
- [ ] Status indicators (Listening/Processing/Speaking)
- [ ] Voice controls (mic, end call)

#### 5.4 Voice Conversation Flow
- [ ] VAD (Voice Activity Detection)
- [ ] Automatic turn-taking
- [ ] Transcription → Agent → TTS flow
- [ ] Save transcriptions to thread
- [ ] Return to chat with history

### Tests Required
```
Tests/CoreTests/
└── Voice/
    ├── SpeechRecognizerTests.swift    # STT logic
    ├── TTSManagerTests.swift          # TTS logic
    └── VoiceSessionTests.swift        # Session management

Tests/FeaturesTests/Voice/
├── VoiceModeViewModelTests.swift      # Voice UI logic
├── TranscriptionFlowTests.swift       # End-to-end flow
└── DeviceCapabilityTests.swift        # Fallback logic

Maestro/flows/
├── 05_enter_voice_mode.yaml           # Enter voice mode
├── 05_voice_conversation.yaml         # Full voice flow
└── 05_exit_voice_mode.yaml            # Exit back to chat
```

### UI Specifications
Reference: `/Users/pablofernandez/10x/tenex-ios-mockups/iphone.html` (Screen 4: Voice Mode)

- Agent avatar: 140pt with pulse rings
- Waveform: 10 bars, 4pt width, animated
- Status text: 15pt blue
- Transcription: 16pt, scrollable area
- Mic button: 80pt primary, 64pt secondary

### Acceptance Criteria
- [ ] Voice mode activates from chat
- [ ] Speech recognition works (SpeechAnalyzer or WhisperKit)
- [ ] TTS plays agent responses
- [ ] Conversation persists to thread
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 6: iPad & macOS Adaptation

**Goal:** Three-pane layout for larger screens.

**Duration:** 4-5 days

**Depends on:** Milestone 5

### Deliverables

#### 6.1 Adaptive Layout
- [ ] Detect device/window size
- [ ] NavigationSplitView for iPad/macOS
- [ ] Sidebar (projects), Content (threads), Detail (chat)
- [ ] Proper column widths (240pt, 320pt, flexible)
- [ ] Collapse behavior

#### 6.2 macOS Specifics
- [ ] Window chrome and title bar
- [ ] Keyboard shortcuts (⌘+Enter, ⌘+⇧+V, etc.)
- [ ] Menu bar integration
- [ ] Proper macOS styling

#### 6.3 iPad Specifics
- [ ] Slide-over support
- [ ] Split view support
- [ ] Keyboard shortcuts with external keyboard
- [ ] Pointer/trackpad support

#### 6.4 Voice Mode Adaptation
- [ ] Sheet presentation on iPad/macOS
- [ ] Floating panel option
- [ ] Keyboard dismiss handling

### Tests Required
```
Tests/FeaturesTests/
└── Layout/
    ├── AdaptiveLayoutTests.swift      # Size class detection
    └── NavigationTests.swift          # Navigation behavior

Maestro/flows/
├── 06_ipad_layout.yaml                # iPad three-pane
├── 06_keyboard_shortcuts.yaml         # Keyboard navigation
└── 06_voice_sheet.yaml                # Voice as sheet
```

### UI Specifications
Reference: `/Users/pablofernandez/10x/tenex-ios-mockups/ipad-macos.html`

### Acceptance Criteria
- [ ] Three-pane layout on iPad landscape
- [ ] Proper macOS window behavior
- [ ] Keyboard shortcuts work
- [ ] Voice mode as sheet/popover
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 7: Documents & Feed Tabs

**Goal:** Complete the remaining project tabs.

**Duration:** 3-4 days

**Depends on:** Milestone 6

### Deliverables

#### 7.1 Documents Tab
- [ ] Document list view
- [ ] Document viewer (markdown rendering)
- [ ] Create/edit documents (if applicable)

#### 7.2 Feed Tab
- [ ] Activity feed subscription
- [ ] Chronological event display
- [ ] Filter by event type

#### 7.3 Tool Rendering
- [ ] Tool call display in messages
- [ ] Collapsible tool output
- [ ] Syntax highlighting for code tools

### Tests Required
```
Tests/FeaturesTests/Documents/
└── DocumentViewModelTests.swift

Tests/FeaturesTests/Feed/
└── FeedViewModelTests.swift

Maestro/flows/
├── 07_documents_tab.yaml
└── 07_feed_tab.yaml
```

### Acceptance Criteria
- [ ] Documents tab displays project docs
- [ ] Feed shows project activity
- [ ] Tool outputs render correctly
- [ ] All tests pass

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Milestone 8: Polish & Production Readiness

**Goal:** Production-ready app with accessibility, performance, and polish.

**Duration:** 5-7 days

**Depends on:** Milestone 7

### Deliverables

#### 8.1 Performance
- [ ] Profile and optimize memory usage
- [ ] Optimize list performance (lazy loading)
- [ ] Image caching optimization
- [ ] Reduce app launch time
- [ ] Background fetch for messages

#### 8.2 Offline Support
- [ ] Leverage NDKSwift cache fully
- [ ] Offline message composition
- [ ] Sync status indicators
- [ ] Retry logic for failed sends

#### 8.3 Accessibility
- [ ] VoiceOver support
- [ ] Dynamic Type support
- [ ] High contrast mode
- [ ] Reduce Motion support

#### 8.4 Error Handling
- [ ] Comprehensive error states
- [ ] User-friendly error messages
- [ ] Retry actions
- [ ] Crash reporting integration

#### 8.5 App Store Preparation
- [ ] App icons (all sizes)
- [ ] Launch screen
- [ ] Screenshots for App Store
- [ ] Privacy policy
- [ ] App Store description

### Tests Required
```
Tests/
└── PerformanceTests/
    ├── LaunchTimeTests.swift
    └── MemoryTests.swift

Maestro/flows/
├── 08_offline_mode.yaml
├── 08_error_recovery.yaml
└── 08_accessibility.yaml
```

### Acceptance Criteria
- [ ] App performs smoothly on iPhone 15 baseline
- [ ] Works offline with graceful degradation
- [ ] Passes accessibility audit
- [ ] No crashes in production
- [ ] Ready for TestFlight

### Status Log
```
[YYYY-MM-DD HH:MM] <agent>
- Status updates go here
```

---

## Known Issues & Blockers

Track issues that affect development here:

| ID | Issue | Milestone | Status | Notes |
|----|-------|-----------|--------|-------|
| - | None yet | - | - | - |

---

## Change Log

Track significant changes to this plan:

| Date | Author | Change |
|------|--------|--------|
| 2025-12-12 | claude-opus | Initial plan creation with 8 milestones |

---

## Appendix A: Event Kind Reference

| Kind | Name | Usage |
|------|------|-------|
| 0 | Metadata | User profiles |
| 11 | Thread | Conversation roots |
| 1111 | GenericReply | Messages in threads |
| 21111 | StreamingResponse | Agent streaming deltas |
| 24010 | ProjectStatus | Agent/model online status |
| 24111 | TypingStart | Agent typing indicator |
| 24112 | TypingStop | Agent stopped typing |
| 31933 | Project | Project definitions |
| 4199 | AgentDefinition | Agent configurations |
| 513 | ConversationMetadata | Thread titles |

## Appendix B: File Naming Conventions

```
Sources/
├── Features/
│   └── Chat/
│       ├── ChatView.swift              # SwiftUI View
│       ├── ChatViewModel.swift         # @Observable view model
│       ├── ChatModels.swift            # Feature-specific models
│       └── Components/                 # Feature-specific components
│           └── MessageRow.swift

Tests/
└── FeaturesTests/
    └── Chat/
        ├── ChatViewModelTests.swift    # Test file mirrors source
        └── MessageRowTests.swift
```

## Appendix C: Subagent Workflow

See `CONTRIBUTING.md` for detailed subagent development workflow.
