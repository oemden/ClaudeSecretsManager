import Foundation
import AppKit
import UserNotifications

// MARK: - Configuration
struct Config {
    // Dynamic configuration via preferences
    static var claudeDesktopBundleID: String {
        return Preferences.claudeDesktopBundleID
    }
    
    static var claudeCodeProcessName: String {
        return Preferences.claudeCodeProcessName
    }
    
    static var claudeCodeBinaryPath: String {
        return Preferences.claudeCodeBinaryPath
    }
    
    static let claudeConfigDir = "~/Library/Application Support/Claude"
    static let templatePath = "\(claudeConfigDir)/claude_desktop_config_template.json"
    static let outputPath = "\(claudeConfigDir)/claude_desktop_config_test.json" // Test file for safety
    static let secretsPath = "~/dev/Claude Auto Config/secrets/claude_secrets"
    
    // For compatibility with existing code
    static let targetBundleID = claudeDesktopBundleID
}

// MARK: - Preferences
struct Preferences {
    static let domain = "com.oemden.claudeautoconfig"
    
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
    
    // App and binary configuration
    static var claudeDesktopBundleID: String {
        return customDefaults.string(forKey: "claude_desktop_bundle_id") ?? "com.apple.TextEdit"
    }
    
    static var claudeCodeProcessName: String {
        return customDefaults.string(forKey: "claude_code_process_name") ?? "sleep"
    }
    
    static var claudeCodeBinaryPath: String {
        return customDefaults.string(forKey: "claude_code_binary_path") ?? "/bin/sleep"
    }
    
    // First-run setup
    static var isFirstRun: Bool {
        return !customDefaults.bool(forKey: "first_run_done")
    }
    
    static var alwaysResetConfigAtLaunch: Bool {
        return customDefaults.bool(forKey: "always_reset_config_at_launch")
    }
    
    // Helper methods
    static func setDefaults() {
        let defaults = [
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
            "shareClaudeDesktop_config_withClaudeCode": false,
            "process_monitoring_interval": 1.0,
            
            // App and binary configuration
            "claude_desktop_bundle_id": "com.apple.TextEdit", // Test: TextEdit, Prod: com.anthropic.claude-desktop
            "claude_code_process_name": "sleep", // Test: sleep, Prod: claude
            "claude_code_binary_path": "/bin/sleep", // Test: /bin/sleep, Prod: /Users/oem/.local/bin/claude
            
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
        
        // Voice notification - only if plist doesn't exist (not already created)
        if voiceNotifications && !FileManager.default.fileExists(atPath: "/Users/\(NSUserName())/Library/Preferences/com.oemden.claudeautoconfig.plist") {
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
        defaults write com.oemden.claudeautoconfig target_claudedesktop_config_file "~/Library/Application Support/Claude/claude_desktop_config_test.json"
        defaults write com.oemden.claudeautoconfig template_claudedesktop_config_file "~/Library/Application Support/Claude/claude_desktop_config_template.json"
        defaults write com.oemden.claudeautoconfig first_run_claudedesktop_config_backup_file "~/Library/Application Support/Claude/claude_desktop_config.firstrun.backup.json"
        
        defaults write com.oemden.claudeautoconfig secrets_file "~/.claudeautoconfig/.claude_secrets"
        
        # Notifications
        defaults write com.oemden.claudeautoconfig voice_notifications -bool true
        defaults write com.oemden.claudeautoconfig macos_notifications -bool true
        
        # App management
        defaults write com.oemden.claudeautoconfig manage_ClaudeDesktop_config -bool true
        defaults write com.oemden.claudeautoconfig manage_ClaudeCode_config -bool true
        defaults write com.oemden.claudeautoconfig shareClaudeDesktop_config_withClaudeCode -bool true
        
        # Mark setup complete
        defaults write com.oemden.claudeautoconfig first_run_done -bool true
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
    var secrets: [String: String] = [:]
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
        loadSecrets()
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
        Logger.shared.info("🔍 DEBUG: Process name to look for: '\(Config.claudeCodeProcessName)'")
        Logger.shared.info("🔍 DEBUG: Binary path to look for: '\(Config.claudeCodeBinaryPath)'")
        
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
                
                // Check if plist exists FIRST - before any settings checks
                let plistPath = "/Users/\(NSUserName())/Library/Preferences/com.oemden.claudeautoconfig.plist"
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
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == Config.claudeDesktopBundleID else {
            return
        }
        
        Logger.shared.info("✅ Claude Desktop (\(app.localizedName ?? "App")) LAUNCHED")
        
        // Check if setup is valid before processing
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
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == Config.targetBundleID else {
            return
        }
        
        Logger.shared.info("🛑 \(app.localizedName ?? "App") TERMINATED")
        
        // Run post-quit script
        runScript(phase: "quit")
    }
    
    private func loadSecrets() {
        let secretsPath = Preferences.secretsFile
        Logger.shared.info("🔐 Loading secrets from: \(secretsPath)")
        
        do {
            secrets = try SecretsParser.parseSecretsFile(at: secretsPath)
            Logger.shared.success("🔐 Loaded \(secrets.count) secrets")
        } catch {
            Logger.shared.error("❌ Failed to load secrets: \(error.localizedDescription)")
            showNotification(
                title: "Secrets Loading Failed",
                body: error.localizedDescription
            )
        }
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
            Logger.shared.info("🔍 New \(Config.claudeCodeProcessName) process detected: \(newProcesses)")
            
            // Check if config file exists
            let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            let configExists = FileManager.default.fileExists(atPath: outputPath)
            
            if !configExists {
                // No config exists - check if plist exists FIRST
                Logger.shared.info("🚀 No config exists - checking if plist exists first")
                
                // Check if plist exists FIRST - before any settings checks
                let plistPath = "/Users/\(NSUserName())/Library/Preferences/com.oemden.claudeautoconfig.plist"
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
            
            let binaryPath = Config.claudeCodeBinaryPath
            let processName = Config.claudeCodeProcessName
            
            Logger.shared.info("🔍 DEBUG: getCurrentClaudeCodeProcesses - processName: '\(processName)', binaryPath: '\(binaryPath)'")
            
            // Use same logic as isClaudeCodeRunning
            if processName == "sleep" {
                // Testing mode - detect sleep command regardless of path
                task.arguments = [processName]
                Logger.shared.info("🔍 DEBUG: Using sleep mode - pgrep arguments: \(task.arguments!)")
            } else if !binaryPath.isEmpty {
                // Production mode - use specific binary path for precise detection
                task.arguments = ["-f", binaryPath]
                Logger.shared.info("🔍 DEBUG: Using binary path mode - pgrep arguments: \(task.arguments!)")
            } else {
                // Fallback - pattern match for process name
                task.arguments = ["-f", processName]
                Logger.shared.info("🔍 DEBUG: Using fallback mode - pgrep arguments: \(task.arguments!)")
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
        
        do {
            // Process template with secrets
            try TemplateProcessor.processTemplate(
                templatePath: templatePath,
                outputPath: outputPath,
                secrets: secrets
            )
            
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
            app.bundleIdentifier == Config.claudeDesktopBundleID
        }
    }
    
    private func isClaudeCodeRunning() -> Bool {
        // Check for Claude CLI processes using configurable process name/path
        do {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
            
            let binaryPath = Config.claudeCodeBinaryPath
            let processName = Config.claudeCodeProcessName
            
            if processName == "sleep" {
                // Testing mode - detect sleep command regardless of path
                task.arguments = [processName]
                Logger.shared.info("🔍 Checking for sleep processes")
            } else if !binaryPath.isEmpty {
                // Production mode - use specific binary path for precise detection
                task.arguments = ["-f", binaryPath]
                Logger.shared.info("🔍 Checking for specific binary: \(binaryPath)")
            } else {
                // Fallback - pattern match for process name
                task.arguments = ["-f", processName]
                Logger.shared.info("🔍 Checking for process: \(processName)")
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
            // Process template with secrets
            try TemplateProcessor.processTemplate(
                templatePath: templatePath,
                outputPath: outputPath,
                secrets: secrets
            )
            
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

// Only validate critical startup requirements (don't block startup)
let monitor = AppMonitor()

// Keep the RunLoop alive
Logger.shared.info("📡 Monitoring... Press Ctrl+C to stop")
Logger.shared.info("ℹ️  Note: Notifications might not appear in terminal mode")
RunLoop.current.run()
