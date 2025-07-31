#!/bin/bash

###############################################################################
# Claude Secrets Manager - User Choices Handler
# Processes user choices from the package installer
# Called by postinstall script to apply user preferences
###############################################################################

set -e

echo "⚙️  Claude Secrets Manager - Processing User Choices"
echo "=================================================="

# Source environment variables
if [[ -f "/tmp/claudesecrets-user-env" ]]; then
    source "/tmp/claudesecrets-user-env"
else
    echo "❌ User environment not found"
    exit 1
fi

echo "👤 Processing choices for user: $LOGIN"

# Function to read installer choice
read_choice() {
    local choice_id="$1"
    local default_value="$2"
    
    # In a real package installer, choices would be available via environment variables
    # For now, we'll use defaults or environment variables
    local value="${!choice_id:-$default_value}"
    echo "$value"
}

# Function to apply storage mechanism choice
apply_storage_mechanism() {
    local mechanism="$1"
    
    echo "🔐 Setting storage mechanism: $mechanism"
    
    # Set the preference for the user
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets secrets_mechanism "$mechanism"
    
    if [[ "$mechanism" == "keychain" ]]; then
        echo "   ✅ Keychain storage configured"
        echo "   💡 Remember: Code signing may be required for keychain access"
    else
        echo "   ✅ File storage configured"
        echo "   📁 Secrets will be stored in: $LOGIN/.claudesecrets/.claude_secrets"
    fi
}

# Function to apply LaunchAgent setting
apply_launchagent_setting() {
    local enable="$1"
    local plist_path="$LOGINHOMEDIR/Library/LaunchAgents/com.oemden.claudesecrets.plist"
    
    echo "🚀 Configuring LaunchAgent: $enable"
    
    if [[ "$enable" == "true" ]]; then
        # Enable and start LaunchAgent
        if [[ -f "$plist_path" ]]; then
            sudo -u "$LOGIN" launchctl load -w "$plist_path" 2>/dev/null || true
            echo "   ✅ LaunchAgent enabled and started"
            echo "   🔄 Daemon will start automatically on login"
        else
            echo "   ⚠️  LaunchAgent plist not found: $plist_path"
        fi
    else
        # Disable LaunchAgent (but don't remove it)
        if [[ -f "$plist_path" ]]; then
            sudo -u "$LOGIN" launchctl unload "$plist_path" 2>/dev/null || true
            echo "   ✅ LaunchAgent disabled"
            echo "   💡 Start manually with: claudesecrets-cli --enable"
        fi
    fi
}

# Function to apply notification settings
apply_notification_settings() {
    local voice="$1"
    local macos="$2"
    
    echo "🔔 Configuring notifications..."
    
    # Set voice notifications
    if [[ "$voice" == "true" ]]; then
        sudo -u "$LOGIN" defaults write com.oemden.claudesecrets voice_notifications -bool true
        echo "   ✅ Voice notifications enabled"
    else
        sudo -u "$LOGIN" defaults write com.oemden.claudesecrets voice_notifications -bool false
        echo "   ⚪ Voice notifications disabled"
    fi
    
    # Set macOS notifications
    if [[ "$macos" == "true" ]]; then
        sudo -u "$LOGIN" defaults write com.oemden.claudesecrets macos_notifications -bool true
        echo "   ✅ macOS notifications enabled"
    else
        sudo -u "$LOGIN" defaults write com.oemden.claudesecrets macos_notifications -bool false
        echo "   ⚪ macOS notifications disabled"
    fi
}

# Function to handle post-install actions
apply_post_install_actions() {
    local open_secrets="$1"
    local open_template="$2"
    local show_status="$3"
    
    echo "📋 Configuring post-install actions..."
    
    # Create post-install script for user execution
    local post_script="/tmp/claudesecrets-post-install-actions.sh"
    cat > "$post_script" << 'EOF'
#!/bin/bash
# Claude Secrets Manager - Post-Install User Actions
# This script runs with user privileges to open files and show status

echo "🎯 Claude Secrets Manager - Post-Install Actions"
echo "=============================================="
EOF
    
    # Add file opening actions
    if [[ "$open_secrets" == "true" ]]; then
        cat >> "$post_script" << EOF
if [[ -f "$LOGINHOMEDIR/.claudesecrets/.claude_secrets" ]]; then
    echo "📝 Opening secrets file for configuration..."
    open -t "$LOGINHOMEDIR/.claudesecrets/.claude_secrets" || open "$LOGINHOMEDIR/.claudesecrets/.claude_secrets"
else
    echo "⚠️  Secrets file not found: $LOGINHOMEDIR/.claudesecrets/.claude_secrets"
fi
EOF
    fi
    
    if [[ "$open_template" == "true" ]]; then
        cat >> "$post_script" << EOF
if [[ -f "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json" ]]; then
    echo "📋 Opening template file for customization..."
    open -t "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json" || open "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json"
else
    echo "⚠️  Template file not found"
fi
EOF
    fi
    
    if [[ "$show_status" == "true" ]]; then
        cat >> "$post_script" << 'EOF'
echo "📊 Showing Claude Secrets Manager status..."
if command -v claudesecrets-cli >/dev/null 2>&1; then
    /usr/local/bin/claudesecrets-cli --status
else
    echo "⚠️  claudesecrets-cli not found in PATH"
fi

echo ""
echo "🚀 Quick Start Commands:"
echo "   claudesecrets-cli --help              # Show all available commands"
echo "   claudesecrets-cli --add API_KEY=value # Add a secret"
echo "   claudesecrets-cli --enable            # Start the daemon"
echo "   claudesecrets-cli --status            # Check daemon status"
echo ""
EOF
    fi
    
    # Make script executable
    chmod +x "$post_script"
    chown "$LOGIN:staff" "$post_script"
    
    # Schedule script to run as user (delayed to avoid installer interference)
    if [[ -s "$post_script" ]]; then
        echo "   ✅ Post-install actions scheduled"
        
        # Create a simple LaunchAgent to run the post-install actions once
        local action_plist="$LOGINHOMEDIR/Library/LaunchAgents/com.oemden.claudesecrets.postinstall.plist"
        cat > "$action_plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.oemden.claudesecrets.postinstall</string>
    <key>Program</key>
    <string>$post_script</string>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/claudesecrets-postinstall.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/claudesecrets-postinstall.log</string>
</dict>
</plist>
EOF
        
        chown "$LOGIN:staff" "$action_plist"
        chmod 644 "$action_plist"
        
        # Load and start the one-time action
        sudo -u "$LOGIN" launchctl load "$action_plist" 2>/dev/null || true
        
        # Schedule cleanup of the temporary plist (after 60 seconds)
        echo "rm -f '$action_plist' '$post_script'" | at now + 1 minute 2>/dev/null || true
        
        echo "   💡 Files will open automatically in a moment"
    fi
}

# Main processing function
main() {
    echo ""
    echo "🔄 Processing installation choices..."
    
    # Read user choices (in real installer, these come from installer environment)
    # For now, use sensible defaults that can be overridden by environment variables
    
    local storage_mechanism=$(read_choice "INSTALLER_CHOICE_storage_mechanism" "file")
    local enable_launchagent=$(read_choice "INSTALLER_CHOICE_enable_launchagent" "true")
    local voice_notifications=$(read_choice "INSTALLER_CHOICE_voice_notifications" "true")
    local macos_notifications=$(read_choice "INSTALLER_CHOICE_macos_notifications" "true")
    local open_secrets=$(read_choice "INSTALLER_CHOICE_open_secrets_file" "true")
    local open_template=$(read_choice "INSTALLER_CHOICE_open_template_file" "true")
    local show_status=$(read_choice "INSTALLER_CHOICE_show_status" "true")
    
    echo "📋 User Choices:"
    echo "   • Storage mechanism: $storage_mechanism"
    echo "   • Auto-start daemon: $enable_launchagent"
    echo "   • Voice notifications: $voice_notifications"
    echo "   • macOS notifications: $macos_notifications"
    echo "   • Open secrets file: $open_secrets"
    echo "   • Open template file: $open_template"
    echo "   • Show status: $show_status"
    
    # Apply each choice
    apply_storage_mechanism "$storage_mechanism"
    apply_launchagent_setting "$enable_launchagent"
    apply_notification_settings "$voice_notifications" "$macos_notifications"
    apply_post_install_actions "$open_secrets" "$open_template" "$show_status"
    
    echo ""
    echo "✅ User choices processed successfully"
    echo "🎉 Installation customized according to your preferences"
}

# Run main function
main "$@"

exit 0