#!/bin/bash

# Build, sign, notarize, and package The Transmogrifier as a DMG
# Usage: ./build-dmg.sh <version> [--sign] [--notarize]
# Example: ./build-dmg.sh 1.0.2
# Example: ./build-dmg.sh 1.0.2 --sign --notarize
#
# Prerequisites for --sign:
#   Developer ID Application certificate installed in Keychain
#
# Prerequisites for --notarize:
#   APPLE_ID and APPLE_TEAM_ID environment variables set
#   App-specific password stored: xcrun notarytool store-credentials "transmogrifier"

set -e

VERSION="${1:?Usage: ./build-dmg.sh <version> [--sign] [--notarize]}"
shift
SIGN=false
NOTARIZE=false
for arg in "$@"; do
  case "$arg" in
    --sign) SIGN=true ;;
    --notarize) NOTARIZE=true ;;
  esac
done

APP_NAME="The Transmogrifier"
DMG_NAME="The.Transmogrifier.${VERSION}.dmg"
SCHEME="The Transmogrifier"
PROJECT="ImageProcessingApp.xcodeproj"
VOLUME_NAME="Install The Transmogrifier"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Find Developer ID certificate if signing
if $SIGN; then
  SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  if [ -z "$SIGN_IDENTITY" ]; then
    echo "Error: No 'Developer ID Application' certificate found."
    echo "Install one from https://developer.apple.com/account/resources/certificates/add"
    exit 1
  fi
  echo "Signing with: ${SIGN_IDENTITY}"
fi

TOTAL_STEPS=5
if $SIGN; then TOTAL_STEPS=$((TOTAL_STEPS + 1)); fi
if $NOTARIZE; then TOTAL_STEPS=$((TOTAL_STEPS + 1)); fi
STEP=0

echo "=== Building ${APP_NAME} v${VERSION} ==="

# Step: Build Release
STEP=$((STEP + 1))
echo "[${STEP}/${TOTAL_STEPS}] Building Release..."
xcodebuild -project "${SCRIPT_DIR}/${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  build \
  MARKETING_VERSION="${VERSION}" \
  -quiet

# Find the built app
APP_PATH=$(xcodebuild -project "${SCRIPT_DIR}/${PROJECT}" \
  -scheme "${SCHEME}" \
  -configuration Release \
  -showBuildSettings 2>/dev/null | \
  grep -m1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')
APP_PATH="${APP_PATH}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
  echo "Error: Built app not found at ${APP_PATH}"
  exit 1
fi

echo "   Built: ${APP_PATH}"

# Step: Code sign the app
if $SIGN; then
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] Code signing..."
  codesign --force --deep --options runtime \
    --sign "${SIGN_IDENTITY}" \
    "${APP_PATH}"
  echo "   Signed: $(codesign -dv "${APP_PATH}" 2>&1 | grep 'Authority=')"
fi

# Step: Create background image
STEP=$((STEP + 1))
echo "[${STEP}/${TOTAL_STEPS}] Creating DMG background..."
python3 << 'PYTHON_SCRIPT'
from PIL import Image, ImageDraw, ImageFont

width, height = 600, 400
img = Image.new('RGB', (width, height), color='#ffffff')
draw = ImageDraw.Draw(img)

try:
    text_font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
except:
    text_font = ImageFont.load_default()

arrow_color = '#333333'
arrow_center_x = width // 2
arrow_center_y = 180
arrow_size = 26
circle_radius = 5

draw.line([(arrow_center_x - 10, arrow_center_y - arrow_size),
           (arrow_center_x + 16, arrow_center_y)], fill=arrow_color, width=10)
draw.line([(arrow_center_x - 10, arrow_center_y + arrow_size),
           (arrow_center_x + 16, arrow_center_y)], fill=arrow_color, width=10)
draw.ellipse([(arrow_center_x - 10 - circle_radius, arrow_center_y - arrow_size - circle_radius),
              (arrow_center_x - 10 + circle_radius, arrow_center_y - arrow_size + circle_radius)], fill=arrow_color)
draw.ellipse([(arrow_center_x - 10 - circle_radius, arrow_center_y + arrow_size - circle_radius),
              (arrow_center_x - 10 + circle_radius, arrow_center_y + arrow_size + circle_radius)], fill=arrow_color)
draw.ellipse([(arrow_center_x + 16 - circle_radius, arrow_center_y - circle_radius),
              (arrow_center_x + 16 + circle_radius, arrow_center_y + circle_radius)], fill=arrow_color)

text = "Drag to Applications to Install"
text_bbox = draw.textbbox((0, 0), text, font=text_font)
text_width = text_bbox[2] - text_bbox[0]
draw.text(((width - text_width) // 2, 330), text, fill='#666666', font=text_font)

img.save('/tmp/transmogrifier-dmg-bg.png')
PYTHON_SCRIPT

# Step: Stage DMG contents
STEP=$((STEP + 1))
echo "[${STEP}/${TOTAL_STEPS}] Staging DMG contents..."
STAGING="/tmp/transmogrifier-dmg-staging"
rm -rf "${STAGING}" "${SCRIPT_DIR}/${DMG_NAME}" /tmp/transmogrifier-temp.dmg 2>/dev/null || true
mkdir -p "${STAGING}/.background"
cp -R "${APP_PATH}" "${STAGING}/"
ln -s /Applications "${STAGING}/Applications"
cp /tmp/transmogrifier-dmg-bg.png "${STAGING}/.background/background.png"

# Step: Create and style DMG
STEP=$((STEP + 1))
echo "[${STEP}/${TOTAL_STEPS}] Creating DMG..."
hdiutil create -volname "${VOLUME_NAME}" -srcfolder "${STAGING}" -ov -format UDRW /tmp/transmogrifier-temp.dmg

sleep 1
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen /tmp/transmogrifier-temp.dmg | grep "^/dev/" | head -1 | awk '{print $1}')
MOUNT_DIR="/Volumes/${VOLUME_NAME}"
sleep 2

SetFile -a V "${MOUNT_DIR}/.background" 2>/dev/null || true

/usr/bin/osascript <<EOT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {400, 100, 1000, 550}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 14
        set background picture of viewOptions to file ".background:background.png"
        set position of item "${APP_NAME}.app" to {150, 150}
        set position of item "Applications" to {450, 150}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOT

sync
sleep 2

for i in {1..10}; do
    if hdiutil detach "${DEVICE}" 2>/dev/null; then
        break
    fi
    sleep 1
done

sleep 2

# Step: Compress final DMG
STEP=$((STEP + 1))
echo "[${STEP}/${TOTAL_STEPS}] Compressing final DMG..."
hdiutil convert /tmp/transmogrifier-temp.dmg -format UDZO -imagekey zlib-level=9 -o "${SCRIPT_DIR}/${DMG_NAME}"

# Step: Notarize DMG
if $NOTARIZE; then
  STEP=$((STEP + 1))
  echo "[${STEP}/${TOTAL_STEPS}] Notarizing with Apple..."
  xcrun notarytool submit "${SCRIPT_DIR}/${DMG_NAME}" \
    --keychain-profile "transmogrifier" \
    --wait
  echo "   Stapling notarization ticket..."
  xcrun stapler staple "${SCRIPT_DIR}/${DMG_NAME}"
fi

# Cleanup
rm -f /tmp/transmogrifier-temp.dmg /tmp/transmogrifier-dmg-bg.png
rm -rf "${STAGING}"

echo ""
echo "=== Done ==="
echo "DMG: ${SCRIPT_DIR}/${DMG_NAME}"
ls -lh "${SCRIPT_DIR}/${DMG_NAME}"
if $SIGN; then
  echo ""
  echo "Signature: $(codesign -dv "${SCRIPT_DIR}/${DMG_NAME}" 2>&1 | grep 'Authority=' || echo 'DMG not signed (normal for DMGs)')"
fi
if $NOTARIZE; then
  echo "Notarization: $(xcrun stapler validate "${SCRIPT_DIR}/${DMG_NAME}" 2>&1 | tail -1)"
fi
echo ""
echo "To test: open \"${SCRIPT_DIR}/${DMG_NAME}\""
