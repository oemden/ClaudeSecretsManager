#!/bin/bash

# ClaudeAutoConfig Test Uninstallation Script
# Cleans up test installation

echo "🧹 ClaudeAutoConfig Test Uninstallation"
echo "======================================="

BINARY_PATH="/usr/local/bin/ClaudeAutoConfig"
PLIST_PATH="$HOME/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
PREFS_PATH="$HOME/Library/Preferences/com.oemden.claudeautoconfig.plist"

# Disable LaunchAgent if loaded
if [ -f "$PLIST_PATH" ]; then
    echo "🛑 Disabling LaunchAgent..."
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || echo "   ℹ️  LaunchAgent was not loaded"
    
    echo "🗑️  Removing LaunchAgent plist..."
    rm "$PLIST_PATH"
    echo "   ✅ Removed: $PLIST_PATH"
fi

# Remove binary (requires sudo)
if [ -f "$BINARY_PATH" ]; then
    echo "🗑️  Removing binary..."
    sudo rm "$BINARY_PATH"
    echo "   ✅ Removed: $BINARY_PATH"
fi

# Remove preferences (optional)
if [ -f "$PREFS_PATH" ]; then
    echo "🗑️  Removing preferences..."
    rm "$PREFS_PATH"
    echo "   ✅ Removed: $PREFS_PATH"
fi

# Clean up any running processes
echo "🔍 Checking for running processes..."
PIDS=$(pgrep -f ClaudeAutoConfig || true)
if [ -n "$PIDS" ]; then
    echo "🛑 Killing running ClaudeAutoConfig processes: $PIDS"
    kill $PIDS
fi

echo ""
echo "✅ Uninstallation complete!"
echo "🧪 Ready for fresh testing"