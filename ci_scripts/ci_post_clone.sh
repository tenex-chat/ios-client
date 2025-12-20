#!/bin/sh

#  ci_post_clone.sh
#  TENEX
#
#  This script runs on Xcode Cloud after the repository is cloned.
#  It sets up the build environment by installing dependencies and generating
#  the Xcode workspace with Tuist.

set -e  # Exit on error
set -x  # Print commands as they execute

echo "📦 Xcode Cloud Post-Clone Script"
echo "================================"

# Install Homebrew if not present (Xcode Cloud doesn't have it by default)
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the current script
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install Tuist
echo "🔧 Installing Tuist..."
if ! command -v tuist &> /dev/null; then
    curl -Ls https://install.tuist.io | bash
fi

# Add Tuist to PATH
export PATH="$HOME/.tuist/bin:$PATH"

# Verify Tuist installation
echo "📋 Tuist version:"
tuist --version

# Install dependencies
echo "📥 Installing dependencies..."
tuist install

# Generate Xcode workspace and project
echo "🏗️  Generating Xcode workspace..."
tuist generate --no-open

echo "✅ Xcode Cloud setup complete!"
echo "================================"
