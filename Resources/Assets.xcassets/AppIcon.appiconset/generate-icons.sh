#!/bin/bash

# TENEX App Icon Generator
# Generates all required iOS and macOS app icon sizes from SVG

set -e  # Exit on error

# Configuration
SVG_FILE="icon-design-v2.svg"
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

cd "$SCRIPT_DIR"

echo "🎨 TENEX App Icon Generator"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if SVG file exists
if [ ! -f "$SVG_FILE" ]; then
    echo "❌ Error: $SVG_FILE not found in $SCRIPT_DIR"
    echo ""
    echo "Available SVG files:"
    ls -1 *.svg 2>/dev/null || echo "  (none found)"
    exit 1
fi

# Check for ImageMagick
if ! command -v convert &> /dev/null; then
    echo "❌ Error: ImageMagick not installed"
    echo ""
    echo "Install using Homebrew:"
    echo "  brew install imagemagick"
    echo ""
    echo "Or using MacPorts:"
    echo "  sudo port install ImageMagick"
    exit 1
fi

echo "✓ Using source file: $SVG_FILE"
echo "✓ ImageMagick found: $(convert --version | head -n1)"
echo ""

# Clean up old PNG files
echo "🧹 Cleaning up old icon files..."
rm -f icon-*.png
echo ""

# Generate icons
echo "⚙️  Generating icon files..."
echo ""

generate_icon() {
    local size=$1
    local filename=$2
    echo "  Creating ${filename} (${size}x${size})"
    convert "$SVG_FILE" -resize ${size}x${size} -quality 100 "$filename"
}

# iOS Universal
generate_icon 1024 "icon-1024.png"

# macOS sizes
generate_icon 16 "icon-16.png"
generate_icon 32 "icon-16@2x.png"
generate_icon 32 "icon-32.png"
generate_icon 64 "icon-32@2x.png"
generate_icon 128 "icon-128.png"
generate_icon 256 "icon-128@2x.png"
generate_icon 256 "icon-256.png"
generate_icon 512 "icon-256@2x.png"
generate_icon 512 "icon-512.png"
generate_icon 1024 "icon-512@2x.png"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Icon generation complete!"
echo ""
echo "Generated files:"
ls -lh icon-*.png | awk '{print "  " $9 " (" $5 ")"}'

echo ""
echo "📋 Next steps:"
echo ""
echo "1. Update Contents.json (if not already done)"
echo "2. Clean Xcode build folder:"
echo "   rm -rf ~/Library/Developer/Xcode/DerivedData"
echo ""
echo "3. Rebuild the project:"
echo "   tuist clean && tuist generate"
echo ""
echo "4. Run the app and verify the icon appears correctly"
echo ""
echo "5. Test on both simulator and physical device"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
