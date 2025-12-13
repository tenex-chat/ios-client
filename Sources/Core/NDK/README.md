# NDKSwift Patterns for TENEX

This document provides code-focused patterns for using NDKSwift in the TENEX iOS/macOS client.

## Table of Contents

- [Initialization](#initialization)
- [Connection](#connection)
- [Subscriptions](#subscriptions)
- [Publishing Events](#publishing-events)
- [Event Handling](#event-handling)
- [Cache Usage](#cache-usage)
- [Filters](#filters)
- [Signers](#signers)

---

## Initialization

### In-Memory Cache (Development/Testing)

```swift
import NDKSwift

let cache = NDKInMemoryCache()
let ndk = NDK(
    relayURLs: [
        "wss://relay.damus.io",
        "wss://nos.lol"
    ],
    cache: cache
)
```

### File Cache (Production - Persistent)

```swift
import NDKSwift

do {
    let cache = try NDKFileCache(path: "tenex-cache")
    let ndk = NDK(
        relayURLs: [
            "wss://relay.damus.io",
            "wss://nos.lol",
            "wss://relay.nostr.band"
        ],
        cache: cache
    )
} catch {
    print("Cache initialization failed: \(error)")
}
```

### With Signer (Authentication)

```swift
import NDKSwift

// From nsec string
let signer = try NDKPrivateKeySigner(nsec: "nsec1...")
let ndk = NDK(
    relayURLs: ["wss://relay.damus.io"],
    signer: signer,
    cache: NDKInMemoryCache()
)

// From hex private key
let signer = try NDKPrivateKeySigner(privateKey: "hex_private_key")
```

---

## Connection

### Connect to Relays

```swift
// Connect to all configured relays
await ndk.connect()
```

### Disconnect from Relays

```swift
// Disconnect from all relays
await ndk.disconnect()
```

### Add Relay Dynamically

```swift
let relay = ndk.addRelay("wss://relay.snort.social")
```

### Observe Relay Connection State

```swift
if let relay = ndk.relays.first {
    relay.observeConnectionState { state in
        switch state {
        case .disconnected:
            print("Disconnected")
        case .connecting:
            print("Connecting...")
        case .connected:
            print("Connected!")
        case .disconnecting:
            print("Disconnecting...")
        case .failed(let error):
            print("Failed: \(error)")
        }
    }
}
```

### Check Connection Status

```swift
let connectedRelays = ndk.pool.connectedRelays()
print("Connected to \(connectedRelays.count) relays")
```

---

## Subscriptions

### Modern Pattern: AsyncSequence (Recommended)

Subscriptions return an `AsyncSequence` of events. This is the preferred pattern for continuous event streams.

```swift
// Create subscription
let filter = NDKFilter(
    kinds: [31933], // Project events
    authors: [userPubkey],
    limit: 50
)

let subscription = ndk.subscribe(filters: [filter])

// Consume events using for-await
for await event in subscription {
    print("Received event: \(event.id ?? "unknown")")
    handleEvent(event)
}
```

### One-Shot Fetch (Fetch and Close)

Use `fetchEvents` when you need events once and don't want continuous updates:

```swift
let filter = NDKFilter(
    kinds: [11], // Thread events
    tags: ["d": Set(["project-id"])],
    limit: 100
)

let events = try await ndk.fetchEvents(filters: [filter])
print("Fetched \(events.count) events")
```

### Fetch Single Event

```swift
let filter = NDKFilter(ids: [eventId])
if let event = try await ndk.fetchEvent(filter: filter) {
    print("Found event: \(event.content)")
}
```

### Subscription with Options

```swift
var options = NDKSubscriptionOptions()
options.closeOnEose = true  // Close after EOSE
options.useCache = true     // Check cache first
options.limit = 50          // Max events

let subscription = ndk.subscribe(
    filters: [filter],
    options: options
)
```

### Stop Subscription

```swift
// Subscription automatically closes when for-await loop exits
// Or explicitly close:
await subscription.close()
```

---

## Publishing Events

### Sign and Publish

```swift
// Create event
let event = NDKEvent(
    pubkey: "", // Will be set by signer
    kind: 1111, // GenericReply
    tags: [
        ["e", rootEventId, "", "root"],
        ["p", recipientPubkey]
    ],
    content: "Hello from TENEX!"
)

// Sign and publish (signer must be configured on NDK)
do {
    let publishedRelays = try await ndk.publish(event)
    print("Published to \(publishedRelays.count) relays")
} catch {
    print("Publish failed: \(error)")
}
```

### Publish to Specific Relays

```swift
let relayURLs: Set<String> = [
    "wss://relay.damus.io",
    "wss://nos.lol"
]

let publishedRelays = try await ndk.publish(
    event: event,
    to: relayURLs
)
```

### Manual Event Creation

```swift
// Create event manually
let event = NDKEvent(
    pubkey: userPubkey,
    createdAt: Timestamp(Date().timeIntervalSince1970),
    kind: 31933, // Project
    tags: [
        ["d", "unique-project-id"],
        ["title", "My Project"]
    ],
    content: "{\"description\": \"Project details\"}"
)

// Generate ID
try event.generateID()

// Sign with signer
if let signer = ndk.signer {
    let signature = try await signer.sign(event)
    event.sig = signature
}

// Publish
try await ndk.publish(event)
```

---

## Event Handling

### Working with Tags

```swift
// Add tags
event.addTag(["e", eventId, relayUrl, "reply"])
event.addTag(["p", pubkey])
event.addTag(["t", "nostr"])

// Get tags by name
let eTags = event.tags(withName: "e")
let pTags = event.tags(withName: "p")

// Tag a user
let user = NDKUser(pubkey: recipientPubkey)
event.tag(user: user, marker: "mention")

// Check relationships
if event.isReply {
    print("Reply to: \(event.replyEventId ?? "unknown")")
}

// Get referenced IDs
print("Referenced events: \(event.referencedEventIds)")
print("Referenced pubkeys: \(event.referencedPubkeys)")
```

### Validate Event

```swift
do {
    try event.validate()
    print("Event is valid")
} catch {
    print("Invalid event: \(error)")
}
```

### Track Publish Status

```swift
// Check which relays accepted the event
print("Published to: \(event.successfullyPublishedRelays)")
print("Failed on: \(event.failedPublishRelays)")

// Check if published to any relay
if event.wasPublished {
    print("Event was successfully published")
}

// Check relay OK messages
for (relay, okMessage) in event.relayOKMessages {
    print("\(relay): \(okMessage.accepted ? "✓" : "✗") \(okMessage.message ?? "")")
}
```

---

## Cache Usage

### Cache Strategy

NDKSwift cache automatically stores events during subscriptions. Both `NDKInMemoryCache` and `NDKFileCache` implement the same `NDKCacheAdapter` protocol.

### Cache-First Pattern (Default)

```swift
var options = NDKSubscriptionOptions()
options.useCache = true // Check cache first, then relays
options.cacheStrategy = .cacheFirst

let subscription = ndk.subscribe(filters: [filter], options: options)
```

### Relay-Only Pattern

```swift
var options = NDKSubscriptionOptions()
options.useCache = false // Skip cache, fetch from relays only
options.cacheStrategy = .relayOnly

let subscription = ndk.subscribe(filters: [filter], options: options)
```

### Manual Cache Access

```swift
// Cache automatically stores events from subscriptions
// No manual cache operations needed for typical use cases

// Clear cache (if needed)
if let cache = ndk.cache as? NDKInMemoryCache {
    await cache.clear()

    // Get statistics
    let stats = await cache.statistics()
    print("Cached events: \(stats.events)")
    print("Cached profiles: \(stats.profiles)")
}
```

### Profile Caching

```swift
// Fetch user profile (automatically cached)
let user = ndk.getUser(pubkey)
if let profile = try await user.fetchProfile() {
    print("Name: \(profile.name ?? "Unknown")")
    print("About: \(profile.about ?? "")")
}

// Force refresh (bypass cache)
if let profile = try await user.fetchProfile(forceRefresh: true) {
    print("Fresh profile: \(profile.displayName ?? "Unknown")")
}
```

---

## Filters

### Basic Filters

```swift
// By kind
let filter = NDKFilter(kinds: [1, 6, 7])

// By authors
let filter = NDKFilter(
    authors: [pubkey1, pubkey2],
    kinds: [1111]
)

// By IDs
let filter = NDKFilter(ids: [eventId1, eventId2])

// With time range
let filter = NDKFilter(
    kinds: [31933],
    since: Timestamp(Date().timeIntervalSince1970 - 86400), // Last 24 hours
    limit: 50
)
```

### Tag Filters

```swift
// Filter by 'd' tag (parameterized replaceable events)
var filter = NDKFilter(kinds: [31933])
filter.addTagFilter("d", values: ["project-id"])

// Filter by 'p' tag (referenced pubkeys)
filter.addTagFilter("p", values: [pubkey])

// Using tags parameter
let filter = NDKFilter(
    kinds: [11],
    tags: ["a": Set(["31933:pubkey:project-id"])]
)
```

### Combined Filters

```swift
let filter = NDKFilter(
    authors: [userPubkey],
    kinds: [11, 1111],
    since: Timestamp(Date().timeIntervalSince1970 - 3600),
    limit: 100
)
filter.addTagFilter("e", values: [rootEventId])
```

### Check Filter Matches

```swift
if filter.matches(event: event) {
    print("Event matches filter")
}
```

---

## Signers

### Private Key Signer

```swift
// From nsec
let signer = try NDKPrivateKeySigner(nsec: "nsec1...")

// From hex private key
let signer = try NDKPrivateKeySigner(privateKey: "hex_private_key")

// Generate new key
let signer = try NDKPrivateKeySigner.generate()

// Get pubkey
let pubkey = try await signer.pubkey
print("Pubkey: \(pubkey)")

// Get npub
let npub = try signer.npub
print("Npub: \(npub)")
```

### Sign Event

```swift
// Sign event (automatically generates ID if needed)
let signature = try await signer.sign(event)
event.sig = signature

// Or use NDK to sign and publish
event.ndk = ndk
try await event.sign() // Uses NDK's configured signer
```

### Encryption (NIP-04/NIP-44)

```swift
// Check encryption support
let schemes = await signer.encryptionEnabled()
print("Supports: \(schemes)") // [.nip04, .nip44]

// Encrypt message
let recipient = NDKUser(pubkey: recipientPubkey)
let encrypted = try await signer.encrypt(
    recipient: recipient,
    value: "Secret message",
    scheme: .nip44
)

// Decrypt message
let sender = NDKUser(pubkey: senderPubkey)
let decrypted = try await signer.decrypt(
    sender: sender,
    value: encrypted,
    scheme: .nip44
)
```

---

## Complete Example: Subscribe and Publish

```swift
import NDKSwift

actor MessageHandler {
    func handle(_ event: NDKEvent) {
        print("📩 \(event.pubkey): \(event.content)")
    }
}

@main
struct TENEXExample {
    static func main() async {
        // Initialize
        let cache = NDKInMemoryCache()
        let signer = try! NDKPrivateKeySigner(nsec: "nsec1...")
        let ndk = NDK(
            relayURLs: [
                "wss://relay.damus.io",
                "wss://nos.lol"
            ],
            signer: signer,
            cache: cache
        )

        // Connect
        await ndk.connect()

        // Subscribe to messages
        let filter = NDKFilter(
            kinds: [1111], // GenericReply
            tags: ["p": Set([try! await signer.pubkey])],
            limit: 50
        )

        let handler = MessageHandler()
        let subscription = ndk.subscribe(filters: [filter])

        Task {
            for await event in subscription {
                await handler.handle(event)
            }
        }

        // Publish a message
        let event = NDKEvent(
            kind: 1111,
            tags: [["p", recipientPubkey]],
            content: "Hello from TENEX!"
        )

        do {
            let relays = try await ndk.publish(event)
            print("✅ Published to \(relays.count) relays")
        } catch {
            print("❌ Publish failed: \(error)")
        }

        // Keep running
        try? await Task.sleep(for: .seconds(60))
        await ndk.disconnect()
    }
}
```

---

## Notes

### Key Differences from Other SDKs

1. **No `fetchEvents` method**: Use `subscribe` with `closeOnEose: true` or the convenience `fetchEvents()` method
2. **AsyncSequence-based**: Modern Swift concurrency patterns
3. **Automatic cache integration**: Events are automatically cached during subscriptions
4. **Relay pool management**: NDK automatically manages relay connections and reconnections

### Best Practices

1. **Use AsyncSequence for continuous streams**: `for await event in subscription { }`
2. **Use fetchEvents for one-shot queries**: `let events = try await ndk.fetchEvents(filters: [filter])`
3. **Cache automatically stores events**: No manual cache operations needed
4. **Always await ndk.connect()**: Before subscribing or publishing
5. **Handle connection state**: Observe relay connection state for UI updates
6. **Close subscriptions**: Subscriptions auto-close when for-await exits, or call `await subscription.close()`

### Common Patterns

```swift
// Pattern: Fetch once on view load
let events = try await ndk.fetchEvents(filters: [filter])

// Pattern: Subscribe for live updates
for await event in ndk.subscribe(filters: [filter]) {
    updateUI(with: event)
}

// Pattern: Publish with error handling
do {
    try await ndk.publish(event)
} catch {
    showError(error)
}
```
