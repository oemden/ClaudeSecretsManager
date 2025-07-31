# Claude Secrets Manager - Project Summary

## Overview
A macOS daemon that monitors Claude Desktop launch/quit events and automatically manages configuration files with secrets injection. Currently testing with TextEdit.app before switching to Claude Desktop.

## Project Status
- ✅ App monitoring (launch/quit detection)
- ✅ Secrets file parsing (supports `KEY=VALUE` and `export KEY=VALUE`)
- ✅ Template processing (replaces placeholders with secrets)
- ✅ File permissions (sets 600 on output)
- ✅ Preferences management with `defaults`
- ✅ LaunchAgent setup (complete with dev/prod installation)
- ✅ Dedicated CLI executable (Claude Secrets ManagerCLI)
- ✅ Dynamic bundle ID detection using osascript
- ✅ Dynamic executable path detection using 'which'
- ✅ Fixed security flaw (secrets loaded on-demand, not cached)
- ✅ Fixed variable substitution corruption
- ✅ Fixed false termination detection
- ✅ Production-ready with Claude Desktop and claude executable
- ✅ Keychain integration (Phase 2)
- ✅ Prepare Packages .pkgproj
- ✅ Create a buil-and-package.sh script to run build and cretae distribution package signed .pkg, also sign binaries in the process.

## Directory Structure
```
~/dev/Claude Secrets Manager/
├── Package.swift                 # Swift Package Manager config
├── Makefile                      # Build shortcuts
├── README.md                     # Documentation
├── test_install.sh              # Installation script (dev/prod modes)
├── check_setup.sh               # Setup verification script
├── Sources/
│   ├── Claude Secrets Manager/
│   │   ├── main.swift           # Main daemon executable
│   │   └── SecretsParser.swift  # Secrets parsing & template processing
│   └── Claude Secrets ManagerCLI/
│       └── main.swift           # Dedicated CLI executable
└── secrets/
    └── claude_secrets           # Secret values file
```

## Key Files & Paths

### Configuration
```swift
struct Config {
    // Dynamic configuration - change these two lines to switch apps/executables
    static let targetApplication = "Claude.app"     // "TextEdit.app" or "Claude.app"  
    static let targetExecutable = "claude"           // "sleep" or "claude"
    
    // Auto-deduce bundle IDs and paths dynamically (cached)
    static var targetAppBundleID: String { /* osascript detection */ }
    static var targetExecutablePath: String { /* which detection */ }
    
    static let claudeConfigDir = "~/Library/Application Support/Claude"
    static let templatePath = "\(claudeConfigDir)/claude_desktop_config_template.json"
    static let outputPath = "\(claudeConfigDir)/claude_desktop_config_test.json"
    static let secretsPath = "~/dev/Claude Secrets Manager/secrets/claude_secrets"
}
```

### Required Files
1. **Template**: `~/Library/Application Support/Claude/claude_desktop_config_template.json`
2. **Secrets**: `~/dev/Claude Secrets Manager/secrets/claude_secrets`
3. **Output**: `~/Library/Application Support/Claude/claude_desktop_config_test.json`

## Secrets File Format
```bash
# Claude Secrets Manager Secrets File
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

### Completed in v0.2.0
1. ✅ **Dynamic Configuration System**: Two-line change switches between dev/semi-prod/prod
2. ✅ **Dedicated CLI Executable**: Claude Secrets ManagerCLI for all management tasks
3. ✅ **Dynamic Detection**: Bundle IDs via osascript, executable paths via 'which'
4. ✅ **Security Fixes**: On-demand secrets loading, no memory caching
5. ✅ **Process Detection**: Fixed claude executable detection and false termination
6. ✅ **LaunchAgent Setup**: Complete dev/prod installation with test_install.sh

### Next Phase
1. **Keychain Support** (Phase 2):
   - Service: `com.yourname.claude-auto-config`
   - Account: Variable name
   - Password: Value

2. **Template Restoration**: Restore original config on quit

## Testing Checklist

- [x] Secrets file exists and is readable
- [x] Template file exists
- [x] Can parse secrets with various formats
- [x] Template processing replaces placeholders
- [x] Output file is created with correct permissions
- [x] Original config is backed up
- [ ] Quit event restores template ?? # what is this ??

## Production Deployment

✅ **Ready for Production** (v0.2.0):
1. ✅ Change `targetApplication` to `"Claude.app"` and `targetExecutable` to `"claude"`
2. ✅ Dynamic bundle ID detection - no hardcoded values
3. ✅ Dynamic executable path detection - works anywhere claude is installed
4. ✅ LaunchAgent plist creation and installation
5. ✅ Complete CLI management interface
6. ✅ Tested with actual Claude Desktop and claude executable

**Deployment Steps**:
```bash
# Set production mode in Sources/Claude Secrets Manager/main.swift:
static let targetApplication = "Claude.app"
static let targetExecutable = "claude"

# Build and install
swift build -c release
./test_install.sh prod

# Manage via CLI
Claude Secrets ManagerCLI --help
```

## Debugging Commands

```bash
# Check if files exist
make check

# Watch console output
make test

# Check generated config
cat ~/Library/Application\ Support/Claude/claude_desktop_config_test.json

# Monitor system logs
log stream --predicate 'process == "Claude Secrets Manager"'
```

## Security Notes

- Secrets file has user-only permissions (recommended: chmod 600)
- Output config is set to 600 permissions automatically
- Template should not contain actual secrets
- Consider encrypting secrets file in production