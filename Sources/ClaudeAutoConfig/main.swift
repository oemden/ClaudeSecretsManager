import Foundation
import AppKit
import UserNotifications

// MARK: - Configuration
struct Config {
    static let targetBundleID = "com.apple.TextEdit" // Testing with TextEdit
    static let claudeConfigDir = "~/Library/Application Support/Claude"
    static let templatePath = "\(claudeConfigDir)/claude_desktop_config_template.json"
    static let outputPath = "\(claudeConfigDir)/claude_desktop_config_test.json" // Test file for safety
    static let secretsPath = "~/dev/Claude Auto Config/secrets/claude_secrets"
}

// MARK: - Preferences
struct Preferences {
    static let domain = "com.oemden.claudeautoconfig"
    
    // File paths
    static var targetClaudeConfigFile: String {
        UserDefaults.standard.string(forKey: "target_claude_config_file") ?? Config.outputPath
    }
    
    static var templateClaudeConfigFile: String {
        UserDefaults.standard.string(forKey: "template_claude_config_file") ?? Config.templatePath
    }
    
    static var firstRunBackupFile: String {
        UserDefaults.standard.string(forKey: "first_run_claude_config_backup_file") ?? 
        "\(Config.claudeConfigDir)/claude_desktop_config.backup.json"
    }
    
    static var secretsFile: String {
        UserDefaults.standard.string(forKey: "secrets_file") ?? Config.secretsPath
    }
    
    // Notification settings
    static var voiceNotifications: Bool {
        // If never set, defaults to true
        if UserDefaults.standard.object(forKey: "voice_notifications") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "voice_notifications")
    }
    
    static var macosNotifications: Bool {
        // If never set, defaults to true
        if UserDefaults.standard.object(forKey: "macos_notifications") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "macos_notifications")
    }
    
    // Secrets mechanism
    static var secretsMechanism: String {
        UserDefaults.standard.string(forKey: "secrets_mechanism") ?? "file"
    }
    
    // LaunchAgent installation
    static var installLaunchdAgent: Bool {
        return UserDefaults.standard.bool(forKey: "install_launchd_agent")
    }
    
    // Helper methods
    static func setDefaults() {
        let defaults = [
            "target_claude_config_file": Config.outputPath,
            "template_claude_config_file": Config.templatePath,
            "first_run_claude_config_backup_file": "\(Config.claudeConfigDir)/claude_desktop_config.backup.json",
            "secrets_file": Config.secretsPath,
            "voice_notifications": true,
            "macos_notifications": true,
            "secrets_mechanism": "file",
            "install_launchd_agent": false
        ] as [String : Any]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    static func printCurrentSettings() {
        print("📋 Current Preferences:")
        print("   Target Config: \(targetClaudeConfigFile)")
        print("   Template: \(templateClaudeConfigFile)")
        print("   Backup: \(firstRunBackupFile)")
        print("   Secrets: \(secretsFile)")
        print("   Voice: \(voiceNotifications)")
        print("   Notifications: \(macosNotifications)")
        print("   Secrets Mechanism: \(secretsMechanism)")
        print("   LaunchAgent: \(installLaunchdAgent)")
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
    
    init() {
        self.notificationCenter = workspace.notificationCenter
        
        // Initialize preferences
        Preferences.setDefaults()
        
        setupNotifications()
        checkIfAlreadyRunning()
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
    
    private func processTemplate() {
        let templatePath = Preferences.templateClaudeConfigFile
        let outputPath = Preferences.targetClaudeConfigFile
        
        Logger.shared.info("🔄 Starting template processing...")
        Logger.shared.info("📄 Template path: \(templatePath.expandingTildeInPath)")
        Logger.shared.info("💾 Output path: \(outputPath.expandingTildeInPath)")
        
        do {
            // Process template with secrets
            try TemplateProcessor.processTemplate(
                templatePath: templatePath,
                outputPath: outputPath,
                secrets: secrets
            )
            
            Logger.shared.success("✅ Template processed successfully - Configuration injected")
            
            // Announce success with voice if enabled
            if Preferences.voiceNotifications {
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
        let outputPath = Preferences.targetClaudeConfigFile
        let expandedOutputPath = outputPath.expandingTildeInPath
        let outputURL = URL(fileURLWithPath: expandedOutputPath)
        
        Logger.shared.info("🧹 Starting configuration cleanup...")
        
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
    }
}

// MARK: - Main
let monitor = AppMonitor()

// Keep the RunLoop alive
Logger.shared.info("📡 Monitoring... Press Ctrl+C to stop")
Logger.shared.info("ℹ️  Note: Notifications might not appear in terminal mode")
RunLoop.current.run()
