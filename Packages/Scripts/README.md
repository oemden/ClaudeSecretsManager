# Claude Secrets Manager - Package Installation Scripts

This directory contains all scripts used by the macOS package installer (.pkg) to safely install Claude Secrets Manager while preserving existing user configurations.

## 🛡️ Failsafe Protection Philosophy

**CRITICAL**: These scripts implement a strict "preserve existing files" policy:
- Existing `.claude_secrets` files are NEVER overwritten
- Existing template files are NEVER overwritten  
- All existing files are backed up before any changes
- Only missing files are created during installation

## 📋 Script Overview

### Core Installation Scripts

#### `failsafe-protection.sh`
- **Purpose**: Protects existing user configurations before installation
- **Function**: Backs up all existing files, detects what needs preservation
- **Output**: Creates `/tmp/claudesecrets-install-state` with preservation flags
- **Guarantee**: No existing user files are ever lost

#### `user-permission-handler.sh`  
- **Purpose**: Detects current user and sets up proper file permissions
- **Function**: Uses multiple detection methods, creates secure directories
- **Output**: Creates `/tmp/claudesecrets-user-env` with user environment
- **Security**: Ensures all files have correct ownership and permissions

#### `enhanced-install.sh`
- **Purpose**: Smart installation that respects failsafe protection
- **Function**: Creates only missing files, preserves existing configurations
- **Features**: Mandatory Claude config backup, template creation, domain preferences
- **Safety**: Never overwrites existing secrets or templates

### Package Installer Scripts

#### `preinstall`
- **Trigger**: Called automatically before package installation
- **Purpose**: Runs failsafe protection and user detection
- **Ensures**: Safe environment for package installation

#### `postinstall`
- **Trigger**: Called automatically after fresh package installation
- **Purpose**: Completes setup and configuration
- **Features**: Final permission adjustments, user guidance

#### `postupgrade`
- **Trigger**: Called automatically when upgrading existing installation
- **Purpose**: Preserves user configurations during upgrades
- **Features**: Daemon restart, upgrade-specific handling

## 🔄 Installation Flow

### Fresh Installation
```
preinstall → Package Installation → postinstall
     ↓              ↓                    ↓
failsafe +     Install bins +     Complete setup +
user setup     LaunchAgent       preserve configs
```

### Upgrade Installation  
```
preinstall → Package Installation → postupgrade
     ↓              ↓                    ↓
failsafe +     Update bins +      Preserve configs +
user setup     LaunchAgent        restart daemon
```

## 📁 File Locations

### User Files (Always Preserved)
- `~/.claudesecrets/.claude_secrets` - User secrets (600 permissions)
- `~/Library/Application Support/Claude/claude_desktop_config_template.json` - Template
- `~/Library/Application Support/Claude/claude_desktop_config.json` - Claude config

### System Files (Managed by Package)
- `/usr/local/bin/claudesecrets` - Main daemon binary
- `/usr/local/bin/claudesecrets-cli` - CLI tool binary
- `~/Library/LaunchAgents/com.oemden.claudesecrets.plist` - LaunchAgent

### Backup Locations
- `~/.claudesecrets/backups/install-YYYYMMDD-HHMMSS/` - Installation backups
- `~/Library/Application Support/Claude/claude_desktop_config.install-backup.*.json` - Config backups

## 🔒 Security Model

### File Permissions
- Secrets file: `600` (owner read/write only)
- Secrets directory: `700` (owner access only)  
- Template/config files: `644` (owner write, world read)
- LaunchAgent plist: `644` (world readable for launchd)
- Backup files: `600` (owner read/write only)

### User Detection
1. Console owner detection (primary method)
2. `who` command fallback
3. `SUDO_USER` environment variable
4. `/Users` directory scan (last resort)

### Ownership
- All user files owned by detected user:staff
- No files ever owned by root in user space
- Proper keychain access permissions maintained

## 🧪 Testing Scripts

### Manual Testing
```bash
# Test failsafe protection
sudo bash failsafe-protection.sh

# Test user permission setup  
sudo bash user-permission-handler.sh

# Test enhanced installation
sudo bash enhanced-install.sh
```

### Integration Testing
```bash
# Test full installation flow
sudo bash preinstall /path/to/pkg /Applications /Volumes/Disk /
# Install package here
sudo bash postinstall /path/to/pkg /Applications /Volumes/Disk /
```

## 📊 State Management

### Temporary Files
- `/tmp/claudesecrets-install-state` - Installation state and preservation flags
- `/tmp/claudesecrets-user-env` - User environment variables

### State Variables
```bash
LOGIN="username"                  # Detected user
LOGINHOMEDIR="/Users/username"    # User home directory  
PRESERVE_SECRETS=true/false       # Whether to preserve secrets file
PRESERVE_TEMPLATE=true/false      # Whether to preserve template file
EXISTING_CONFIG=true/false        # Whether config file exists
BACKUP_DIR="/path/to/backups"     # Backup directory location
```

## 🚨 Error Handling

### Script Failures
- All scripts use `set -e` for immediate error termination
- Pre-installation failures prevent package installation
- Post-installation failures are logged but don't prevent completion

### Recovery Procedures
- Backup files are always created before modifications
- Failed installations can be recovered from backup directories  
- User configurations are never lost due to failsafe protection

## 📝 Logging

### Installation Logs
- Standard installer logs in `/var/log/install.log`
- Script output captured by macOS installer
- Backup manifests in `~/.claudesecrets/backups/*/backup-manifest.txt`

### Debug Information
- User detection results logged to stdout
- File permission changes logged
- Preservation decisions clearly documented

This script architecture ensures that Claude Secrets Manager can be safely installed and upgraded without ever losing user configurations, while maintaining proper security and permissions throughout the process.