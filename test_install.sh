#!/bin/bash

###############################################################################
# ClaudeAutoConfig Test Installation Script
# Simulates what Packages.app installer will do
# This script is for testing purposes only and should not be used in production environments.
# It assumes you have already built the binary using `swift build -c release`
# It will install the binary and plist in the appropriate locations based on the environment (dev or prod).
###############################################################################

set -e

echo "🧪 ClaudeAutoConfig Test Installation"
echo "======================================"

# Build first
echo "🔨 Building ClaudeAutoConfig..."
swift build -c release

BUILD_DIR=".build/release"
BINARY_DAEMON="ClaudeAutoConfig"
BINARY_SOURCE="${PWD}/${BUILD_DIR}/${BINARY_DAEMON}"
PLIST_SOURCE="${PWD}/com.oemden.claudeautoconfig.plist"

# Installation paths
ENV="dev" # Change to "prod" for production install
BINARY_DEST_DIR_PROD="/usr/local/bin/"
BINARY_DEST_DIR_DEV="/opt/dev/bin/"
# Destination paths
BINARY_DEST_PROD="${BINARY_DEST_DIR_PROD}/${BINARY_DAEMON}"
BINARY_DEST_DEV="${BINARY_DEST_DIR_DEV}/${BINARY_DAEMON}"
PLIST_DEST="${HOME}/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"

echo ""
echo "📦 Installing files..."
echo "📋 Installing binary to /usr/local/bin..."
if [ "${ENV}" == "prod" ]; then
    echo "   ⚠️ Running in prod mode, sudo required"
elif [ "${ENV}" == "dev" ]; then
    echo "   ⚠️ Running in dev mode, no sudo required"
fi

# Check if binary was built
if [ ! -f "${BINARY_SOURCE}" ]; then
    echo "❌ Binary not found: ${BINARY_SOURCE}"
    exit 1
fi

# Check if plist exists
if [ ! -f "${PLIST_SOURCE}" ]; then
    echo "❌ Plist not found: ${PLIST_SOURCE}"
    exit 1
fi

# Create directories if needed
echo "📁 Creating directories..."
if [ "${ENV}" == "prod" ]; then
    BINARY_DEST="${BINARY_DEST_PROD}"
    BINARY_DEST_DIR="${BINARY_DEST_DIR_PROD}"
    sudo mkdir -p ${BINARY_DEST_DIR}
elif [ "${ENV}" == "dev" ]; then
    BINARY_DEST="${BINARY_DEST_DEV}"
    BINARY_DEST_DIR=${BINARY_DEST_DIR_DEV}
    mkdir -p ${BINARY_DEST_DIR}
fi
mkdir -p "$HOME/Library/LaunchAgents"
mkdir -p "$HOME/Library/Logs"

# Copy binary (requires sudo)
echo "📋 Installing binary to ${BINARY_DEST_DIR}..."
if [ "${ENV}" == "prod" ]; then
    # echo "   ⚠️ Running in prod mode, sudo required"
    # sudo mkdir -p "${BINARY_DEST_DIR_PROD}"
    sudo cp "${BINARY_SOURCE}" "${BINARY_DEST}"
    sudo chmod +x "${BINARY_DEST}"
elif [ "${ENV}" == "dev" ]; then
    # echo "   ⚠️ Running in dev mode, no sudo required"
    # mkdir -p "${BINARY_DEST_DIR_DEV}"
    cp "${BINARY_SOURCE}" "${BINARY_DEST}"
    chmod +x "${BINARY_DEST}"
fi
echo "   ✅ Binary installed: ${BINARY_DEST}"

# Copy LaunchAgent plist (user space)
echo "unloading LaunchAgent if it exists..."
launchctl unload -w "${PLIST_DEST}" 2>/dev/null || true
rm -f "${PLIST_DEST}"
sleep 5
echo "📋 Installing LaunchAgent plist..."
cp "${PLIST_SOURCE}" "${PLIST_DEST}"

# Update binary path in plist based on environment
echo "🔧 Updating plist binary path for ${ENV} environment..."
if [ "${ENV}" == "prod" ]; then
    sed -i '' "s|<string>/usr/local/bin/ClaudeAutoConfig</string>|<string>${BINARY_DEST}</string>|g" "${PLIST_DEST}"
    echo "   ✅ Updated plist to use: ${BINARY_DEST}"
elif [ "${ENV}" == "dev" ]; then
    sed -i '' "s|<string>/usr/local/bin/ClaudeAutoConfig</string>|<string>${BINARY_DEST}</string>|g" "${PLIST_DEST}"
    echo "   ✅ Updated plist to use: ${BINARY_DEST}"
fi
echo "   ✅ Plist installed: ${PLIST_DEST}"

# Enable the daemon
echo "🚀 Enabling LaunchAgent..."
launchctl load -w "${PLIST_DEST}"
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
echo "   ${BINARY_DEST} --status"
echo ""
echo "🛑 To uninstall later:"
echo "   ${BINARY_DEST} --disable"
echo "   sudo rm ${BINARY_DEST}"
echo "   rm ${PLIST_DEST}"