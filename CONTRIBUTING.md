# Contributing to TENEX iOS

This document outlines the development workflow for TENEX iOS, designed for both human developers and AI agents working in a subagent-driven development flow.

## Table of Contents

- [Setup](#setup)
- [Development Workflow](#development-workflow)
- [Subagent Protocol](#subagent-protocol)
- [TDD Requirements](#tdd-requirements)
- [Code Standards](#code-standards)
- [Testing](#testing)
- [Commit Guidelines](#commit-guidelines)

---

## Setup

### Prerequisites

```bash
# Install Tuist
curl -Ls https://install.tuist.io | bash

# Install SwiftLint
brew install swiftlint

# Install SwiftFormat
brew install swiftformat

# Install Maestro (for UI tests)
curl -Ls "https://get.maestro.mobile.dev" | bash
```

### Initial Setup

```bash
# Clone the repository
git clone <repo-url>
cd tenex-ios

# Install git hooks
./scripts/install-hooks.sh

# Generate Xcode project
tuist generate

# Open in Xcode
open TENEX.xcodeproj
```

### Verify Setup

```bash
# Run all checks
tuist generate && tuist test

# Run linting
swiftlint lint

# Run formatting check
swiftformat --lint .
```

---

## Development Workflow

### Branch Strategy

```
main                    # Production-ready code
├── milestone/N-name    # Milestone branches (e.g., milestone/1-auth)
│   └── feature/X       # Feature branches off milestone
└── fix/issue-id        # Hotfix branches
```

### Starting Work

1. **Read PLAN.md** - Understand current milestone and status
2. **Check for blockers** - Review "Known Issues & Blockers" section
3. **Create branch** - `git checkout -b feature/your-feature`
4. **Write tests first** - TDD is mandatory
5. **Implement** - Write minimal code to pass tests
6. **Update PLAN.md** - Log your work in the status section

### Completing Work

1. **Run all tests** - `tuist test`
2. **Run linting** - `swiftlint lint --strict`
3. **Update PLAN.md** - Mark tasks complete, add change log entry
4. **Commit** - Use conventional commits
5. **Push** - Pre-push hook runs tests
6. **Create PR** - Reference milestone and tasks

---

## Subagent Protocol

When working as an AI agent in subagent-driven development, follow this protocol exactly:

### Before Starting Work

```markdown
## Pre-Work Checklist

1. [ ] Read PLAN.md completely
2. [ ] Identify current milestone and status
3. [ ] Check "Known Issues & Blockers"
4. [ ] Identify specific task(s) to work on
5. [ ] Verify no conflicts with other agents' work
```

### During Work

**Always update PLAN.md with a status log entry:**

```markdown
### Status Log
[YYYY-MM-DD HH:MM] <agent-id>
- What I'm working on
- Files created/modified
- Tests written
- Deviations from plan (with reasoning)
- Blockers encountered
```

**Test-Driven Development is mandatory:**

1. Write failing test first
2. Verify test fails for the right reason
3. Write minimal implementation to pass
4. Refactor if needed
5. Verify all tests still pass

### After Completing Work

```markdown
## Post-Work Checklist

1. [ ] All new code has tests
2. [ ] All tests pass (`tuist test`)
3. [ ] Linting passes (`swiftlint lint --strict`)
4. [ ] PLAN.md updated with:
   - [ ] Status log entry
   - [ ] Tasks marked complete with date
   - [ ] Any new blockers documented
   - [ ] Change log entry added
5. [ ] Commit with conventional format
6. [ ] Files changed listed in commit body
```

### Handoff Protocol

When handing off to another agent:

1. **Complete current task** - Don't leave partial work
2. **Update PLAN.md** - Full status log entry
3. **Document next steps** - Clear "Next recommended action"
4. **List open questions** - Anything needing human decision
5. **Commit all changes** - Including PLAN.md updates

### Conflict Resolution

If you encounter conflicts with another agent's work:

1. **Stop immediately** - Don't overwrite others' work
2. **Document in PLAN.md** - Add to "Known Issues & Blockers"
3. **Request human review** - Note in status log
4. **Wait for resolution** - Don't proceed until resolved

---

## TDD Requirements

### Test Structure

```
Tests/
├── CoreTests/           # Core module tests
│   ├── NDK/
│   ├── Auth/
│   └── Events/
├── FeaturesTests/       # Feature module tests
│   ├── Projects/
│   ├── Threads/
│   ├── Chat/
│   └── Voice/
├── SharedTests/         # Shared module tests
└── UITests/             # XCUITest (limited)
```

### Test Naming Convention

```swift
func test_methodName_condition_expectedResult() {
    // Given
    // When
    // Then
}

// Examples:
func test_authenticate_withValidNsec_savesSession()
func test_projectList_whenOffline_showsCachedProjects()
func test_sendMessage_withSelectedAgent_includesCorrectPTags()
```

### Test Requirements by Type

**Unit Tests (Required for all business logic):**
- View models
- Data transformations
- Event parsing
- Utility functions

**Integration Tests (Required for external dependencies):**
- NDKSwift subscriptions
- Relay connections
- Cache operations

**UI Tests with Maestro (Required for user flows):**
- Critical user journeys
- Regression prevention
- Cross-platform verification

### Minimum Coverage Requirements

- Core module: 80% coverage
- Features modules: 70% coverage
- Shared module: 80% coverage

---

## Code Standards

### File Organization

Every Swift file must follow this structure:

```swift
//
//  FileName.swift
//  TENEX
//

import Framework1
import Framework2

// MARK: - Type Definition

/// Documentation for the type
public struct/class/enum TypeName {

    // MARK: - Types (nested types, typealiases)

    // MARK: - Properties

    // MARK: - Initialization

    // MARK: - Public Methods

    // MARK: - Private Methods
}

// MARK: - Protocol Conformances

extension TypeName: ProtocolName {
    // Protocol implementation
}
```

### Naming Conventions

| Item | Convention | Example |
|------|------------|---------|
| Types | PascalCase | `ProjectListViewModel` |
| Properties | camelCase | `selectedProject` |
| Methods | camelCase verb | `fetchProjects()` |
| Constants | camelCase | `maxRetryCount` |
| Files | PascalCase matching type | `ProjectListViewModel.swift` |

### SwiftUI Views

```swift
struct FeatureView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - State
    @State private var isLoading = false

    // MARK: - Dependencies
    let viewModel: FeatureViewModel

    // MARK: - Body
    var body: some View {
        content
            .onAppear { viewModel.onAppear() }
    }

    // MARK: - Subviews
    @ViewBuilder
    private var content: some View {
        // ...
    }
}
```

### View Models

```swift
@Observable
final class FeatureViewModel {
    // MARK: - Published State
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var error: Error?

    // MARK: - Dependencies
    private let ndk: NDK

    // MARK: - Initialization
    init(ndk: NDK) {
        self.ndk = ndk
    }

    // MARK: - Public Methods
    func onAppear() {
        Task { await loadItems() }
    }

    // MARK: - Private Methods
    private func loadItems() async {
        // Implementation
    }
}
```

### Error Handling

```swift
// Define specific errors
enum ProjectError: LocalizedError {
    case notFound(id: String)
    case networkFailure(underlying: Error)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notFound(let id):
            return "Project \(id) not found"
        case .networkFailure(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid project data"
        }
    }
}

// Handle errors explicitly
func loadProject(id: String) async throws -> Project {
    guard let project = try await fetchProject(id: id) else {
        throw ProjectError.notFound(id: id)
    }
    return project
}
```

---

## Testing

### Running Tests

```bash
# Run all tests
tuist test

# Run specific test target
tuist test TENEXCoreTests

# Run with coverage
tuist test --coverage
```

### Maestro Tests

```bash
# Run all Maestro flows
maestro test Maestro/flows/

# Run specific flow
maestro test Maestro/flows/01_login_nsec.yaml

# Run with video recording
maestro test --format junit --output results/ Maestro/flows/
```

### Writing Maestro Tests

```yaml
# Maestro/flows/01_login_nsec.yaml
appId: chat.tenex.ios
---
- launchApp:
    clearState: true

- assertVisible: "Sign In"

- tapOn: "Enter nsec"

- inputText: "nsec1..."

- tapOn: "Continue"

- assertVisible: "Projects"
```

### Test Utilities Location

```
Tests/
└── TestUtilities/
    ├── Mocks/
    │   ├── MockNDK.swift
    │   └── MockSigner.swift
    ├── Fixtures/
    │   ├── ProjectFixtures.swift
    │   └── MessageFixtures.swift
    └── Helpers/
        └── AsyncTestHelpers.swift
```

---

## Commit Guidelines

### Conventional Commits

All commits must follow the conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Code style (formatting, no logic change) |
| `refactor` | Code change that neither fixes nor adds |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `build` | Build system or dependencies |
| `ci` | CI configuration |
| `chore` | Other changes (tooling, etc.) |
| `revert` | Revert a previous commit |

### Scopes

| Scope | Description |
|-------|-------------|
| `auth` | Authentication |
| `projects` | Projects feature |
| `threads` | Threads feature |
| `chat` | Chat feature |
| `voice` | Voice feature |
| `agents` | Agents feature |
| `core` | Core module |
| `shared` | Shared module |
| `ui` | UI components |
| `ndk` | NDKSwift integration |

### Examples

```bash
# Feature
git commit -m "feat(auth): add biometric authentication"

# Bug fix
git commit -m "fix(chat): resolve message ordering in threads"

# Documentation
git commit -m "docs: update PLAN.md with milestone 2 status"

# Multiple changes (use body)
git commit -m "feat(chat): implement message sending

- Add MessageSender service
- Create send button component
- Add optimistic UI updates

Closes #123"
```

### What NOT to Commit

- `.xcodeproj` and `.xcworkspace` files (generated by Tuist)
- `Derived/` folder
- `.build/` folder
- API keys or secrets
- Personal configuration files

---

## Questions?

If you're an agent and have questions about the workflow:

1. Check PLAN.md for context
2. Review existing code patterns
3. Document questions in your status log
4. Request human review if blocked

If you're a human developer:

1. Open an issue for discussion
2. Reach out to the team
3. Update this document if processes change
