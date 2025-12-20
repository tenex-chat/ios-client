#!/bin/sh

#  ci_post_clone.sh
#  TENEX
#
#  This script runs on Xcode Cloud after the repository is cloned.
#  It sets up the build environment by installing dependencies and generating
#  the Xcode workspace with Tuist.
#
#  Based on: https://docs.tuist.dev/guides/develop/automate/continuous-integration

set -e  # Exit on error
set -x  # Print commands as they execute

echo "Xcode Cloud Post-Clone Script"
echo "================================"

# Install Mise (Tuist's recommended version manager)
# See: https://mise.jdx.dev/continuous-integration.html#xcode-cloud
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"

# Install tools from .mise.toml (includes Tuist)
mise install

# Install dependencies (--path needed as this runs from ci_scripts directory)
mise exec -- tuist install --path ../

# Generate Xcode workspace and project
mise exec -- tuist generate --path ../ --no-open

echo "Xcode Cloud setup complete!"
