#!/bin/bash

###############################################################################
# Claude Secrets Manager - User Detection & Permission Handler
# Detects current user and applies correct permissions to all files
# Must be run with appropriate privileges to set ownership
###############################################################################

set -e

echo "👤 Claude Secrets Manager - User Permission Handler"
echo "==================================================="

# Detect current user using multiple methods for reliability
detect_user() {
    local detected_user=""
    
    # Method 1: Console owner (most reliable for GUI sessions)
    detected_user="$(/bin/ls -l /dev/console 2>/dev/null | /usr/bin/awk '{ print $3 }' || echo "")"
    
    # Method 2: If console method fails, try who command
    if [[ -z "$detected_user" || "$detected_user" == "root" ]]; then
        detected_user="$(who | grep console | head -1 | awk '{print $1}' || echo "")"
    fi
    
    # Method 3: Fall back to SUDO_USER if available
    if [[ -z "$detected_user" || "$detected_user" == "root" ]] && [[ -n "$SUDO_USER" ]]; then
        detected_user="$SUDO_USER"
    fi
    
    # Method 4: Check /Users directory for non-system users
    if [[ -z "$detected_user" || "$detected_user" == "root" ]]; then
        detected_user="$(ls /Users | grep -v Shared | grep -v .localized | head -1 || echo "")"
    fi
    
    echo "$detected_user"
}

# Get user home directory
get_user_home() {
    local username="$1"
    local home_dir=""
    
    # Use dscl to get home directory
    home_dir="$(/usr/bin/dscl . -read /Users/$username NFSHomeDirectory 2>/dev/null | grep -v OriginalNFSHomeDirectory | awk '{print $2}' || echo "")"
    
    # Fall back to standard /Users path
    if [[ -z "$home_dir" ]]; then
        home_dir="/Users/$username"
    fi
    
    echo "$home_dir"
}

# Validate user and home directory
validate_user_setup() {
    local username="$1"
    local home_dir="$2"
    
    # Check if user exists
    if ! id "$username" >/dev/null 2>&1; then
        echo "❌ User '$username' does not exist"
        return 1
    fi
    
    # Check if home directory exists
    if [[ ! -d "$home_dir" ]]; then
        echo "❌ Home directory '$home_dir' does not exist"
        return 1
    fi
    
    return 0
}

# Apply permissions to a file/directory
apply_permissions() {
    local path="$1"
    local perm="$2"
    local username="$3"
    local description="$4"
    
    if [[ -e "$path" ]]; then
        chown "$username:staff" "$path"
        chmod "$perm" "$path"
        echo "   ✅ $description: $path (${perm})"
        return 0
    else
        echo "   ⚠️  $description not found: $path"
        return 1
    fi
}

# Create directory with proper permissions
create_secure_directory() {
    local dir_path="$1"
    local perm="$2"
    local username="$3"
    local description="$4"
    
    if [[ ! -d "$dir_path" ]]; then
        mkdir -p "$dir_path"
        echo "   📁 Created $description: $dir_path"
    fi
    
    chown "$username:staff" "$dir_path"
    chmod "$perm" "$dir_path"
    echo "   ✅ $description permissions: $dir_path (${perm})"
}

# Main execution
main() {
    # Detect user
    LOGIN=$(detect_user)
    
    if [[ -z "$LOGIN" ]]; then
        echo "❌ Could not detect current user"
        exit 1
    fi
    
    # Get home directory
    LOGINHOMEDIR=$(get_user_home "$LOGIN")
    
    echo "🔍 Detected user: $LOGIN"
    echo "🏠 Home directory: $LOGINHOMEDIR"
    
    # Validate setup
    if ! validate_user_setup "$LOGIN" "$LOGINHOMEDIR"; then
        exit 1
    fi
    
    echo ""
    echo "📁 Creating required directories..."
    
    # Create directories with proper permissions
    create_secure_directory "$LOGINHOMEDIR/.claudesecrets" "700" "$LOGIN" "secrets directory"
    create_secure_directory "$LOGINHOMEDIR/.claudesecrets/backups" "700" "$LOGIN" "backups directory"
    create_secure_directory "$LOGINHOMEDIR/Library/LaunchAgents" "755" "$LOGIN" "LaunchAgents directory"
    create_secure_directory "$LOGINHOMEDIR/Library/Preferences" "700" "$LOGIN" "Preferences directory"
    create_secure_directory "$LOGINHOMEDIR/Library/Application Support/Claude" "755" "$LOGIN" "Claude config directory"
    create_secure_directory "$LOGINHOMEDIR/Library/Logs" "755" "$LOGIN" "Logs directory"
    
    echo ""
    echo "🔒 Applying file permissions..."
    
    # Apply permissions to existing files
    
    # LaunchAgent plist (readable by launchd)
    apply_permissions "$LOGINHOMEDIR/Library/LaunchAgents/com.oemden.claudesecrets.plist" "644" "$LOGIN" "LaunchAgent plist"
    
    # Domain preferences (private)
    apply_permissions "$LOGINHOMEDIR/Library/Preferences/com.oemden.claudesecrets.plist" "600" "$LOGIN" "preferences file"
    
    # Secrets file (highly restricted)
    apply_permissions "$LOGINHOMEDIR/.claudesecrets/.claude_secrets" "600" "$LOGIN" "secrets file"
    
    # Template file (readable by user)
    apply_permissions "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json" "644" "$LOGIN" "template file"
    
    # Config file (readable by user and Claude app)
    apply_permissions "$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config.json" "644" "$LOGIN" "config file"
    
    # Backup files (if they exist)
    if [[ -d "$LOGINHOMEDIR/.claudesecrets/backups" ]]; then
        find "$LOGINHOMEDIR/.claudesecrets/backups" -type f -exec chown "$LOGIN:staff" {} \;
        find "$LOGINHOMEDIR/.claudesecrets/backups" -type f -exec chmod 600 {} \;
        echo "   ✅ Backup files permissions updated"
    fi
    
    # Log files
    if [[ -d "$LOGINHOMEDIR/Library/Logs" ]]; then
        find "$LOGINHOMEDIR/Library/Logs" -name "*claudesecrets*" -type f -exec chown "$LOGIN:staff" {} \; 2>/dev/null || true
        find "$LOGINHOMEDIR/Library/Logs" -name "*claudesecrets*" -type f -exec chmod 644 {} \; 2>/dev/null || true
    fi
    
    echo ""
    echo "🔑 Setting up keychain access permissions..."
    
    # Ensure the user can access their own keychain
    # This is handled automatically by macOS, but we verify the setup
    local keychain_path="$LOGINHOMEDIR/Library/Keychains/login.keychain-db"
    if [[ -f "$keychain_path" ]]; then
        # Ensure proper ownership (should already be correct)
        chown "$LOGIN:staff" "$keychain_path"
        echo "   ✅ Keychain access verified"
    fi
    
    echo ""
    echo "📤 Exporting environment variables..."
    
    # Export variables for use by other installer scripts
    cat > "/tmp/claudesecrets-user-env" << EOF
# Claude Secrets Manager User Environment
# Generated: $(date)
LOGIN="$LOGIN"
LOGINHOMEDIR="$LOGINHOMEDIR"
SECRETS_DIR="$LOGINHOMEDIR/.claudesecrets"
LAUNCHAGENTS_DIR="$LOGINHOMEDIR/Library/LaunchAgents"
PREFERENCES_DIR="$LOGINHOMEDIR/Library/Preferences"
CLAUDE_CONFIG_DIR="$LOGINHOMEDIR/Library/Application Support/Claude"
LOGS_DIR="$LOGINHOMEDIR/Library/Logs"
EOF
    
    # Make the environment file readable by installer processes
    chmod 644 "/tmp/claudesecrets-user-env"
    
    echo "   ✅ Environment variables exported to /tmp/claudesecrets-user-env"
    
    echo ""
    echo "📊 Permission Summary:"
    echo "   • User: $LOGIN"
    echo "   • Home: $LOGINHOMEDIR"
    echo "   • Secrets directory: 700 (owner only)"
    echo "   • Secrets file: 600 (owner read/write only)"
    echo "   • LaunchAgent plist: 644 (world readable)"
    echo "   • Preferences: 600 (owner only)"
    echo "   • Config files: 644 (user readable)"
    echo "   • Backup files: 600 (owner only)"
    
    echo ""
    echo "✅ User permissions configured successfully"
    echo "🔄 Ready for installation to proceed"
}

# Run main function
main "$@"

exit 0