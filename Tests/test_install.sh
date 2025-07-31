#!/bin/bash

###############################################################################
# Claude Secrets Manager Test Installation Script
# Simulates what Packages.app installer will do
# This script is for testing purposes only and should not be used in production MYENVironments.
# It assumes you have already built the binary using `swift build -c release`
# It will install the binary and plist in the appropriate locations based on the MYENVironment (dev or prod).
###############################################################################

set -e

echo "🧪 Claude Secrets Manager Test Installation"
echo "======================================"

# Build first
echo "🔨 Building Claude Secrets Manager..."
swift build -c release

BUILD_DIR="../.build/release"
BINARY_DAEMON="claudesecrets"
BINARY_CLI="claudesecrets-cli"
BINARY_DAEMON_SOURCE="${PWD}/${BUILD_DIR}/${BINARY_DAEMON}"
BINARY_CLI_SOURCE="${PWD}/${BUILD_DIR}/${BINARY_CLI}"
PLIST_SOURCE="../LaunchAgent/com.oemden.claudesecrets.plist"

# Installation paths
MYENV="dev" # Change to "prod" for production install
BINARY_DEST_DIR_PROD="/usr/local/bin/"
BINARY_DEST_DIR_DEV="/opt/dev/bin/"
# Destination paths
BINARY_DAEMON_DEST_PROD="${BINARY_DEST_DIR_PROD}/${BINARY_DAEMON}"
BINARY_DAEMON_DEST_DEV="${BINARY_DEST_DIR_DEV}/${BINARY_DAEMON}"
BINARY_CLI_DEST_PROD="${BINARY_DEST_DIR_PROD}/${BINARY_CLI}"
BINARY_CLI_DEST_DEV="${BINARY_DEST_DIR_DEV}/${BINARY_CLI}"
PLIST_DEST="${HOME}/Library/LaunchAgents/com.oemden.claudesecrets.plist"

echo ""
echo "📦 Installing files..."
if [ "${MYENV}" == "prod" ]; then
    echo "   ⚠️ Running in prod mode, sudo required"
elif [ "${MYENV}" == "dev" ]; then
    echo "   ⚠️ Running in dev mode, no sudo required"
fi

# Check if binaries were built
if [ ! -f "${BINARY_DAEMON_SOURCE}" ]; then
    echo "❌ Daemon binary not found: ${BINARY_DAEMON_SOURCE}"
    exit 1
fi

if [ ! -f "${BINARY_CLI_SOURCE}" ]; then
    echo "❌ CLI binary not found: ${BINARY_CLI_SOURCE}"
    exit 1
fi

# Check if plist exists
if [ ! -f "${PLIST_SOURCE}" ]; then
    echo "❌ Plist not found: ${PLIST_SOURCE}"
    exit 1
fi

# Create directories if needed
echo "📁 Creating directories..."
if [ "${MYENV}" == "prod" ]; then
    BINARY_DEST="${BINARY_DEST_PROD}"
    BINARY_DEST_DIR="${BINARY_DEST_DIR_PROD}"
    sudo mkdir -p ${BINARY_DEST_DIR}
elif [ "${MYENV}" == "dev" ]; then
    BINARY_DEST="${BINARY_DEST_DEV}"
    BINARY_DEST_DIR=${BINARY_DEST_DIR_DEV}
    mkdir -p ${BINARY_DEST_DIR}
fi
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Install daemon binary
echo "📋 Installing daemon and cli binaries to ${BINARY_DEST_DIR}..."
if [ "${MYENV}" == "prod" ]; then
    BINARY_DAEMON_DEST="${BINARY_DAEMON_DEST_PROD}"
    sudo cp "${BINARY_DAEMON_SOURCE}" "${BINARY_DAEMON_DEST}"
    sudo chmod +x "${BINARY_DAEMON_DEST}"
elif [ "${MYENV}" == "dev" ]; then
    BINARY_DAEMON_DEST="${BINARY_DAEMON_DEST_DEV}"
    cp "${BINARY_DAEMON_SOURCE}" "${BINARY_DAEMON_DEST}"
    chmod +x "${BINARY_DAEMON_DEST}"
fi
echo "   ✅ Daemon binary installed: ${BINARY_DAEMON_DEST}"

# Install CLI binary
echo "📋 Installing CLI binary to ${BINARY_DEST_DIR}..."
if [ "${MYENV}" == "prod" ]; then
    BINARY_CLI_DEST="${BINARY_CLI_DEST_PROD}"
    sudo cp "${BINARY_CLI_SOURCE}" "${BINARY_CLI_DEST}"
    sudo chmod +x "${BINARY_CLI_DEST}"
elif [ "${MYENV}" == "dev" ]; then
    BINARY_CLI_DEST="${BINARY_CLI_DEST_DEV}"
    cp "${BINARY_CLI_SOURCE}" "${BINARY_CLI_DEST}"
    chmod +x "${BINARY_CLI_DEST}"
fi
echo "   ✅ CLI binary installed: ${BINARY_CLI_DEST}"

# Copy LaunchAgent plist (user space)
echo "unloading LaunchAgent if it exists..."
launchctl unload -w "${PLIST_DEST}" 2>/dev/null || true
rm -f "${PLIST_DEST}"
sleep 5
echo "📋 Installing LaunchAgent plist..."
cp "${PLIST_SOURCE}" "${PLIST_DEST}"

# Update binary path in plist based on MYENVironment
echo "🔧 Updating plist binary path for ${MYENV} MYENVironment..."
if [ "${MYENV}" == "prod" ]; then
    sed -i '' "s|<string>/usr/local/bin/claudesecrets</string>|<string>${BINARY_DAEMON_DEST}</string>|g" "${PLIST_DEST}"
    echo "   ✅ Updated plist to use: ${BINARY_DAEMON_DEST}"
elif [ "${MYENV}" == "dev" ]; then
    sed -i '' "s|<string>/usr/local/bin/claudesecrets</string>|<string>${BINARY_DAEMON_DEST}</string>|g" "${PLIST_DEST}"
    echo "   ✅ Updated plist to use: ${BINARY_DAEMON_DEST}"
fi
echo "   ✅ Plist installed: ${PLIST_DEST}"

# Enable the daemon
echo "🚀 Enabling LaunchAgent..."
launchctl load -w "${PLIST_DEST}"
echo "   ✅ LaunchAgent enabled and started"

# Check status
echo "Check daemon status:"
${BINARY_CLI_DEST} --status

echo ""
echo "✅ Installation complete!"
echo ""
echo "🧪 Test Steps:"
echo "1. Delete your com.oemden.claudesecrets preferences:"
echo "   rm ~/Library/Preferences/com.oemden.claudesecrets.plist"
echo ""
echo "2. Launch TextEdit to trigger the daemon:"
echo "   open -a TextEdit"
echo ""
echo "3. Check daemon status:"
echo "   ${BINARY_CLI_DEST} --status"
echo ""
echo "4. Manage secrets:"
echo "   ${BINARY_CLI_DEST} --add API_KEY=your_key_here"
echo "   ${BINARY_CLI_DEST} --config"
echo ""
echo "🛑 To uninstall later:"
echo "   ${BINARY_CLI_DEST} --disable"
if [ "${MYENV}" == "prod" ]; then
    echo "   sudo rm ${BINARY_DAEMON_DEST} ${BINARY_CLI_DEST}"
else
    echo "   rm ${BINARY_DAEMON_DEST} ${BINARY_CLI_DEST}"
fi
echo "   rm ${PLIST_DEST}"