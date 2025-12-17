# Operations Status & Stop Command Support

**Date:** 2025-12-17
**Status:** Approved

## Overview

Add support for kind 24133 (Operations Status) and kind 24134 (Stop Command) to the iOS client, enabling users to see which agents are actively working and stop them.

## Event Specifications

| Kind | Name | Direction | Purpose |
|------|------|-----------|---------|
| 24133 | Operations Status | Incoming | Backend broadcasts which agents are working on which events |
| 24134 | Stop Command | Outgoing | Client requests to stop agent operations |

### Kind 24133 (Operations Status)
- **Tags:** `a` (project ref), `e` (event ID), `p` (0..n agent pubkeys), `P` (user pubkey for routing)
- **Content:** Empty
- **Behavior:** Last-write-wins; empty `p` tags = no active agents

### Kind 24134 (Stop Command)
- **Tags:** `a` (project ref), `e` (event ID), optional `p` (specific agent pubkey)
- **Content:** Empty
- **Behavior:** Omit `p` tag to stop all agents on the event

## Architecture

### Global State (DataStore)

DataStore maintains a single global subscription to 24133 events tagged for the current user:

```swift
// Active operations: eventId -> Set of agent pubkeys
public private(set) var activeOperations: [String: Set<String>] = [:]

func subscribeToOperationsStatus(userPubkey: String) async {
    let filter = NDKFilter(
        kinds: [24133],
        tags: ["P": Set([userPubkey])]
    )

    let subscription = ndk.subscribe(filter: filter)

    for await events in subscription.events {
        for event in events {
            handleOperationsStatus(event)
        }
    }
}

private func handleOperationsStatus(_ event: NDKEvent) {
    guard let eventId = event.tagValue("e") else { return }
    let agentPubkeys = Set(event.tags(withName: "p").compactMap { $0.count > 1 ? $0[1] : nil })
    activeOperations[eventId] = agentPubkeys
}
```

### Stop Command Publishing (MessagePublisher)

```swift
/// Publish a stop command (kind 24134) to halt agent operations
public func publishStopCommand(
    ndk: NDK,
    projectRef: String,
    eventId: String,
    agentPubkey: String? = nil
) async throws {
    let event = NDKEvent()
    event.kind = 24134
    event.content = ""
    event.tags = [
        ["a", projectRef],
        ["e", eventId]
    ]

    if let agentPubkey {
        event.tags.append(["p", agentPubkey])
    }

    try await ndk.publish(event)
}
```

### UI Component (ActiveAgentsView)

New file: `Sources/Features/Chat/ActiveAgentsView.swift`

```swift
struct ActiveAgentsView: View {
    @Environment(NDK.self) private var ndk
    @Environment(DataStore.self) private var dataStore

    let eventId: String
    let projectReference: String
    let onlineAgents: [ProjectAgent]

    var activeAgentPubkeys: Set<String> {
        dataStore.activeOperations[eventId] ?? []
    }

    var activeAgents: [ProjectAgent] {
        onlineAgents.filter { activeAgentPubkeys.contains($0.pubkey) }
    }

    var body: some View {
        if !activeAgents.isEmpty {
            HStack(spacing: 8) {
                ForEach(activeAgents, id: \.pubkey) { agent in
                    agentButton(agent)
                }
                stopAllButton
            }
        }
    }

    @ViewBuilder
    private func agentButton(_ agent: ProjectAgent) -> some View {
        Button {
            Task { await stopAgent(agent.pubkey) }
        } label: {
            // Agent avatar with X overlay on press
        }
    }

    private var stopAllButton: some View {
        Button {
            Task { await stopAgent(nil) }
        } label: {
            Image(systemName: "stop.circle")
        }
    }

    private func stopAgent(_ pubkey: String?) async {
        try? await MessagePublisher().publishStopCommand(
            ndk: ndk,
            projectRef: projectReference,
            eventId: eventId,
            agentPubkey: pubkey
        )
    }
}
```

### ChatView Integration

Embed ActiveAgentsView near the input/compose area:

```swift
ActiveAgentsView(
    eventId: viewModel.threadID ?? "",
    projectReference: projectReference,
    onlineAgents: onlineAgents
)
```

## Component Responsibilities

| Component | Responsibility |
|-----------|---------------|
| **DataStore** | Global 24133 subscription, stores `activeOperations` map |
| **MessagePublisher** | Publishes kind 24134 stop commands |
| **ActiveAgentsView** | Reads from DataStore, displays active agents, triggers stop |
| **ChatView** | Embeds ActiveAgentsView near input area |
| **ConversationState** | Unchanged - stays focused on messages/streaming |

## Subscription Lifecycle

The global 24133 subscription starts when the user authenticates:

```swift
// In DataStore, called after authentication
func startGlobalSubscriptions(userPubkey: String) async {
    // Existing subscriptions...

    Task {
        await subscribeToOperationsStatus(userPubkey: userPubkey)
    }
}
```

## Files to Create/Modify

**New:**
- `Sources/Features/Chat/ActiveAgentsView.swift`

**Modify:**
- `Sources/Core/DataStore.swift` - Add `activeOperations` state and subscription
- `Sources/Core/Events/MessagePublisher.swift` - Add `publishStopCommand()`
- `Sources/Features/Chat/ChatView.swift` - Embed ActiveAgentsView

## Reference Implementation

Web client files for reference:
- `src/lib/ndk-events/operations.ts` - Parse 24133, publish 24134
- `src/lib/stores/activeOperations.svelte.ts` - Reactive subscription
- `src/lib/components/chat/ActiveAgents.svelte` - UI component
