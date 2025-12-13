# TENEX App Icon Design

## Design Concept

The TENEX app icon features a modern, geometric design based on a stylized "T" lettermark. The design represents:

- **Structure & Organization**: The geometric "T" shape symbolizes project management and structured workflows
- **Technology & Innovation**: Clean, modern aesthetics with gradient treatments
- **Connection & Collaboration**: Subtle accent elements suggesting network connections and AI interaction
- **Professionalism**: Sophisticated color palette and balanced composition

## Design Versions

Two SVG designs are provided:

### 1. `icon-design.svg` - Layered Geometric Design
A more detailed design with:
- Multiple layers creating depth
- Subtle accent nodes representing connections
- Foundation element at the bottom
- Best for: Users who want a more distinctive, detailed icon

### 2. `icon-design-simple.svg` - Minimalist Clean Design (RECOMMENDED)
A simplified, bold design with:
- Clean, thick letterform for better recognition at small sizes
- Strong contrast and readability
- Minimal details that scale well
- Small accent dot representing AI/connection point
- Best for: Maximum clarity at all sizes (16x16 to 1024x1024)

**Recommendation**: Use `icon-design-simple.svg` for production as it maintains clarity at all sizes.

## Color Scheme

The icon uses a cohesive blue/teal gradient palette that complements the app's accent color:

- **Primary Blue**: `#3C82E0` (matches the app's accent color RGB: 60, 130, 224)
- **Light Blue**: `#4A9FF5` (highlights and accents)
- **Dark Blue**: `#2563BC` (depth and shadows)
- **Background Dark**: `#0A1F44` (deep blue-black background)
- **Background Mid**: `#0F2A52` (inner layer)

### Accessibility
- High contrast ratio for visibility
- Works in both light and dark mode
- Recognizable at small sizes (20x20 and up)
- Distinct from other app icons

## Converting SVG to PNG Icons

### Required Sizes

iOS and macOS require the following sizes:

**iOS (Universal):**
- 1024x1024 (App Store & iOS)

**macOS:**
- 16x16 (1x and 2x = 32x32)
- 32x32 (1x and 2x = 64x64)
- 128x128 (1x and 2x = 256x256)
- 256x256 (1x and 2x = 512x512)
- 512x512 (1x and 2x = 1024x1024)

### Conversion Methods

#### Option 1: Using ImageMagick (Recommended)

Install ImageMagick:
```bash
brew install imagemagick
```

Convert SVG to all required PNG sizes:
```bash
# Navigate to the AppIcon directory
cd Resources/Assets.xcassets/AppIcon.appiconset/

# Choose your design (simple is recommended)
SVG_FILE="icon-design-simple.svg"

# Generate all required sizes
convert $SVG_FILE -resize 1024x1024 icon-1024.png
convert $SVG_FILE -resize 16x16 icon-16.png
convert $SVG_FILE -resize 32x32 icon-16@2x.png
convert $SVG_FILE -resize 32x32 icon-32.png
convert $SVG_FILE -resize 64x64 icon-32@2x.png
convert $SVG_FILE -resize 128x128 icon-128.png
convert $SVG_FILE -resize 256x256 icon-128@2x.png
convert $SVG_FILE -resize 256x256 icon-256.png
convert $SVG_FILE -resize 512x512 icon-256@2x.png
convert $SVG_FILE -resize 512x512 icon-512.png
convert $SVG_FILE -resize 1024x1024 icon-512@2x.png
```

#### Option 2: Using rsvg-convert (Alternative)

Install librsvg:
```bash
brew install librsvg
```

Convert:
```bash
rsvg-convert -w 1024 -h 1024 icon-design-simple.svg > icon-1024.png
rsvg-convert -w 16 -h 16 icon-design-simple.svg > icon-16.png
# ... repeat for other sizes
```

#### Option 3: Using Online Tools

1. Upload SVG to [CloudConvert](https://cloudconvert.com/svg-to-png)
2. Set dimensions to 1024x1024
3. Download PNG
4. Use [App Icon Generator](https://appicon.co/) to generate all sizes

#### Option 4: Using Sketch/Figma/Illustrator

1. Open the SVG file in your design tool
2. Export as PNG at 1024x1024
3. Use design tool's asset export features to generate @1x, @2x, @3x variants

### Automated Script

A convenience script is provided below. Save as `generate-icons.sh`:

```bash
#!/bin/bash

# TENEX App Icon Generator
# Generates all required iOS and macOS app icon sizes from SVG

SVG_FILE="icon-design-simple.svg"

if [ ! -f "$SVG_FILE" ]; then
    echo "Error: $SVG_FILE not found"
    exit 1
fi

if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not installed. Run: brew install imagemagick"
    exit 1
fi

echo "Generating TENEX app icons from $SVG_FILE..."

# Generate all sizes
convert "$SVG_FILE" -resize 1024x1024 -quality 100 icon-1024.png
convert "$SVG_FILE" -resize 16x16 -quality 100 icon-16.png
convert "$SVG_FILE" -resize 32x32 -quality 100 icon-16@2x.png
convert "$SVG_FILE" -resize 32x32 -quality 100 icon-32.png
convert "$SVG_FILE" -resize 64x64 -quality 100 icon-32@2x.png
convert "$SVG_FILE" -resize 128x128 -quality 100 icon-128.png
convert "$SVG_FILE" -resize 256x256 -quality 100 icon-128@2x.png
convert "$SVG_FILE" -resize 256x256 -quality 100 icon-256.png
convert "$SVG_FILE" -resize 512x512 -quality 100 icon-256@2x.png
convert "$SVG_FILE" -resize 512x512 -quality 100 icon-512.png
convert "$SVG_FILE" -resize 1024x1024 -quality 100 icon-512@2x.png

echo "✓ Icon generation complete!"
echo "Generated files:"
ls -lh icon-*.png

echo ""
echo "Next steps:"
echo "1. Update Contents.json to reference these files"
echo "2. Clean and rebuild your Xcode project"
echo "3. Test the app icon on device and simulator"
```

Make it executable:
```bash
chmod +x generate-icons.sh
./generate-icons.sh
```

## Updating Contents.json

After generating PNG files, update `Contents.json` to reference them:

```json
{
  "images" : [
    {
      "filename" : "icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    },
    {
      "filename" : "icon-16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon-16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon-32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon-32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon-128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon-128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon-256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon-256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon-512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon-512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

## Design Guidelines

The icon follows iOS Human Interface Guidelines:

1. **No transparency**: Background is opaque (required for app icons)
2. **Rounded corners**: iOS automatically applies corner radius; SVG includes rounded rect for preview
3. **Safe area**: Critical elements are kept within the safe area (avoiding outer 5% margin)
4. **Scalability**: Design maintains clarity from 16x16 to 1024x1024
5. **Uniqueness**: Distinctive shape and color palette
6. **Simplicity**: Clean, focused design without unnecessary details

## Testing the Icon

After installing:

1. Clean Xcode build folder: Cmd+Shift+K
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Rebuild project: `tuist clean && tuist generate && tuist build`
4. Test on simulator and device
5. Check home screen appearance in both light and dark mode
6. Verify App Store screenshots

## Alternative Design Ideas (Future Iterations)

If you want to explore different concepts:

1. **Network Grid**: Interconnected nodes representing collaboration
2. **Layered Cards**: Stacked cards representing projects and threads
3. **Chat Bubble + Folder**: Combining messaging and project management
4. **Abstract "X"**: Playing on the "TENEX" name with a geometric X shape
5. **Circuit Pattern**: Tech-forward design with circuit board aesthetics

## Files in This Directory

- `icon-design.svg` - Detailed layered geometric design
- `icon-design-simple.svg` - Simple minimalist design (RECOMMENDED)
- `README.md` - This documentation
- `Contents.json` - Xcode Asset Catalog configuration
- `*.png` - Generated icon files (after running conversion)
- `generate-icons.sh` - Automated icon generation script (to be created)

## Support

For questions or design iterations:
1. Open the SVG files in any vector editor (Figma, Sketch, Illustrator, Inkscape)
2. Modify colors, shapes, or layout as needed
3. Re-export and regenerate PNG files
4. Test thoroughly on device

## Version History

- v1.0 - Initial icon designs (Geometric and Simple variants)
- Color scheme aligned with app accent color (#3C82E0)
- Optimized for iOS 17+ and macOS 14+
