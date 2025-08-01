# Package Installation Scripts

macOS package installer scripts for Claude Secrets Manager v0.4.2. These scripts handle safe installation and upgrades while preserving user configurations.

## Scripts

### `preinstall`
- **Purpose**: Prepares system before package installation
- **Function**: Detects console user, exports keychain secrets, creates backups
- **Key Operations**:
  - User detection via `/dev/console` ownership
  - Keychain export to encrypted temporary file
  - Backup of existing config files
  - LaunchAgent unloading

### `postinstall`  
- **Purpose**: Completes installation after package files are copied
- **Function**: Imports keychain secrets, sets permissions, starts services
- **Key Operations**:
  - Keychain import from encrypted temporary file
  - File ownership and permission setup (user:staff, 600/644)
  - LaunchAgent loading and startup
  - Cleanup of temporary files

## Installation Flow

```
preinstall → Package Installation → postinstall
     ↓              ↓                    ↓
Export keys +   Install bins +      Import keys +
user setup      LaunchAgent         start daemon
```

## File Handling

**Always Preserved:**
- `~/.claudesecrets/.claude_secrets` (never overwritten)
- `~/Library/Application Support/Claude/claude_desktop_config_template.json` (never overwritten)

**Managed by Package:**
- `/usr/local/bin/claudesecrets` (daemon binary)
- `/usr/local/bin/claudesecrets-cli` (CLI binary)
- `~/Library/LaunchAgents/com.oemden.claudesecrets.plist` (launch agent)

## Security

- All user files owned by detected user, never root
- Secrets file: 600 permissions (owner read/write only)
- Keychain data encrypted during temporary storage
- Automatic cleanup of temporary files

