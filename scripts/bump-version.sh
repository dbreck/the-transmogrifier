#!/bin/bash
set -euo pipefail

# Bump version across all app and website files
# Usage: ./scripts/bump-version.sh <version> [build-number]
# Example: ./scripts/bump-version.sh 1.2.0       # auto-increments build number
# Example: ./scripts/bump-version.sh 1.2.0 5     # explicit build number

if [ $# -lt 1 ]; then
    echo "Usage: $0 <version> [build-number]"
    echo "  version       e.g. 1.2.0"
    echo "  build-number  optional, auto-increments from current if omitted"
    exit 1
fi

VERSION="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Validate version format
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "Error: Version must be in x.y.z format (e.g. 1.2.0)"
    exit 1
fi

PBXPROJ="$REPO_ROOT/ImageProcessingApp.xcodeproj/project.pbxproj"
INFO_PLIST="$REPO_ROOT/ImageProcessingApp/Resources/Info.plist"
BASE_LAYOUT="$REPO_ROOT/website/src/layouts/BaseLayout.astro"
INDEX_ASTRO="$REPO_ROOT/website/src/pages/index.astro"
PRICING_ASTRO="$REPO_ROOT/website/src/pages/pricing.astro"
FEATURES_ASTRO="$REPO_ROOT/website/src/pages/features.astro"

# Determine build number
if [ $# -ge 2 ]; then
    BUILD="$2"
else
    CURRENT_BUILD=$(grep -A1 'CFBundleVersion' "$INFO_PLIST" | grep '<string>' | sed 's/.*<string>\(.*\)<\/string>/\1/')
    BUILD=$((CURRENT_BUILD + 1))
fi

echo "Bumping to version $VERSION (build $BUILD)"
echo ""

# --- App files ---

# project.pbxproj — MARKETING_VERSION (all occurrences)
sed -i '' "s/MARKETING_VERSION = [0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/MARKETING_VERSION = $VERSION/g" "$PBXPROJ"
echo "  Updated project.pbxproj MARKETING_VERSION"

# project.pbxproj — CURRENT_PROJECT_VERSION (all occurrences)
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9][0-9]*/CURRENT_PROJECT_VERSION = $BUILD/g" "$PBXPROJ"
echo "  Updated project.pbxproj CURRENT_PROJECT_VERSION"

# Info.plist — CFBundleShortVersionString
sed -i '' "/<key>CFBundleShortVersionString<\/key>/{ n; s/<string>.*<\/string>/<string>$VERSION<\/string>/; }" "$INFO_PLIST"
echo "  Updated Info.plist CFBundleShortVersionString"

# Info.plist — CFBundleVersion
sed -i '' "/<key>CFBundleVersion<\/key>/{ n; s/<string>.*<\/string>/<string>$BUILD<\/string>/; }" "$INFO_PLIST"
echo "  Updated Info.plist CFBundleVersion"

# --- Website files ---

# BaseLayout.astro — JSON-LD softwareVersion
sed -i '' "s/\"softwareVersion\": \"[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\"/\"softwareVersion\": \"$VERSION\"/" "$BASE_LAYOUT"
echo "  Updated BaseLayout.astro softwareVersion"

# All download URLs across website files (tag and filename)
OLD_URL_PATTERN='releases/download/v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*/The\.Transmogrifier\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.dmg'
NEW_URL="releases/download/v$VERSION/The.Transmogrifier.$VERSION.dmg"

for FILE in "$BASE_LAYOUT" "$INDEX_ASTRO" "$PRICING_ASTRO" "$FEATURES_ASTRO"; do
    COUNT=$(grep -c "$OLD_URL_PATTERN" "$FILE" 2>/dev/null || true)
    if [ "$COUNT" -gt 0 ]; then
        sed -i '' "s|$OLD_URL_PATTERN|$NEW_URL|g" "$FILE"
        BASENAME=$(basename "$FILE")
        echo "  Updated $BASENAME download URLs ($COUNT)"
    fi
done

echo ""
echo "Done! Version bumped to $VERSION (build $BUILD)"
echo ""
echo "Files changed:"
echo "  - ImageProcessingApp.xcodeproj/project.pbxproj"
echo "  - ImageProcessingApp/Resources/Info.plist"
echo "  - website/src/layouts/BaseLayout.astro"
echo "  - website/src/pages/index.astro"
echo "  - website/src/pages/pricing.astro"
echo ""
echo "Next: review changes with 'git diff', then commit."
