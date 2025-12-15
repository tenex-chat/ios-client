#!/bin/bash

# Patch ElevenlabsSwift to support macOS
ELEVENLABS_PACKAGE="/Users/pablofernandez/10x/TENEX-iOS-Client-cawc6h/master/Tuist/.build/checkouts/ElevenlabsSwift/Package.swift"

if [ -f "$ELEVENLABS_PACKAGE" ]; then
    # Check if macOS is already in the platforms
    if ! grep -q "\.macOS" "$ELEVENLABS_PACKAGE"; then
        echo "Patching ElevenlabsSwift Package.swift to add macOS support..."

        # Replace the platforms line to include macOS 12.0 (required for data(for:delegate:) API)
        sed -i '' 's/\.iOS(\.v14), \.tvOS(\.v14)/.iOS(.v14), .tvOS(.v14), .macOS(.v12)/' "$ELEVENLABS_PACKAGE"

        echo "✅ ElevenlabsSwift patched successfully"
    else
        echo "✅ ElevenlabsSwift already has macOS support"
    fi
else
    echo "⚠️  ElevenlabsSwift Package.swift not found. Run 'tuist install' first."
fi
