#!/bin/bash

# Simple DMG creator with white background and arrow
# The Transmogrifier v1.0.1 (HEIC support)

set -e

APP_NAME="The Transmogrifier"
DMG_NAME="The Transmogrifier 1.0.1.dmg"
APP_PATH="/Users/dannybreckenridge/Library/Developer/Xcode/DerivedData/ImageProcessingApp-enbpgjpfantyrbghuvhopmoicsmy/Build/Products/Release/The Transmogrifier.app"
VOLUME_NAME="Install The Transmogrifier"

# Clean up completely
echo "Cleaning up old files..."
rm -rf dmg_temp "${DMG_NAME}" temp.dmg background.png 2>/dev/null || true
sleep 1

echo "Creating white background image with arrow..."

# Create background using Python
python3 << 'PYTHON_SCRIPT'
from PIL import Image, ImageDraw, ImageFont

# Create a 600x400 image with WHITE background
width, height = 600, 400
img = Image.new('RGB', (width, height), color='#ffffff')
draw = ImageDraw.Draw(img)

# Draw a custom ">" arrow with rounded ends (like the icon you showed)
try:
    text_font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
except:
    text_font = ImageFont.load_default()

# Draw a ">" shape with rounded line caps centered between icons
# Made 35% smaller and vertically centered with the icons
arrow_color = '#333333'
arrow_center_x = width // 2
arrow_center_y = 180  # Vertically centered with icons (icons are at y=150 + half their height ~128/2)
arrow_size = 26  # 40 * 0.65 = 26 (35% smaller)

# Draw the two lines of the ">" with rounded caps
# PIL's draw.line with 'round' cap will give rounded ends
from PIL import ImageDraw

# Top line of ">" (from top-left to center-right)
draw.line(
    [(arrow_center_x - 10, arrow_center_y - arrow_size),
     (arrow_center_x + 16, arrow_center_y)],
    fill=arrow_color, width=10
)

# Bottom line of ">" (from bottom-left to center-right)
draw.line(
    [(arrow_center_x - 10, arrow_center_y + arrow_size),
     (arrow_center_x + 16, arrow_center_y)],
    fill=arrow_color, width=10
)

# Draw circles at the ends to create rounded caps
circle_radius = 5
# Top end
draw.ellipse(
    [(arrow_center_x - 10 - circle_radius, arrow_center_y - arrow_size - circle_radius),
     (arrow_center_x - 10 + circle_radius, arrow_center_y - arrow_size + circle_radius)],
    fill=arrow_color
)
# Bottom end
draw.ellipse(
    [(arrow_center_x - 10 - circle_radius, arrow_center_y + arrow_size - circle_radius),
     (arrow_center_x - 10 + circle_radius, arrow_center_y + arrow_size + circle_radius)],
    fill=arrow_color
)
# Point (right end)
draw.ellipse(
    [(arrow_center_x + 16 - circle_radius, arrow_center_y - circle_radius),
     (arrow_center_x + 16 + circle_radius, arrow_center_y + circle_radius)],
    fill=arrow_color
)

# Add instruction text at bottom
text = "Drag to Applications to Install"
text_bbox = draw.textbbox((0, 0), text, font=text_font)
text_width = text_bbox[2] - text_bbox[0]
text_x = (width - text_width) // 2

draw.text((text_x, 330), text, fill='#666666', font=text_font)

# Save
img.save('background.png')
print("✓ Background created")
PYTHON_SCRIPT

echo "Creating DMG staging directory..."
mkdir -p dmg_temp/.background
cp -R "$APP_PATH" dmg_temp/
ln -s /Applications dmg_temp/Applications
cp background.png dmg_temp/.background/

echo "Creating temporary DMG..."
hdiutil create -volname "$VOLUME_NAME" -srcfolder dmg_temp -ov -format UDRW temp.dmg

# Mount it
echo "Mounting DMG..."
sleep 1
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen temp.dmg | grep "^/dev/" | head -1 | awk '{print $1}')
MOUNT_DIR="/Volumes/$VOLUME_NAME"

echo "Mounted at: $MOUNT_DIR"
sleep 2

# Make .background folder invisible
SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null || echo "SetFile not available"

# Style the DMG window
echo "Styling DMG..."
sleep 1

/usr/bin/osascript <<EOT
tell application "Finder"
    tell disk "$VOLUME_NAME"
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

        set position of item "$APP_NAME.app" to {150, 150}
        set position of item "Applications" to {450, 150}

        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOT

# Finalize
echo "Finalizing..."
sync
sleep 2

# Unmount - try multiple times if needed
echo "Unmounting..."
for i in {1..10}; do
    if hdiutil detach "$DEVICE" 2>/dev/null; then
        echo "Unmounted successfully"
        break
    fi
    echo "Retry unmount ($i/10)..."
    sleep 1
done

sleep 2

# Convert to compressed DMG
echo "Creating final compressed DMG..."
rm -f "$DMG_NAME"
hdiutil convert temp.dmg -format UDZO -imagekey zlib-level=9 -o "$DMG_NAME"

# Clean up
rm -f temp.dmg background.png
rm -rf dmg_temp

echo ""
echo "✅ DMG created successfully: $DMG_NAME"
echo "   Version 1.0.1 with HEIC input support"
echo ""
ls -lh "$DMG_NAME"
echo ""
echo "To test, run: open \"$DMG_NAME\""
