# Inbox Feature Test Suite

## Overview

This test suite follows **Test-Driven Development (TDD)** for the Inbox feature implementation. All tests are written BEFORE implementation (Red phase).

## Test Files

### 1. InboxStoreTests.swift
**Purpose:** Tests the core data layer and business logic

**Test Coverage:**
- ✅ Initialization (empty state, persisted last visit)
- ✅ Event subscription setup (filter creation, NDK integration)
- ✅ Event handling (incoming events, real-time updates)
- ✅ Event deduplication by E-tag (grouping, keeping most recent)
- ✅ Event sorting (newest first)
- ✅ Unread count calculation (based on last visit timestamp)
- ✅ Mark as read functionality (timestamp updates, persistence)
- ✅ Event filtering (valid kinds: 1, 1111, 7, 30023)
- ✅ Time window filtering (last 7 days)
- ✅ Cleanup operations (stop subscription, clear state)
- ✅ Event type detection (agent response vs mention vs reply vs reaction)
- ✅ Suggestion extraction (from event tags)

**Total Tests:** 25

### 2. InboxViewTests.swift
**Purpose:** Tests the full-page inbox view and popover component

**Test Coverage:**
- ✅ Empty state display
- ✅ Event list rendering
- ✅ Navigation on event tap
- ✅ Navigation bar (title, filter button)
- ✅ Auto-mark as read on view appear
- ✅ Event count display
- ✅ Authentication state handling
- ✅ Popover: Top 5 events display
- ✅ Popover: View All button (when >5 events)
- ✅ Popover: Auto-mark as read timer (1.5s delay)
- ✅ Popover: Timer cancellation on early close
- ✅ Popover: Navigation behavior
- ✅ Popover: Fixed dimensions (400x500)
- ✅ InboxButton: Unread badge visibility
- ✅ InboxButton: Badge count display (9+ for >9)
- ✅ InboxButton: Keyboard shortcut hint (⌘I)
- ✅ InboxButton: Popover toggle
- ✅ InboxButton: Badge animation (pulsing)

**Total Tests:** 18

### 3. InboxEventCardTests.swift
**Purpose:** Tests the individual event card component

**Test Coverage:**
- ✅ Visual indicators (blue bar, New badge, background tint)
- ✅ Event type badges (agent response, mention, reply, reaction, article)
- ✅ Badge icons and colors (purple, blue, green, pink, orange)
- ✅ Content display (avatar, author name, preview, timestamp)
- ✅ Content expansion/collapse
- ✅ Suggestion indicator (count, singular/plural, status)
- ✅ Toggle button behavior
- ✅ Layout (HStack, padding)
- ✅ Accessibility (labels, ARIA attributes)
- ✅ EventTypeBadge component tests

**Total Tests:** 25

### 4. InboxIntegrationTests.swift
**Purpose:** End-to-end integration tests with NDK and navigation

**Test Coverage:**
- ✅ NDK subscription filter creation (kinds, p-tag, time window)
- ✅ Subscription lifecycle (open, close on EOSE)
- ✅ Real-time event handling
- ✅ Event replacement (deduplication in action)
- ✅ Unread count recalculation on new events
- ✅ Sort order maintenance
- ✅ Persistence (last visit across instances)
- ✅ Navigation (to chat, to inbox page)
- ✅ Keyboard shortcuts (⌘I)
- ✅ Complete flow (subscribe → receive → display → read)
- ✅ Real-time deduplication
- ✅ Concurrent subscriptions
- ✅ Error handling (subscription errors, malformed events)
- ✅ Performance (large event volume, deduplication scaling)
- ✅ Authentication integration (auto-start, auto-stop)

**Total Tests:** 20

## Total Test Count: 88 tests

## Test Categories

### Unit Tests (48)
- InboxStore logic
- EventCard component behavior
- Badge display logic
- Event type detection

### Integration Tests (20)
- NDK subscription
- Navigation router
- Persistence layer
- Authentication flow

### UI/View Tests (20)
- View rendering states
- User interactions
- Accessibility

## Running the Tests

```bash
# Run all inbox tests
tuist test --filter "Inbox"

# Run specific test file
tuist test --filter "InboxStoreTests"
tuist test --filter "InboxViewTests"
tuist test --filter "InboxEventCardTests"
tuist test --filter "InboxIntegrationTests"

# Run specific test
tuist test --filter "InboxStoreTests/deduplicatesEventsByETag"
```

## Expected Behavior (Red Phase)

All tests should **FAIL** because:
1. `InboxStore` class does not exist
2. `InboxView` component does not exist
3. `InboxEventCard` component does not exist
4. `InboxButton` component does not exist
5. `InboxEventType` enum does not exist
6. Helper methods not implemented

## Next Steps (Green Phase)

After verifying tests fail:
1. Implement `InboxStore.swift` (Observable class)
2. Implement `InboxView.swift` (full-page view)
3. Implement `InboxPopoverView.swift` (quick view)
4. Implement `InboxButton.swift` (sidebar button)
5. Implement `InboxEventCard.swift` (event row)
6. Implement `EventTypeBadge.swift` (type indicator)
7. Add navigation routes to `AppRoute.swift`
8. Integrate into `NavigationShell.swift`

## Test Philosophy

These tests follow TENEX's TDD principles:
- ✅ **Tests first** - All tests written before implementation
- ✅ **Comprehensive** - Cover happy paths, edge cases, and error scenarios
- ✅ **Independent** - Each test can run in isolation
- ✅ **Fast** - Unit tests run in milliseconds
- ✅ **Clear** - Given/When/Then structure with descriptive names
- ✅ **Maintainable** - Tests document expected behavior

## Key Testing Patterns

1. **State Management:** Verify Observable state updates correctly
2. **Async Operations:** Use `await` for NDK subscriptions and event handling
3. **Time-based Logic:** Test timestamp comparisons and time windows
4. **Deduplication:** Verify complex grouping and filtering logic
5. **UI State:** Test empty states, loading states, and error states
6. **Navigation:** Verify routing behavior
7. **Persistence:** Test UserDefaults integration
8. **Performance:** Ensure scalability with large datasets

## Coverage Goals

- **Line Coverage:** >90%
- **Branch Coverage:** >85%
- **Critical Paths:** 100% (deduplication, unread tracking)

## Notes

- Some tests use mocked NDK instances (no real relay connections)
- UI layout/snapshot tests would be added separately
- Maestro E2E tests would complement this suite
- Tests follow Swift Testing framework syntax
- All tests are @MainActor annotated where needed for SwiftUI
