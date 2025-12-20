#!/bin/bash

# Generate BuildInfo.swift with git commit hash
OUTPUT_FILE="$SRCROOT/Sources/Shared/Generated/BuildInfo.swift"
mkdir -p "$(dirname "$OUTPUT_FILE")"

COMMIT_HASH=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
COMMIT_DATE=$(git -C "$SRCROOT" log -1 --format=%ci 2>/dev/null | cut -d' ' -f1 || echo "unknown")
BRANCH=$(git -C "$SRCROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

cat > "$OUTPUT_FILE" << EOF
//
// BuildInfo.swift
// TENEX iOS Client
// Copyright (c) 2025 TENEX Team
//
// swiftlint:disable all
// Auto-generated file - do not edit

public enum BuildInfo {
    public static let commitHash = "$COMMIT_HASH"
    public static let commitDate = "$COMMIT_DATE"
    public static let branch = "$BRANCH"
}
// swiftlint:enable all
EOF

echo "Generated BuildInfo.swift with commit: $COMMIT_HASH"
