#!/bin/bash

###############################################################################
# Claude Secrets Manager - Failsafe Protection Script
# Preserves existing user configurations during installation/updates
# This script MUST be run before any installation operations
###############################################################################

set -e

echo "🔒 Claude Secrets Manager - Failsafe Protection"
echo "================================================"

# Detect current user (works even when run via installer)
LOGIN="$(/bin/ls -l /dev/console | /usr/bin/awk '{ print $3 }')"
LOGINHOMEDIR="$(/usr/bin/dscl . -read /Users/$LOGIN | grep 'NFSHomeDirectory:' | grep -v 'OriginalNFSHomeDirectory:' | awk '{print $2}')"

echo "🔍 Detected user: $LOGIN"
echo "🏠 Home directory: $LOGINHOMEDIR"

# File paths
SECRETS_FILE="$LOGINHOMEDIR/.claudesecrets/.claude_secrets"
TEMPLATE_FILE="$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config_template.json"
CONFIG_FILE="$LOGINHOMEDIR/Library/Application Support/Claude/claude_desktop_config.json"
PREFS_FILE="$LOGINHOMEDIR/Library/Preferences/com.oemden.claudesecrets.plist"

# Backup directory with timestamp
BACKUP_DIR="$LOGINHOMEDIR/.claudesecrets/backups/install-$(date +%Y%m%d-%H%M%S)"
BACKUP_LOG="$BACKUP_DIR/backup-manifest.txt"

# Function to create backup directory
create_backup_dir() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        chown "$LOGIN:staff" "$BACKUP_DIR"
        chmod 700 "$BACKUP_DIR"
        echo "📁 Created backup directory: $BACKUP_DIR"
    fi
}

# Function to backup a file safely
backup_file() {
    local source_file="$1"
    local file_type="$2"
    
    if [[ -f "$source_file" ]]; then
        create_backup_dir
        local backup_name="$(basename "$source_file").backup"
        local backup_path="$BACKUP_DIR/$backup_name"
        
        # Copy with preserved permissions and ownership
        cp -p "$source_file" "$backup_path"
        chown "$LOGIN:staff" "$backup_path"
        
        echo "✅ $file_type backed up: $backup_path"
        echo "[$(date)] $file_type: $source_file -> $backup_path" >> "$BACKUP_LOG"
        return 0
    else
        echo "ℹ️  No existing $file_type found"
        return 1
    fi
}

# Function to check if secrets file exists (ANY existing file is preserved)
secrets_file_exists() {
    [[ -f "$SECRETS_FILE" ]]
}

# Function to check if template file exists (ANY existing file is preserved)
template_file_exists() {
    [[ -f "$TEMPLATE_FILE" ]]
}

# Function to check if secrets file has meaningful content
has_secrets_content() {
    if [[ -f "$SECRETS_FILE" ]]; then
        # Check if file has non-comment, non-empty lines
        if grep -q '^[^#]*=' "$SECRETS_FILE" 2>/dev/null; then
            return 0  # Has content
        fi
    fi
    return 1  # No content or doesn't exist
}

# Function to check if template file has meaningful content
has_template_content() {
    if [[ -f "$TEMPLATE_FILE" ]]; then
        # Check if file is valid JSON and not empty
        if python3 -m json.tool "$TEMPLATE_FILE" > /dev/null 2>&1; then
            local size=$(stat -f%z "$TEMPLATE_FILE" 2>/dev/null || echo "0")
            if [[ $size -gt 50 ]]; then  # More than just empty JSON
                return 0  # Has content
            fi
        fi
    fi
    return 1  # No content or doesn't exist
}

# Main protection logic
echo ""
echo "🔍 Scanning for existing configurations..."

EXISTING_SECRETS=false
EXISTING_TEMPLATE=false
EXISTING_CONFIG=false
EXISTING_PREFS=false
PRESERVE_SECRETS=false
PRESERVE_TEMPLATE=false

# CRITICAL: Check for ANY existing secrets file (preserve all existing files)
if secrets_file_exists; then
    echo "🔐 Found existing secrets file - WILL BE PRESERVED"
    backup_file "$SECRETS_FILE" "secrets file"
    EXISTING_SECRETS=true
    PRESERVE_SECRETS=true
    if has_secrets_content; then
        echo "   ✅ File contains configuration data"
    else
        echo "   ℹ️  File exists but appears empty (still preserved)"
    fi
else
    echo "ℹ️  No existing secrets file found - new one will be created"
fi

# CRITICAL: Check for ANY existing template file (preserve all existing files)
if template_file_exists; then
    echo "📋 Found existing template file - WILL BE PRESERVED"
    backup_file "$TEMPLATE_FILE" "template file"
    EXISTING_TEMPLATE=true
    PRESERVE_TEMPLATE=true
    if has_template_content; then
        echo "   ✅ File contains template data"
    else
        echo "   ℹ️  File exists but appears empty (still preserved)"
    fi
else
    echo "ℹ️  No existing template file found - new one will be created"
fi

# Check config file (always backup if exists)
if backup_file "$CONFIG_FILE" "Claude config file"; then
    EXISTING_CONFIG=true
fi

# Check preferences file
if backup_file "$PREFS_FILE" "preferences file"; then
    EXISTING_PREFS=true
fi

# Create backup manifest
if [[ -d "$BACKUP_DIR" ]]; then
    cat > "$BACKUP_LOG" << EOF
# Claude Secrets Manager - Installation Backup Manifest
# Created: $(date)
# User: $LOGIN
# Home: $LOGINHOMEDIR

EXISTING_SECRETS=$EXISTING_SECRETS
EXISTING_TEMPLATE=$EXISTING_TEMPLATE
EXISTING_CONFIG=$EXISTING_CONFIG
EXISTING_PREFS=$EXISTING_PREFS

# Backup Location: $BACKUP_DIR
# Files backed up:
EOF

    # List all backed up files
    if [[ $EXISTING_SECRETS == true ]]; then
        echo "- .claude_secrets.backup" >> "$BACKUP_LOG"
    fi
    if [[ $EXISTING_TEMPLATE == true ]]; then
        echo "- claude_desktop_config_template.json.backup" >> "$BACKUP_LOG"
    fi
    if [[ $EXISTING_CONFIG == true ]]; then
        echo "- claude_desktop_config.json.backup" >> "$BACKUP_LOG"
    fi
    if [[ $EXISTING_PREFS == true ]]; then
        echo "- com.oemden.claudesecrets.plist.backup" >> "$BACKUP_LOG"
    fi
    
    chown "$LOGIN:staff" "$BACKUP_LOG"
    chmod 600 "$BACKUP_LOG"
fi

# Export variables for use by installer
cat > "/tmp/claudesecrets-install-state" << EOF
LOGIN="$LOGIN"
LOGINHOMEDIR="$LOGINHOMEDIR"
EXISTING_SECRETS=$EXISTING_SECRETS
EXISTING_TEMPLATE=$EXISTING_TEMPLATE
EXISTING_CONFIG=$EXISTING_CONFIG
EXISTING_PREFS=$EXISTING_PREFS
PRESERVE_SECRETS=$PRESERVE_SECRETS
PRESERVE_TEMPLATE=$PRESERVE_TEMPLATE
BACKUP_DIR="$BACKUP_DIR"
EOF

echo ""
echo "📊 Protection Summary:"
echo "   • Secrets file: $([ $PRESERVE_SECRETS == true ] && echo "WILL BE PRESERVED" || echo "WILL BE CREATED")"
echo "   • Template file: $([ $PRESERVE_TEMPLATE == true ] && echo "WILL BE PRESERVED" || echo "WILL BE CREATED")"
echo "   • Config file: $([ $EXISTING_CONFIG == true ] && echo "BACKED UP" || echo "NOT FOUND")"  
echo "   • Preferences: $([ $EXISTING_PREFS == true ] && echo "BACKED UP" || echo "NOT FOUND")"

if [[ -d "$BACKUP_DIR" ]]; then
    echo "   • Backup location: $BACKUP_DIR"
fi

echo ""
echo "🛡️  FAILSAFE GUARANTEE:"
echo "   ✅ Existing secrets file will NEVER be overwritten"
echo "   ✅ Existing template file will NEVER be overwritten" 
echo "   ✅ All existing files backed up before any changes"
echo "   ✅ Only missing files will be created during installation"

echo ""
echo "✅ Failsafe protection complete - existing configurations preserved"
echo "🔄 Installation can proceed safely"

exit 0