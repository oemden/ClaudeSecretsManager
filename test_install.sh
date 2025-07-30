#!/bin/bash

# ClaudeAutoConfig Test Installation Script
# Simulates what Packages.app installer will do

set -e

echo "🧪 ClaudeAutoConfig Test Installation"
echo "======================================"

# Build first
echo "🔨 Building ClaudeAutoConfig..."
swift build -c release

BUILD_DIR=".build/release"
BINARY_SOURCE="$PWD/$BUILD_DIR/ClaudeAutoConfig"
PLIST_SOURCE="$PWD/com.oemden.claudeautoconfig.plist"

# Installation paths
BINARY_DEST="/usr/local/bin/ClaudeAutoConfig"
PLIST_DEST="$HOME/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"

echo ""
echo "📦 Installing files..."

# Check if binary was built
if [ ! -f "$BINARY_SOURCE" ]; then
    echo "❌ Binary not found: $BINARY_SOURCE"
    exit 1
fi

# Check if plist exists
if [ ! -f "$PLIST_SOURCE" ]; then
    echo "❌ Plist not found: $PLIST_SOURCE"
    exit 1
fi

# Create directories if needed
echo "📁 Creating directories..."
sudo mkdir -p /usr/local/bin
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Copy binary (requires sudo)
echo "📋 Installing binary to /usr/local/bin..."
sudo cp "$BINARY_SOURCE" "$BINARY_DEST"
sudo chmod +x "$BINARY_DEST"
echo "   ✅ Binary installed: $BINARY_DEST"

# Copy plist (user space)
echo "📋 Installing LaunchAgent plist..."
cp "$PLIST_SOURCE" "$PLIST_DEST"
echo "   ✅ Plist installed: $PLIST_DEST"

# Enable the daemon
echo "🚀 Enabling LaunchAgent..."
launchctl load -w "$PLIST_DEST"
echo "   ✅ LaunchAgent enabled and started"

echo ""
echo "✅ Installation complete!"
echo ""
echo "🧪 Test Steps:"
echo "1. Delete your com.oemden.claudeautoconfig preferences:"
echo "   rm ~/Library/Preferences/com.oemden.claudeautoconfig.plist"
echo ""
echo "2. Launch TextEdit to trigger the daemon:"
echo "   open -a TextEdit"
echo ""
echo "3. Check daemon status:"
echo "   $BINARY_DEST --status"
echo ""
echo "🛑 To uninstall later:"
echo "   $BINARY_DEST --disable"
echo "   sudo rm $BINARY_DEST"
echo "   rm $PLIST_DEST"