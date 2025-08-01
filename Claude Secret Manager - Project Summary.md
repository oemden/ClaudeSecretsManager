# Claude Secret Manager - Project Summary

## Overview
Production-ready macOS daemon that monitors Claude Desktop/Code launches and manages configurations with secure secrets injection. Eliminates plain-text API keys in Claude configs by using dynamic template processing with macOS keychain or encrypted file storage.

### Current Status - v0.4.2 (Production Ready)

## TODOs
- 🚧  **macOS Notifications**: Implement native macOS notification system
- 🚧  **logs**: Move logs from /tmp to ~/Library/Logs/claudesecrets
- 🚧  **config timer**: Alow a timer so that the config is not deleted each time Claude Desktop or Claude is Stopped. 'config_timer_allow' {ON|OFF} - defaults OFF.
- 🚧  **config timer**: Set the timer for the config if 'config_timer' is set {ON|OFF}, decide minimal Time - defaults 2h
   - ( WARNING, must only delete the file is noApp is running of course.)

## DONE

### Core Functionality ✅
- ✅  **App Monitoring**: Works with both Claude Desktop and TextEdit (dynamic detection)
- ✅  **Executable Monitoring**: Works with both claude and sleep processes (dynamic detection)  
- ✅  **Secrets Parser**: Handles `KEY=VALUE`, `export KEY=VALUE`, and nested `KEY=VAR=VALUE`
- ✅  **Template Processing**: Successfully replaces placeholders with secrets (fixed corruption bug)
- ✅  **File Permissions**: Sets 600 on output files
- ✅  **Voice Feedback**: "Configuration injected" on launch, "Configuration cleaned" on quit
- ✅  **Debug Output**: Clear console logging of all operations
- ✅  **CLI Management**: Dedicated Claude Secrets ManagerCLI executable for all management tasks
- ✅  **Dynamic Detection**: Bundle IDs via osascript, executable paths via 'which'
- ✅  **LaunchAgent**: Complete dev/prod installation with test_install.sh - Production ready

### Major Fixes Completed in v0.2.0 ✅
- ✅  **Security**: Fixed cached secrets flaw - now loaded on-demand only
- ✅  **Variable Substitution**: Fixed corruption by sorting secrets by key length
- ✅  **Process Detection**: Fixed claude executable detection with simplified pgrep
- ✅  **False Termination**: Fixed spurious termination events causing config deletion
- ✅  **Dynamic Configuration**: Two-line change switches between dev/semi-prod/prod modes

### Completed in v0.2.0 ✅
- ✅ **Dynamic Configuration System**: Change 2 lines to switch between dev/semi-prod/prod
- ✅ **Dedicated CLI Executable**: Claude Secrets ManagerCLI handles all management tasks
- ✅ **Dynamic Detection**: Bundle IDs via osascript, executable paths via 'which'
- ✅ **Security Overhaul**: On-demand secrets loading, eliminated memory caching
- ✅ **Fixed Process Detection**: Claude executable detection and false termination
- ✅ **Complete LaunchAgent**: Dev/prod installation with test_install.sh
- ✅ **Production Ready**: Works with actual Claude Desktop and claude executable

### Recent v0.4.2 Enhancements ✅
- ✅ **Secure Storage**: File-based or macOS Keychain secrets storage
- ✅ **Process Monitoring**: Detects Claude Desktop & Claude Code launch/quit
- ✅ **Dynamic Config**: On-the-fly configuration generation with variable substitution
- ✅ **Template System**: Uses template files with placeholder variables
- ✅ **CLI Management**: Full command-line interface for secrets management
- ✅ **LaunchAgent**: Automatic startup and background operation
- ✅ **Backup System**: Automatic config backup on first run
- ✅ **Dual Mechanism**: Switch between file and keychain storage seamlessly
- ✅ **Seamless Upgrades**: AES-256-CBC encrypted export/import for package installations
- ✅ **Bulk Import**: Import secrets from external files with `--migrate --file`
- ✅ **Intelligent Logging**: 3-level logging system (minimal/normal/debug) with preference control
- ✅ **Package Installer**: Complete `.pkg` installer with pre/post-install automation
- ✅ **Enterprise Security**: Random key generation, service isolation, comprehensive error handling
- ✅ **Keychain Integration**: Secure macOS keychain storage (DONE)
- ✅ **Logging Options**: Fixed and working correctly (DONE)
- ✅ **LaunchDaemon**: Using launchd integration (DONE)
- ✅ **Install Scripts**: test_install and uninstall scripts for dev vs prod (DONE)
- ✅ **Build & Package**: build-and-package scripts working (DONE)
- ✅ **Package Releases**: Packages project for .pkg releases (DONE)
- ✅  **Silent Daemon**: `daemon_console` preference controls console output
- ✅  **Intelligent Logging**: Separate error logs, filtered message levels
- ✅  **Security Hardening**: Service isolation, random key generation
- ✅  **Package Robustness**: XCreds-pattern installation, comprehensive error handling

## Technical Architecture

### Executables
- ✅  **`claudesecrets`**: Background daemon (process monitoring, config management)
- ✅  **`claudesecrets-cli`**: Management interface (secrets, preferences, migration)

### Storage
- ✅  **Keychain**: Secure macOS keychain integration (recommended)
- ✅  **File**: Encrypted file storage with 600 permissions

### Preferences Domain
- ✅  **`com.oemden.claudesecrets`**: All settings stored in macOS preferences
- ✅  **Key Settings**: `log_level`, `daemon_console`, `secrets_mechanism`

### Process Flow
1. Claude launch detected → Load secrets → Process template → Write config
2. Claude quit detected → Cleanup config

## Development Notes

### Logging Levels
- ✅  **0 (minimal)**: Essential operations (launches, completions, warnings)
- ✅  **1 (normal)**: Operational details (paths, notifications, steps)  
- ✅  **2 (debug)**: Internal debugging (process monitoring, detailed operations)

### Security Model
- ✅  Secrets never cached in memory
- ✅  On-demand loading during config generation
- ✅  Separate error logging to prevent sensitive data leakage
- ✅  Proper file permissions and ownership

## Directory Structure (v0.4.2)
```
~/dev/Claude Auto Config/
├── Package.swift                    # Swift Package Manager config
├── Makefile                         # Build shortcuts  
├── README.md                        # User documentation
├── CLAUDE.md                        # Development context
├── build-and-package.sh            # Complete build and package script
├── Sources/
│   ├── ClaudeSecrets/              # Main daemon
│   │   ├── main.swift
│   │   └── SecretsParser.swift
│   ├── ClaudeSecretsCLI/           # CLI tool
│   │   └── main.swift
│   ├── KeychainManager/            # Keychain integration
│   │   └── KeychainManager.swift
│   └── SharedConstants/            # Shared configuration
│       └── SharedConstants.swift
├── LaunchAgent/
│   └── com.oemden.claudesecrets.plist
├── Packages/                        # Installer package
│   ├── ClaudeSecretsManager.pkgproj
│   └── Scripts/
│       ├── preinstall               # Export keychain, backup
│       └── postinstall              # Import keychain, configure
└── Tests/                           # Development scripts
    ├── test_install.sh
    └── test_uninstall.sh
```

## Technical Architecture

### Process Flow
1. **Launch Detection**: Claude starts → daemon detects process
2. **Secret Loading**: From keychain or file storage  
3. **Template Processing**: Variables replaced with secrets
4. **Config Generation**: Final config written to Claude's location
5. **Cleanup**: Config removed when Claude quits (optional)

### Security Model
- **No Caching**: Secrets loaded on-demand, never stored in memory
- **Encryption**: AES-256-CBC for temporary data during upgrades
- **Permissions**: 600 for secrets, 644 for configs, proper ownership
- **Isolation**: Separate services for upgrade operations

### Preferences System
Domain: `com.oemden.claudesecrets`
- **`log_level`**: 0=minimal, 1=normal, 2=debug
- **`daemon_console`**: Console output control (default: false)
- **`secrets_mechanism`**: "keychain" or "file"

## Recent Enhancements (v0.4.2)
- **Silent Operation**: Daemon console output controllable via preferences
- **Enhanced Logging**: Separate error logs, intelligent message filtering
- **Package Robustness**: XCreds-pattern installation with comprehensive error handling
- **Security Hardening**: Service isolation, random key generation

## Quick Commands
```bash
# Add secrets
claudesecrets-cli -a API_KEY=value

# Control logging  
claudesecrets-cli -L minimal
claudesecrets-cli --daemon-console off

# Migration
claudesecrets-cli --migrate file-to-keychain
claudesecrets-cli --migrate --file /path/to/secrets
```

Project provides enterprise-grade secrets management for Claude configurations while maintaining ease of use for individual developers.