#!/bin/bash
# ============================================================
# API Tester - One-Click Build Script
# Run this script on your local machine (with Flutter installed)
# ============================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  API Tester - Build Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Step 0: Check Flutter
echo ""
echo -e "${YELLOW}[0/6] Checking prerequisites...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}ERROR: Flutter not found!${NC}"
    echo "Install Flutter first: https://docs.flutter.dev/get-started/install"
    exit 1
fi
echo "  Flutter: $(flutter --version | head -1)"

if ! command -v java &> /dev/null; then
    echo -e "${RED}ERROR: Java not found! Install JDK 17+${NC}"
    exit 1
fi
echo "  Java: $(java -version 2>&1 | head -1)"
echo -e "${GREEN}  OK${NC}"

# Step 1: Download Inter font
echo ""
echo -e "${YELLOW}[1/6] Setting up Inter font...${NC}"
FONT_DIR="assets/fonts"
mkdir -p "$FONT_DIR"

if [ ! -f "$FONT_DIR/Inter-Regular.ttf" ]; then
    echo "  Downloading Inter font..."
    cd "$FONT_DIR"
    curl -sL "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bwght%5D.ttf" -o Inter-Variable.ttf 2>/dev/null || \
    curl -sL "https://fonts.google.com/download?family=Inter" -o inter.zip && unzip -qo inter.zip -d tmp_font && \
        cp tmp_font/static/Inter-Regular.ttf . 2>/dev/null; \
        cp tmp_font/static/Inter-Medium.ttf . 2>/dev/null; \
        cp tmp_font/static/Inter-SemiBold.ttf . 2>/dev/null; \
        cp tmp_font/static/Inter-Bold.ttf . 2>/dev/null; \
        rm -rf tmp_font inter.zip 2>/dev/null
    cd ../..

    # Fallback: create dummy font files if download fails
    if [ ! -f "$FONT_DIR/Inter-Regular.ttf" ]; then
        echo -e "${YELLOW}  Font download failed, using system fallback...${NC}"
        # Remove font references from pubspec.yaml to use default font
        sed -i '/fonts:/,/Inter-Bold.ttf/d' pubspec.yaml 2>/dev/null || true
        sed -i '/Inter-\[wght\]/d' pubspec.yaml 2>/dev/null || true
    fi
fi
echo -e "${GREEN}  OK${NC}"

# Step 2: Install dependencies
echo ""
echo -e "${YELLOW}[2/6] Installing dependencies (flutter pub get)...${NC}"
flutter pub get

# Step 3: Generate code (freezed, drift, json_serializable, riverpod)
echo ""
echo -e "${YELLOW}[3/6] Generating code (build_runner)...${NC}"
echo "  This may take a few minutes on first run..."
dart run build_runner build --delete-conflicting-outputs

# Step 4: Fix common issues automatically
echo ""
echo -e "${YELLOW}[4/6] Running static analysis...${NC}"
flutter analyze 2>&1 | tail -20 || true
echo -e "${GREEN}  Done (warnings above are non-blocking)${NC}"

# Step 5: Build APK
echo ""
echo -e "${YELLOW}[5/6] Building release APK...${NC}"
flutter build apk --release

# Step 6: Show result
echo ""
echo -e "${GREEN}[6/6] ========================================${NC}"
echo -e "${GREEN}  BUILD SUCCESSFUL!${NC}"
echo -e "${GREEN} ========================================${NC}"
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
if [ -f "$APK_PATH" ]; then
    SIZE=$(du -h "$APK_PATH" | cut -f1)
    echo -e "  APK: ${GREEN}${APK_PATH}${NC}"
    echo -e "  Size: ${GREEN}${SIZE}${NC}"
    echo ""
    echo "  Install on device:"
    echo "    adb install $APK_PATH"
else
    echo -e "${RED}  APK file not found. Check build output above.${NC}"
fi