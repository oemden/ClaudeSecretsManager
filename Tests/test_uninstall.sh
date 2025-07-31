#!/bin/bash

###############################################################################
# Claude Secrets Manager Test Uninstallation Script
# Supports dev/prod uninstallation modes
# Cleans up test installation based on environment
###############################################################################

# Environment configuration (dev/prod)
# ENV="${ENV:-dev}"  # Default to dev mode, override with ENV=prod ./test_uninstall.sh
KEEP_Prefs="yes" # Keep local com.oemden.claudesecrets file
TEST_SCRIPT="${PWD}/test_install.sh"
MYENV=$(cat "${TEST_SCRIPT}" | grep "MYENV=" | awk -F'"' '{print $2}')

if [[ -z "$MYENV" ]]; then
    echo "❌ MYENV not set in test_install.sh, defaulting to dev mode"
    MYENV="dev"
fi

echo "🧹 Claude Secrets Manager Test Uninstallation ( $MYENV mode)"
echo "========================================================"

# Configure paths based on environment
if [[ "$ENV" == "prod" ]]; then
    # Production mode: system-wide installation paths
    DAEMON_PATH="/usr/local/bin/claudesecrets"
    CLI_PATH="/usr/local/bin/claudesecrets-cli"
    SUDO_CMD="sudo"
    echo "📦 Production mode: Uninstalling from /usr/local/bin (requires sudo)"
else
    # Development mode: user installation paths
    DAEMON_PATH="/opt/dev/bin/claudesecrets"
    CLI_PATH="/opt/dev/bin/claudesecrets-cli"
    SUDO_CMD=""
    echo "🛠️  Development mode: Uninstalling from /opt/dev/bin (no sudo required)"
fi

PLIST_PATH="$HOME/Library/LaunchAgents/com.oemden.claudesecrets.plist"
PREFS_PATH="$HOME/Library/Preferences/com.oemden.claudesecrets.plist"

# Disable LaunchAgent if loaded
if [ -f "$PLIST_PATH" ]; then
    echo "🛑 Disabling LaunchAgent..."
    launchctl unload -w "$PLIST_PATH" 2>/dev/null || echo "   ℹ️  LaunchAgent was not loaded"
    
    echo "🗑️  Removing LaunchAgent plist..."
    rm "$PLIST_PATH"
    echo "   ✅ Removed: $PLIST_PATH"
fi

# Remove daemon binary
if [ -f "$DAEMON_PATH" ]; then
    echo "🗑️  Removing daemon binary..."
    $SUDO_CMD rm "$DAEMON_PATH"
    echo "   ✅ Removed: $DAEMON_PATH"
fi

# Remove CLI binary
if [ -f "$CLI_PATH" ]; then
    echo "🗑️  Removing CLI binary..."
    $SUDO_CMD rm "$CLI_PATH"
    echo "   ✅ Removed: $CLI_PATH"
fi

# Remove preferences (optional)
if [[ "${KEEP_Prefs}" == "no" ]] && [[ -f "${PREFS_PATH}" ]] ; then
    echo "🗑️  Removing preferences..."
    rm "$PREFS_PATH"
    echo "   ✅ Removed: $PREFS_PATH"
else
    echo "ℹ️  Keeping preferences file: $PREFS_PATH"
fi

# Clean up any running processes
echo "🔍 Checking for running processes..."
PIDS=$(pgrep -f claudesecrets || true)
if [ -n "$PIDS" ]; then
    echo "🛑 Killing running claudesecrets processes: $PIDS"
    kill $PIDS
    sleep 1
    # Force kill if still running
    PIDS=$(pgrep -f claudesecrets || true)
    if [ -n "$PIDS" ]; then
        echo "🔥 Force killing stubborn processes: $PIDS"
        kill -9 $PIDS
    fi
fi

# Clean up temporary files
echo "🧹 Cleaning up temporary files..."
if [ -d "/tmp/ClaudeSecretsManager" ]; then
    rm -rf "/tmp/ClaudeSecretsManager"
    echo "   ✅ Removed: /tmp/ClaudeSecretsManager"
fi

echo ""
echo "✅ Uninstallation complete!"
echo "🧪 Ready for fresh testing"