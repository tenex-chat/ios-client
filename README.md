# TENEX iOS/macOS

A professional, production-grade iOS and macOS client for TENEX — the decentralized AI agent orchestration platform built on Nostr.

## Features

- **Multi-platform**: Native iOS and macOS support
- **Voice-first**: Integrated voice mode with on-device speech recognition
- **Offline-first**: Full offline support via NDKSwift
- **Professional grade**: TDD, comprehensive testing, strict code quality

## Requirements

- iOS 17.0+ / macOS 14.0+
- Xcode 16.0+
- Swift 6.0

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

### Development Setup

```bash
# Clone the repository
git clone https://github.com/your-org/tenex-ios.git
cd tenex-ios

# Install git hooks
./scripts/install-hooks.sh

# Fetch dependencies and generate Xcode project
tuist install
tuist generate

# Open in Xcode
open TENEX.xcodeproj
```

### Running Tests

```bash
# Run all unit tests
tuist test

# Run Maestro UI tests
maestro test Maestro/flows/
```

## Architecture

```
Sources/
├── App/           # App entry point and lifecycle
├── Core/          # Infrastructure (NDK, Auth, Cache)
├── Features/      # Feature modules (Projects, Chat, Voice, etc.)
└── Shared/        # Reusable components and utilities
```

See [PLAN.md](PLAN.md) for detailed architecture and milestone documentation.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development workflow, code standards, and the subagent protocol.

## Documentation

- [PLAN.md](PLAN.md) - Implementation plan and milestones
- [CONTRIBUTING.md](CONTRIBUTING.md) - Development workflow
- [docs/architecture/](docs/architecture/) - Architecture decisions

## License

MIT License - see LICENSE file for details.
