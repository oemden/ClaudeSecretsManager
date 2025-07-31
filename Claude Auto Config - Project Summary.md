# Claude Auto Config - Project Summary

## Overview
A macOS daemon that monitors Claude Desktop launch/quit events and automatically manages configuration files with secrets injection. Currently testing with TextEdit.app before switching to Claude Desktop.

## Project Status
- ✅ App monitoring (launch/quit detection)
- ✅ Secrets file parsing (supports `KEY=VALUE` and `export KEY=VALUE`)
- ✅ Template processing (replaces placeholders with secrets)
- ✅ File permissions (sets 600 on output)
- 🚧 Restore template on quit
- 🚧 Preferences management with `defaults`
- 🚧 LaunchDaemon setup
- 🚧 Keychain integration (Phase 2)

## Directory Structure
```
~/dev/Claude Auto Config/
├── Package.swift                 # Swift Package Manager config
├── Makefile                      # Build shortcuts
├── README.md                     # Documentation
├── check_setup.sh               # Setup verification script
├── Sources/
│   └── ClaudeAutoConfig/
│       ├── main.swift           # Main monitor logic
│       └── SecretsParser.swift  # Secrets parsing & template processing
└── secrets/
    └── claude_secrets           # Secret values file
```

## Key Files & Paths

### Configuration
```swift
struct Config {
    static let targetBundleID = "com.apple.TextEdit" // Change to "com.anthropic.claude-desktop"
    static let claudeConfigDir = "~/Library/Application Support/Claude"
    static let templatePath = "\(claudeConfigDir)/claude_desktop_config_template.json"
    static let outputPath = "\(claudeConfigDir)/claude_desktop_config_test.json" // Change to claude_desktop_config.json
    static let secretsPath = "~/dev/Claude Auto Config/secrets/claude_secrets"
}
```

### Required Files
1. **Template**: `~/Library/Application Support/Claude/claude_desktop_config_template.json`
2. **Secrets**: `~/dev/Claude Auto Config/secrets/claude_secrets`
3. **Output**: `~/Library/Application Support/Claude/claude_desktop_config_test.json`

## Secrets File Format
```bash
# Claude Auto Config Secrets File
# Format: KEY=VALUE or export KEY=VALUE

# Basic format
SIMPLE_KEY=simple_value

# Export format (optional)
export ANOTHER_KEY=another_value

# Nested values (for MCP requirements)
AUTOPWPMCP_AUTH_TOKEN=AUTH_TOKEN=XYZ0987654321
NOTION_MCP_NOTION_TOKEN=NOTION_TOKEN=ntn_1234567890
```

## How It Works

1. **Monitor starts** → Loads secrets from file
2. **App launches** → Reads template, replaces placeholders with secrets, writes config
3. **App quits** → Restores template (removes secrets from disk)

## Building & Running

### Using Xcode (Recommended)
```bash
cd ~/dev/Claude\ Auto\ Config
open Package.swift
# Press ⌘+R to run
```

### Using Terminal
```bash
cd ~/dev/Claude\ Auto\ Config
make build    # Build release version
make test     # Run with TextEdit monitoring
make check    # Verify setup
```

## Current Issues & Next Steps

### To Fix
1. Implement template restoration on quit
2. Add proper backup mechanism
3. Switch from TextEdit to Claude Desktop monitoring

### To Add
1. **Preferences with `defaults`**:
   - secrets_file_path
   - template_path
   - backup_enabled
   - log_level

2. **LaunchDaemon** for auto-start:
   ```xml
   ~/Library/LaunchAgents/com.user.claudeautoconfig.plist
   ```

3. **Keychain Support** (Phase 2):
   - Service: `com.yourname.claude-auto-config`
   - Account: Variable name
   - Password: Value

## Testing Checklist

- [x] Secrets file exists and is readable
- [x] Template file exists
- [x] Can parse secrets with various formats
- [x] Template processing replaces placeholders
- [x] Output file is created with correct permissions
- [x] Original config is backed up
- [ ] Quit event restores template ?? # what is this ??

## Production Deployment

1. Change `targetBundleID` to `"com.anthropic.claude-desktop"`
2. Change output path from `test.json` to actual config
3. Implement backup on first run
4. Create LaunchAgent plist
5. Code sign for notifications
6. Test thoroughly with actual Claude Desktop

## Debugging Commands

```bash
# Check if files exist
make check

# Watch console output
make test

# Check generated config
cat ~/Library/Application\ Support/Claude/claude_desktop_config_test.json

# Monitor system logs
log stream --predicate 'process == "ClaudeAutoConfig"'
```

## Security Notes

- Secrets file has user-only permissions (recommended: chmod 600)
- Output config is set to 600 permissions automatically
- Template should not contain actual secrets
- Consider encrypting secrets file in production