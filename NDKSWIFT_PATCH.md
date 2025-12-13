# NDKSwift Thread Safety Patch

## Issue
The app was crashing with `EXC_CRASH (SIGABRT)` and "unrecognized selector" errors in `NDKSubscription.handleEvent()` at line 298.

**Root Cause**: Race condition in NDKSwift v0.4.0 - the `seenEventIds` Set was being accessed from multiple threads without synchronization, causing memory corruption.

## Crash Details
- **Location**: `NDKSubscription.swift:298` in `NDKSwift.framework`
- **Error**: `Set.contains(_:)` triggered Objective-C message forwarding to an invalid object
- **Cause**: Concurrent access to unsynchronized Set from multiple relay connections

## Applied Fix
Applied a local patch to `/Tuist/.build/checkouts/NDKSwift/Sources/NDKSwift/Subscription/NDKSubscription.swift`:

### 1. Added Thread-Safe Actor (after line 39)
```swift
/// Actor for thread-safe event deduplication
actor EventDeduplicationActor {
    private var seenEventIds: Set<String> = []

    func hasSeenEvent(_ eventId: String) -> Bool {
        seenEventIds.contains(eventId)
    }

    func markEventAsSeen(_ eventId: String) {
        seenEventIds.insert(eventId)
    }
}
```

### 2. Replaced Unsafe Set with Actor Instance (line 120)
```swift
// OLD (line 108):
private var seenEventIds: Set<EventID> = []

// NEW (line 120-121):
/// Event deduplication - thread-safe actor
private let deduplicationActor = EventDeduplicationActor()
```

### 3. Updated handleEvent Method (lines 305-329)
```swift
/// Handle an event received from a relay
public func handleEvent(_ event: NDKEvent, fromRelay relay: RelayProtocol?) {
    guard state != .closed else { return }

    guard let eventId = event.id else { return }

    // Deduplicate event using thread-safe actor
    Task {
        let alreadySeen = await deduplicationActor.hasSeenEvent(eventId)
        guard !alreadySeen else {
            return // Already seen
        }
        await deduplicationActor.markEventAsSeen(eventId)

        // Check if event matches our filters
        guard filters.contains(where: { $0.matches(event: event) }) else {
            return
        }

        // Continue with event processing
        await processMatchedEvent(event, fromRelay: relay)
    }
}

/// Process an event that has passed deduplication and filter checks
private func processMatchedEvent(_ event: NDKEvent, fromRelay relay: RelayProtocol?) async {
    // [rest of event processing logic]
}
```

## Why Not Update to Newer NDKSwift?
Attempted to update to v0.7.17, v0.9.1, and v0.14.x, but all have Swift Package Manager dependency resolution issues:
- v0.7.17+: Depends on unstable `swift-secp256k1` package
- v0.14.x: Depends on unstable `cashuswift` or local packages

The latest NDKSwift (v0.14.2+) has this fix built-in using a similar Actor pattern, but cannot be used due to these dependency conflicts.

## Maintenance
This patch is applied to the checked-out NDKSwift code in `/Tuist/.build/checkouts/NDKSwift/`.

**IMPORTANT**: This patch will be **lost if you run `tuist clean` or delete the build cache**. After any clean operation, you must:
1. Run `tuist install` to re-download dependencies
2. Re-apply this patch to `Tuist/.build/checkouts/NDKSwift/Sources/NDKSwift/Subscription/NDKSubscription.swift`
3. Rebuild the project

## Future Resolution
Monitor NDKSwift releases for:
1. A stable version (v0.15+) that includes the thread-safety fix
2. Resolution of the dependency issues
3. Then update `Tuist/Package.swift` to use the newer version and remove this patch

## Verification
Build succeeded on 2025-12-13 after applying this patch. The app should no longer crash with the "unrecognized selector" error during subscription event handling.
