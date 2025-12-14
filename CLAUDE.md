- the svelte reference implementation client (which matches what we're building in this ios client is /Users/pablofernandez/10x/TENEX-Web-Svelte-ow3jsn/main/ -- the backend we communicate with from the ios and svelte clients is /Users/pablofernandez/10x/TENEX-ff3ssq/master/

## NDKSwift Subscription Patterns

### CRITICAL: How NDK Subscriptions Work

`ndk.subscribe()` returns `NDKSubscription<T>` which is `@Observable` with a `.data` property.

**DO NOT:**
- ❌ Manually iterate with `for await event in subscription` to build arrays
- ❌ Create ViewModels that just wrap subscriptions in local arrays
- ❌ Manually deduplicate events with `contains(where:)`
- ❌ Manually sort on every event with `array.sort()`
- ❌ Use `Task {}` blocks to manage subscription iteration

**NDKSubscription ALREADY provides:**
- ✅ Observable `.data` array (auto-updates SwiftUI)
- ✅ Automatic deduplication (via Set<String>)
- ✅ Batched MainActor updates (prevents UI flickering)
- ✅ Thread safety
- ✅ Memory management

### Correct Patterns

**Pattern 1: Direct in SwiftUI View (PREFERRED)**
```swift
struct FeedView: View {
    let ndk: NDK
    @State private var subscription: NDKSubscription<NDKEvent>?

    var sortedEvents: [NDKEvent] {
        subscription?.data.sorted { $0.createdAt > $1.createdAt } ?? []
    }

    var body: some View {
        List {
            ForEach(sortedEvents, id: \.id) { event in
                EventRow(event: event)
            }
        }
        .onAppear {
            subscription = ndk.subscribe(
                filter: NDKFilter(kinds: [1], limit: 50)
            )
        }
    }
}
```

**Pattern 2: ViewModel ONLY if adding business logic**
```swift
@MainActor
@Observable
final class FeedViewModel {
    private let ndk: NDK
    private(set) var subscription: NDKSubscription<NDKEvent>?

    // Only add computed properties if they add VALUE
    var filteredEvents: [NDKEvent] {
        subscription?.data.filter { /* complex filter logic */ } ?? []
    }

    init(ndk: NDK) {
        self.ndk = ndk
    }

    func start() {
        subscription = ndk.subscribe(filter: NDKFilter(kinds: [1]))
    }
}
```

**WRONG - Antipattern to NEVER repeat:**
```swift
// ❌ DON'T DO THIS
@Observable
final class BadViewModel {
    private(set) var events: [NDKEvent] = []  // ❌ Duplicate state!

    func subscribe() async {
        let sub = ndk.subscribeToEvents(filters: [filter])
        for try await event in sub {  // ❌ Manual iteration!
            guard !events.contains(where: { $0.id == event.id }) else { continue }  // ❌ Manual dedup!
            events.append(event)  // ❌ Manual management!
            events.sort { $0.createdAt > $1.createdAt }  // ❌ O(n log n) per event!
        }
    }
}
```

### Decision Tree

**Do you need to reactively display events in SwiftUI?**
- YES → Use `subscription.data` directly in View or expose `subscription` from ViewModel
- NO → Continue

**Do you need to process events as they arrive (logging, side effects)?**
- YES → Use `for await event in subscription.events`
- NO → Continue

**Do you need to collect a bounded set of events once?**
- YES → Use `await subscription.collect(timeout:limit:)`
- NO → You probably want the first case

### Key Rule

**If you're creating an `@Observable` class with an array property that you manually populate from NDK events, you're doing it wrong.**

Just expose the `NDKSubscription` itself - it's already observable with a `.data` property.