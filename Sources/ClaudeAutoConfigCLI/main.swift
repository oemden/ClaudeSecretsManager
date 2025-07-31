#!/usr/bin/env swift

import Foundation

// MARK: - Shared Components (will be moved to shared module later)

// Copy of Preferences class needed for CLI
struct Preferences {
    private static let suiteName = "com.oemden.claudeautoconfig"
    private static let customDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    
    static var secretsFile: String {
        customDefaults.string(forKey: "secrets_file") ?? "~/.claudeautoconfig/.claude_secrets"
    }
    
    static var templateClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "template_claudedesktop_config_file") ?? "~/Library/Application Support/Claude/claude_desktop_config_template.json"
    }
    
    static var targetClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "target_claudedesktop_config_file") ?? "~/Library/Application Support/Claude/claude_desktop_config_test.json"
    }
    
    static var voiceNotifications: Bool {
        return customDefaults.bool(forKey: "voice_notifications")
    }
    
    static var macosNotifications: Bool {
        return customDefaults.bool(forKey: "macos_notifications")
    }
    
    static var secretsMechanism: String {
        return customDefaults.string(forKey: "secrets_mechanism") ?? "file"
    }
    
    static var manageClaudeDesktopConfig: Bool {
        return customDefaults.bool(forKey: "manage_ClaudeDesktop_config")
    }
    
    static var manageClaudeCodeConfig: Bool {
        return customDefaults.bool(forKey: "manage_ClaudeCode_config")
    }
    
    static var shareClaudeDesktopConfigWithClaudeCode: Bool {
        return customDefaults.bool(forKey: "shareClaudeDesktop_config_withClaudeCode")
    }
    
    static var alwaysSecureConfig: Bool {
        return customDefaults.bool(forKey: "always_secure_config")
    }
    
    static var processMonitoringInterval: Double {
        return customDefaults.double(forKey: "process_monitoring_interval")
    }
    
    static var isFirstRun: Bool {
        return !customDefaults.bool(forKey: "first_run_done")
    }
    
    static var alwaysResetConfigAtLaunch: Bool {
        return customDefaults.bool(forKey: "always_reset_config_at_launch")
    }
}

// Copy of SecretsParser needed for CLI
struct SecretsParser {
    static func parseSecretsFile(at path: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: path.expandingTildeInPath)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SecretsError.fileNotFound(path)
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseSecrets(from: content)
    }
    
    static func parseSecrets(from content: String) -> [String: String] {
        var secrets: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Handle export prefix
            let processedLine = trimmedLine.hasPrefix("export ") 
                ? String(trimmedLine.dropFirst(7)) 
                : trimmedLine
            
            // Find the first = sign to split key and value
            if let equalIndex = processedLine.firstIndex(of: "=") {
                let key = String(processedLine[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(processedLine[processedLine.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if !key.isEmpty {
                    secrets[key] = value
                }
            }
        }
        
        return secrets
    }
}

enum SecretsError: LocalizedError {
    case fileNotFound(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Secrets file not found: \(path)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}

// MARK: - CLI Command Processing
struct CLICommands {
    static func showHelp() {
        print("""
        ClaudeAutoConfigCLI - Claude Desktop & Claude Code Configuration Manager
        
        USAGE:
            claudeautoconfig [OPTIONS]
            claudeautoconfig [COMMAND] [ARGUMENTS]
        
        OPTIONS:
            -h, --help                     Show this help message
            -s, --status                   Show current daemon and configuration status
            -c, --config                   Show current configuration settings
            -v, --voice [on|off]          Enable/disable voice notifications
            -n, --notifications [on|off]  Enable/disable macOS notifications
        
        COMMANDS:
            -a, --add VAR=VALUE           Add secret(s) to configuration
                                         Multiple: VAR1=VALUE1,VAR2=VALUE2
                                         Or: VAR1=VALUE1 VAR2=VALUE2
            -d, --delete VAR              Delete secret(s) from configuration
                                         Multiple: VAR1,VAR2 or VAR1 VAR2
            -m, --mechanism [file|keychain] Set storage mechanism for secrets
                                         (use with --add/--delete)
            -t, --template                Create template from current Claude config
            -r, --reset                   Reset to default ClaudeAutoConfig settings
            -I, --install                 Install LaunchAgent plist (doesn't start)
            -U, --uninstall               Remove LaunchAgent plist (stops if running)
            -E, --enable                  Enable and start LaunchAgent daemon
            -D, --disable                 Disable and stop LaunchAgent daemon
            -R, --restore                 Restore original Claude config and disable daemon
        
        EXAMPLES:
            claudeautoconfig --add API_KEY=abc123 -m file
            claudeautoconfig -a VAR1=val1,VAR2=val2 -m keychain
            claudeautoconfig --delete API_KEY -m file
            claudeautoconfig --voice on
            claudeautoconfig --install
            claudeautoconfig --enable
            claudeautoconfig --status
            claudeautoconfig --disable
        
        COMPLEX VALUES (use single quotes to protect special characters):
            claudeautoconfig -a 'API_URL=https://api.example.com/v1' -m file
            claudeautoconfig -a 'PASSWORD=P@ssw0rd123!&' -m file
            claudeautoconfig -a 'MULTI=val1,API_URL=https://example.com' -m file
        
        ALTERNATIVE METHODS for complex values:
            # Method 1: Single quotes (recommended)
            claudeautoconfig -a 'DB_PASS=Very%$#@Complex!' -m file
            
            # Method 2: Double quotes with escaping  
            claudeautoconfig -a "DB_PASS=Very%\\$#@Complex\\!" -m file
            
            # Method 3: Interactive mode (future feature)
            claudeautoconfig --add-interactive -m file
        
        CONFIGURATION:
            Secrets file: \(Preferences.secretsFile)
            Template file: \(Preferences.templateClaudeDesktopConfigFile)
            Voice notifications: \(Preferences.voiceNotifications ? "enabled" : "disabled")
            macOS notifications: \(Preferences.macosNotifications ? "enabled" : "disabled")
        """)
    }
    
    static func parseArguments(_ args: [String]) -> Bool {
        guard !args.isEmpty else {
            showHelp()
            return true
        }
        
        var i = 0
        var mechanism: String = Preferences.secretsMechanism
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "-h", "--help":
                showHelp()
                return true
                
            case "-s", "--status":
                showStatus()
                return true
                
            case "-c", "--config":
                showConfig()
                return true
                
            case "-v", "--voice":
                if i + 1 < args.count {
                    let value = args[i + 1]
                    setVoiceNotifications(enabled: value == "on" || value == "true")
                    i += 1
                } else {
                    print("❌ --voice requires a value: on|off")
                    return true
                }
                
            case "-n", "--notifications":
                if i + 1 < args.count {
                    let value = args[i + 1]
                    setMacOSNotifications(enabled: value == "on" || value == "true")
                    i += 1
                } else {
                    print("❌ --notifications requires a value: on|off")
                    return true
                }
                
            case "-m", "--mechanism":
                if i + 1 < args.count {
                    mechanism = args[i + 1]
                    if mechanism != "file" && mechanism != "keychain" {
                        print("❌ --mechanism must be 'file' or 'keychain'")
                        return true
                    }
                    i += 1
                } else {
                    print("❌ --mechanism requires a value: file|keychain")
                    return true
                }
                
            case "-a", "--add":
                if i + 1 < args.count {
                    // Collect all arguments until next flag or end
                    var secretArgs: [String] = []
                    var j = i + 1
                    while j < args.count && !args[j].hasPrefix("-") {
                        secretArgs.append(args[j])
                        j += 1
                    }
                    
                    if secretArgs.isEmpty {
                        print("❌ --add requires secrets in format: VAR=VALUE or VAR1=VALUE1,VAR2=VALUE2")
                        return true
                    }
                    
                    // Parse all collected secret arguments
                    var allSecrets: [String: String] = [:]
                    for secretArg in secretArgs {
                        let secrets = parseSecrets(secretArg)
                        allSecrets.merge(secrets) { _, new in new }
                    }
                    
                    addSecrets(allSecrets, mechanism: mechanism)
                    i = j - 1 // Move index to last processed argument
                } else {
                    print("❌ --add requires secrets in format: VAR=VALUE or VAR1=VALUE1,VAR2=VALUE2")
                    return true
                }
                
            case "--add-interactive":
                addSecretsInteractive(mechanism: mechanism)
                
            case "-d", "--delete":
                if i + 1 < args.count {
                    // Collect all arguments until next flag or end
                    var variableArgs: [String] = []
                    var j = i + 1
                    while j < args.count && !args[j].hasPrefix("-") {
                        variableArgs.append(args[j])
                        j += 1
                    }
                    
                    if variableArgs.isEmpty {
                        print("❌ --delete requires variable names: VAR or VAR1,VAR2")
                        return true
                    }
                    
                    // Parse all collected variable arguments
                    var allVariables: [String] = []
                    for variableArg in variableArgs {
                        let variables = parseVariables(variableArg)
                        allVariables.append(contentsOf: variables)
                    }
                    
                    deleteSecrets(allVariables, mechanism: mechanism)
                    i = j - 1 // Move index to last processed argument
                } else {
                    print("❌ --delete requires variable names: VAR or VAR1,VAR2")
                    return true
                }
                
            case "-t", "--template":
                createTemplateFromCurrentConfig()
                return true
                
            case "-r", "--reset":
                resetConfiguration()
                return true
                
            case "-I", "--install":
                installLaunchAgent()
                return true
                
            case "-U", "--uninstall":
                uninstallLaunchAgent()
                return true
                
            case "-E", "--enable":
                enableLaunchAgent()
                return true
                
            case "-D", "--disable":
                disableLaunchAgent()
                return true
                
            case "--daemon":
                print("❌ --daemon mode should be handled by ClaudeAutoConfig, not ClaudeAutoConfigCLI")
                return false
                
            case "-R", "--restore":
                restoreOriginalConfig()
                
            default:
                print("❌ Unknown argument: \(arg)")
                print("Run --help for usage information")
                return true
            }
            
            i += 1
        }
        
        return true
    }
    
    // Helper functions for CLI commands
    static func parseSecrets(_ input: String) -> [String: String] {
        var secrets: [String: String] = [:]
        let pairs = input.contains(",") ? input.components(separatedBy: ",") : [input]
        
        for pair in pairs {
            let trimmed = pair.trimmingCharacters(in: .whitespaces)
            if let equalIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(trimmed[trimmed.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                if !key.isEmpty {
                    secrets[key] = value
                }
            }
        }
        return secrets
    }
    
    static func parseVariables(_ input: String) -> [String] {
        return input.contains(",") ? 
            input.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } :
            input.components(separatedBy: " ").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    
    static func setVoiceNotifications(enabled: Bool) {
        let defaults = UserDefaults(suiteName: "com.oemden.claudeautoconfig") ?? UserDefaults.standard
        defaults.set(enabled, forKey: "voice_notifications")
        print("🔊 Voice notifications: \(enabled ? "ENABLED" : "DISABLED")")
    }
    
    static func setMacOSNotifications(enabled: Bool) {
        let defaults = UserDefaults(suiteName: "com.oemden.claudeautoconfig") ?? UserDefaults.standard
        defaults.set(enabled, forKey: "macos_notifications")
        print("📱 macOS notifications: \(enabled ? "ENABLED" : "DISABLED")")
    }
    
    static func addSecrets(_ secrets: [String: String], mechanism: String) {
        print("🔐 Processing \(secrets.count) secret(s) using \(mechanism) mechanism...")
        
        if mechanism == "file" {
            addSecretsToFile(secrets)
        } else {
            addSecretsToKeychain(secrets)
        }
    }
    
    static func deleteSecrets(_ variables: [String], mechanism: String) {
        print("🗑️  Deleting \(variables.count) secret(s) using \(mechanism) mechanism...")
        
        if mechanism == "file" {
            deleteSecretsFromFile(variables)
        } else {
            deleteSecretsFromKeychain(variables)
        }
    }
    
    static func addSecretsToFile(_ secrets: [String: String]) {
        let secretsPath = Preferences.secretsFile.expandingTildeInPath
        
        do {
            var existingSecrets: [String: String] = [:]
            
            // Read existing secrets if file exists
            if FileManager.default.fileExists(atPath: secretsPath) {
                existingSecrets = try SecretsParser.parseSecretsFile(at: Preferences.secretsFile)
            }
            
            // Track added vs modified
            var addedCount = 0
            var modifiedCount = 0
            
            // Merge new secrets with existing ones
            for (key, value) in secrets {
                if existingSecrets[key] != nil {
                    existingSecrets[key] = value
                    print("  ✅ Modified: \(key)")
                    modifiedCount += 1
                } else {
                    existingSecrets[key] = value
                    print("  ✅ Added: \(key)")
                    addedCount += 1
                }
            }
            
            // Write updated secrets back to file
            let content = existingSecrets.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
            let header = """
            # Claude Auto Config Secrets File
            # Format: KEY=VALUE or export KEY=VALUE
            # Supports nested values like KEY=VAR=VALUE
            
            """
            
            try (header + content).write(toFile: secretsPath, atomically: true, encoding: .utf8)
            
            // Set secure permissions
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: secretsPath)
            
            // Show appropriate success message
            if addedCount > 0 && modifiedCount > 0 {
                print("✅ Successfully added \(addedCount) and modified \(modifiedCount) secret(s) in \(secretsPath)")
            } else if addedCount > 0 {
                print("✅ Successfully added \(addedCount) secret(s) to \(secretsPath)")
            } else if modifiedCount > 0 {
                print("✅ Successfully modified \(modifiedCount) secret(s) in \(secretsPath)")
            }
            
        } catch {
            print("❌ Failed to add secrets to file: \(error.localizedDescription)")
        }
    }
    
    static func deleteSecretsFromFile(_ variables: [String]) {
        let secretsPath = Preferences.secretsFile.expandingTildeInPath
        
        do {
            guard FileManager.default.fileExists(atPath: secretsPath) else {
                print("❌ Secrets file not found: \(secretsPath)")
                return
            }
            
            var existingSecrets = try SecretsParser.parseSecretsFile(at: Preferences.secretsFile)
            
            // Remove specified variables
            for variable in variables {
                if existingSecrets.removeValue(forKey: variable) != nil {
                    print("  ✅ Deleted: \(variable)")
                } else {
                    print("  ⚠️  Not found: \(variable)")
                }
            }
            
            // Write updated secrets back to file
            let content = existingSecrets.map { "\($0.key)=\($0.value)" }.joined(separator: "\n")
            let header = """
            # Claude Auto Config Secrets File
            # Format: KEY=VALUE or export KEY=VALUE
            # Supports nested values like KEY=VAR=VALUE
            
            """
            
            try (header + content).write(toFile: secretsPath, atomically: true, encoding: .utf8)
            
            print("✅ Successfully deleted \(variables.count) variable(s) from \(secretsPath)")
            
        } catch {
            print("❌ Failed to delete secrets from file: \(error.localizedDescription)")
        }
    }
    
    static func addSecretsToKeychain(_ secrets: [String: String]) {
        print("🔑 Keychain support not yet implemented")
        print("   Will add \(secrets.count) secrets to keychain")
    }
    
    static func deleteSecretsFromKeychain(_ variables: [String]) {
        print("🔑 Keychain support not yet implemented") 
        print("   Will delete \(variables.count) variables from keychain")
    }
    
    static func createTemplateFromCurrentConfig() {
        print("📄 Creating template from current Claude Desktop config...")
        
        let configPath = "~/Library/Application Support/Claude/claude_desktop_config.json".expandingTildeInPath
        let templatePath = Preferences.templateClaudeDesktopConfigFile.expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: configPath) else {
            print("❌ Claude Desktop config not found: \(configPath)")
            return
        }
        
        do {
            try FileManager.default.copyItem(atPath: configPath, toPath: templatePath)
            print("✅ Template created: \(templatePath)")
        } catch {
            print("❌ Failed to create template: \(error.localizedDescription)")
        }
    }
    
    static func resetConfiguration() {
        print("🔄 Resetting ClaudeAutoConfig to defaults...")
        
        let defaults = UserDefaults(suiteName: "com.oemden.claudeautoconfig") ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: "com.oemden.claudeautoconfig")
        
        print("✅ Configuration reset to defaults")
        print("   Note: You may need to run setup again")
    }
    
    static func showStatus() {
        print("📊 ClaudeAutoConfig Status")
        print(String(repeating: "=", count: 40))
        
        // Check if daemon is running
        let daemonRunning = isDaemonRunning()
        print("🔄 Daemon Status: \(daemonRunning ? "RUNNING" : "STOPPED")")
        
        // Check LaunchAgent status
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
        let launchAgentInstalled = FileManager.default.fileExists(atPath: launchAgentPath)
        print("📦 LaunchAgent: \(launchAgentInstalled ? "INSTALLED" : "NOT INSTALLED")")
        
        // Check config files
        let templateExists = FileManager.default.fileExists(atPath: Preferences.templateClaudeDesktopConfigFile.expandingTildeInPath)
        let secretsExists = FileManager.default.fileExists(atPath: Preferences.secretsFile.expandingTildeInPath)
        let configExists = FileManager.default.fileExists(atPath: Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath)
        
        print("📄 Template File: \(templateExists ? "EXISTS" : "MISSING")")
        print("🔐 Secrets File: \(secretsExists ? "EXISTS" : "MISSING")")
        print("⚙️  Active Config: \(configExists ? "EXISTS" : "MISSING")")
        
        // Show current settings
        print("\n📋 Current Settings:")
        print("   Voice Notifications: \(Preferences.voiceNotifications ? "ON" : "OFF")")
        print("   macOS Notifications: \(Preferences.macosNotifications ? "ON" : "OFF")")
        print("   Secrets File: \(Preferences.secretsFile)")
        print("   Template File: \(Preferences.templateClaudeDesktopConfigFile)")
    }
    
    static func showConfig() {
        print("⚙️  ClaudeAutoConfig Configuration")
        print(String(repeating: "=", count: 40))
        
        print("📁 File Paths:")
        print("   • Secrets: \(Preferences.secretsFile)")
        print("   • Template: \(Preferences.templateClaudeDesktopConfigFile)")
        print("   • Target Config: \(Preferences.targetClaudeDesktopConfigFile)")
        
        print("\n🔔 Notifications:")
        print("   • Voice: \(Preferences.voiceNotifications ? "Enabled" : "Disabled")")
        print("   • macOS: \(Preferences.macosNotifications ? "Enabled" : "Disabled")")
        
        print("\n⚙️  Management:")
        print("   • Claude Desktop: \(Preferences.manageClaudeDesktopConfig ? "Enabled" : "Disabled")")
        print("   • Claude Code: \(Preferences.manageClaudeCodeConfig ? "Enabled" : "Disabled")")
        print("   • Config Sharing: \(Preferences.shareClaudeDesktopConfigWithClaudeCode ? "Enabled" : "Disabled")")
        print("   • Always Secure: \(Preferences.alwaysSecureConfig ? "Enabled" : "Disabled")")
        
        print("\n🔧 Advanced:")
        print("   • Monitor Interval: \(Preferences.processMonitoringInterval)s")
        print("   • First Run: \(Preferences.isFirstRun ? "Yes" : "No")")
        print("   • Reset at Launch: \(Preferences.alwaysResetConfigAtLaunch ? "Yes" : "No")")
    }
    
    static func isDaemonRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "ClaudeAutoConfig"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    static func installLaunchAgent() {
        print("📦 Installing ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
        let binaryPath = "/usr/local/bin/ClaudeAutoConfig"
        
        // Check if binary exists
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            print("❌ ClaudeAutoConfig binary not found at: \(binaryPath)")
            print("   Please install the binary first or check the installation path")
            return
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>com.oemden.claudeautoconfig</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>/tmp/ClaudeAutoConfig.log</string>
            <key>StandardErrorPath</key>
            <string>/tmp/ClaudeAutoConfig.error.log</string>
        </dict>
        </plist>
        """
        
        do {
            // Create LaunchAgents directory if needed
            let launchAgentsDir = "\(NSHomeDirectory())/Library/LaunchAgents"
            try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            
            // Write plist file
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: .utf8)
            
            print("✅ LaunchAgent plist installed: \(launchAgentPath)")
            print("📋 Use --enable to start the daemon")
            
        } catch {
            print("❌ Failed to install LaunchAgent: \(error.localizedDescription)")
        }
    }
    
    static func uninstallLaunchAgent() {
        print("🗑️  Uninstalling ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
        
        // First stop the daemon if running
        disableLaunchAgent()
        
        // Remove plist file
        do {
            if FileManager.default.fileExists(atPath: launchAgentPath) {
                try FileManager.default.removeItem(atPath: launchAgentPath)
                print("✅ LaunchAgent plist removed: \(launchAgentPath)")
            } else {
                print("⚠️  LaunchAgent plist not found (already uninstalled)")
            }
        } catch {
            print("❌ Failed to remove LaunchAgent plist: \(error.localizedDescription)")
        }
    }
    
    static func enableLaunchAgent() {
        print("🚀 Enabling ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
        
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            print("❌ LaunchAgent not installed. Run --install first.")
            return
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", "-w", launchAgentPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                print("✅ LaunchAgent enabled and started")
                print("📋 Check status with --status")
            } else {
                print("❌ Failed to enable LaunchAgent (exit code: \(process.terminationStatus))")
            }
        } catch {
            print("❌ Failed to enable LaunchAgent: \(error.localizedDescription)")
        }
    }
    
    static func disableLaunchAgent() {
        print("🛑 Disabling ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudeautoconfig.plist"
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", "-w", launchAgentPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Don't treat exit code 3 (not loaded) as error
            if process.terminationStatus == 0 || process.terminationStatus == 3 {
                print("✅ LaunchAgent disabled and stopped")
            } else {
                print("❌ Failed to disable LaunchAgent (exit code: \(process.terminationStatus))")
            }
        } catch {
            print("❌ Failed to disable LaunchAgent: \(error.localizedDescription)")
        }
    }
    
    static func restoreOriginalConfig() {
        print("🔄 Restoring original Claude Desktop configuration...")
        
        let configPath = "~/Library/Application Support/Claude/claude_desktop_config.json".expandingTildeInPath
        let backupPath = "~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json".expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: backupPath) else {
            print("❌ Backup file not found: \(backupPath)")
            return
        }
        
        do {
            // Stop daemon first
            disableLaunchAgent()
            
            // Restore backup
            try FileManager.default.copyItem(atPath: backupPath, toPath: configPath)
            print("✅ Original configuration restored from backup")
            
            // Remove active config
            let activeConfigPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            if FileManager.default.fileExists(atPath: activeConfigPath) {
                try FileManager.default.removeItem(atPath: activeConfigPath)
                print("✅ Active configuration removed")
            }
            
        } catch {
            print("❌ Failed to restore configuration: \(error.localizedDescription)")
        }
    }
    
    static func addSecretsInteractive(mechanism: String) {
        print("🔐 Interactive secret addition (mechanism: \(mechanism))")
        print("Enter secrets in KEY=VALUE format. Press Enter with empty line to finish.")
        print("📝 Special characters will be preserved exactly as typed")
        print("")
        
        var secrets: [String: String] = [:]
        
        while true {
            print("Enter secret (KEY=VALUE): ", terminator: "")
            guard let input = readLine(), !input.isEmpty else {
                break
            }
            
            if let equalIndex = input.firstIndex(of: "=") {
                let key = String(input[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                let value = String(input[input.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                
                if !key.isEmpty {
                    secrets[key] = value
                    print("  ✅ Added: \(key)")
                } else {
                    print("  ❌ Invalid format (empty key)")
                }
            } else {
                print("  ❌ Invalid format. Use KEY=VALUE")
            }
        }
        
        if !secrets.isEmpty {
            addSecrets(secrets, mechanism: mechanism)
        } else {
            print("ℹ️  No secrets added")
        }
    }
}

// MARK: - Main Entry Point
let arguments = Array(CommandLine.arguments.dropFirst())
let _ = CLICommands.parseArguments(arguments)