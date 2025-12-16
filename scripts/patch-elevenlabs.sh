#!/bin/bash

# Patch ElevenlabsSwift to support macOS
ELEVENLABS_DIR="$SRCROOT/Tuist/.build/checkouts/ElevenlabsSwift"
ELEVENLABS_PACKAGE="$ELEVENLABS_DIR/Package.swift"
ELEVENLABS_SOURCE="$ELEVENLABS_DIR/Sources/ElevenlabsSwift/ElevenlabsSwift.swift"

if [ -f "$ELEVENLABS_PACKAGE" ]; then
    # Patch Package.swift for macOS support
    if ! grep -q "\.macOS" "$ELEVENLABS_PACKAGE"; then
        echo "Patching ElevenlabsSwift Package.swift to add macOS support..."
        sed -i '' 's/\.iOS(\.v14), \.tvOS(\.v14)/.iOS(.v14), .tvOS(.v14), .macOS(.v12)/' "$ELEVENLABS_PACKAGE"
        echo "✅ Package.swift patched"
    fi

    # Patch source code to add @available attributes
    if [ -f "$ELEVENLABS_SOURCE" ]; then
        if ! grep -q "@available(macOS 12.0" "$ELEVENLABS_SOURCE"; then
            echo "Patching ElevenlabsSwift source code for macOS availability..."

            # Add @available to fetchVoices
            sed -i '' '/public func fetchVoices/i\
    @available(macOS 12.0, *)
' "$ELEVENLABS_SOURCE"

            # Add @available to textToSpeech
            sed -i '' '/public func textToSpeech/i\
    @available(macOS 12.0, *)
' "$ELEVENLABS_SOURCE"

            # Add @available to deleteVoice
            sed -i '' '/public func deleteVoice/i\
    @available(macOS 12.0, *)
' "$ELEVENLABS_SOURCE"

            echo "✅ Source code patched"
        fi
    fi

    echo "✅ ElevenlabsSwift fully patched for macOS"
else
    echo "⚠️  ElevenlabsSwift not found. Run 'tuist install' first."
fi
