# Group Selection Indicator Design

**Date:** 2025-12-16
**Status:** Approved

## Overview

Display the selected project group in the navigation title to provide clear visual feedback about the current filter state.

## User Experience

When "All Projects" is selected, the navigation title displays "Projects". When a specific group is selected, the title changes to display only the group name (e.g., "Work Projects", "Personal").

### User Flow

1. User opens Projects view → sees "Projects" title
2. User taps filter menu → selects a group
3. Title smoothly transitions to show the group name
4. Projects list filters to show only that group's projects
5. User can tap the filter menu to see which group is active (checkmark)
6. Selecting "All Projects" returns the title to "Projects"

### Benefits

- Always visible - user never loses context
- No additional vertical space required
- Clean, focused experience when filtering
- Native iOS/macOS pattern

## Implementation

### Changes Required

**File:** `Sources/Features/Projects/ProjectListView.swift`

**Modify navigation title:**
```swift
// Current (line 32)
.navigationTitle("Projects")

// New
.navigationTitle(navigationTitle)
```

**Add computed property:**
```swift
private var navigationTitle: String {
    if let selectedGroup {
        return selectedGroup.name
    }
    return "Projects"
}
```

### Technical Details

- Reuses existing `selectedGroup` computed property (line 119-121)
- SwiftUI automatically animates title transitions
- Works with large title display mode on iOS
- Adapts to navigation area on macOS

## Edge Cases

**Long Group Names:** SwiftUI handles truncation automatically. Large titles wrap; collapsed titles truncate with ellipsis.

**Empty State:** Existing empty state messages already adapt based on `selectedGroupID`, maintaining consistency.

**Accessibility:** Navigation title is automatically accessible to VoiceOver.

**Platform Differences:**
- iOS: Large title mode - prominent display, collapses when scrolling
- macOS: Navigation area - subtle but visible

## Files Modified

- `Sources/Features/Projects/ProjectListView.swift`
