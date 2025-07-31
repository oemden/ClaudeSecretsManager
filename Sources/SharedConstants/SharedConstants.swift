// SharedConstants.swift
// Shared constants for Claude Secrets Manager components

import Foundation

/// Shared constants used across daemon and CLI components
public enum SharedConstants {
    
    // MARK: - Version Information
    
    /// Application version (updated automatically by build script)
    public static let version = "0.4.0"
    
    /// Build number (can be used for build identification)
    public static let buildNumber = "1"
    
    /// Full version string
    public static let fullVersion = "\(version).\(buildNumber)"
    
    // MARK: - Application Configuration
    
    /// Target application to monitor (change between "TextEdit.app" and "Claude.app")
    public static let targetApplication = "Claude.app"
    
    /// Target executable name (change between "sleep" and "claude")
    public static let targetExecutable = "claude"
    
    // MARK: - File Paths
    
    /// Claude configuration directory
    public static let claudeConfigDir = "~/Library/Application Support/Claude"
    
    /// Secrets file path
    public static let secretsPath = "~/.claudesecrets/.claude_secrets"
    
    /// Template configuration file path
    public static let templatePath = "\(claudeConfigDir)/claude_desktop_config_template.json"
    
    /// Production output path (real Claude config)
    public static let outputPath = "\(claudeConfigDir)/claude_desktop_config.json"
    
    /// Test output path (for testing with TextEdit)
    public static let testOutputPath = "\(claudeConfigDir)/claude_desktop_config_test.json"
    
    /// Backup configuration path
    public static let backupPath = "\(claudeConfigDir)/claude_desktop_config.firstrun.backup.json"
    
    // MARK: - System Configuration
    
    /// UserDefaults suite name
    public static let suiteName = "com.oemden.claudesecrets"
    
    /// LaunchAgent identifier
    public static let launchAgentIdentifier = "com.oemden.claudesecrets"
    
    /// LaunchAgent plist filename
    public static let launchAgentPlistName = "\(launchAgentIdentifier).plist"
    
    /// Default daemon binary installation path
    public static let defaultBinaryPath = "/usr/local/bin/claudesecrets"
    
    /// Default CLI binary installation path
    public static let defaultCLIBinaryPath = "/usr/local/bin/claudesecrets-cli"
    
    // MARK: - Default Settings
    
    /// Default process monitoring interval (seconds)
    public static let defaultMonitoringInterval: Double = 2.0
    
    /// Default file permissions for secrets file
    public static let secretsFilePermissions: UInt16 = 0o600
    
    /// Default secrets mechanism
    public static let defaultSecretsMechanism = "file"
    
    // MARK: - Keychain Configuration
    
    /// Keychain service identifier for Claude Secrets Manager
    public static let keychainService = "claudesecrets"
    
    /// Keychain accessibility level
    public static let keychainAccessibility = "kSecAttrAccessibleWhenUnlocked"
}