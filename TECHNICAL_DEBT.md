# Technical Debt and Inconsistencies Report

This report identifies technical debt and inconsistencies in the `tenex-ios` codebase, using the `PLAN.md` specifications (which reflect the `tenex-chat/web-svelte` design) as the reference.

## 1. UI/UX Inconsistencies with Design Reference

### 1.1 Project List (`ProjectListView.swift`)
- **Deviation from Plan**: The implementation uses `.listStyle(.plain)` with hidden separators, while `PLAN.md` initially called for `.insetGrouped`. Although `PLAN.md` notes this change, the "flat" appearance might not fully align with the intricate "Project avatar: 56pt, 12pt corner radius" and "Online indicator: 16pt green dot with 3pt border" spec if not carefully implemented.
- **Missing Elements**:
  - The "Online indicator: 16pt green dot with 3pt border" specified in Milestone 1 is not visible in `ProjectRow`.
  - "Unread message badge" and "Online agent indicator" are listed as TODOs in `PLAN.md` but implementation is missing in `ProjectRow`.

### 1.2 Project Detail / Thread List (`ProjectDetailView.swift`)
- **Icon Toolbar**: The `tabToolbar` implementation uses standard SF Symbols (`message.fill`, `doc.fill`, etc.) which may not match the "Icon toolbar matching web app design" specific icons if the web app uses custom SVGs or specific icon sets.
- **Tabs Placeholder**: `docs`, `agents`, and `feed` tabs render a "Coming Soon" view. This is acceptable for Milestone 2 but represents incomplete feature parity with the web reference.
- **Header**: The "Online agent count" is hardcoded to "0 agents online" and the indicator is a simple green circle. This relies on `ProjectStatus` integration which appears incomplete.

### 1.3 Chat View (`ChatView.swift` & `MessageRow.swift`)
- **Scroll Behavior**: `ChatView` uses a simple `ScrollView` without `ScrollViewReader` or `defaultScrollAnchor`. This means it won't automatically scroll to the newest message, which is standard chat behavior (and likely how the web app works).
- **Code Blocks**: `MessageRow` implements a custom regex-based parser for code blocks. This is fragile and lacks syntax highlighting ("Code block display with syntax highlighting" is a Milestone 3 deliverable). The web app likely uses a robust library like `highlight.js`.
- **Avatars**: Uses `Image(systemName: "person.circle.fill")` as a placeholder. It should load user/agent profile images (Milestone 3 "Avatar, name, timestamp display").

## 2. Technical Debt

### 2.1 Hardcoded Values & Strings
- **UI Strings**: Many user-facing strings are hardcoded in views (e.g., "No Messages Yet", "Loading messages...", "Agent", "You"). These should be localized.
- **Colors**: Colors like `.blue` for agents and `.green` for online status are hardcoded. They should be defined in a semantic color palette (e.g., `Color.tenex.agentMessage`) to ensure consistency and dark mode support matching the web theme.

### 2.2 Performance
- **Regex in View Body**: `MessageRow` performs regex matching (`splitByCodeBlocks`) inside the `body` computation. This is computationally expensive and will cause scroll hitching in long threads. This logic should be moved to the ViewModel or a background task, producing a structured model for the view to render.
- **List Rendering**: `ChatView` uses `ForEach` inside a `ScrollView`. For very long chat histories, this will instantiate all rows. `LazyVStack` should be considered, though it has trade-offs with bi-directional scrolling.

### 2.3 Architecture & Patterns
- **User Identification**: `MessageRow` determines if a message is from an "Agent" by checking `currentUserPubkey != nil && message.pubkey != currentUserPubkey`. This is brittle. It implies that *anyone* who isn't the current user is an "Agent", which is incorrect for multi-user chats. The system needs a robust way to identify Agents (likely via `kind:4199` metadata).
- **Incomplete Models**: `ProjectAgent` is parsed from status tags but `AgentDefinition` (kind:4199) is missing. The system conflates "online status presence" with "agent definition".

### 2.4 Error Handling
- **Silenced Errors**: `MessageRow` uses `try? AttributedString(markdown:)` which silences markdown parsing errors.
- **Alerts**: `ChatView` and `ProjectListView` use basic alerts for errors. A more robust error presentation (toasts or inline banners) would better match a "professional-grade" app.

## 3. Recommendations

1.  **Fix Scroll Behavior**: Implement `ScrollViewReader` in `ChatView` to handle auto-scrolling.
2.  **Refactor Message Parsing**: Move markdown/code block parsing out of `MessageRow` body into `ChatViewModel` or a dedicated parser that runs asynchronously.
3.  **Implement Real Agent Identity**: Check `kind:4199` or specific profile metadata to distinguish Agents from other Users, rather than "not me = agent".
4.  **Externalize Resources**: Move strings to `Localizable.strings` and colors to an asset catalog or `Color+Extension`.
5.  **Syntax Highlighting**: Integrate a Swift syntax highlighting library for code blocks to match the web experience.
