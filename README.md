# Claude Secrets Manager

A macOS daemon that monitors Claude Desktop/Code launch events and manages configuration with secure secrets injection. This project aims to enable vibe coding while dealing with secrets management for Claude config.

## Project Goal

This project is a way to use vibe coding and deal with secrets management for Claude config. It annoyed me to put all secrets, passwords and tokens directly in the JSON Claude config. While there is a file mechanism, the goal is to use the macOS keychain for secure storage. I have not found other ways than to detect if Claude Desktop or Claude Code are running and create the config on the fly with variable substitution - surely there is a better way.

As of now it seems that Claude Desktop and Code share the JSON config, yet there are preference keys ready in case that changes in the future.

As of now I have not dealt with complex strings and how they are handled in a JSON file, but my few tests proved to be working.

**⚠️ This is a side project - use at your own risk and ALWAYS BACKUP your config files before using the tool, although there is a built-in config backup at first run and installation process.**

## Features

- ✅ **Secure Storage**: File-based or macOS Keychain secrets storage
- ✅ **Process Monitoring**: Detects Claude Desktop & Claude Code launch/quit
- ✅ **Dynamic Config**: On-the-fly configuration generation with variable substitution
- ✅ **Template System**: Uses template files with placeholder variables
- ✅ **CLI Management**: Full command-line interface for secrets management
- ✅ **LaunchAgent**: Automatic startup and background operation
- ✅ **Backup System**: Automatic config backup on first run
- ✅ **Dual Mechanism**: Switch between file and keychain storage seamlessly

## Quick Start

### Installation

**For Release Users (Recommended):**
- Download and install the `.pkg` installer (coming soon)
- The installer handles everything automatically

**For Development/Testing:**
```bash
# Clone and build from source
git clone <repository>
cd "Claude Auto Config"
swift build -c release

# Install binaries and LaunchAgent (dev/testing)
./test_install.sh
```

### Basic Usage
```bash
# Set up keychain storage (recommended)
claudesecrets-cli -m keychain --add API_KEY=your_secret_key
claudesecrets-cli -m keychain --add DATABASE_URL=your_connection_string

# Or use file storage
claudesecrets-cli -m file --add API_KEY=your_secret_key

# List stored secrets (values hidden for security)
claudesecrets-cli --list-secrets keychain
claudesecrets-cli --list-secrets file

# Check daemon status
claudesecrets-cli --status
```

### Setup Template

**Template Creation (Automatic):**
- Installation and first run automatically create template from your existing Claude config
- No manual copying needed!

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

## Project Structure
```
Claude Auto Config/
├── Package.swift                    # Swift Package Manager
├── Makefile                         # Build shortcuts  
├── test_install.sh                  # Installation script
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
├── com.oemden.claudesecrets.plist  # LaunchAgent plist
└── secrets/
    └── claude_secrets              # File-based secrets (if used)
```

## CLI Commands

### Secrets Management
```bash
# Add secrets (keychain recommended)
claudesecrets-cli -m keychain --add API_KEY=abc123
claudesecrets-cli -m keychain --add VAR1=val1,VAR2=val2

# Delete secrets  
claudesecrets-cli -m keychain --delete API_KEY
claudesecrets-cli -m keychain --delete VAR1,VAR2

# List secrets (values hidden)
claudesecrets-cli --list-secrets keychain
claudesecrets-cli --list-secrets file

# Switch storage mechanism
defaults write com.oemden.claudesecrets secrets_mechanism "keychain"
```

### Migration (File to Keychain)
```bash
# Migrate from file-based to keychain storage
claudesecrets-cli --migrate file-to-keychain

# Migrate and automatically empty the source file (with backup)
claudesecrets-cli --migrate file-to-keychain --emptysecretfile

# After migration, switch mechanism
defaults write com.oemden.claudesecrets secrets_mechanism "keychain"

# Verify migration success
claudesecrets-cli --list-secrets keychain
```

### Emergency Recovery
```bash
# Emergency disable - stops daemon, restores original config
claudesecrets-cli --noclaudesecrets

# Completely wipe all secrets (requires confirmation)
claudesecrets-cli --wipesecrets
```

### Daemon Management
```bash
# Status and configuration
claudesecrets-cli --status
claudesecrets-cli --config

# LaunchAgent control
claudesecrets-cli --install    # Install plist
claudesecrets-cli --enable     # Start daemon
claudesecrets-cli --disable    # Stop daemon
claudesecrets-cli --uninstall  # Remove plist

# Notifications
claudesecrets-cli --voice on
claudesecrets-cli --notifications on
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

# Check logs
tail -f /tmp/claudesecrets.log
```

## Security Notes

- **Keychain**: Uses `kSecAttrAccessibleWhenUnlocked` for daemon access
- **File Storage**: Set to 600 permissions (owner read/write only)  
- **Service ID**: "claudesecrets" in keychain
- **Code Signing**: Required for production keychain access
- **Backup**: Automatic config backup before first modification

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