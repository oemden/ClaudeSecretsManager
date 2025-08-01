#!/bin/bash

###############################################################################
# Claude Secrets Manager - Build and Package Script
# Builds Swift binaries, signs them, and creates a macOS installer package
# Based on XCreds build patterns
###############################################################################

set -e

PRODUCT_NAME="ClaudeSecretsManager"
SCRIPT_DIR="$(dirname "$0")"
PROJECT_DIR="$(pwd)"
BUILD_CONFIG="release"
CLAUDE_CODE_VERSION=$(claude --version | awk '{print $1}' 2>/dev/null || echo "Unknown")
CLAUDE_DESKTOP_VERSION=$(osascript -e 'version of app "Claude"' 2>/dev/null || echo "Unknown")
MACOS_VERSION="$(sw_vers -productName) $(sw_vers -productVersion)"
RELEASE_DATE=$(date "+%B %Y")

# Certificate names (update these with your actual certificate names)
DEV_ID_APP_CERT="Developer ID Application: Olivier EMSELLEM (PV98B3794W)"
DEV_ID_INSTALLER_CERT="Developer ID Installer: Olivier EMSELLEM (PV98B3794W)"

echo "🚀 Claude Secrets Manager - Build and Package"
echo "============================================="
echo "Project: $PROJECT_DIR"
echo "Build Config: $BUILD_CONFIG"

# Get version from git tag (remove 'v' prefix if present)
GIT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "0.0.1")
GIT_VERSION=${GIT_VERSION#v}  # Remove 'v' prefix if present
echo "📋 Git version: $GIT_VERSION"

# Update version in SharedConstants.swift
echo "🔄 Updating version in SharedConstants.swift..."
sed -i '' "s/public static let version = \".*\"/public static let version = \"$GIT_VERSION\"/" Sources/SharedConstants/SharedConstants.swift
echo "🔄 Updating version in Packages Scripts..."
sed -i '' "s/Version \".*\"/Version \"$GIT_VERSION\"/" Packages/Scripts/*install
# Update README
echo "🔄 Updating Claude Desktop version in README..."
sed -i '' "s/Claude Desktop Version: \".*\"/Claude Desktop Version: \"$CLAUDE_DESKTOP_VERSION\"/" ./README.md
echo "🔄 Updating Claude Code version in README..."
sed -i '' "s/Claude Desktop Version: \".*\"/Claude Desktop Version: \"$CLAUDE_DESKTOP_VERSION\"/" ./README.md
echo "🔄 Updating macOS version in README..."
sed -i '' "s/macOS Version: \".*\"/macOS Version: \"$MACOS_VERSION\"/" ./README.md
echo "🔄 Updating What's New in README..."
# sed -i '' "s/What's New in version \`.*\`/What's New in version \"$GIT_VERSION\"/" ./README.md
sed -i '' "s/What's New in version [0-9.]* ([^)]*)/What's New in version $GIT_VERSION ($RELEASE_DATE)/" ./README.md

echo "   ✅ Version updated to: $GIT_VERSION"

# # Check if git working directory is clean (unless --force is used)
# if [[ "${1}" == "--force" ]]; then
#     echo "⚠️  Skipping git clean check (--force used)"
# else
#     if output="$(git status --porcelain)" && [[ -z "$output" ]]; then
#         echo "✅ Git working directory is clean"
#     else
#         echo "❌ Working directory has uncommitted changes"
#         echo "   Use --force to build anyway, or commit your changes first"
#         exit 1
#     fi
# fi

echo ""
echo "🔨 Building Swift Package..."

# Clean and build release binaries
swift package clean
swift build -c "$BUILD_CONFIG"

if [[ $? -ne 0 ]]; then
    echo "❌ Swift build failed"
    exit 1
fi

echo "✅ Swift build completed successfully"

# Get build paths using symlinked release directory
BUILD_DIR="$PROJECT_DIR/.build/$BUILD_CONFIG"
CLAUDESECRETS_BINARY="$BUILD_DIR/claudesecrets"
CLAUDESECRETS_CLI_BINARY="$BUILD_DIR/claudesecrets-cli"

# Verify binaries exist
if [[ ! -f "$CLAUDESECRETS_BINARY" ]]; then
    echo "❌ Main binary not found: $CLAUDESECRETS_BINARY"
    exit 1
fi

if [[ ! -f "$CLAUDESECRETS_CLI_BINARY" ]]; then
    echo "❌ CLI binary not found: $CLAUDESECRETS_CLI_BINARY"
    exit 1
fi

echo ""
echo "🔐 Code Signing Binaries..."

# Sign the main daemon binary
echo "   Signing claudesecrets daemon..."
if codesign --force --options runtime --sign "$DEV_ID_APP_CERT" "$CLAUDESECRETS_BINARY"; then
    echo "   ✅ claudesecrets signed successfully"
else
    echo "   ❌ Failed to sign claudesecrets"
    exit 1
fi

# Sign the CLI binary
echo "   Signing claudesecrets-cli..."
if codesign --force --options runtime --sign "$DEV_ID_APP_CERT" "$CLAUDESECRETS_CLI_BINARY"; then
    echo "   ✅ claudesecrets-cli signed successfully"
else
    echo "   ❌ Failed to sign claudesecrets-cli"
    exit 1
fi

# Verify signatures
echo "   Verifying signatures..."
codesign -dv "$CLAUDESECRETS_BINARY"
codesign -dv "$CLAUDESECRETS_CLI_BINARY"


echo ""
echo "🏗️  Building Package..."

# Ensure Packages directory exists
if [[ ! -d "$PROJECT_DIR/Packages" ]]; then
    echo "❌ Packages directory not found: $PROJECT_DIR/Packages"
    exit 1
fi

# Set the payload reference folder for the package project
PKGPROJ_FILE="$PROJECT_DIR/Packages/ClaudeSecretsManager.pkgproj"
if [[ ! -f "$PKGPROJ_FILE" ]]; then
    echo "❌ Package project file not found: $PKGPROJ_FILE"
    exit 1
fi

echo ""
echo "📦 Updating Package Version with latest git Tag..."

/usr/libexec/PlistBuddy -c "Set :PACKAGES:0:PACKAGE_SETTINGS:VERSION $GIT_VERSION" "$PKGPROJ_FILE"

echo "   ✅ Package version updated to: $GIT_VERSION"
echo "   ✅ Package paths updated to use .build/release/ symlinks"

# Build the package using packagesbuild (Packages.app command line tool)
PACKAGE_OUTPUT_DIR="$PROJECT_DIR/Packages/build"
mkdir -p "$PACKAGE_OUTPUT_DIR"

if command -v packagesbuild >/dev/null 2>&1; then
    echo "   Using packagesbuild to create package..."
    if packagesbuild "$PKGPROJ_FILE"; then
        echo "   ✅ Package built successfully"
    else
        echo "   ❌ Package build failed"
        exit 1
    fi
else
    echo "   ❌ packagesbuild not found. Please install Packages.app"
    echo "      Download from: http://s.sudre.free.fr/Software/Packages/about.html"
    exit 1
fi

# Find the created package
PACKAGE_FILE=$(find "$PACKAGE_OUTPUT_DIR" -name "*.pkg" | head -1)
if [[ -z "$PACKAGE_FILE" ]]; then
    echo "❌ Package file not found in $PACKAGE_OUTPUT_DIR"
    exit 1
fi

echo "   ✅ Build completed successfully"

echo ""
echo "🎉 Build and Package Complete!"
echo "================================="
echo "✅ Binaries built and signed"
echo "✅ Package created and signed"
echo "📦 Package location: $PACKAGE_FILE"
echo ""
echo "📋 Next Steps:"
echo "   1. Test installation: sudo installer -pkg \"$PACKAGE_FILE\" -target /"
echo "   2. For distribution: notarize the package with Apple"
echo "   3. Staple the notarization: xcrun stapler staple \"$PACKAGE_FILE\""
echo ""

# Optional: Show package info
echo "📊 Package Information:"
pkgutil --payload-files "$PACKAGE_FILE" | head -10
echo ""
echo "🏗️ open Build Folder"
open "${PACKAGE_OUTPUT_DIR}"
echo ""

exit 0