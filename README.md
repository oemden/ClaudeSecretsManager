# Claude Auto Config

A macOS daemon that monitors Claude Desktop launch/quit events and manages configuration with secrets injection.

## Current Status
- ✅ App monitoring (testing with TextEdit.app)
- ✅ Launch/quit detection
- ✅ Script execution hooks
- ✅ Secrets file parsing
- ✅ Template processing
- 🚧 Preferences with `defaults`
- 🚧 LaunchDaemon setup

## Quick Start

### Build and Test
```bash
# Open in Xcode (recommended)
open Package.swift

# Or use terminal:
make test
```

### Setup Before Testing
1. Create your template file:
   ```bash
   # Copy your Claude config as template
   cp ~/Library/Application\ Support/Claude/claude_desktop_config.json \
      ~/Library/Application\ Support/Claude/claude_desktop_config_template.json
   ```

2. Edit the secrets file:
   ```bash
   nano ~/dev/Claude\ Auto\ Config/secrets/claude_secrets
   ```

### Testing
1. Run `make test` or press ⌘+R in Xcode
2. Launch TextEdit.app - you'll hear "Configuration injected"
   - Check `~/Library/Application Support/Claude/claude_desktop_config_test.json`
   - Your secrets should be replaced in the test file
3. Quit TextEdit.app - you'll hear "Configuration cleaned"

⚠️ **Note**: Using TextEdit for testing. Switch to Claude Desktop when ready for production.

## Project Structure
```
Claude Auto Config/
├── Package.swift           # SPM configuration
├── Makefile               # Build shortcuts
├── Sources/
│   └── ClaudeAutoConfig/
│       ├── main.swift         # Main monitor code
│       └── SecretsParser.swift # Secrets parsing logic
├── secrets/
│   └── claude_secrets         # Your secret values
└── README.md             # This file
```

## Next Steps
1. Add preferences management using `defaults`
2. Implement secrets file parsing
3. Create config template system
4. Switch from TextEdit to Claude Desktop monitoring
5. Create LaunchDaemon for auto-start

## Building
- **Xcode**: Just open Package.swift and press ⌘+B
- **Terminal**: `swift build` or `make build`
- **Release**: `swift build -c release`

## Notes
- **Notifications**: macOS notifications require the app to be code-signed or run from Xcode.
  If running from terminal, notifications might not appear but the app will still work.
- **Permissions**: The app needs permission to monitor other apps. macOS will prompt on first run.
