# Claude Secrets Manager v0.4.2

<img src="./Pictures/ClaudeSecretsManager.png" width="256" height="256">

A production-ready macOS daemon that automatically manages Claude Desktop/Code configurations with secure secrets injection.

Never put API keys directly in your Claude config again - use the macOS keychain or secure files instead.

For now the .claude_secrets is in clear, but at least it is a single place to manage secrets. I intend to see iof I can do some encryption-decryption oif the file.
If you want real secured secrets, they set --mechanism to Keychain rather than file.

## What It Does

**The Problem**: 
- Claude Desktop/Code configs contain sensitive API keys and tokens in plain text JSON files.

**The Solution**: 
- This daemon monitors when Claude launches, dynamically injects secrets from secure storage (keychain/files), and cleans up when Claude quits. 
  
  Your sensitive data stays protected while Claude gets the config it needs.

## Project Goals

- **Secure Secrets**: Store API keys in macOS keychain or encrypted files, not plain text configs
- **Dynamic Injection**: Generate configs on-the-fly when Claude launches, remove when it quits  
- **Zero Maintenance**: Runs silently in background, requires no manual intervention
- **Backup Safety**: Automatic backups ensure configs are never lost
- **Production Ready**: Complete package installer with upgrade preservation

**Tested with**: 
- **Claude Desktop Version: "0.12.55"**
- **Claude Code Version: "3.44"**
- **macOS Version: "macOS 15.5"**

**⚠️ Always backup your configs - even if the built-in backup system should protect against data loss at first run/install**

## 🚀 What's New in version 0.4.3 (August 2025)

**Major Breakthrough**: Keychain GUI prompts eliminated! Package upgrades now seamlessly preserve all keychain secrets without user intervention.

### Key Enhancements:
- **🔐 Seamless Package Upgrades**: AES-256-CBC encrypted export/import system eliminates keychain ownership issues during installation
- **📦 Bulk Import Operations**: `--migrate --file` command for importing secrets from external files
- **🔧 Intelligent Logging**: 3-level system (minimal/normal/debug) dramatically reduces log noise while maintaining debugging capability
- **🛡️ Enterprise Security**: Random key generation with OpenSSL to export-import Keychain records, service isolation, error log
- **📊 Production Package**: Complete `.pkg` installer with automated pre/post-install scripts and certificate signing

### Technical Improvements:
- **EncryptionManager**: AES-256-CBC with 16-byte IV and PBKDF2 key derivation for the export import Keychain KEY=VALUE during an upgrade. 
  - It is Mandatory to export/import existing Keychain records at each Binary change (updates) otherwise macOS will prompt for user's password for each Key in the GUI and will attempt to do it 3 times per Keychain record.
- **Service Isolation**: Separate `claudesecretsupgradekey` service prevents keychain conflicts.
  - This is the temporary encryption key set to encrypt the export file during migration. deleted after importing.
- **Logger System**: Preference-controlled verbosity with immediate effect
- **Package Scripts**: pre|post installation scripts for basic checks and preparing files
  - Backup of actual json Claude config, and existing files like template and .claude_secrets if they exist. Include the export-import of Keychain records.

### Achievements and TODOs

- Achievements and TODOs can been seen here: **[Claude Secret Manager - Project Summary.md](./Claude%20Secret%20Manager%20-%20Project%20Summary.md)**

## Usage

### CLI Commands
```bash
# Basic Options
claudesecrets-cli -h, --help                     # Show help message
claudesecrets-cli -v, --version                  # Show version information
claudesecrets-cli -s, --status                   # Show daemon and configuration status
claudesecrets-cli -c, --config                   # Show current configuration settings

# Secrets Management
claudesecrets-cli -a API_KEY=your_secret_value    # Add secret
claudesecrets-cli -a VAR1=val1,VAR2=val2         # Add multiple secrets
claudesecrets-cli -a API_KEY=secret123 -j "Production API key"  # Add with comment
claudesecrets-cli -l keychain                     # List keychain secrets
claudesecrets-cli -l file                         # List file secrets
claudesecrets-cli -d API_KEY                      # Delete secret
claudesecrets-cli -d VAR1,VAR2                    # Delete multiple secrets
claudesecrets-cli -m keychain                     # Set storage mechanism (use with --add/--delete)
claudesecrets-cli --wipesecrets                   # Clear all secrets

# Template & Configuration Generation
claudesecrets-cli -t, --template                 # Create template from current Claude config
claudesecrets-cli -g TEMPLATE OUTPUT             # Generate config from template and secrets

# Configuration & Notifications
claudesecrets-cli -V on                           # Enable voice notifications
claudesecrets-cli -n off                          # Disable macOS notifications

# Logging Control (NEW in v0.4.2)
claudesecrets-cli -L minimal                      # Minimal logging (essential only)
claudesecrets-cli -L normal                       # Normal logging (operational)  
claudesecrets-cli -L debug                        # Debug logging (verbose)
claudesecrets-cli --daemon-console off            # Silent daemon (default)
claudesecrets-cli --daemon-console on             # Verbose daemon

# LaunchAgent Management
claudesecrets-cli -I, --install                  # Install LaunchAgent plist (doesn't start)
claudesecrets-cli -U, --uninstall                # Remove LaunchAgent plist (stops if running)
claudesecrets-cli -E, --enable                   # Enable and start LaunchAgent daemon
claudesecrets-cli -D, --disable                  # Disable and stop LaunchAgent daemon

# System Management
claudesecrets-cli -r, --reset                    # Reset to default claudesecrets settings
claudesecrets-cli -R, --restore                  # Restore original Claude config and disable daemon
claudesecrets-cli -u, --upgrade                  # Transfer keychain ownership to current binary

# Migration & Import
claudesecrets-cli --migrate file-to-keychain      # Move secrets to keychain
claudesecrets-cli --migrate file-to-keychain --emptysecretfile  # Move and empty source file
claudesecrets-cli --migrate --file /path/secrets  # Bulk import from file
                                                  # create a file with:
                                                  #   KEY01=VALUE01
                                                  #   KEY02=TOKEN02
                                                  #   KEY03=1234$=
                                                  # you can then bulk import multiples secrets ( do not forget to delete the file )

# Emergency Commands
claudesecrets-cli --noclaudesecrets              # Emergency disable: stop daemon, restore config
claudesecrets-cli --wipesecrets                  # Delete ALL secrets from both file and keychain
```

### Handling Complex Values

Not heavily tested, you may need to adjust escaping etc. Normally what you've set in your JSON should the VALUE of your KEY.

```bash
# COMPLEX VALUES (use single quotes to protect special characters):
claudesecrets-cli -a 'API_URL=https://api.example.com/v1' -m file
claudesecrets-cli -a 'PASSWORD=P@ssw0rd123!&' -m file
claudesecrets-cli -a 'MULTI=val1,API_URL=https://example.com' -m file

# ALTERNATIVE METHODS for complex values:
# Method 1: Single quotes (recommended)
claudesecrets-cli -a 'DB_PASS=Very%$#@Complex!' -m file

# Method 2: Double quotes with escaping  
claudesecrets-cli -a "DB_PASS=Very%\\$#@Complex\\!" -m file

# Method 3: Interactive mode (future feature)
claudesecrets-cli --add-interactive -m file
```

### Direct Settings (defaults commands)
```bash
# Log level control
defaults write com.oemden.claudesecrets log_level -int 0      # minimal
defaults write com.oemden.claudesecrets log_level -int 1      # normal
defaults write com.oemden.claudesecrets log_level -int 2      # debug

# Daemon console output
defaults write com.oemden.claudesecrets daemon_console -bool false  # silent
defaults write com.oemden.claudesecrets daemon_console -bool true   # verbose

# Check current settings  
defaults read com.oemden.claudesecrets
```

### Logging System (3-Level)
- **Level 0 (minimal)**: Essential operations only - app launches, config processing, warnings
- **Level 1 (normal)**: Operational details - file paths, notifications, detailed steps  
- **Level 2 (debug)**: Full debugging - process monitoring, internal operations

**Log Locations:**
- Main logs: `/tmp/ClaudeAutoConfig.log` (filtered by level)
- Error logs: `/tmp/ClaudeAutoConfig.error.log` (always written)

## Features (v0.4.2)

- ✅ **Secure Storage**: File-based or macOS Keychain secrets storage
- ✅ **Process Monitoring**: Detects Claude Desktop & Claude Code launch/quit
- ✅ **Dynamic Config**: On-the-fly configuration generation with variable substitution
- ✅ **Template System**: Uses template files with placeholder variables
- ✅ **CLI Management**: Full command-line interface for secrets management
- ✅ **LaunchAgent**: Automatic startup and background operation
- ✅ **Backup System**: Automatic config backup on first run
- ✅ **Dual Mechanism**: Switch between file and keychain storage seamlessly
- 🆕 **Seamless Upgrades**: AES-256-CBC encrypted export/import for package installations
- 🆕 **Bulk Import**: Import secrets from external files with `--migrate --file`
- 🆕 **Intelligent Logging**: 3-level logging system (minimal/normal/debug) with preference control
- 🆕 **Package Installer**: Complete `.pkg` installer with pre/post-install automation
- 🆕 **Enterprise Security**: Random key generation, service isolation, comprehensive error handling

## Quick Start

### Installation

**For Release Users (Recommended):**
- Download and install the `.pkg` installer 
- The installer handles everything automatically including:
  - Keychain secrets export/import during upgrades
  - Automatic backup of existing configurations
  - LaunchAgent setup and daemon startup
  - User preference initialization

**For Development/Testing:**
```bash
# Clone and build from source
git clone <repository>
cd "Claude Auto Config"
swift build -c release

# Install binaries and LaunchAgent (dev/testing)
./Tests/test_install.sh

# Build complete package
./build-and-package.sh
```

### Basic Usage
```bash
# Set up keychain storage (recommended)
claudesecrets-cli -m keychain -a API_KEY=your_secret_key
claudesecrets-cli -m keychain -a DATABASE_URL=your_connection_string

# Or use file storage
claudesecrets-cli -m file -a API_KEY=your_secret_key

# Create template from current Claude config
claudesecrets-cli -t

# List stored secrets (values hidden for security)
claudesecrets-cli -l keychain
claudesecrets-cli -l file

# Check daemon status
claudesecrets-cli -s
```

### Setup Template

**Template Creation:**
- **Automatic**: Installation and first run automatically create template from your existing Claude config
- **Manual**: Use `claudesecrets-cli -t` to create template from current Claude config
- **Generate**: Use `claudesecrets-cli -g TEMPLATE OUTPUT` to generate config from template

**Edit Template with Variables:**
Simply use variable names directly in your template:
```json
{
  "mcpServers": {
    "myserver": {
      "command": "server-command",
      "args": [
        "-e", "WP_USERNAME=AUTOPWPMCP_WP_USERNAME",
        "-e", "WP_PASSWORD=AUTOPWPMCP_WP_PASSWORD",
        "-e", "API_KEY=MY_SECRET_API_KEY"
      ]
    }
  }
}
```

**Variable Syntax:**
- Use direct variable names: `AUTOPWPMCP_WP_USERNAME`
- The system replaces them with values from your secrets
- No special brackets needed - just the variable name

**Launch Claude** - secrets automatically injected!

## Architecture

### Executables
- **`claudesecrets`** - Background daemon (monitors Claude processes)
- **`claudesecrets-cli`** - Command-line management tool

### Storage Mechanisms
- **Keychain** - Secure macOS keychain storage (recommended)
- **File** - Encrypted file storage (`~/.claudesecrets/.claude_secrets`)

### Process Flow
1. **Launch Detection** → Claude Desktop/Code starts
2. **Secret Loading** → From keychain or file
3. **Template Processing** → Variables replaced with secrets
4. **Config Generation** → Final config written
5. **Quit Detection** → Original config restored (optional)

## Project Structure (v0.4.2)
```
Claude Auto Config/
├── Package.swift                    # Swift Package Manager
├── Makefile                         # Build shortcuts
├── build-and-package.sh            # Complete build and package script
├── Sources/
│   ├── ClaudeSecrets/              # Main daemon
│   │   ├── main.swift
│   │   └── SecretsParser.swift
│   ├── ClaudeSecretsCLI/           # Enhanced CLI tool
│   │   └── main.swift              # Export/import, bulk operations, 3-level logging
│   ├── KeychainManager/            # Keychain integration
│   │   └── KeychainManager.swift
│   └── SharedConstants/            # Shared configuration (v0.4.2)
│       └── SharedConstants.swift
├── LaunchAgent/
│   └── com.oemden.claudesecrets.plist # LaunchAgent plist
├── Packages/                        # Complete installer package
│   ├── ClaudeSecretsManager.pkgproj # Packages project file
│   ├── CERTIFICATE_SETUP.md         # Code signing instructions
│   └── Scripts/
│       ├── preinstall               # Export keychain, backup files
│       └── postinstall              # Import keychain, configure system
├── Tests/
│   ├── test_install.sh              # Development installation
│   ├── test_uninstall.sh           # Clean removal
│   └── check_setup.sh               # Setup verification
└── secrets/
    └── .claude_secrets.exemple      # Example secrets file
```

## CLI Commands

### Secrets Management
```bash
# Add secrets (keychain recommended)
claudesecrets-cli -m keychain -a API_KEY=abc123
claudesecrets-cli -m keychain -a VAR1=val1,VAR2=val2
claudesecrets-cli -m keychain -a API_KEY=secret123 -j "Production API key"  # With comment

# Delete secrets  
claudesecrets-cli -m keychain -d API_KEY
claudesecrets-cli -m keychain -d VAR1,VAR2

# List secrets (values hidden)
claudesecrets-cli -l keychain
claudesecrets-cli -l file

# Switch storage mechanism
defaults write com.oemden.claudesecrets secrets_mechanism "keychain"
```

### Migration & Bulk Operations (v0.4.2)
```bash
# Migrate from file-based to keychain storage
claudesecrets-cli --migrate file-to-keychain

# Migrate and automatically empty the source file (with backup)
claudesecrets-cli --migrate file-to-keychain --emptysecretfile

# Bulk import from external file
claudesecrets-cli --migrate --file /path/to/secrets.txt

# Package upgrade migration (transfer keychain ownership)
claudesecrets-cli --upgrade              # Transfer keychain ownership to current binary

# After migration, switch mechanism
defaults write com.oemden.claudesecrets secrets_mechanism "keychain"

# Verify migration success
claudesecrets-cli -l keychain
```

### Emergency Recovery
```bash
# Emergency disable - stops daemon, restores original config
claudesecrets-cli --noclaudesecrets

# Completely wipe all secrets (requires confirmation)
claudesecrets-cli --wipesecrets
```

### Daemon Management & Logging (v0.4.2)
```bash
# Status and configuration
claudesecrets-cli -s, --status           # Show daemon and configuration status
claudesecrets-cli -c, --config           # Show current configuration settings

# LaunchAgent control
claudesecrets-cli -I, --install          # Install LaunchAgent plist (doesn't start)
claudesecrets-cli -E, --enable           # Enable and start LaunchAgent daemon
claudesecrets-cli -D, --disable          # Disable and stop LaunchAgent daemon
claudesecrets-cli -U, --uninstall        # Remove LaunchAgent plist (stops if running)

# System management
claudesecrets-cli -r, --reset            # Reset to default claudesecrets settings
claudesecrets-cli -R, --restore          # Restore original Claude config and disable daemon

# Template management
claudesecrets-cli -t, --template         # Create template from current Claude config
claudesecrets-cli -g TEMPLATE OUTPUT     # Generate config from template and secrets

# Logging control (NEW in v0.4.2)
claudesecrets-cli -L minimal             # Minimal logging (essential only)
claudesecrets-cli -L normal              # Normal logging (operational)
claudesecrets-cli -L debug               # Debug logging (verbose)
claudesecrets-cli --daemon-console off   # Silent daemon (default)
claudesecrets-cli --daemon-console on    # Verbose daemon

# Alternative logging control via defaults
defaults write com.oemden.claudesecrets log_level -int 0      # minimal
defaults write com.oemden.claudesecrets log_level -int 1      # normal
defaults write com.oemden.claudesecrets log_level -int 2      # debug

# Notifications
claudesecrets-cli -V on                  # Enable voice notifications
claudesecrets-cli -n off                 # Disable macOS notifications
```

## Configuration

### File Paths (configurable via defaults)
- **Template**: `~/Library/Application Support/Claude/claude_desktop_config_template.json`
- **Target Config**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **Secrets File**: `~/.claudesecrets/.claude_secrets`
- **Backup**: `~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json`

### Preferences Domain
- **Domain**: `com.oemden.claudesecrets`
- **Mechanism**: `defaults write com.oemden.claudesecrets secrets_mechanism "keychain"`

## Development

### Building
```bash
# Development build
swift build

# Release build (for distribution)
swift build -c release

# Xcode development
open Package.swift
```

### Testing
```bash
# Test installation (dev mode)
ENV="dev" ./test_install.sh

# Production installation  
ENV="prod" ./test_install.sh

# Check logs (v0.4.2 enhanced logging)
tail -f /tmp/claudesecrets.log

# Control log verbosity
defaults write com.oemden.claudesecrets log_level "minimal"  # Errors only
defaults write com.oemden.claudesecrets log_level "debug"    # Full debugging
```

## Security Notes (Enhanced in v0.4.2)

- **Keychain**: Uses `kSecAttrAccessibleWhenUnlocked` for daemon access
- **File Storage**: Set to 600 permissions (owner read/write only)  
- **Service ID**: "claudesecrets" in keychain, "claudesecretsupgradekey" for migration
- **Code Signing**: Required for production keychain access
- **Backup**: Automatic config backup before first modification
- **Migration Security**: AES-256-CBC encryption with random keys via OpenSSL  
- **Service Isolation**: Separate keychain services prevent conflicts during upgrades
- **Error Recovery**: Comprehensive error handling with automatic cleanup

## Compatibility

- **macOS**: 12.0+ (Monterey and later)
- **Claude Desktop**: All versions
- **Claude Code**: All versions  
- **Swift**: 5.9+

## Troubleshooting

### Common Issues
```bash
# Permission denied
# → Grant app monitoring permissions in System Preferences

# Keychain access denied  
# → Code sign the binary or run from Xcode

# Daemon not starting
claudesecrets-cli --status
launchctl list | grep claudesecrets

# Debug logs
tail -f /tmp/claudesecrets.log
```

### Reset Configuration
```bash
# Reset all settings
claudesecrets-cli --reset

# Remove preferences
defaults delete com.oemden.claudesecrets

# Restore original config
claudesecrets-cli --restore
```

## Contributing

This is a personal side project, but contributions are welcome:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)  
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## License

Use at your own risk. Always backup your configuration files.

---

**Note**: This tool monitors system processes and modifies configuration files. Review the code and test thoroughly before production use.