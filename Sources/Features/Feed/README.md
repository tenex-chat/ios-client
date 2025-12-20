# Feed Tab Architecture

## Overview

The Feed Tab feature follows a clean MVVM (Model-View-ViewModel) architecture with a dedicated service layer for networking operations. This design ensures separation of concerns, testability, and maintainability.

## Architecture Layers

```
┌─────────────────────────────────────────────────┐
│                  FeedTabView                     │
│              ("Dumb" Presentation)               │
│  - Displays data                                 │
│  - Forwards user events                          │
│  - No business logic                             │
└────────────────┬────────────────────────────────┘
                 │
                 │ observes & sends events
                 ▼
┌─────────────────────────────────────────────────┐
│              FeedTabViewModel                    │
│              (Business Logic)                    │
│  - Manages view state                            │
│  - Coordinates with service layer                │
│  - Handles filtering & search                    │
│  - Observable for UI updates                     │
└────────────────┬────────────────────────────────┘
                 │
                 │ calls
                 ▼
┌─────────────────────────────────────────────────┐
│          FeedServiceProtocol                     │
│            (Networking Layer)                    │
│  - Abstracts network operations                  │
│  - Mockable for testing                          │
│  - Handles NDK subscriptions                     │
└─────────────────────────────────────────────────┘
         │                        │
         │ implements             │ implements
         ▼                        ▼
┌──────────────────┐    ┌──────────────────┐
│   FeedService    │    │ MockFeedService  │
│  (Production)    │    │   (Testing)      │
└──────────────────┘    └──────────────────┘
```

## Components

### 1. FeedTabView (Presentation Layer)

**Responsibility**: Display data and forward user events

**Key Characteristics**:
- "Dumb" view - no business logic
- Uses `@Bindable` for two-way data binding
- Handles different view states (loading, loaded, error, idle)
- Delegates all actions to ViewModel

**State Management**:
```swift
switch viewModel.state {
case .idle: emptyView
case .loading: loadingView
case .loaded: loadedContent
case .error(let error): errorView(error: error)
}
```

### 2. FeedTabViewModel (Business Logic Layer)

**Responsibility**: Manage application state and coordinate between view and service

**Key Features**:
- Observable using `@Observable` macro
- State management with `FeedViewState` enum
- Filtering and search logic
- Thread grouping logic
- Error handling

**Public Interface**:
```swift
// State
var state: FeedViewState { get }
var events: [NDKEvent] { get }
var filteredEvents: [NDKEvent] { get }

// User Actions
func subscribe() async
func retry() async
func clearFilters()
func cleanup()
```

### 3. FeedServiceProtocol (Network Abstraction)

**Responsibility**: Define contract for feed data operations

**Benefits**:
- Protocol-oriented design
- Easily mockable for testing
- Dependency injection friendly
- Clean separation from business logic

**Interface**:
```swift
protocol FeedServiceProtocol {
    func subscribeToProject(_ projectID: String) async throws -> NDKSubscription<NDKEvent>
    func unsubscribe()
}
```

### 4. FeedService (Network Implementation)

**Responsibility**: Handle actual network operations via NDK

**Key Features**:
- Manages NDK subscriptions
- Creates appropriate filters
- Handles subscription lifecycle
- Error handling with typed errors

### 5. FeedTabViewFactory (Dependency Injection)

**Responsibility**: Simplify view creation with proper dependencies

**Usage**:
```swift
// Production
let feedView = FeedTabViewFactory.create(
    ndk: ndk,
    projectID: "30003:pubkey:dTag",
    onEventClick: { event in
        // Handle event tap
    }
)

// Testing/Previews
let mockView = FeedTabViewFactory.createMock(
    projectID: "30003:pubkey:dTag",
    mockEvents: testEvents,
    shouldFail: false
)
```

## Data Flow

### Subscription Flow
```
User opens feed
    ↓
View.task → ViewModel.subscribe()
    ↓
ViewModel sets state = .loading
    ↓
ViewModel → Service.subscribeToProject()
    ↓
Service creates NDK subscription
    ↓
Service returns subscription
    ↓
ViewModel sets state = .loaded
    ↓
View displays events
```

### Error Flow
```
Service.subscribeToProject() throws error
    ↓
ViewModel catches error
    ↓
ViewModel sets state = .error(error)
    ↓
View displays error UI with retry button
    ↓
User taps retry
    ↓
View calls ViewModel.retry()
    ↓
(Flow repeats from subscription flow)
```

### Filter Flow
```
User types in search bar
    ↓
View updates ViewModel.searchQuery via binding
    ↓
ViewModel.filteredEvents computed property recalculates
    ↓
View automatically updates (Observable)
```

## State Management

### FeedViewState Enum
```swift
enum FeedViewState {
    case idle       // Initial state
    case loading    // Fetching data
    case loaded     // Data available
    case error(FeedServiceError)  // Error occurred
}
```

This explicit state enum prevents impossible states and makes state transitions clear.

## Error Handling

### FeedServiceError
```swift
enum FeedServiceError: Error, LocalizedError {
    case subscriptionFailed
    case invalidProjectID
    case ndkNotAvailable
}
```

All errors are typed and provide user-friendly descriptions via `LocalizedError`.

## Testing Strategy

### Unit Testing ViewModel
```swift
let mockService = MockFeedService()
let viewModel = FeedTabViewModel(
    service: mockService,
    projectID: "test-project"
)

// Test success case
await viewModel.subscribe()
XCTAssertEqual(viewModel.state, .loaded)

// Test failure case
mockService.shouldFail = true
await viewModel.retry()
XCTAssertEqual(viewModel.state, .error(.subscriptionFailed))
```

### UI Testing with Previews
```swift
#Preview("Loading") {
    FeedTabViewFactory.createMock(
        projectID: "test",
        shouldFail: false
    )
}

#Preview("Error") {
    FeedTabViewFactory.createMock(
        projectID: "test",
        shouldFail: true
    )
}
```

## Migration Guide

### Before (Old Architecture)
```swift
// View created ViewModel inline
// Direct NDK access in ViewModel
FeedTabView(projectID: "30003:pubkey:dTag")
```

### After (New Architecture)
```swift
// Factory creates view with all dependencies
let feedView = FeedTabViewFactory.create(
    ndk: ndk,
    projectID: "30003:pubkey:dTag"
)
```

## Best Practices

1. **View Layer**:
   - No business logic in views
   - Use `@Bindable` for two-way bindings
   - Always handle all state cases
   - Forward user actions to ViewModel

2. **ViewModel Layer**:
   - Single responsibility: manage state
   - Use protocols for dependencies
   - Async/await for operations
   - Comprehensive error handling

3. **Service Layer**:
   - Protocol-first design
   - Throw typed errors
   - Manage resource lifecycle
   - No UI code

4. **Dependency Injection**:
   - Use factories for complex creation
   - Inject dependencies via initializers
   - Prefer protocols over concrete types

## Future Enhancements

- [ ] Add pagination support
- [ ] Implement caching layer
- [ ] Add real-time event updates
- [ ] Improve search with fuzzy matching
- [ ] Add filter persistence
- [ ] Implement event batching
