import Foundation
import AppKit
import UserNotifications
import SharedConstants

// MARK: - Configuration
struct Config {
    // Using shared constants
    static let targetApplication = SharedConstants.targetApplication
    static let targetExecutable = SharedConstants.targetExecutable
    
    static let claudeConfigDir = SharedConstants.claudeConfigDir
    static let templatePath = SharedConstants.templatePath
    static let outputPath = SharedConstants.outputPath
    static let secretsPath = SharedConstants.secretsPath
    
    // Auto-deduce bundle IDs dynamically from app name (cached)
    static var targetAppBundleID: String {
        if _cachedBundleID == nil {
            _cachedBundleID = findAppBundleID(targetApplication)
        }
        return _cachedBundleID!
    }
    private static var _cachedBundleID: String?
    
    // Helper function to find app bundle ID using osascript
    private static func findAppBundleID(_ appName: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "id of app \"\(appName)\""]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let bundleID = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !bundleID.isEmpty {
                    print("🔍 DEBUG: osascript found bundle ID '\(bundleID)' for app '\(appName)'")
                    return bundleID
                }
            }
        } catch {
            // If osascript fails, fall back to hardcoded mappings
            print("🔍 DEBUG: osascript failed for app '\(appName)', using fallback")
        }
        
        // Last resort fallback to known mappings (for safety)
        let fallbackID: String
        switch appName {
        case "TextEdit.app", "TextEdit": fallbackID = "com.apple.TextEdit"
        case "Claude.app", "Claude": fallbackID = "com.anthropic.claudefordesktop"
        default: fallbackID = "com.unknown.app" // Will likely fail, but safe
        }
        
        print("🔍 DEBUG: Using fallback bundle ID '\(fallbackID)' for app '\(appName)'")
        return fallbackID
    }
    
    static var targetExecutablePath: String {
        switch targetExecutable {
        case "sleep": return "/bin/sleep" // System binary, fixed path
        case "claude": return findExecutablePath("claude") // Use which-like detection
        default: return findExecutablePath("claude") // Default to claude
        }
    }
    
    // Helper function to find executable path using 'which' logic
    private static func findExecutablePath(_ executableName: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [executableName]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe() // Suppress error output
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            // If which fails, fall back to common locations
        }
        
        // Fallback: check common installation paths
        let commonPaths = [
            "\(NSHomeDirectory())/.local/bin/\(executableName)",
            "/usr/local/bin/\(executableName)",
            "/opt/homebrew/bin/\(executableName)",
            "/usr/bin/\(executableName)"
        ]
        
        for path in commonPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Last resort: return the name and let system PATH resolve it
        return executableName
    }
    
    static var targetExecutableName: String {
        switch targetExecutable {
        case "sleep": return "sleep"
        case "claude": return "claude"
        default: return "claude" // Default to claude
        }
    }
    
    // For compatibility with existing code
    static let targetBundleID = targetAppBundleID
}

// MARK: - Preferences
struct Preferences {
    static let domain = "com.oemden.claudesecrets"
    
    // Claude Desktop file paths
    static var targetClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "target_claudedesktop_config_file") ?? 
        "\(Config.claudeConfigDir)/claude_desktop_config.json"
    }
    
    static var templateClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "template_claudedesktop_config_file") ?? Config.templatePath
    }
    
    static var firstRunClaudeDesktopBackupFile: String {
        customDefaults.string(forKey: "first_run_claudedesktop_config_backup_file") ?? 
        "\(Config.claudeConfigDir)/claude_desktop_config.backup.json"
    }
    
    // Claude Code file paths
    static var targetClaudeCodeConfigFile: String {
        customDefaults.string(forKey: "target_claudecode_config_file") ?? 
        "/Library/Application Support/ClaudeCode/managed-settings.json"
    }
    
    static var templateClaudeCodeConfigFile: String {
        customDefaults.string(forKey: "template_claudecode_config_file") ?? 
        "\(Config.claudeConfigDir)/claude_code_config_template.json"
    }
    
    static var firstRunClaudeCodeBackupFile: String {
        customDefaults.string(forKey: "first_run_claudecode_config_backup_file") ?? 
        "/Library/Application Support/ClaudeCode/managed-settings.backup.json"
    }
    
    static var secretsFile: String {
        customDefaults.string(forKey: "secrets_file") ?? Config.secretsPath
    }
    
    // Notification settings
    static var voiceNotifications: Bool {
        // If never set, defaults to true
        if customDefaults.object(forKey: "voice_notifications") == nil {
            return true
        }
        return customDefaults.bool(forKey: "voice_notifications")
    }
    
    static var macosNotifications: Bool {
        // If never set, defaults to true
        if customDefaults.object(forKey: "macos_notifications") == nil {
            return true
        }
        return customDefaults.bool(forKey: "macos_notifications")
    }
    
    // Secrets mechanism
    static var secretsMechanism: String {
        customDefaults.string(forKey: "secrets_mechanism") ?? "file"
    }
    
    // LaunchAgent installation
    static var installLaunchdAgent: Bool {
        return customDefaults.bool(forKey: "install_launchd_agent")
    }
    
    // App-specific management
    static var manageClaudeDesktopConfig: Bool {
        // If never set, defaults to true for backwards compatibility
        if customDefaults.object(forKey: "manage_ClaudeDesktop_config") == nil {
            return true
        }
        return customDefaults.bool(forKey: "manage_ClaudeDesktop_config")
    }
    
    static var manageClaudeCodeConfig: Bool {
        // If never set, defaults to false (safer default)
        return customDefaults.bool(forKey: "manage_ClaudeCode_config")
    }
    
    // Helper to get our custom UserDefaults domain
    private static var customDefaults: UserDefaults {
        return UserDefaults(suiteName: domain) ?? UserDefaults.standard
    }
    
    // Define mandatory keys that MUST exist for proper configuration
    static let mandatoryKeys = [
        "target_claudedesktop_config_file",
        "template_claudedesktop_config_file", 
        "template_claudecode_config_file",
        "first_run_claudedesktop_config_backup_file",
        "first_run_claudecode_config_backup_file",
        "secrets_mechanism",
        "secrets_file",
        "voice_notifications",
        "macos_notifications",
        "manage_ClaudeDesktop_config",
        "manage_ClaudeCode_config",
        "shareClaudeDesktop_config_withClaudeCode",
        "always_secure_config",
        "first_run_done"
    ]
    
    // Default values for mandatory keys
    static let mandatoryDefaults: [String: Any] = [
        "target_claudedesktop_config_file": "~/Library/Application Support/Claude/claude_desktop_config_test.json",
        "template_claudedesktop_config_file": "~/Library/Application Support/Claude/claude_desktop_config_template.json",
        "template_claudecode_config_file": "~/Library/Application Support/Claude/claude_desktop_config_template.json",
        "first_run_claudedesktop_config_backup_file": "~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json",
        "first_run_claudecode_config_backup_file": "~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json",
        "secrets_mechanism": "file",
        "secrets_file": "~/.claudeautoconfig/.claude_secrets",
        "voice_notifications": true,
        "macos_notifications": true,
        "manage_ClaudeDesktop_config": true,
        "manage_ClaudeCode_config": true,
        "shareClaudeDesktop_config_withClaudeCode": true,
        "always_secure_config": true,
        "first_run_done": true
    ]
    
    // Check if preferences are properly configured using 3-step logic
    static func isProperlyConfigured() -> Bool {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/\(domain).plist"
        
        // Step 1: detect file -> ls -> not present -> create new file with all defaults
        if !FileManager.default.fileExists(atPath: plistPath) {
            Logger.shared.info("🔧 Plist file not present - creating with all defaults")
            return createCompleteConfiguration()
        }
        
        // Step 2: detect file -> ls -> present -> defaults -> empty -> create new file with all defaults  
        if isPlistEmpty() {
            Logger.shared.info("🔧 Plist file empty - recreating with all defaults")
            return createCompleteConfiguration()
        }
        
        // Step 3: detect file -> ls -> present -> defaults -> not empty -> detect missing keys -> set with defaults
        let missingKeys = getMissingMandatoryKeys()
        if !missingKeys.isEmpty {
            Logger.shared.info("🔧 Plist has missing keys: \(missingKeys) - setting defaults")
            return setMissingKeysToDefaults(missingKeys)
        }
        
        // All keys present, validate files exist
        return validateAndCreateFiles()
    }
    
    // Check if plist domain is empty (no keys)
    static func isPlistEmpty() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", domain]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus != 0 // Empty if can't read domain
        } catch {
            return true
        }
    }
    
    // Get list of missing mandatory keys
    static func getMissingMandatoryKeys() -> [String] {
        var missing: [String] = []
        
        for key in mandatoryKeys {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = ["read", domain, key]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    missing.append(key)
                }
            } catch {
                missing.append(key)
            }
        }
        
        return missing
    }
    
    // Create complete configuration with all defaults
    static func createCompleteConfiguration() -> Bool {
        Logger.shared.info("🔧 Creating complete configuration with all mandatory keys...")
        
        for (key, value) in mandatoryDefaults {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            
            // Handle different value types
            if let boolValue = value as? Bool {
                process.arguments = ["write", domain, key, "-bool", boolValue ? "true" : "false"]
            } else if let stringValue = value as? String {
                process.arguments = ["write", domain, key, stringValue]
            } else {
                process.arguments = ["write", domain, key, "\(value)"]
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    Logger.shared.error("❌ Failed to set key: \(key)")
                    return false
                }
            } catch {
                Logger.shared.error("❌ Failed to set key \(key): \(error)")
                return false
            }
        }
        
        Logger.shared.success("✅ Complete configuration created")
        return validateAndCreateFiles()
    }
    
    // Set missing keys to their default values
    static func setMissingKeysToDefaults(_ missingKeys: [String]) -> Bool {
        for key in missingKeys {
            guard let defaultValue = mandatoryDefaults[key] else {
                Logger.shared.error("❌ No default value for key: \(key)")
                return false
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            
            // Handle different value types
            if let boolValue = defaultValue as? Bool {
                process.arguments = ["write", domain, key, "-bool", boolValue ? "true" : "false"]
            } else if let stringValue = defaultValue as? String {
                process.arguments = ["write", domain, key, stringValue]
            } else {
                process.arguments = ["write", domain, key, "\(defaultValue)"]
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus != 0 {
                    Logger.shared.error("❌ Failed to set missing key: \(key)")
                    return false
                }
                Logger.shared.success("✅ Set missing key: \(key)")
            } catch {
                Logger.shared.error("❌ Failed to set missing key \(key): \(error)")
                return false
            }
        }
        
        return validateAndCreateFiles()
    }
    
    // Validate and auto-create missing files (backup+template, secrets)
    static func validateAndCreateFiles() -> Bool {
        let templatePath = templateClaudeDesktopConfigFile.expandingTildeInPath
        let secretsPath = secretsFile.expandingTildeInPath
        let configPath = "\(Config.claudeConfigDir)/claude_desktop_config.json"
        
        // Check/create backup and template from existing config
        if !FileManager.default.fileExists(atPath: templatePath) {
            Logger.shared.info("🔧 Template file missing, attempting backup+template creation")
            do {
                try TemplateProcessor.backupOriginalAndCreateTemplate(
                    configPath: configPath,
                    templatePath: templateClaudeDesktopConfigFile
                )
            } catch {
                Logger.shared.error("❌ Failed to create backup and template: \(error)")
                return false
            }
        }
        
        // Check/create secrets file  
        if !FileManager.default.fileExists(atPath: secretsPath) {
            Logger.shared.info("🔧 Secrets file missing, creating: \(secretsPath)")
            if !createSecretsFile(at: secretsPath) {
                return false
            }
        }
        
        return true
    }
    
    
    // Create secrets file with placeholder values
    static func createSecretsFile(at secretsPath: String) -> Bool {
        let defaultSecrets = """
# ClaudeAutoConfig Secrets File
# Add your secrets here in KEY=VALUE format

API_KEY=your_api_key_here
SECRET_TOKEN=your_secret_token_here

# You can also use export format:
# export ANOTHER_KEY=another_value
"""
        
        do {
            // Create directory if needed  
            let secretsDir = URL(fileURLWithPath: secretsPath).deletingLastPathComponent().path
            try FileManager.default.createDirectory(atPath: secretsDir, withIntermediateDirectories: true, attributes: nil)
            
            try defaultSecrets.write(toFile: secretsPath, atomically: true, encoding: .utf8)
            
            // Set secure permissions (600 = read/write for owner only)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: secretsPath)
            
            Logger.shared.success("✅ Default secrets file created: \(secretsPath)")
            return true
        } catch {
            Logger.shared.error("❌ Failed to create secrets file: \(error)")
            return false
        }
    }
    
    // Safety cleanup preference
    static var alwaysSecureConfig: Bool {
        // If never set, defaults to true for security
        if customDefaults.object(forKey: "always_secure_config") == nil {
            return true
        }
        return customDefaults.bool(forKey: "always_secure_config")
    }
    
    // Shared config preference
    static var shareClaudeDesktopConfigWithClaudeCode: Bool {
        return customDefaults.bool(forKey: "shareClaudeDesktop_config_withClaudeCode")
    }
    
    // Process monitoring interval
    static var processMonitoringInterval: TimeInterval {
        let interval = customDefaults.double(forKey: "process_monitoring_interval")
        return interval > 0 ? interval : 1.0 // Default to 1 second for faster response
    }
    
    // Use adaptive monitoring (faster when no processes, slower when stable)
    static var useAdaptiveMonitoring: Bool {
        return customDefaults.bool(forKey: "use_adaptive_monitoring")
    }
    
    // App and binary configuration (removed - Config provides these directly)
    
    // First-run setup
    static var isFirstRun: Bool {
        return !customDefaults.bool(forKey: "first_run_done")
    }
    
    static var alwaysResetConfigAtLaunch: Bool {
        return customDefaults.bool(forKey: "always_reset_config_at_launch")
    }
    
    // Helper methods
    static func setDefaults() {
        let defaults: [String: Any] = [
            // Claude Desktop paths (for testing, we use test file)
            "target_claudedesktop_config_file": Config.outputPath, // claude_desktop_config_test.json for now
            "template_claudedesktop_config_file": Config.templatePath,
            "first_run_claudedesktop_config_backup_file": "\(Config.claudeConfigDir)/claude_desktop_config.backup.json",
            
            // Claude Code paths (enterprise managed settings)
            "target_claudecode_config_file": "/Library/Application Support/ClaudeCode/managed-settings.json",
            "template_claudecode_config_file": "\(Config.claudeConfigDir)/claude_code_config_template.json",
            "first_run_claudecode_config_backup_file": "/Library/Application Support/ClaudeCode/managed-settings.backup.json",
            
            // Common settings
            "secrets_file": Config.secretsPath,
            "voice_notifications": true,
            "macos_notifications": true,
            "secrets_mechanism": "file",
            "install_launchd_agent": false,
            "manage_ClaudeDesktop_config": true,
            "manage_ClaudeCode_config": false,
            "always_secure_config": true,
            "shareClaudeDesktop_config_withClaudeCode": true,
            "process_monitoring_interval": 1.0,
            
            // App and binary configuration (using Config values)
            "target_app_bundle_id": Config.targetAppBundleID,
            "target_executable_name": Config.targetExecutableName,
            "target_executable_path": Config.targetExecutablePath,
            
            // First-run setup
            "first_run_done": false,
            "always_reset_config_at_launch": false
        ] as [String : Any]
        
        customDefaults.register(defaults: defaults)
    }
    
    static func printCurrentSettings() {
        print("📋 Current Preferences:")
        print("   Claude Desktop Target: \(targetClaudeDesktopConfigFile)")
        print("   Claude Desktop Template: \(templateClaudeDesktopConfigFile)")
        print("   Claude Desktop Backup: \(firstRunClaudeDesktopBackupFile)")
        print("   Claude Code Target: \(targetClaudeCodeConfigFile)")
        print("   Claude Code Template: \(templateClaudeCodeConfigFile)")
        print("   Claude Code Backup: \(firstRunClaudeCodeBackupFile)")
        print("   Secrets: \(secretsFile)")
        print("   Voice: \(voiceNotifications)")
        print("   Notifications: \(macosNotifications)")
        print("   Secrets Mechanism: \(secretsMechanism)")
        print("   LaunchAgent: \(installLaunchdAgent)")
        print("   Manage Claude Desktop: \(manageClaudeDesktopConfig)")
        print("   Manage Claude Code: \(manageClaudeCodeConfig)")
        print("   Always Secure Config: \(alwaysSecureConfig)")
        print("   Share Config: \(shareClaudeDesktopConfigWithClaudeCode)")
        print("   Monitor Interval: \(processMonitoringInterval)s")
        print("   First Run: \(isFirstRun)")
        print("   Reset at Launch: \(alwaysResetConfigAtLaunch)")
    }
    
    // MARK: - Setup Validation
    static func validateSetup() -> (isValid: Bool, errors: [String]) {
        var errors: [String] = []
        
        // Always check critical setup requirements (don't rely on isFirstRun)
        
        // Check if first_run_done is explicitly set to true
        if isFirstRun {
            errors.append("Setup not completed. Please run initial setup.")
        }
        
        // Check critical files exist
        let templatePath = templateClaudeDesktopConfigFile.expandingTildeInPath
        if !FileManager.default.fileExists(atPath: templatePath) {
            errors.append("Template file missing: \(templatePath)")
        }
        
        let secretsPath = secretsFile.expandingTildeInPath
        if !FileManager.default.fileExists(atPath: secretsPath) {
            errors.append("Secrets file missing: \(secretsPath)")
        }
        
        // Check target directory is writable
        let targetPath = targetClaudeDesktopConfigFile.expandingTildeInPath
        let targetDir = (targetPath as NSString).deletingLastPathComponent
        if !FileManager.default.isWritableFile(atPath: targetDir) {
            errors.append("Target directory not writable: \(targetDir)")
        }
        
        return (errors.isEmpty, errors)
    }
    
    static func createFirstRunBackups() -> Bool {
        if isFirstRun {
            Logger.shared.info("ℹ️  Creating first-run backups...")
            
            // Backup Claude Desktop config if it exists
            let originalConfig = "~/Library/Application Support/Claude/claude_desktop_config.json".expandingTildeInPath
            let backupPath = firstRunClaudeDesktopBackupFile.expandingTildeInPath
            
            if FileManager.default.fileExists(atPath: originalConfig) && !FileManager.default.fileExists(atPath: backupPath) {
                do {
                    try FileManager.default.copyItem(atPath: originalConfig, toPath: backupPath)
                    Logger.shared.success("✅ Created first-run backup: \(backupPath)")
                } catch {
                    Logger.shared.error("❌ Failed to create backup: \(error.localizedDescription)")
                    return false
                }
            }
        }
        return true // Backup creation successful or not needed
    }
    
    static func markSetupCompleted() {
        customDefaults.set(true, forKey: "first_run_done")
        Logger.shared.success("✅ First-run setup completed")
    }
    
    static func killRunningAppsForSetup() {
        Logger.shared.warning("⚠️  Setup incomplete - terminating monitored applications")
        
        // Kill TextEdit (Claude Desktop test app)
        let killTextEdit = Process()
        killTextEdit.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killTextEdit.arguments = ["-f", "TextEdit"]
        try? killTextEdit.run()
        
        // Kill sleep processes (Claude Code test)
        let killSleep = Process()
        killSleep.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killSleep.arguments = ["-f", "sleep"]
        try? killSleep.run()
        
        Logger.shared.info("🛑 Terminated running applications")
    }
    
    static func showSetupInstructions(errors: [String]) {
        // First show console output for debugging
        print("\n" + String(repeating: "=", count: 60))
        print("🚨 CLAUDEAUTOCONFIG SETUP REQUIRED")
        print(String(repeating: "=", count: 60))
        print("\nConfiguration errors found:")
        for error in errors {
            print("❌ \(error)")
        }
        
        // Try to show SwiftDialog GUI
        showSwiftDialogSetup(errors: errors)
        
        // Voice notification - only if preferences not configured (not already created)
        if voiceNotifications && !Preferences.isProperlyConfigured() {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            process.arguments = ["ClaudeAutoConfig setup required"]
            try? process.run()
        }
    }
    
    static func showSwiftDialogSetup(errors: [String]) {
        // Check if SwiftDialog is available
        let dialogPath = "/usr/local/bin/dialog"
        guard FileManager.default.fileExists(atPath: dialogPath) else {
            Logger.shared.warning("⚠️  SwiftDialog not found at \(dialogPath) - showing console instructions only")
            showConsoleInstructions(errors: errors)
            return
        }
        
        // Create SwiftDialog command
        let task = Process()
        task.executableURL = URL(fileURLWithPath: dialogPath)
        
        let dialogArgs = [
            "--title", "ClaudeAutoConfig Setup Required",
            "--message", "Configuration errors found:\n\n" + errors.map { "• \($0)" }.joined(separator: "\n"),
            "--button1text", "Setup with Defaults",
            "--button2text", "Show Manual Instructions",
            "--icon", "SF=gear.circle.fill",
            "--iconsize", "64",
            "--width", "600",
            "--height", "400",
            "--ontop",
            "--moveable"
        ]
        
        task.arguments = dialogArgs
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let exitCode = task.terminationStatus
            Logger.shared.info("🔍 SwiftDialog exit code: \(exitCode)")
            
            if exitCode == 0 {
                // Button 1 clicked - Setup with defaults
                Logger.shared.info("✅ User chose to setup with defaults")
                setupWithDefaults()
            } else if exitCode == 2 {
                // Button 2 clicked - Show manual instructions
                Logger.shared.info("📋 User chose to see manual instructions")
                showConsoleInstructions(errors: errors)
            } else {
                // Dialog cancelled or error
                Logger.shared.info("❌ Dialog cancelled or error occurred")
                showConsoleInstructions(errors: errors)
            }
        } catch {
            Logger.shared.error("❌ Failed to show SwiftDialog: \(error.localizedDescription)")
            showConsoleInstructions(errors: errors)
        }
    }
    
    static func setupWithDefaults() {
        Logger.shared.info("🔧 Setting up ClaudeAutoConfig with default preferences...")
        
        // Call the firstrun_setup script
        let scriptPath = "/Users/oem/dev/Claude Auto Config/firstrun_setup"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: scriptPath)
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                Logger.shared.success("✅ firstrun_setup script completed successfully!")
                // Force UserDefaults to synchronize with disk
                customDefaults.synchronize()
                // Show settings confirmation dialog
                showSettingsDialog()
            } else {
                Logger.shared.error("❌ firstrun_setup script failed with exit code: \(task.terminationStatus)")
            }
        } catch {
            Logger.shared.error("❌ Failed to run firstrun_setup script: \(error.localizedDescription)")
        }
    }
    
    static func showSettingsDialog() {
        Logger.shared.info("📋 Showing current settings dialog...")
        
        // Get current settings with better formatting
        let settings = [
            "• Target Claude Desktop Config:\\n    \(targetClaudeDesktopConfigFile)",
            "• Template File:\\n    \(templateClaudeDesktopConfigFile)", 
            "• Secrets File:\\n    \(secretsFile)",
            "• Voice Notifications:\\n    \(voiceNotifications ? "Enabled" : "Disabled")",
            "• macOS Notifications:\\n    \(macosNotifications ? "Enabled" : "Disabled")",
            "• Manage Claude Desktop:\\n    \(manageClaudeDesktopConfig ? "Yes" : "No")",
            "• Manage Claude Code:\\n    \(manageClaudeCodeConfig ? "Yes" : "No")",
            "• Always Secure Config:\\n    \(alwaysSecureConfig ? "Yes" : "No")",
            "• Share Config between Apps:\\n    \(shareClaudeDesktopConfigWithClaudeCode ? "Yes" : "No")",
            "• First Run Done:\\n    \(isFirstRun ? "No" : "Yes")"
        ]
        
        let message = "ClaudeAutoConfig Settings Created Successfully!\\n\\n" + settings.joined(separator: "\\n\\n")
        
        let dialogPath = "/usr/local/bin/dialog"
        guard FileManager.default.fileExists(atPath: dialogPath) else {
            Logger.shared.warning("⚠️  SwiftDialog not found - showing settings in console")
            Logger.shared.info("📋 Current ClaudeAutoConfig Settings:")
            for setting in settings {
                Logger.shared.info("   ✅ \(setting)")
            }
            return
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: dialogPath)
        
        let dialogArgs = [
            "--title", "ClaudeAutoConfig Settings",
            "--message", message,
            "--button1text", "OK", 
            "--icon", "SF=checkmark.circle.fill",
            "--iconsize", "64",
            "--width", "700",
            "--height", "500",
            "--messagefont", "size=11",
            "--ontop",
            "--moveable"
        ]
        
        task.arguments = dialogArgs
        
        do {
            try task.run()
            task.waitUntilExit()
            Logger.shared.info("📋 Settings dialog displayed via SwiftDialog")
        } catch {
            Logger.shared.error("❌ Failed to show SwiftDialog settings dialog: \(error.localizedDescription)")
            Logger.shared.info("📋 Current settings:")
            for setting in settings {
                Logger.shared.info("   \(setting)")
            }
        }
    }
    
    static func showConsoleInstructions(errors: [String]) {
        print("\n📋 TO SETUP WITH DEFAULT PREFERENCES, RUN:")
        print("""
        # File paths
        defaults write com.oemden.claudesecrets target_claudedesktop_config_file "~/Library/Application Support/Claude/claude_desktop_config_test.json"
        defaults write com.oemden.claudesecrets template_claudedesktop_config_file "~/Library/Application Support/Claude/claude_desktop_config_template.json"
        defaults write com.oemden.claudesecrets first_run_claudedesktop_config_backup_file "~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json"
        
        defaults write com.oemden.claudesecrets secrets_file "~/.claudesecrets/.claude_secrets"
        
        # Notifications
        defaults write com.oemden.claudesecrets voice_notifications -bool true
        defaults write com.oemden.claudesecrets macos_notifications -bool true
        
        # App management
        defaults write com.oemden.claudesecrets manage_ClaudeDesktop_config -bool true
        defaults write com.oemden.claudesecrets manage_ClaudeCode_config -bool true
        defaults write com.oemden.claudesecrets shareClaudeDesktop_config_withClaudeCode -bool true
        
        # Mark setup complete
        defaults write com.oemden.claudesecrets first_run_done -bool true
        """)
        
        print("\n📁 THEN CREATE REQUIRED FILES:")
        print("• Template: ~/Library/Application Support/Claude/claude_desktop_config_template.json")
        print("• Secrets: ~/.claudeautoconfig/.claude_secrets")
        
        print("\n🔄 After setup, restart ClaudeAutoConfig")
        print(String(repeating: "=", count: 60) + "\n")
    }
}

// MARK: - Logger
struct Logger {
    static let shared = Logger()
    private let dateFormatter: DateFormatter
    
    private init() {
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = dateFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(filename):\(line)] \(message)"
        
        print(logMessage)
        
        // Also write to log file if needed in the future
        // writeToLogFile(logMessage)
    }
    
    func success(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.success, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
}

enum LogLevel: String {
    case success = "SUCCESS"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

// MARK: - App Monitor
class AppMonitor {
    let workspace = NSWorkspace.shared
    let notificationCenter: NotificationCenter
    var configInjected: Bool = false  // Track if we actually injected a config
    var processMonitorTimer: Timer?  // Timer for periodic process monitoring
    var lastSeenProcesses: Set<String> = []  // Track process IDs we've seen
    
    init() {
        self.notificationCenter = workspace.notificationCenter
        
        // Initialize preferences
        Preferences.setDefaults()
        
        setupNotifications()
        checkIfAlreadyRunning()
        checkForExistingProcesses()
        startProcessMonitoring()
    }
    
    private func setupNotifications() {
        // Monitor app launch
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidLaunch(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
        
        // Monitor app termination
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        Logger.shared.info("🚀 ClaudeAutoConfig started - monitoring Claude Desktop & Claude Code")
        Preferences.printCurrentSettings()
    }
    
    
    private func checkIfAlreadyRunning() {
        // Check if the app is already running when we start monitoring
        let runningApps = workspace.runningApplications
        
        for app in runningApps {
            if app.bundleIdentifier == Config.targetBundleID {
                let appName = app.localizedName ?? "App"
                Logger.shared.warning("⚠️  \(appName) is already running!")
                
                // Send notification to user
                showNotification(
                    title: "\(appName) Already Running",
                    body: "Please quit \(appName) and relaunch it for configuration to be applied."
                )
                break
            }
        }
    }
    
    private func checkForExistingProcesses() {
        Logger.shared.info("🔍 Checking for existing Claude Code processes on startup...")
        Logger.shared.info("🔍 DEBUG: Process name to look for: '\(Config.targetExecutableName)'")
        Logger.shared.info("🔍 DEBUG: Binary path to look for: '\(Config.targetExecutablePath)'")
        
        // Get current running processes
        let currentProcesses = getCurrentClaudeCodeProcesses()
        Logger.shared.info("🔍 DEBUG: Found processes: \(currentProcesses)")
        
        if !currentProcesses.isEmpty {
            Logger.shared.info("🔍 Found existing Claude Code processes: \(currentProcesses)")
            
            // Check if config file exists
            let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            let configExists = FileManager.default.fileExists(atPath: outputPath)
            
            if !configExists {
                Logger.shared.info("🚀 No config exists for existing processes - checking if plist exists first")
                
                // Check if plist exists FIRST - before any settings checks (working de5c13c logic)
                let plistPath = "/Users/\(NSUserName())/Library/Preferences/com.oemden.claudesecrets.plist"
                let plistExists = FileManager.default.fileExists(atPath: plistPath)
                
                if !plistExists {
                    Logger.shared.error("❌ No plist exists - terminating existing Claude Code processes and showing setup")
                    
                    // Kill the existing processes
                    killSpecificProcesses(pids: Array(currentProcesses))
                    
                    // Show setup instructions (plist doesn't exist, so setup is definitely required)
                    Preferences.showSetupInstructions(errors: ["Configuration file (plist) does not exist"])
                    return
                }
                
                // Plist exists, now validate setup normally
                let (isValid, errors) = Preferences.validateSetup()
                if !isValid {
                    Logger.shared.error("❌ Setup incomplete - terminating existing Claude Code processes")
                    
                    // Kill the existing processes
                    killSpecificProcesses(pids: Array(currentProcesses))
                    
                    // Show setup instructions
                    Preferences.showSetupInstructions(errors: errors)
                    return
                }
                
                // Setup is valid, check management settings
                let appType = "ClaudeCode"
                let (managementEnabled, templatePath, outputPath) = getAppSettings(for: appType)
                
                if managementEnabled {
                    createConfigForProcess(appType: appType, templatePath: templatePath, outputPath: outputPath)
                } else {
                    Logger.shared.info("ℹ️  Claude Code management disabled - not creating config")
                }
            } else {
                Logger.shared.info("ℹ️  Config already exists for existing processes")
            }
        } else {
            Logger.shared.info("ℹ️  No existing Claude Code processes found")
        }
        
        // Update lastSeenProcesses to current state
        lastSeenProcesses = currentProcesses
    }
    
    private func showNotification(title: String, body: String) {
        // Always print to console
        Logger.shared.info("📢 NOTIFICATION: \(title) - \(body)")
        
        // Voice notification if enabled
        if Preferences.voiceNotifications {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
            process.arguments = [title]
            try? process.run()
        }
        
        // TODO: macOS notification support for command-line tools is complex
        // For now, we'll use voice + console logging
        if Preferences.macosNotifications {
            Logger.shared.info("📱 macOS notification would show: \(title) - \(body)")
        }
    }
    
    @objc private func appDidLaunch(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let expectedBundleID = Config.targetAppBundleID
        let actualBundleID = app.bundleIdentifier ?? "nil"
        
        Logger.shared.info("🔍 DEBUG: App launched - expected: '\(expectedBundleID)', actual: '\(actualBundleID)'")
        
        guard actualBundleID == expectedBundleID else {
            return
        }
        
        Logger.shared.info("✅ Claude Desktop (\(app.localizedName ?? "App")) LAUNCHED")
        
        // Check if plist exists FIRST - before any validation that might auto-heal
        let plistPath = NSHomeDirectory() + "/Library/Preferences/\(Preferences.domain).plist"
        if !FileManager.default.fileExists(atPath: plistPath) {
            Logger.shared.error("❌ Configuration plist missing - terminating Claude Desktop and showing setup")
            
            // Force kill the app that just launched
            app.forceTerminate()
            
            // Also use pkill as backup to ensure termination
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killTask.arguments = ["-f", "TextEdit"]
            try? killTask.run()
            
            // Show setup instructions
            Preferences.showSetupInstructions(errors: ["Configuration file (plist) does not exist"])
            return
        }
        
        // Plist exists, now check if setup is valid
        let (isValid, errors) = Preferences.validateSetup()
        if !isValid {
            Logger.shared.error("❌ Setup incomplete - terminating Claude Desktop")
            
            // Force kill the app that just launched
            app.forceTerminate()
            
            // Also use pkill as backup to ensure termination
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            killTask.arguments = ["-f", "TextEdit"]
            try? killTask.run()
            
            // Show setup instructions
            Preferences.showSetupInstructions(errors: errors)
            return
        }
        
        // Create first-run backups if needed
        if !Preferences.createFirstRunBackups() {
            Logger.shared.error("❌ Failed to create first-run backups")
            app.terminate()
            return
        }
        
        Logger.shared.info("🔍 DEBUG: appDidLaunch triggered - calling runScript(phase: \"launch\")")
        
        // Run pre-launch script
        runScript(phase: "launch")
    }
    
    @objc private func appDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        let expectedBundleID = Config.targetAppBundleID
        let actualBundleID = app.bundleIdentifier ?? "nil"
        
        Logger.shared.info("🔍 DEBUG: App terminated - expected: '\(expectedBundleID)', actual: '\(actualBundleID)'")
        
        guard actualBundleID == expectedBundleID else {
            Logger.shared.info("🔍 DEBUG: Ignoring termination of non-target app: \(actualBundleID)")
            return
        }
        
        Logger.shared.info("🛑 \(app.localizedName ?? "App") TERMINATED")
        
        // Run post-quit script
        runScript(phase: "quit")
    }
    
    // MARK: - Shared Template Processing
    private func loadSecretsAndProcessTemplate(templatePath: String, outputPath: String) throws {
        // Load secrets fresh from file
        let secretsPath = Preferences.secretsFile
        Logger.shared.info("🔐 Loading secrets on-demand from: \(secretsPath)")
        let secrets = try SecretsParser.parseSecretsFile(at: secretsPath)
        Logger.shared.success("🔐 Loaded \(secrets.count) secrets for template processing")
        
        // Process template with fresh secrets
        try TemplateProcessor.processTemplate(
            templatePath: templatePath,
            outputPath: outputPath,
            secrets: secrets
        )
    }
    
    private func runScript(phase: String) {
        Logger.shared.info("🔍 DEBUG: runScript called with phase: \(phase)")
        switch phase {
        case "launch":
            Logger.shared.info("🔍 DEBUG: runScript calling processTemplate()")
            processTemplate()
        case "quit":
            Logger.shared.info("🔍 DEBUG: runScript calling restoreTemplate()")
            restoreTemplate()
        default:
            break
        }
    }
    
    // MARK: - Process Monitoring
    private func startProcessMonitoring() {
        let interval = Preferences.processMonitoringInterval
        // Start a timer to periodically check if we need to clean up config
        processMonitorTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkForOrphanedConfig()
        }
        Logger.shared.info("🔄 Started process monitoring (\(interval)-second intervals)")
    }
    
    private func checkForOrphanedConfig() {
        let desktopRunning = isClaudeDesktopRunning()
        let codeRunning = isClaudeCodeRunning()
        
        Logger.shared.info("🔍 DEBUG: Periodic check - Claude Desktop running: \(desktopRunning), Claude Code running: \(codeRunning)")
        
        // Check for new process launches that need config creation
        checkForNewProcessLaunches(desktopRunning: desktopRunning, codeRunning: codeRunning)
        
        // Only cleanup if always_secure_config is enabled
        guard Preferences.alwaysSecureConfig else {
            return
        }
        
        // Check if config exists but no Claude apps are running
        if !desktopRunning && !codeRunning {
            // No Claude apps running - check if config file exists and clean it up
            let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            
            if FileManager.default.fileExists(atPath: outputPath) {
                // Add delay to avoid race condition with config creation
                let configModifiedTime = (try? FileManager.default.attributesOfItem(atPath: outputPath)[.modificationDate] as? Date) ?? Date.distantPast
                let timeSinceModified = Date().timeIntervalSince(configModifiedTime)
                
                // Only cleanup if config is older than 3 seconds (avoids race condition)
                if timeSinceModified > 3.0 {
                    Logger.shared.warning("⚠️  Found orphaned Claude config (age: \(Int(timeSinceModified))s) with no Claude apps running - cleaning up")
                    cleanupOrphanedConfig()
                } else {
                    Logger.shared.info("ℹ️  Config recently created (\(Int(timeSinceModified))s ago) - skipping cleanup to avoid race condition")
                }
            }
        }
    }
    
    private func checkForNewProcessLaunches(desktopRunning: Bool, codeRunning: Bool) {
        // Get current running process IDs for our target process
        let currentProcesses = getCurrentClaudeCodeProcesses()
        
        // Check for new processes (not in lastSeenProcesses)
        let newProcesses = currentProcesses.subtracting(lastSeenProcesses)
        let terminatedProcesses = lastSeenProcesses.subtracting(currentProcesses)
        
        Logger.shared.info("🔍 DEBUG: checkForNewProcessLaunches - current: \(currentProcesses), last seen: \(lastSeenProcesses), new: \(newProcesses), terminated: \(terminatedProcesses)")
        
        // Handle process terminations
        if !terminatedProcesses.isEmpty {
            Logger.shared.info("🔍 Claude Code process terminated: \(terminatedProcesses)")
            
            // Check if Claude Desktop is still running
            if desktopRunning {
                Logger.shared.info("ℹ️  Claude Desktop is still running - config preserved")
                if Preferences.voiceNotifications {
                    Logger.shared.info("🔊 Voice notification: Claude Desktop is running - Config preserved")
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                    process.arguments = ["Claude Desktop is running - Config preserved"]
                    try? process.run()
                }
            }
        }
        
        if !newProcesses.isEmpty {
            Logger.shared.info("🔍 New \(Config.targetExecutableName) process detected: \(newProcesses)")
            
            // Check if config file exists
            let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            let configExists = FileManager.default.fileExists(atPath: outputPath)
            
            if !configExists {
                // No config exists - check if plist exists FIRST
                Logger.shared.info("🚀 No config exists - checking if plist exists first")
                
                // Check if plist exists FIRST - before any settings checks (working de5c13c logic)
                let plistPath = "/Users/\(NSUserName())/Library/Preferences/com.oemden.claudesecrets.plist"
                let plistExists = FileManager.default.fileExists(atPath: plistPath)
                
                if !plistExists {
                    Logger.shared.error("❌ No plist exists - terminating new Claude Code processes and showing setup")
                    
                    // Kill the specific processes that were detected
                    killSpecificProcesses(pids: Array(newProcesses))
                    
                    // Show setup instructions (plist doesn't exist, so setup is definitely required)
                    Preferences.showSetupInstructions(errors: ["Configuration file (plist) does not exist"])
                    return
                }
                
                // Plist exists, now validate setup normally
                let (isValid, errors) = Preferences.validateSetup()
                if !isValid {
                    Logger.shared.error("❌ Setup incomplete - terminating Claude Code processes")
                    
                    // Kill the specific processes that were detected
                    killSpecificProcesses(pids: Array(newProcesses))
                    
                    // Show setup instructions
                    Preferences.showSetupInstructions(errors: errors)
                    return
                }
                
                // Setup is valid, check management settings
                let appType = "ClaudeCode" // Since this is a process launch, treat as Claude Code
                let (managementEnabled, templatePath, outputPath) = getAppSettings(for: appType)
                
                if managementEnabled {
                    createConfigForProcess(appType: appType, templatePath: templatePath, outputPath: outputPath)
                } else {
                    Logger.shared.info("ℹ️  Claude Code management disabled - skipping config creation")
                }
            } else {
                Logger.shared.info("ℹ️  Config already exists - no need to create for new process")
                
                // Voice notification when Claude Code starts but config already exists
                if Preferences.voiceNotifications {
                    Logger.shared.info("🔊 Voice notification: Claude configuration in place")
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                    process.arguments = ["Claude configuration in place"]
                    try? process.run()
                }
            }
        }
        
        // Update our tracking
        lastSeenProcesses = currentProcesses
    }
    
    private func getCurrentClaudeCodeProcesses() -> Set<String> {
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            
            let binaryPath = Config.targetExecutablePath
            let processName = Config.targetExecutableName
            
            Logger.shared.info("🔍 DEBUG: getCurrentClaudeCodeProcesses - processName: '\(processName)', binaryPath: '\(binaryPath)'")
            
            // Use same logic as isClaudeCodeRunning
            if processName == "sleep" {
                // Testing mode - detect sleep command regardless of path
                task.arguments = [processName]
                Logger.shared.info("🔍 DEBUG: Using sleep mode - pgrep arguments: \(task.arguments!)")
            } else {
                // For claude and other executables, use process name
                task.arguments = [processName]
                Logger.shared.info("🔍 DEBUG: Using process name mode - pgrep arguments: \(task.arguments!)")
            }
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            try task.run()
            task.waitUntilExit()
            
            Logger.shared.info("🔍 DEBUG: pgrep exit status: \(task.terminationStatus)")
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                Logger.shared.info("🔍 DEBUG: pgrep raw output: '\(output)'")
                let pids = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                Logger.shared.info("🔍 DEBUG: pgrep parsed PIDs: \(pids)")
                return Set(pids)
            } else {
                Logger.shared.info("🔍 DEBUG: pgrep failed - no processes found")
            }
        } catch {
            Logger.shared.error("❌ Failed to get current processes: \(error.localizedDescription)")
        }
        return Set()
    }
    
    private func createConfigForProcess(appType: String, templatePath: String, outputPath: String) {
        Logger.shared.info("🔄 Creating config for \(appType) process...")
        Logger.shared.info("📄 Template path: \(templatePath.expandingTildeInPath)")
        Logger.shared.info("💾 Output path: \(outputPath.expandingTildeInPath)")
        
        // Validate and create missing files (template, secrets) before processing
        if !Preferences.validateAndCreateFiles() {
            Logger.shared.error("❌ Failed to validate and create required files for \(appType)")
            showNotification(
                title: "Config Creation Failed", 
                body: "Failed to create required template or secrets files"
            )
            return
        }
        
        do {
            try loadSecretsAndProcessTemplate(templatePath: templatePath, outputPath: outputPath)
            
            // Mark that we successfully injected config
            configInjected = true
            
            Logger.shared.success("✅ Config created for \(appType) process")
            
            // Announce success with voice if enabled
            if Preferences.voiceNotifications {
                Logger.shared.info("🔊 Voice notification: Configuration created for \(appType) process")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                let message = appType == "ClaudeCode" ? "Configuration created for Claude Code process" : "Configuration created for \(appType) process"
                process.arguments = [message]
                try process.run()
            }
            
        } catch {
            Logger.shared.error("❌ Failed to create config for process: \(error.localizedDescription)")
            showNotification(
                title: "Process Config Creation Failed",
                body: error.localizedDescription
            )
        }
    }
    
    private func cleanupOrphanedConfig() {
        let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
        let outputURL = URL(fileURLWithPath: outputPath)
        
        do {
            try FileManager.default.removeItem(at: outputURL)
            Logger.shared.success("🗑️  Cleaned up orphaned Claude config: \(outputPath)")
            
            if Preferences.voiceNotifications {
                Logger.shared.info("🔊 Voice notification: Claude configuration cleaned")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Claude configuration cleaned"]
                try? process.run()
            }
        } catch {
            Logger.shared.error("❌ Failed to clean orphaned config: \(error.localizedDescription)")
        }
    }
    
    private func killSpecificProcesses(pids: [String]) {
        Logger.shared.warning("⚠️  Terminating specific processes: \(pids.joined(separator: ", "))")
        
        for pid in pids {
            let killTask = Process()
            killTask.executableURL = URL(fileURLWithPath: "/bin/kill")
            killTask.arguments = ["-TERM", pid]
            
            do {
                try killTask.run()
                killTask.waitUntilExit()
                
                if killTask.terminationStatus == 0 {
                    Logger.shared.success("✅ Terminated process \(pid)")
                } else {
                    Logger.shared.warning("⚠️  Process \(pid) may have already terminated")
                }
            } catch {
                Logger.shared.error("❌ Failed to terminate process \(pid): \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Cross-Process Detection
    private func isClaudeDesktopRunning() -> Bool {
        let runningApps = workspace.runningApplications
        return runningApps.contains { app in
            app.bundleIdentifier == Config.targetAppBundleID
        }
    }
    
    private func isClaudeCodeRunning() -> Bool {
        // Check for Claude CLI processes using configurable process name/path
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            
            let _ = Config.targetExecutablePath  // Unused but available if needed
            let processName = Config.targetExecutableName
            
            if processName == "sleep" {
                // Testing mode - detect sleep command regardless of path
                task.arguments = [processName]
                Logger.shared.info("🔍 Checking for sleep processes")
            } else {
                // For claude and other executables, use process name
                task.arguments = [processName]
                Logger.shared.info("🔍 Checking for process name: \(processName)")
            }
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe() // Suppress error output
            
            try task.run()
            task.waitUntilExit()
            
            let isRunning = task.terminationStatus == 0
            Logger.shared.info("🔍 Process running: \(isRunning)")
            return isRunning
        } catch {
            Logger.shared.error("❌ Failed to check if process is running: \(error.localizedDescription)")
            return false
        }
    }
    
    private func isOtherClaudeAppRunning(excluding currentAppType: String) -> Bool {
        switch currentAppType {
        case "ClaudeDesktop":
            return isClaudeCodeRunning()
        case "ClaudeCode":
            return isClaudeDesktopRunning()
        default:
            Logger.shared.warning("⚠️  Unknown app type for cross-process check: \(currentAppType)")
            return false
        }
    }
    
    private func getAppType() -> String {
        // For now, we're testing with TextEdit but treating it as Claude Desktop
        // In the future, we can detect based on Config.targetBundleID
        // if Config.targetBundleID == "com.anthropic.claude-desktop" {
        //     return "ClaudeDesktop"
        // } else if Config.targetBundleID == "com.anthropic.claude-code" {
        //     return "ClaudeCode"
        // }
        
        // For testing with TextEdit, we'll treat it as Claude Desktop
        return "ClaudeDesktop"
    }
    
    private func getAppSettings(for appType: String) -> (managementEnabled: Bool, templatePath: String, outputPath: String) {
        switch appType {
        case "ClaudeDesktop":
            return (
                Preferences.manageClaudeDesktopConfig,
                Preferences.templateClaudeDesktopConfigFile,
                Preferences.targetClaudeDesktopConfigFile
            )
        case "ClaudeCode":
            // Check if we should share Claude Desktop's config
            if Preferences.shareClaudeDesktopConfigWithClaudeCode {
                Logger.shared.info("🔗 Using shared Claude Desktop config for Claude Code")
                return (
                    Preferences.manageClaudeCodeConfig,
                    Preferences.templateClaudeDesktopConfigFile,
                    Preferences.targetClaudeDesktopConfigFile
                )
            } else {
                return (
                    Preferences.manageClaudeCodeConfig,
                    Preferences.templateClaudeCodeConfigFile,
                    Preferences.targetClaudeCodeConfigFile
                )
            }
        default:
            Logger.shared.warning("⚠️  Unknown app type: \(appType), defaulting to Claude Desktop settings")
            return (
                Preferences.manageClaudeDesktopConfig,
                Preferences.templateClaudeDesktopConfigFile,
                Preferences.targetClaudeDesktopConfigFile
            )
        }
    }
    
    private func processTemplate() {
        Logger.shared.info("🔍 DEBUG: processTemplate() started")
        
        // Determine app type and get appropriate settings
        let appType = getAppType()
        let (managementEnabled, templatePath, outputPath) = getAppSettings(for: appType)
        
        Logger.shared.info("🔍 DEBUG: appType=\(appType), managementEnabled=\(managementEnabled)")
        
        if !managementEnabled {
            Logger.shared.info("ℹ️  Config management disabled for \(appType) - skipping template processing")
            return
        }
        
        // Check if config already exists
        let expandedOutputPath = outputPath.expandingTildeInPath
        let configExists = FileManager.default.fileExists(atPath: expandedOutputPath)
        
        if configExists {
            Logger.shared.info("ℹ️  Configuration already exists - no need to recreate")
            if Preferences.voiceNotifications {
                Logger.shared.info("🔊 Voice notification: Claude configuration in place")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Claude configuration in place"]
                try? process.run()
            }
            return
        }
        
        Logger.shared.info("🔄 Starting template processing...")
        Logger.shared.info("📄 Template path: \(templatePath.expandingTildeInPath)")
        Logger.shared.info("💾 Output path: \(expandedOutputPath)")
        
        do {
            try loadSecretsAndProcessTemplate(templatePath: templatePath, outputPath: outputPath)
            
            // Mark that we successfully injected config
            configInjected = true
            
            Logger.shared.success("✅ Template processed successfully - Configuration injected")
            
            // Announce success with voice if enabled
            if Preferences.voiceNotifications {
                Logger.shared.info("🔊 Voice notification: Claude Desktop configuration injected")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Claude Desktop configuration injected"]
                Logger.shared.info("🔍 DEBUG: About to call say process...")
                try process.run()
                process.waitUntilExit()
                Logger.shared.info("🔍 DEBUG: Say process completed with exit code: \(process.terminationStatus)")
            }
            
        } catch {
            Logger.shared.error("❌ Failed to process template: \(error.localizedDescription)")
            showNotification(
                title: "Template Processing Failed",
                body: error.localizedDescription
            )
        }
    }
    
    private func restoreTemplate() {
        // Only cleanup if we actually injected a config
        if !configInjected {
            Logger.shared.info("ℹ️  No config was injected - skipping cleanup")
            return
        }
        
        // Get the current app type
        let appType = getAppType()
        
        // Check if other Claude app is still running
        let otherAppRunning = isOtherClaudeAppRunning(excluding: appType)
        Logger.shared.info("🔍 Other Claude app running: \(otherAppRunning)")
        
        if otherAppRunning {
            Logger.shared.info("🔄 Other Claude app is still running - keeping config intact")
            if Preferences.voiceNotifications {
                let otherAppName = appType == "ClaudeDesktop" ? "Claude Code" : "Claude Desktop"
                let message = "\(otherAppName) is running - Config preserved"
                Logger.shared.info("🔊 Voice notification: \(message)")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = [message]
                try? process.run()
            }
            // DON'T reset injection state - keep it so periodic cleanup won't delete
            // configInjected = false  // REMOVED - this was causing the bug!
            return
        }
        
        // No other Claude app running - safe to delete config
        let (_, _, outputPath) = getAppSettings(for: appType)
        let expandedOutputPath = outputPath.expandingTildeInPath
        let outputURL = URL(fileURLWithPath: expandedOutputPath)
        
        Logger.shared.info("🧹 Starting configuration cleanup (no other Claude apps running)...")
        
        do {
            // Delete the config file if it exists
            if FileManager.default.fileExists(atPath: expandedOutputPath) {
                try FileManager.default.removeItem(at: outputURL)
                Logger.shared.success("🗑️  Deleted config: \(expandedOutputPath)")
            } else {
                Logger.shared.info("ℹ️  Config file not found: \(expandedOutputPath)")
            }
            
            // Announce success with voice if enabled
            if Preferences.voiceNotifications {
                Logger.shared.info("🔊 Voice notification: Claude configuration cleaned")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Claude configuration cleaned"]
                try process.run()
            }
            
            Logger.shared.success("🧹 Configuration cleaned successfully")
            
        } catch {
            Logger.shared.error("❌ Failed to clean configuration: \(error.localizedDescription)")
            showNotification(
                title: "Cleanup Failed",
                body: error.localizedDescription
            )
        }
        
        // Reset the injection state
        configInjected = false
    }
}

// MARK: - Main

// Check for existing instances to prevent duplicates
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
task.arguments = ["-f", "ClaudeAutoConfig"]

let pipe = Pipe()
task.standardOutput = pipe
task.standardError = Pipe()

do {
    try task.run()
    task.waitUntilExit()
    
    if task.terminationStatus == 0 {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let processes = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        // If more than 1 process (current process), exit
        if processes.count > 1 {
            print("❌ ClaudeAutoConfig is already running (PID: \(processes.first ?? "unknown"))")
            print("   Kill existing instance with: kill \(processes.first ?? "")")
            exit(1)
        }
    }
} catch {
    // Continue if check fails
}

// MARK: - CLI Command Processing
struct CLICommands {
    static func showHelp() {
        print("""
        ClaudeAutoConfig - Claude Desktop & Claude Code Configuration Manager
        
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
            claudeautoconfig -a 'PASSWORD=P@ssw0rd123!&$' -m file
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
            // No arguments - check if running via LaunchAgent
            if ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"] != nil ||
               ProcessInfo.processInfo.environment["LAUNCH_AGENT"] != nil ||
               ProcessInfo.processInfo.environment["USER"] == nil {
                // Running via LaunchAgent - run as daemon
                return false
            } else {
                // Running manually - show help
                showHelp()
                return true
            }
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
                    let secrets = parseSecrets(args[i + 1])
                    addSecrets(secrets, mechanism: mechanism)
                    i += 1
                } else {
                    print("❌ --add requires secrets in format: VAR=VALUE or VAR1=VALUE1,VAR2=VALUE2")
                    return true
                }
                
            case "--add-interactive":
                addSecretsInteractive(mechanism: mechanism)
                
            case "-d", "--delete":
                if i + 1 < args.count {
                    let variables = parseVariables(args[i + 1])
                    deleteSecrets(variables, mechanism: mechanism)
                    i += 1
                } else {
                    print("❌ --delete requires variable names: VAR or VAR1,VAR2")
                    return true
                }
                
            case "-t", "--template":
                createTemplate()
                
            case "-r", "--reset":
                resetSettings()
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
                
            case "--run-daemon":
                // Hidden parameter for LaunchAgent - run as daemon
                return false
                
            case "-R", "--restore":
                restoreOriginalConfig()
                
                
            default:
                print("❌ Unknown argument: \(arg)")
                print("Use --help for usage information")
                return true
            }
            
            i += 1
        }
        
        return true // Arguments processed, exit
    }
    
    // Helper functions for CLI commands
    static func parseSecrets(_ input: String) -> [String: String] {
        var secrets: [String: String] = [:]
        let pairs = input.contains(",") ? input.components(separatedBy: ",") : [input]
        
        for pair in pairs {
            let parts = pair.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                // Join all parts after the first "=" to handle values containing "="
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                secrets[key] = value
            } else {
                print("⚠️  Skipping invalid secret format: '\(pair)'")
                print("   Expected format: KEY=VALUE")
            }
        }
        
        return secrets
    }
    
    static func parseVariables(_ input: String) -> [String] {
        return input.contains(",") ? 
            input.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } :
            [input.trimmingCharacters(in: .whitespaces)]
    }
    
    static func setVoiceNotifications(enabled: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.oemden.claudesecrets", "voice_notifications", "-bool", enabled ? "true" : "false"]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("✅ Voice notifications \(enabled ? "enabled" : "disabled")")
        } catch {
            print("❌ Failed to set voice notifications: \(error.localizedDescription)")
        }
    }
    
    static func setMacOSNotifications(enabled: Bool) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["write", "com.oemden.claudesecrets", "macos_notifications", "-bool", enabled ? "true" : "false"]
        
        do {
            try process.run()
            process.waitUntilExit()
            print("✅ macOS notifications \(enabled ? "enabled" : "disabled")")
        } catch {
            print("❌ Failed to set macOS notifications: \(error.localizedDescription)")
        }
    }
    
    static func addSecrets(_ secrets: [String: String], mechanism: String) {
        print("🔐 Adding \(secrets.count) secret(s) using \(mechanism) mechanism...")
        
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
        
        // Read existing secrets
        var existingContent = ""
        if FileManager.default.fileExists(atPath: secretsPath) {
            existingContent = (try? String(contentsOfFile: secretsPath)) ?? ""
        }
        
        // Add new secrets
        var newContent = existingContent
        for (key, value) in secrets {
            // Check if key already exists and update it
            let pattern = "^\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*="
            let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines])
            let range = NSRange(location: 0, length: newContent.count)
            
            if regex?.firstMatch(in: newContent, options: [], range: range) != nil {
                // Update existing - replace the entire line
                let lines = newContent.components(separatedBy: .newlines)
                let updatedLines = lines.map { line in
                    let lineRange = NSRange(location: 0, length: line.count)
                    if regex?.firstMatch(in: line, options: [], range: lineRange) != nil {
                        return "\(key)=\(value)"
                    }
                    return line
                }
                newContent = updatedLines.joined(separator: "\n")
                print("✅ Updated secret: \(key)")
            } else {
                // Add new
                if !newContent.hasSuffix("\n") && !newContent.isEmpty {
                    newContent += "\n"
                }
                newContent += "\(key)=\(value)\n"
                print("✅ Added secret: \(key)")
            }
        }
        
        // Write back to file
        do {
            try newContent.write(toFile: secretsPath, atomically: true, encoding: .utf8)
            
            // Set secure permissions
            let attributes = [FileAttributeKey.posixPermissions: 0o600]
            try FileManager.default.setAttributes(attributes, ofItemAtPath: secretsPath)
            
            print("✅ Secrets file updated: \(secretsPath)")
        } catch {
            print("❌ Failed to update secrets file: \(error.localizedDescription)")
        }
    }
    
    static func deleteSecretsFromFile(_ variables: [String]) {
        let secretsPath = Preferences.secretsFile.expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: secretsPath) else {
            print("❌ Secrets file not found: \(secretsPath)")
            return
        }
        
        do {
            let content = try String(contentsOfFile: secretsPath)
            var lines = content.components(separatedBy: .newlines)
            
            for variable in variables {
                let pattern = "^\\s*\(NSRegularExpression.escapedPattern(for: variable))\\s*="
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                
                lines = lines.filter { line in
                    let range = NSRange(location: 0, length: line.count)
                    return regex.firstMatch(in: line, options: [], range: range) == nil
                }
                
                print("✅ Deleted secret: \(variable)")
            }
            
            let newContent = lines.joined(separator: "\n")
            try newContent.write(toFile: secretsPath, atomically: true, encoding: .utf8)
            
            print("✅ Secrets file updated: \(secretsPath)")
        } catch {
            print("❌ Failed to delete secrets: \(error.localizedDescription)")
        }
    }
    
    static func addSecretsToKeychain(_ secrets: [String: String]) {
        print("🔑 Keychain support not yet implemented")
        // TODO: Implement keychain operations
    }
    
    static func deleteSecretsFromKeychain(_ variables: [String]) {
        print("🔑 Keychain support not yet implemented") 
        // TODO: Implement keychain operations
    }
    
    static func createTemplate() {
        print("📄 Creating template from current Claude config...")
        // TODO: Implement template creation
    }
    
    static func resetSettings() {
        print("🔄 Resetting ClaudeAutoConfig to default settings...")
        // TODO: Implement settings reset
    }
    
    static func getRunningDaemonPIDs() -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", "ClaudeAutoConfig"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                return output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
            }
        } catch {
            // Ignore errors - return empty array
        }
        
        return []
    }
    
    static func showStatus() {
        print("📊 ClaudeAutoConfig Status")
        print(String(repeating: "=", count: 40))
        
        // Check if daemon is running
        let pids = getRunningDaemonPIDs()
        if pids.count > 0 {
            print("🟢 Daemon Status: RUNNING (PID: \(pids.joined(separator: ", ")))")
        } else {
            print("🔴 Daemon Status: NOT RUNNING")
        }
        
        // Check LaunchAgent status
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudesecrets.plist"
        if FileManager.default.fileExists(atPath: launchAgentPath) {
            print("🟢 LaunchAgent: INSTALLED")
            
            // Check if loaded
            let launchctl = Process()
            launchctl.executableURL = URL(fileURLWithPath: "/bin/launchctl")
            launchctl.arguments = ["list", "com.oemden.claudesecrets"]
            launchctl.standardOutput = Pipe()
            launchctl.standardError = Pipe()
            
            do {
                try launchctl.run()
                launchctl.waitUntilExit()
                if launchctl.terminationStatus == 0 {
                    print("🟢 LaunchAgent: LOADED")
                } else {
                    print("🟡 LaunchAgent: NOT LOADED")
                }
            } catch {
                print("❓ LaunchAgent: STATUS UNKNOWN")
            }
        } else {
            print("🔴 LaunchAgent: NOT INSTALLED")
        }
        
        // Check configuration
        if Preferences.isProperlyConfigured() {
            print("🟢 Configuration: SETUP COMPLETE")
            
            let (isValid, errors) = Preferences.validateSetup()
            if isValid {
                print("🟢 Validation: ALL CHECKS PASSED")
            } else {
                print("🟡 Validation: \(errors.count) ISSUE(S) FOUND")
                for error in errors.prefix(3) {
                    print("   ❌ \(error)")
                }
                if errors.count > 3 {
                    print("   ... and \(errors.count - 3) more")
                }
            }
        } else {
            print("🔴 Configuration: NOT SETUP")
        }
        
        // Show current settings summary
        print("\n📋 Quick Settings:")
        print("   Voice Notifications: \(Preferences.voiceNotifications ? "ON" : "OFF")")
        print("   macOS Notifications: \(Preferences.macosNotifications ? "ON" : "OFF")")
        print("   Secrets File: \(Preferences.secretsFile)")
        print("   Template File: \(Preferences.templateClaudeDesktopConfigFile)")
    }
    
    static func showConfig() {
        print("⚙️  ClaudeAutoConfig Configuration")
        print(String(repeating: "=", count: 50))
        
        Preferences.printCurrentSettings()
        
        // Show secrets count (don't show actual values)
        let secretsPath = Preferences.secretsFile.expandingTildeInPath
        if FileManager.default.fileExists(atPath: secretsPath) {
            do {
                let secretsContent = try String(contentsOfFile: secretsPath)
                let secretLines = secretsContent.components(separatedBy: .newlines)
                    .filter { line in
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        return !trimmed.isEmpty && !trimmed.hasPrefix("#") && trimmed.contains("=")
                    }
                print("\n🔐 Secrets: \(secretLines.count) configured")
                
                // Show secret keys (not values)
                print("   Keys: ", terminator: "")
                let keys = secretLines.compactMap { line -> String? in
                    let parts = line.components(separatedBy: "=")
                    return parts.first?.trimmingCharacters(in: .whitespaces)
                }
                print(keys.joined(separator: ", "))
            } catch {
                print("\n🔐 Secrets: Error reading file")
            }
        } else {
            print("\n🔐 Secrets: No secrets file found")
        }
    }
    
    static func installLaunchAgent() {
        print("📦 Installing ClaudeAutoConfig LaunchAgent...")
        
        // TODO: UNCOMMENT WHEN READY TO TEST WITH ADMIN
        /*
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudesecrets.plist"
        let bundlePlistPath = Bundle.main.path(forResource: "com.oemden.claudesecrets", ofType: "plist")
        
        guard let sourcePlistPath = bundlePlistPath else {
            print("❌ Could not find com.oemden.claudesecrets.plist in bundle")
            return
        }
        
        do {
            // Create LaunchAgents directory if it doesn't exist
            let launchAgentsDir = "\(NSHomeDirectory())/Library/LaunchAgents"
            try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
            
            // Create Logs directory
            let logsDir = "\(NSHomeDirectory())/Library/Logs"
            try FileManager.default.createDirectory(atPath: logsDir, withIntermediateDirectories: true)
            
            // Copy plist file from bundle
            try FileManager.default.copyItem(atPath: sourcePlistPath, toPath: launchAgentPath)
            
            print("✅ LaunchAgent plist installed: \(launchAgentPath)")
            print("📋 Use --enable to start the daemon")
            
        } catch {
            print("❌ Failed to install LaunchAgent: \(error.localizedDescription)")
        }
        */
        
        print("📝 This will create:")
        print("   ~/Library/LaunchAgents/com.oemden.claudesecrets.plist")
        print("   ~/Library/Logs/ClaudeAutoConfig.log")
        print("🚧 Implementation commented out - requires admin testing")
    }
    
    static func uninstallLaunchAgent() {
        print("🗑️  Uninstalling ClaudeAutoConfig LaunchAgent...")
        
        // TODO: UNCOMMENT WHEN READY TO TEST WITH ADMIN
        /*
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudesecrets.plist"
        
        // First disable if loaded
        disableLaunchAgent()
        
        do {
            if FileManager.default.fileExists(atPath: launchAgentPath) {
                try FileManager.default.removeItem(atPath: launchAgentPath)
                print("✅ LaunchAgent plist removed")
            } else {
                print("ℹ️  LaunchAgent plist not found")
            }
        } catch {
            print("❌ Failed to remove LaunchAgent: \(error.localizedDescription)")
        }
        */
        
        print("📝 This will:")
        print("   1. Disable LaunchAgent (if enabled)")
        print("   2. Remove ~/Library/LaunchAgents/com.oemden.claudesecrets.plist")
        print("🚧 Implementation commented out - requires admin testing")
    }
    
    static func enableLaunchAgent() {
        print("🚀 Enabling ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudesecrets.plist"
        
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            print("❌ LaunchAgent not installed. Run --install first.")
            return
        }
        
        // First, modify plist to set RunAtLoad=true and KeepAlive=true
        print("📝 Updating plist configuration...")
        do {
            let plistURL = URL(fileURLWithPath: launchAgentPath)
            var plistDict = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as! [String: Any]
            
            plistDict["RunAtLoad"] = true
            plistDict["KeepAlive"] = true
            
            let updatedData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try updatedData.write(to: plistURL)
            print("✅ Plist updated: RunAtLoad=true, KeepAlive=true")
        } catch {
            print("❌ Failed to update plist: \(error.localizedDescription)")
            return
        }
        
        // Then load the LaunchAgent
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["load", "-w", launchAgentPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("✅ LaunchAgent enabled and started")
                print("🔄 Daemon will start automatically on login")
            } else {
                print("❌ Failed to enable LaunchAgent (exit code: \(task.terminationStatus))")
            }
        } catch {
            print("❌ Failed to run launchctl: \(error.localizedDescription)")
        }
    }
    
    static func disableLaunchAgent() {
        print("🛑 Disabling ClaudeAutoConfig LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/com.oemden.claudesecrets.plist"
        
        guard FileManager.default.fileExists(atPath: launchAgentPath) else {
            print("ℹ️  LaunchAgent not installed")
            return
        }
        
        // First, kill any running daemon processes
        let pids = getRunningDaemonPIDs()
        if !pids.isEmpty {
            print("🔪 Killing running daemon processes: \(pids.joined(separator: ", "))")
            for pid in pids {
                let killTask = Process()
                killTask.executableURL = URL(fileURLWithPath: "/bin/kill")
                killTask.arguments = [pid]
                try? killTask.run()
                killTask.waitUntilExit()
            }
        }
        
        // Then unload the LaunchAgent
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        task.arguments = ["unload", "-w", launchAgentPath]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("✅ LaunchAgent disabled and stopped")
            } else {
                print("❌ Failed to disable LaunchAgent (exit code: \(task.terminationStatus))")
            }
        } catch {
            print("❌ Failed to run launchctl: \(error.localizedDescription)")
            return
        }
        
        // Finally, modify plist to set RunAtLoad=false and KeepAlive=false
        print("📝 Updating plist configuration...")
        do {
            let plistURL = URL(fileURLWithPath: launchAgentPath)
            var plistDict = try PropertyListSerialization.propertyList(from: Data(contentsOf: plistURL), format: nil) as! [String: Any]
            
            plistDict["RunAtLoad"] = false
            plistDict["KeepAlive"] = false
            
            let updatedData = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try updatedData.write(to: plistURL)
            print("✅ Plist updated: RunAtLoad=false, KeepAlive=false")
        } catch {
            print("❌ Failed to update plist: \(error.localizedDescription)")
        }
    }
    
    static func restoreOriginalConfig() {
        print("🔙 Restoring original Claude configuration...")
        // TODO: Implement config restoration
    }
    
    static func addSecretsInteractive(mechanism: String) {
        print("🔐 Interactive secret addition (mechanism: \(mechanism))")
        print("📝 Enter secrets one per line in format: KEY=VALUE")
        print("📝 Press Enter on empty line to finish")
        print("📝 Special characters will be preserved exactly as typed")
        print("")
        
        var secrets: [String: String] = [:]
        
        while true {
            print("Enter secret (KEY=VALUE): ", terminator: "")
            
            guard let input = readLine(), !input.isEmpty else {
                break
            }
            
            let parts = input.components(separatedBy: "=")
            if parts.count >= 2 {
                let key = parts[0].trimmingCharacters(in: .whitespaces)
                let value = parts.dropFirst().joined(separator: "=").trimmingCharacters(in: .whitespaces)
                secrets[key] = value
                print("✅ Added: \(key)")
            } else {
                print("❌ Invalid format. Use: KEY=VALUE")
            }
        }
        
        if !secrets.isEmpty {
            addSecrets(secrets, mechanism: mechanism)
        } else {
            print("ℹ️  No secrets added")
        }
    }
}

// COMMENTED OUT FOR PURE DAEMON MODE - CLI arguments
// let arguments = Array(CommandLine.arguments.dropFirst())
// if CLICommands.parseArguments(arguments) {
//     exit(0) // Exit after processing CLI commands
// }

// Only validate critical startup requirements (don't block startup)
let monitor = AppMonitor()

// Keep the RunLoop alive
Logger.shared.info("📡 Monitoring... Press Ctrl+C to stop")
Logger.shared.info("ℹ️  Note: Notifications might not appear in terminal mode")
RunLoop.current.run()
