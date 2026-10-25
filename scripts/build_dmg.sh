#!/bin/bash
set -e

# ==============================================================================
# Notchify - Universal Binary & Custom DMG Builder Script
# ==============================================================================

# Ensure clean system PATH so system tools (head, sed, awk) are prioritized
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:$PATH"

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "🚀 [1/5] Building Notchify Universal Binary (arm64 + x86_64)..."
rm -rf ./build ./dmg_source ./dist ./build_dmg
mkdir -p ./dmg_source ./dist ./build_dmg

xcodebuild -scheme Notchify \
  -configuration Release \
  -derivedDataPath ./build \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  clean build

echo "🔍 [2/5] Verifying Universal Binary Architectures..."
APP_BIN="./build/Build/Products/Release/Notchify.app/Contents/MacOS/Notchify"
lipo -info "$APP_BIN"

echo "🎨 [3/5] Generating Custom Retina DMG Background..."
python3 - << 'EOF'
import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def make_bg(scale=2):
    w, h = 660 * scale, 420 * scale
    img = Image.new('RGBA', (w, h), (0, 0, 0, 255))
    draw = ImageDraw.Draw(img)

    # 1. Background space gradient
    for y in range(h):
        f = y / float(h)
        r = int(24 * (1 - f) + 11 * f)
        g = int(27 * (1 - f) + 12 * f)
        b = int(34 * (1 - f) + 16 * f)
        draw.line([(0, y), (w, y)], fill=(r, g, b, 255))

    # 2. Glowing icon pedestals
    glow = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    
    # Left icon glow (Cyan/Blue)
    cx1, cy1 = 180 * scale, 200 * scale
    r1 = 110 * scale
    glow_draw.ellipse([cx1 - r1, cy1 - r1, cx1 + r1, cy1 + r1], fill=(0, 160, 255, 38))
    
    # Right icon glow (Purple/Blue)
    cx2, cy2 = 480 * scale, 200 * scale
    r2 = 110 * scale
    glow_draw.ellipse([cx2 - r2, cy2 - r2, cx2 + r2, cy2 + r2], fill=(120, 90, 255, 38))
    
    glow = glow.filter(ImageFilter.GaussianBlur(radius=35 * scale))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # 3. Target pedestals
    pr = 75 * scale
    draw.ellipse([cx1 - pr, cy1 - pr, cx1 + pr, cy1 + pr], outline=(255, 255, 255, 45), width=2 * scale)
    draw.ellipse([cx2 - pr, cy2 - pr, cx2 + pr, cy2 + pr], outline=(255, 255, 255, 45), width=2 * scale)

    # 4. Realistic Notch at top center
    notch_w = 110 * scale
    notch_h = 28 * scale
    nx1 = (w - notch_w) // 2
    nx2 = nx1 + notch_w
    ny1 = 0
    ny2 = notch_h
    draw.rounded_rectangle([nx1, ny1 - 10, nx2, ny2], radius=10 * scale, fill=(4, 5, 7, 255))
    draw.rounded_rectangle([nx1, ny1 - 10, nx2, ny2], radius=10 * scale, outline=(255, 255, 255, 40), width=scale)
    cam_r = 3 * scale
    draw.ellipse([(w // 2) - cam_r, (ny2 // 2) - cam_r, (w // 2) + cam_r, (ny2 // 2) + cam_r], fill=(15, 20, 28, 255), outline=(40, 50, 70, 255))
    ind_r = 1.5 * scale
    draw.ellipse([(w // 2) + 12 * scale - ind_r, (ny2 // 2) - ind_r, (w // 2) + 12 * scale + ind_r, (ny2 // 2) + ind_r], fill=(52, 199, 89, 230))

    # 5. Typography
    font_path = "/System/Library/Fonts/SFNS.ttf"
    title_font = ImageFont.truetype(font_path, 25 * scale)
    sub_font = ImageFont.truetype(font_path, 13 * scale)
    badge_font = ImageFont.truetype(font_path, 11 * scale)

    # Title & Subtitle
    title_text = "Notchify"
    tb = draw.textbbox((0, 0), title_text, font=title_font)
    tw = tb[2] - tb[0]
    draw.text(((w - tw) // 2, 42 * scale), title_text, font=title_font, fill=(255, 255, 255, 245))

    sub_text = "Drag Notchify to Applications to install"
    sb = draw.textbbox((0, 0), sub_text, font=sub_font)
    sw = sb[2] - sb[0]
    draw.text(((w - sw) // 2, 75 * scale), sub_text, font=sub_font, fill=(160, 168, 185, 210))

    # 6. Directional Arrow
    ax1 = 280 * scale
    ax2 = 380 * scale
    ay = 190 * scale
    arrow_color = (0, 190, 255, 230)
    draw.line([(ax1, ay), (ax2 - 12 * scale, ay)], fill=arrow_color, width=3 * scale)
    head_points = [
        (ax2, ay),
        (ax2 - 16 * scale, ay - 11 * scale),
        (ax2 - 12 * scale, ay),
        (ax2 - 16 * scale, ay + 11 * scale)
    ]
    draw.polygon(head_points, fill=arrow_color)

    arr_label = "INSTALL"
    alb = draw.textbbox((0, 0), arr_label, font=badge_font)
    alw = alb[2] - alb[0]
    draw.text(((ax1 + ax2 - alw) // 2, ay - 24 * scale), arr_label, font=badge_font, fill=(0, 190, 255, 210))

    # 7. Bottom Badge
    badge_text = " Universal Binary (Apple Silicon & Intel)  •  macOS 12.0+"
    bb = draw.textbbox((0, 0), badge_text, font=badge_font)
    bw = bb[2] - bb[0]
    bh = bb[3] - bb[1]
    badge_pad_x = 18 * scale
    badge_pad_y = 6 * scale
    bx1 = (w - bw) // 2 - badge_pad_x
    bx2 = (w + bw) // 2 + badge_pad_x
    by1 = 368 * scale
    by2 = by1 + bh + badge_pad_y * 2
    draw.rounded_rectangle([bx1, by1, bx2, by2], radius=14 * scale, fill=(20, 23, 28, 200), outline=(255, 255, 255, 35), width=scale)
    draw.text(((w - bw) // 2, by1 + badge_pad_y), badge_text, font=badge_font, fill=(155, 165, 185, 220))

    draw.line([(0, 0), (w, 0)], fill=(255, 255, 255, 40), width=scale)
    return img

img_2x = make_bg(scale=2)
img_2x.save("build_dmg/background@2x.png")
img_1x = make_bg(scale=1)
img_1x.save("build_dmg/background.png")
EOF

tiffutil -cathidpicheck build_dmg/background.png build_dmg/background@2x.png -out build_dmg/background.tiff

echo "📦 [4/5] Staging Application Files..."
cp -R ./build/Build/Products/Release/Notchify.app dmg_source/

echo "💿 [5/5] Packaging Custom DMG with create-dmg..."
create-dmg \
  --volname "Notchify" \
  --volicon "Notchify/AppIcon.icns" \
  --background "build_dmg/background.tiff" \
  --window-pos 200 120 \
  --window-size 660 420 \
  --icon-size 128 \
  --text-size 13 \
  --icon "Notchify.app" 180 200 \
  --hide-extension "Notchify.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  --format UDZO \
  "dist/Notchify.dmg" \
  "dmg_source"

echo "🎉 Success! DMG is ready at dist/Notchify.dmg"
ls -lh dist/Notchify.dmg
