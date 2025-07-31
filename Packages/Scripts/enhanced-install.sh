#!/bin/bash

###############################################################################
# Claude Secrets Manager - Enhanced Installation Script
# Integrates failsafe protection with smart file creation
# Only creates files that don't exist, preserves all existing configurations
###############################################################################

set -e

echo "🚀 Claude Secrets Manager - Enhanced Installation"
echo "================================================="

# Source environment variables from previous scripts
if [[ -f "/tmp/claudesecrets-install-state" ]]; then
    source "/tmp/claudesecrets-install-state"
    echo "📋 Loaded installation state"
else
    echo "❌ Installation state not found. Run failsafe-protection.sh first."
    exit 1
fi

if [[ -f "/tmp/claudesecrets-user-env" ]]; then
    source "/tmp/claudesecrets-user-env"
    echo "👤 Loaded user environment"
else
    echo "❌ User environment not found. Run user-permission-handler.sh first."
    exit 1
fi

echo "🔍 Installation for user: $LOGIN"
echo "🏠 Home directory: $LOGINHOMEDIR"

# File paths
SECRETS_FILE="$LOGINHOMEDIR/.claudesecrets/.claude_secrets"
TEMPLATE_FILE="$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json"
CONFIG_FILE="$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config.json"

# Function to create Claude config backup (MANDATORY)
create_claude_config_backup() {
    echo ""
    echo "💾 Creating mandatory Claude config backup..."
    
    if [[ -f "$CONFIG_FILE" ]]; then
        local backup_name="claude_desktop_config.install-backup.$(date +%Y%m%d-%H%M%S).json"
        local backup_path="$LOGINHOMEDIR/Library/Application Support/Claude/$backup_name"
        
        # Create backup with preserved permissions
        cp -p "$CONFIG_FILE" "$backup_path"
        chown "$LOGIN:staff" "$backup_path"
        chmod 644 "$backup_path"
        
        echo "   ✅ Claude config backed up: $backup_name"
        echo "   📍 Location: $backup_path"
        
        # Export backup path for post-install use
        echo "CLAUDE_CONFIG_BACKUP=\"$backup_path\"" >> "/tmp/claudesecrets-install-state"
        
        return 0
    else
        echo "   ⚠️  No existing Claude config found to backup"
        echo "   ℹ️  This is normal for first-time Claude installations"
        return 1
    fi
}

# Function to create template from current config (only if template doesn't exist)
create_template_from_config() {
    echo ""
    echo "📋 Handling template file creation..."
    
    if [[ "$PRESERVE_TEMPLATE" == "true" ]]; then
        echo "   🛡️  Existing template file preserved - no changes made"
        echo "   📁 Location: $TEMPLATE_FILE"
        return 0
    fi
    
    # Template doesn't exist, create it
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "   📝 Creating template from current Claude config..."
        
        # Copy current config as template
        cp "$CONFIG_FILE" "$TEMPLATE_FILE"
        chown "$LOGIN:staff" "$TEMPLATE_FILE"
        chmod 644 "$TEMPLATE_FILE"
        
        echo "   ✅ Template created from current config"
        echo "   📁 Location: $TEMPLATE_FILE"
        echo "   💡 Edit this file to add variable placeholders (e.g., API_KEY)"
        
    else
        echo "   📝 Creating default template..."
        
        # Create a basic template structure
        cat > "$TEMPLATE_FILE" << 'EOF'
{
  "mcpServers": {
    "example-server": {
      "command": "echo",
      "args": ["Example MCP Server"],
      "env": {
        "API_KEY": "YOUR_API_KEY_VARIABLE",
        "SECRET_TOKEN": "YOUR_SECRET_TOKEN_VARIABLE"
      }
    }
  }
}
EOF
        
        chown "$LOGIN:staff" "$TEMPLATE_FILE"
        chmod 644 "$TEMPLATE_FILE"
        
        echo "   ✅ Default template created"
        echo "   📁 Location: $TEMPLATE_FILE"
        echo "   💡 Customize this template with your MCP servers and variables"
    fi
}

# Function to create secrets file (only if doesn't exist)
create_secrets_file() {
    echo ""
    echo "🔐 Handling secrets file creation..."
    
    if [[ "$PRESERVE_SECRETS" == "true" ]]; then
        echo "   🛡️  Existing secrets file preserved - no changes made"
        echo "   📁 Location: $SECRETS_FILE"
        return 0
    fi
    
    # Secrets file doesn't exist, create it
    echo "   📝 Creating new secrets file..."
    
    cat > "$SECRETS_FILE" << 'EOF'
# Claude Secrets Manager - Secrets File
# Add your secrets here in KEY=VALUE format
# Lines starting with # are comments and will be ignored

# Example secrets (replace with your actual values):
# API_KEY=your_api_key_here
# SECRET_TOKEN=your_secret_token_here
# DATABASE_URL=your_database_connection_string

# You can also use export format:
# export ANOTHER_KEY=another_value

# For complex values with special characters, use quotes:
# COMPLEX_PASSWORD="P@ssw0rd123!&"

# Add your secrets below:
EOF
    
    # Set secure permissions (read/write for owner only)
    chown "$LOGIN:staff" "$SECRETS_FILE"
    chmod 600 "$SECRETS_FILE"
    
    echo "   ✅ New secrets file created"
    echo "   📁 Location: $SECRETS_FILE"
    echo "   🔒 Permissions: 600 (owner read/write only)"
    echo "   💡 Add your secrets to this file using KEY=VALUE format"
}

# Function to set up domain preferences
setup_domain_preferences() {
    echo ""
    echo "⚙️  Setting up domain preferences..."
    
    # Use defaults command to set preferences for the detected user
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets secrets_file "$SECRETS_FILE"
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets template_claudedesktop_config_file "$TEMPLATE_FILE"
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets target_claudedesktop_config_file "$CONFIG_FILE"
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets first_run_claudedesktop_config_backup_file "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json"
    
    # Notification preferences (defaults)
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets voice_notifications -bool true
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets macos_notifications -bool true
    
    # Default secrets mechanism (file by default, can be changed later)
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets secrets_mechanism "file"
    
    # Management preferences
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets manage_ClaudeDesktop_config -bool true
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets manage_ClaudeCode_config -bool true
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets always_secure_config -bool true
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets shareClaudeDesktop_config_withClaudeCode -bool true
    
    # Mark first run as complete
    sudo -u "$LOGIN" defaults write com.oemden.claudesecrets first_run_done -bool true
    
    echo "   ✅ Domain preferences configured"
    echo "   🔧 Default mechanism: file (change with claudesecrets-cli)"
    echo "   🔔 Notifications: enabled"
    echo "   ⚙️  Config management: enabled"
}

# Function to verify installation
verify_installation() {
    echo ""
    echo "✅ Verifying installation..."
    
    local errors=0
    
    # Check required files
    if [[ -f "$SECRETS_FILE" ]]; then
        echo "   ✅ Secrets file: present"
    else
        echo "   ❌ Secrets file: missing"
        ((errors++))
    fi
    
    if [[ -f "$TEMPLATE_FILE" ]]; then
        echo "   ✅ Template file: present"
    else
        echo "   ❌ Template file: missing"
        ((errors++))
    fi
    
    # Check permissions
    local secrets_perm=$(stat -f%A "$SECRETS_FILE" 2>/dev/null || echo "000")
    if [[ "$secrets_perm" == "600" ]]; then
        echo "   ✅ Secrets file permissions: secure (600)"
    else
        echo "   ⚠️  Secrets file permissions: $secrets_perm (should be 600)"
    fi
    
    # Check ownership
    local secrets_owner=$(stat -f%Su "$SECRETS_FILE" 2>/dev/null || echo "unknown")
    if [[ "$secrets_owner" == "$LOGIN" ]]; then
        echo "   ✅ Secrets file ownership: correct ($LOGIN)"
    else
        echo "   ❌ Secrets file ownership: $secrets_owner (should be $LOGIN)"
        ((errors++))
    fi
    
    # Check domain preferences
    if sudo -u "$LOGIN" defaults read com.oemden.claudesecrets secrets_file >/dev/null 2>&1; then
        echo "   ✅ Domain preferences: configured"
    else
        echo "   ❌ Domain preferences: not configured"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "   🎉 All checks passed!"
        return 0
    else
        echo "   ⚠️  $errors error(s) found"
        return 1
    fi
}

# Main installation flow
main() {
    echo ""
    echo "🔄 Starting enhanced installation process..."
    
    # Step 1: Create mandatory Claude config backup
    create_claude_config_backup
    
    # Step 2: Handle template file (preserve existing or create new)
    create_template_from_config
    
    # Step 3: Handle secrets file (preserve existing or create new)  
    create_secrets_file
    
    # Step 4: Set up domain preferences
    setup_domain_preferences
    
    # Step 5: Verify installation
    if verify_installation; then
        echo ""
        echo "🎉 Enhanced installation completed successfully!"
    else
        echo ""
        echo "⚠️  Installation completed with warnings"
    fi
    
    # Export additional info for post-install
    cat >> "/tmp/claudesecrets-install-state" << EOF
SECRETS_FILE_CREATED=$([[ "$PRESERVE_SECRETS" != "true" ]] && echo "true" || echo "false")
TEMPLATE_FILE_CREATED=$([[ "$PRESERVE_TEMPLATE" != "true" ]] && echo "true" || echo "false")
INSTALLATION_COMPLETE=true
EOF
    
    echo ""
    echo "📋 Installation Summary:"
    echo "   • Secrets file: $([ "$PRESERVE_SECRETS" == "true" ] && echo "preserved" || echo "created")"
    echo "   • Template file: $([ "$PRESERVE_TEMPLATE" == "true" ] && echo "preserved" || echo "created")"
    echo "   • Claude config: $([ -f "$CONFIG_FILE" ] && echo "backed up" || echo "not found")"
    echo "   • Domain preferences: configured"
    echo "   • File permissions: secured"
    
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]]; then
        echo "   • Backups: $BACKUP_DIR"
    fi
    
    echo ""
    echo "📝 Next Steps:"
    if [[ "$PRESERVE_SECRETS" != "true" ]]; then
        echo "   1. Edit secrets file: $SECRETS_FILE"
    fi
    if [[ "$PRESERVE_TEMPLATE" != "true" ]]; then
        echo "   2. Customize template: $TEMPLATE_FILE"
    fi
    echo "   3. Install LaunchAgent: claudesecrets-cli --install"
    echo "   4. Start daemon: claudesecrets-cli --enable"
    echo "   5. Check status: claudesecrets-cli --status"
}

# Run main installation
main "$@"

exit 0