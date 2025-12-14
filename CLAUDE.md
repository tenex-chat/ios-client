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

**Pattern 3: Event Processing (non-UI, background tasks)**
```swift
@MainActor
@Observable
final class DataStore {
    private let ndk: NDK
    private(set) var projects: [Project] = []

    func subscribeToProjects(userPubkey: String) async {
        let filter = Project.filter(for: userPubkey)
        let subscription = ndk.subscribe(filter: filter)

        var projectsByID: [String: Project] = [:]
        var projectOrder: [String] = []

        // Use subscription.events for async stream processing
        for await event in subscription.events {
            if let project = Project.from(event: event) {
                if projectsByID[project.id] == nil {
                    projectOrder.append(project.id)
                }
                projectsByID[project.id] = project
                projects = projectOrder.compactMap { projectsByID[$0] }
            }
        }
    }
}
```

**Pattern 4: Multiple filters (parallel subscriptions)**
```swift
private func fetchEvents(filters: [NDKFilter]) async {
    var allEvents: [NDKEvent] = []

    await withTaskGroup(of: [NDKEvent].self) { group in
        for filter in filters {
            group.addTask {
                var events: [NDKEvent] = []
                let subscription = ndk.subscribe(filter: filter)
                for await event in subscription.events {
                    events.append(event)
                }
                return events
            }
        }

        for await filterEvents in group {
            allEvents.append(contentsOf: filterEvents)
        }
    }
}
```

**WRONG - Antipatterns to NEVER repeat:**
```swift
// ❌ DON'T DO THIS
@Observable
final class BadViewModel {
    private(set) var events: [NDKEvent] = []  // ❌ Duplicate state!

    func subscribe() async {
        let subscription = ndk.subscribe(filter: filter)
        for await event in subscription.events {
            guard !events.contains(where: { $0.id == event.id }) else { continue }  // ❌ Manual dedup!
            events.append(event)  // ❌ Manual management!
            events.sort { $0.createdAt > $1.createdAt }  // ❌ O(n log n) per event!
        }
    }
}

// ❌ DON'T CREATE WRAPPER EXTENSIONS
extension NDK {
    func subscribeToEvents(filters: [NDKFilter]) -> AsyncThrowingStream<NDKEvent, Error> {
        // ❌ Just use ndk.subscribe(filter:) directly!
    }
}
```

### Decision Tree

**Do you need to reactively display events in SwiftUI?**
- YES → Use `subscription.data` directly in View or expose `subscription` from ViewModel (Pattern 1 or 2)
- NO → Continue

**Do you need to process events as they arrive (DataStore, background processing)?**
- YES → Use `for await event in subscription.events` (Pattern 3)
- NO → Continue

**Do you need to handle multiple filters?**
- YES → Use `withTaskGroup` to run subscriptions in parallel (Pattern 4)
- NO → Continue

**Do you need to collect a bounded set of events once?**
- YES → Use `await subscription.collect(timeout:limit:)`
- NO → You probably want the first case

### Key Rule

**If you're creating an `@Observable` class with an array property that you manually populate from NDK events, you're doing it wrong.**

Just expose the `NDKSubscription` itself - it's already observable with a `.data` property.