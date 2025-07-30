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
            "claude_code_binary_path": "/bin/sleep" // Test: /bin/sleep, Prod: /Users/oem/.local/bin/claude
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
        
        Logger.shared.info("🚀 ClaudeAutoConfig started - monitoring \(Config.targetBundleID)")
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
              app.bundleIdentifier == Config.targetBundleID else {
            return
        }
        
        Logger.shared.info("✅ \(app.localizedName ?? "App") LAUNCHED")
        
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
        switch phase {
        case "launch":
            processTemplate()
        case "quit":
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
                Logger.shared.warning("⚠️  Found orphaned config file with no Claude apps running - cleaning up")
                cleanupOrphanedConfig()
            }
        }
    }
    
    private func checkForNewProcessLaunches(desktopRunning: Bool, codeRunning: Bool) {
        // Get current running process IDs for our target process
        let currentProcesses = getCurrentClaudeCodeProcesses()
        
        // Check for new processes (not in lastSeenProcesses)
        let newProcesses = currentProcesses.subtracting(lastSeenProcesses)
        
        if !newProcesses.isEmpty {
            Logger.shared.info("🔍 New \(Config.claudeCodeProcessName) process detected: \(newProcesses)")
            
            // Check if config file exists
            let outputPath = Preferences.targetClaudeDesktopConfigFile.expandingTildeInPath
            let configExists = FileManager.default.fileExists(atPath: outputPath)
            
            if !configExists {
                // No config exists - create it for the new process
                Logger.shared.info("🚀 No config exists - creating for new \(Config.claudeCodeProcessName) process")
                
                // Refresh UserDefaults to pick up any external changes
                UserDefaults.standard.synchronize()
                
                // Comprehensive UserDefaults debugging
                Logger.shared.info("🔍 UserDefaults debugging:")
                Logger.shared.info("   - Domain: \(Preferences.domain)")
                
                // Check if we should use our custom domain
                let customDefaults = UserDefaults(suiteName: Preferences.domain)
                let systemValue = UserDefaults.standard.bool(forKey: "manage_ClaudeCode_config")
                let systemObject = UserDefaults.standard.object(forKey: "manage_ClaudeCode_config")
                let customValue = customDefaults?.bool(forKey: "manage_ClaudeCode_config") ?? false
                let customObject = customDefaults?.object(forKey: "manage_ClaudeCode_config")
                
                Logger.shared.info("   - System UserDefaults: value=\(systemValue), object exists=\(systemObject != nil)")
                Logger.shared.info("   - Custom domain UserDefaults: value=\(customValue), object exists=\(customObject != nil)")
                
                // Try reading directly from defaults command
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
                task.arguments = ["read", Preferences.domain, "manage_ClaudeCode_config"]
                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = Pipe()
                
                do {
                    try task.run()
                    task.waitUntilExit()
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    Logger.shared.info("   - defaults read output: '\(output ?? "nil")'")
                } catch {
                    Logger.shared.info("   - defaults read failed: \(error)")
                }
                
                // Create config for the new process
                let appType = "ClaudeCode" // Since this is a process launch, treat as Claude Code
                let (managementEnabled, templatePath, outputPath) = getAppSettings(for: appType)
                
                Logger.shared.info("🔍 Final result: managementEnabled = \(managementEnabled)")
                
                if managementEnabled {
                    createConfigForProcess(appType: appType, templatePath: templatePath, outputPath: outputPath)
                } else {
                    Logger.shared.info("ℹ️  Claude Code management disabled - skipping config creation")
                }
            } else {
                Logger.shared.info("ℹ️  Config already exists - no need to create for new process")
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
            
            // Use same logic as isClaudeCodeRunning
            if processName == "sleep" {
                // Testing mode - detect sleep command regardless of path
                task.arguments = [processName]
            } else if !binaryPath.isEmpty {
                // Production mode - use specific binary path for precise detection
                task.arguments = ["-f", binaryPath]
            } else {
                // Fallback - pattern match for process name
                task.arguments = ["-f", processName]
            }
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()
            
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                let pids = output.trimmingCharacters(in: .whitespacesAndNewlines)
                    .components(separatedBy: .newlines)
                    .filter { !$0.isEmpty }
                return Set(pids)
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
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Configuration created for process"]
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
            Logger.shared.success("🗑️  Cleaned up orphaned config: \(outputPath)")
            
            if Preferences.voiceNotifications {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Orphaned config cleaned"]
                try? process.run()
            }
        } catch {
            Logger.shared.error("❌ Failed to clean orphaned config: \(error.localizedDescription)")
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
        // Determine app type and get appropriate settings
        let appType = getAppType()
        let (managementEnabled, templatePath, outputPath) = getAppSettings(for: appType)
        
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
                Logger.shared.info("🔊 Voice notification: Configuration in place")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Configuration in place"]
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
                Logger.shared.info("🔊 Voice notification: Configuration injected")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Configuration injected"]
                try process.run()
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
                Logger.shared.info("🔊 Voice notification: Config preserved for other app")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Config preserved for other app"]
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
                Logger.shared.info("🔊 Voice notification: Configuration cleaned")
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
                process.arguments = ["Configuration cleaned"]
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
let monitor = AppMonitor()

// Keep the RunLoop alive
Logger.shared.info("📡 Monitoring... Press Ctrl+C to stop")
Logger.shared.info("ℹ️  Note: Notifications might not appear in terminal mode")
RunLoop.current.run()
