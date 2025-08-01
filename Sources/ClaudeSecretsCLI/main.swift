#!/usr/bin/env swift

import Foundation
import SharedConstants
import KeychainManager
#if canImport(CommonCrypto)
import CommonCrypto
#endif

// MARK: - Shared Components (will be moved to shared module later)

// Copy of Preferences class needed for CLI
struct Preferences {
    private static let suiteName = SharedConstants.suiteName
    private static let customDefaults = UserDefaults(suiteName: suiteName) ?? UserDefaults.standard
    
    static var secretsFile: String {
        customDefaults.string(forKey: "secrets_file") ?? SharedConstants.secretsPath
    }
    
    static var templateClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "template_claudedesktop_config_file") ?? SharedConstants.templatePath
    }
    
    static var targetClaudeDesktopConfigFile: String {
        customDefaults.string(forKey: "target_claudedesktop_config_file") ?? SharedConstants.outputPath
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
    
    static var logLevel: Int {
        return customDefaults.integer(forKey: "log_level") // Defaults to 0 (minimal) if not set
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
    
    /// Validate and auto-create missing files (backup+template, secrets)
    static func validateAndCreateFiles() -> Bool {
        let templatePath = templateClaudeDesktopConfigFile.expandingTildeInPath
        let secretsPath = secretsFile.expandingTildeInPath
        let configPath = "\(SharedConstants.claudeConfigDir)/claude_desktop_config.json"
        
        // Check/create backup and template from existing config
        if !FileManager.default.fileExists(atPath: templatePath) {
            print("🔧 Template file missing, attempting backup+template creation")
            do {
                try TemplateProcessor.backupOriginalAndCreateTemplate(
                    configPath: configPath,
                    templatePath: templateClaudeDesktopConfigFile
                )
            } catch {
                print("❌ Failed to create backup and template: \(error)")
                return false
            }
        }
        
        // Check/create secrets file  
        if !FileManager.default.fileExists(atPath: secretsPath) {
            print("🔧 Secrets file missing, creating default")
            do {
                let secretsDir = (secretsPath as NSString).deletingLastPathComponent
                try FileManager.default.createDirectory(atPath: secretsDir, withIntermediateDirectories: true, attributes: nil)
                
                let defaultContent = """
                    # Claude Auto Config Secrets File
                    # Format: KEY=VALUE or export KEY=VALUE
                    # Add your API keys and other secrets here
                    # Example:
                    # API_KEY_SECRET=your_actual_api_key_here
                    # SECRET_TOKEN_SECRET=your_actual_token_here
                    """
                
                try defaultContent.write(toFile: secretsPath, atomically: true, encoding: .utf8)
                try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: secretsPath)
                print("📄 Created default secrets file at: \(secretsPath)")
            } catch {
                print("❌ Failed to create secrets file: \(error)")
                return false
            }
        }
        
        return true
    }
}

// MARK: - Logging System
enum LogLevel: Int, CaseIterable {
    case minimal = 0    // Only essential results
    case normal = 1     // Default operational info  
    case debug = 2      // Full verbose debugging
    
    var description: String {
        switch self {
        case .minimal: return "minimal"
        case .normal: return "normal" 
        case .debug: return "debug"
        }
    }
}

struct Logger {
    /// Log message if current log level allows it
    static func log(_ message: String, level: LogLevel = .normal) {
        let currentLevel = LogLevel(rawValue: Preferences.logLevel) ?? .minimal
        if level.rawValue <= currentLevel.rawValue {
            print(message)
        }
    }
    
    /// Always log regardless of level (for critical messages)
    static func always(_ message: String) {
        print(message)
    }
    
    /// Log at minimal level (essential results only)
    static func minimal(_ message: String) {
        log(message, level: .minimal)
    }
    
    /// Log at normal level (default operational info)
    static func normal(_ message: String) {
        log(message, level: .normal)
    }
    
    /// Log at debug level (verbose debugging)
    static func debug(_ message: String) {
        log(message, level: .debug)
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

// MARK: - Template Processor (copied from daemon for CLI config generation)
struct TemplateProcessor {
    
    /// Process template file with secrets and write output
    static func processTemplate(
        templatePath: String,
        outputPath: String,
        secrets: [String: String]
    ) throws {
        let templateURL = URL(fileURLWithPath: templatePath.expandingTildeInPath)
        let outputURL = URL(fileURLWithPath: outputPath.expandingTildeInPath)
        
        print("🔍 Checking template at: \(templateURL.path)")
        
        // Read template
        guard FileManager.default.fileExists(atPath: templateURL.path) else {
            throw SecretsError.templateNotFound(templatePath)
        }
        
        var content = try String(contentsOf: templateURL, encoding: .utf8)
        print("📏 Template loaded, size: \(content.count) characters")
        
        // Replace all occurrences of secret keys with their values
        // Sort by key length descending to avoid partial replacements
        var replacementCount = 0
        let sortedSecrets = secrets.sorted { $0.key.count > $1.key.count }
        for (key, value) in sortedSecrets {
            let originalContent = content
            content = content.replacingOccurrences(of: key, with: value)
            if content != originalContent {
                replacementCount += 1
                print("🔄 Replaced \(key) in template")
            }
        }
        print("✅ Made \(replacementCount) replacements")
        
        // Create output directory if needed
        let outputDir = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        
        // Write output
        try content.write(to: outputURL, atomically: true, encoding: .utf8)
        
        // Set restrictive permissions (600)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: outputURL.path
        )
        
        print("✅ Wrote processed config to: \(outputURL.path)")
    }
    
    /// Backup original config and create template if they don't exist
    static func backupOriginalAndCreateTemplate(configPath: String, templatePath: String) throws {
        let configURL = URL(fileURLWithPath: configPath.expandingTildeInPath)
        let templateURL = URL(fileURLWithPath: templatePath.expandingTildeInPath)
        let backupPath = configURL.deletingLastPathComponent()
            .appendingPathComponent("claudeAutoConfig.firstrun.claude_desktop_config.json.backup")
        
        // Case 1: Original config exists - create backup and template from it
        if FileManager.default.fileExists(atPath: configURL.path) &&
           !FileManager.default.fileExists(atPath: backupPath.path) {
            
            try FileManager.default.copyItem(at: configURL, to: backupPath)
            print("💾 Created first-run backup at: \(backupPath.path)")
            
            // Also create template from the same source
            if !FileManager.default.fileExists(atPath: templateURL.path) {
                try FileManager.default.copyItem(at: configURL, to: templateURL)
                print("📄 Created template from config at: \(templateURL.path)")
            }
        }
        // Case 2: No original config exists - create default template
        else if !FileManager.default.fileExists(atPath: templateURL.path) {
            print("📄 No existing config found, creating default template at: \(templateURL.path)")
            
            let defaultTemplate = """
{
  "mcpServers": {
    "example-server": {
      "command": "echo",
      "args": ["Hello from MCP server!"],
      "env": {
        "API_KEY": "API_KEY_SECRET",
        "SECRET_TOKEN": "SECRET_TOKEN_SECRET"
      }
    }
  }
}
"""
            
            // Create directory if needed
            let templateDir = templateURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: templateDir, withIntermediateDirectories: true, attributes: nil)
            
            // Write default template
            try defaultTemplate.write(to: templateURL, atomically: true, encoding: .utf8)
            print("📄 Created default template at: \(templateURL.path)")
        }
    }
}

enum SecretsError: LocalizedError {
    case fileNotFound(String)
    case parseError(String)
    case templateNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Secrets file not found: \(path)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .templateNotFound(let path):
            return "Template file not found: \(path)"
        }
    }
}

extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}

// MARK: - Encryption Manager for Secure Export/Import
struct EncryptionManager {
    
    static let saltLength = 32
    static let ivLength = 16
    static let migrationKeyAccount = "claudesecrets_migration_key"
    
    /// Encrypt secrets dictionary to data with random key and IV
    /// File format: [iv:16][encrypted_data]
    static func encrypt(secrets: [String: String]) throws -> Data {
        // Convert secrets to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: secrets, options: [])
        
        // Generate random encryption key and store in keychain
        let key = try generateAndStoreMigrationKey()
        
        // Generate random IV
        let iv = generateRandomBytes(count: ivLength)
        
        #if canImport(CommonCrypto)
        // Encrypt using AES-256-CBC (more widely supported than GCM)
        let bufferSize = jsonData.count + kCCBlockSizeAES128
        var encryptedData = Data(count: bufferSize)
        var encryptedLength = 0
        
        let status = encryptedData.withUnsafeMutableBytes { encryptedPtr in
            jsonData.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, jsonData.count,
                            encryptedPtr.baseAddress, bufferSize,
                            &encryptedLength
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw EncryptionError.encryptionFailed
        }
        
        // Combine: iv + encrypted_data (no salt needed, key stored in keychain)
        var result = Data()
        result.append(iv)
        result.append(encryptedData.prefix(encryptedLength))
        
        return result
        #else
        throw EncryptionError.encryptionNotSupported
        #endif
    }
    
    /// Decrypt data back to secrets dictionary
    static func decrypt(data: Data) throws -> [String: String] {
        guard data.count >= ivLength else {
            throw EncryptionError.invalidDataFormat
        }
        
        // Extract components
        let iv = data.subdata(in: 0..<ivLength)
        let encryptedData = data.subdata(in: ivLength..<data.count)
        
        // Retrieve key from keychain and delete it
        let key = try retrieveAndDeleteMigrationKey()
        
        #if canImport(CommonCrypto)
        // Decrypt using AES-256-CBC
        let bufferSize = encryptedData.count
        var decryptedData = Data(count: bufferSize)
        var decryptedLength = 0
        
        let status = decryptedData.withUnsafeMutableBytes { decryptedPtr in
            encryptedData.withUnsafeBytes { encryptedPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            encryptedPtr.baseAddress, encryptedData.count,
                            decryptedPtr.baseAddress, bufferSize,
                            &decryptedLength
                        )
                    }
                }
            }
        }
        
        guard status == kCCSuccess else {
            throw EncryptionError.decryptionFailed
        }
        
        // Parse JSON back to dictionary
        let jsonData = decryptedData.prefix(decryptedLength)
        let secrets = try JSONSerialization.jsonObject(with: jsonData, options: [])
        
        guard let secretsDict = secrets as? [String: String] else {
            throw EncryptionError.invalidDataFormat
        }
        
        return secretsDict
        #else
        throw EncryptionError.encryptionNotSupported
        #endif
    }
    
    /// Generate cryptographically secure random bytes
    private static func generateRandomBytes(count: Int) -> Data {
        var bytes = Data(count: count)
        let status = bytes.withUnsafeMutableBytes { ptr in
            SecRandomCopyBytes(kSecRandomDefault, count, ptr.baseAddress!)
        }
        
        if status != errSecSuccess {
            // Fallback to less secure random generation
            for i in 0..<count {
                bytes[i] = UInt8.random(in: 0...255)
            }
        }
        
        return bytes
    }
    
    /// Generate random encryption key using openssl and store in keychain
    private static func generateAndStoreMigrationKey() throws -> Data {
        // Use openssl to generate cryptographically secure random key
        let process = Process()
        let pipe = Pipe()
        process.standardOutput = pipe
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = ["rand", "-hex", "32"] // 32 bytes = 256 bits for AES-256
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw EncryptionError.keyGenerationFailed
        }
        
        let keyData = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let keyHex = String(data: keyData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              keyHex.count == 64 else { // 32 bytes = 64 hex characters
            throw EncryptionError.keyGenerationFailed
        }
        
        // Store hex key in keychain using separate service for migration keys
        try storeMigrationKeyInKeychain(account: migrationKeyAccount, value: keyHex)
        
        // Convert hex string to Data for encryption
        guard let keyData = Data(hexString: keyHex) else {
            throw EncryptionError.keyGenerationFailed
        }
        
        return keyData
    }
    
    /// Retrieve migration key from keychain and delete it immediately
    private static func retrieveAndDeleteMigrationKey() throws -> Data {
        // Retrieve hex key from keychain using separate service
        let keyHex = try retrieveMigrationKeyFromKeychain(account: migrationKeyAccount)
        
        // Delete the key immediately (cleanup)
        try deleteMigrationKeyFromKeychain(account: migrationKeyAccount)
        
        // Convert hex string back to Data
        guard let keyData = Data(hexString: keyHex) else {
            throw EncryptionError.invalidDataFormat
        }
        
        return keyData
    }
    
    /// Store migration key in keychain using separate service identifier
    private static func storeMigrationKeyInKeychain(account: String, value: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "claudesecretsupgradekey", // Separate service
            kSecAttrAccount as String: account,
            kSecValueData as String: value.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecAttrComment as String: "Migration key for package upgrade - auto-deleted after import"
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieve migration key from keychain using separate service identifier
    private static func retrieveMigrationKeyFromKeychain(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "claudesecretsupgradekey", // Separate service
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
        
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unableToConvertToString
        }
        
        return string
    }
    
    /// Delete migration key from keychain using separate service identifier
    private static func deleteMigrationKeyFromKeychain(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "claudesecretsupgradekey", // Separate service
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
}

enum EncryptionError: LocalizedError {
    case encryptionFailed
    case decryptionFailed
    case keyGenerationFailed
    case encryptionNotSupported
    case invalidDataFormat
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt data"
        case .decryptionFailed:
            return "Failed to decrypt data"
        case .keyGenerationFailed:
            return "Failed to generate encryption key"
        case .encryptionNotSupported:
            return "Encryption not supported on this platform"
        case .invalidDataFormat:
            return "Invalid encrypted data format"
        }
    }
}

// MARK: - Data Hex Extension
extension Data {
    /// Initialize Data from hex string
    init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count % 2 == 0 else { return nil }
        
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            let byteString = hex[index..<nextIndex]
            
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            
            index = nextIndex
        }
        
        self = data
    }
}

// MARK: - CLI Command Processing
struct CLICommands {
    static func showHelp() {
        print("""
        claudesecrets-cli - Claude Desktop & Claude Code Configuration Manager
        
        USAGE:
            claudesecrets-cli [OPTIONS]
            claudesecrets-cli [COMMAND] [ARGUMENTS]
        
        OPTIONS:
            -h, --help                     Show this help message
            -v, --version                  Show version information
            -s, --status                   Show current daemon and configuration status
            -c, --config                   Show current configuration settings
            -l, --list-secrets [file|keychain] List all stored secrets
            -V, --voice [on|off]          Enable/disable voice notifications
            -n, --notifications [on|off]  Enable/disable macOS notifications
            -L, --log-level [level]       Set logging verbosity: minimal|normal|debug
            --daemon-console [on|off]     Enable/disable daemon console output
            -j COMMENT                     Specify comment string for keychain entries
        
        COMMANDS:
            -a, --add VAR=VALUE           Add secret(s) to configuration
                                         Multiple: VAR1=VALUE1,VAR2=VALUE2
                                         Or: VAR1=VALUE1 VAR2=VALUE2
            -d, --delete VAR              Delete secret(s) from configuration
                                         Multiple: VAR1,VAR2 or VAR1 VAR2
            -m, --mechanism [file|keychain] Set storage mechanism for secrets
                                         (use with --add/--delete)
            -g, --generate-config TEMPLATE OUTPUT
                                         Generate config from template and secrets
            -t, --template                Create template from current Claude config
            -r, --reset                   Reset to default claudesecrets settings
            -I, --install                 Install LaunchAgent plist (doesn't start)
            -U, --uninstall               Remove LaunchAgent plist (stops if running)
            -E, --enable                  Enable and start LaunchAgent daemon
            -D, --disable                 Disable and stop LaunchAgent daemon
            -R, --restore                 Restore original Claude config and disable daemon
            -u, --upgrade                 Transfer keychain ownership to current binary
                                         (use after installing new build/package)
            --migrate [file-to-keychain] [--emptysecretfile] | --file <path>
                                         Migrate secrets between storage mechanisms
                                         file-to-keychain: Migrate from default secrets file to keychain
                                         --emptysecretfile: Empty source file after migration
                                         --file <path>: Bulk import secrets from specified file to keychain
            --noclaudesecrets            Emergency disable: stop daemon, restore config
            --wipesecrets                Delete ALL secrets from both file and keychain
        
        EXAMPLES:
            claudeautoconfig --add API_KEY=abc123 -m file
            claudeautoconfig -a VAR1=val1,VAR2=val2 -m keychain
            claudeautoconfig -a API_KEY=secret123 -m keychain -j "Production API key"
            claudeautoconfig --delete API_KEY -m file
            claudeautoconfig --voice on
            claudeautoconfig --install
            claudeautoconfig --enable
            claudeautoconfig --status
            claudeautoconfig --disable
            claudeautoconfig --upgrade
            claudeautoconfig --migrate file-to-keychain
            claudeautoconfig --migrate file-to-keychain --emptysecretfile
            claudeautoconfig --migrate --file /path/to/secrets.env
            claudeautoconfig --log-level minimal
            claudeautoconfig --daemon-console off
            claudeautoconfig --noclaudesecrets
            claudeautoconfig --wipesecrets
        
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
    
    static func showVersion() {
        print("claudesecrets-cli version \(SharedConstants.fullVersion)")
        print("Claude Secrets Manager - Build \(SharedConstants.buildNumber)")
    }
    
    static func parseArguments(_ args: [String]) -> Bool {
        guard !args.isEmpty else {
            showHelp()
            return true
        }
        
        var i = 0
        var mechanism: String = Preferences.secretsMechanism
        var customComment: String? = nil
        
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "-h", "--help":
                showHelp()
                return true
                
            case "-v", "--version":
                showVersion()
                return true
                
            case "-s", "--status":
                showStatus()
                return true
                
            case "-c", "--config":
                showConfig()
                return true
                
            case "-l", "--list-secrets":
                if i + 1 < args.count {
                    let mechanism = args[i + 1]
                    if mechanism == "file" || mechanism == "keychain" {
                        listSecrets(mechanism: mechanism)
                        i += 1
                    } else {
                        print("❌ --list-secrets requires: file|keychain")
                        return true
                    }
                } else {
                    // Default to current mechanism
                    listSecrets(mechanism: Preferences.secretsMechanism)
                }
                return true
                
            case "-V", "--voice":
                if i + 1 < args.count {
                    let value = args[i + 1]
                    setVoiceNotifications(enabled: value == "on" || value == "true")
                    i += 1
                } else {
                    print("❌ --voice requires a value: on|off")
                    return true
                }
                
            case "-L", "--log-level":
                if i + 1 < args.count {
                    let value = args[i + 1]
                    setLogLevel(value: value)
                    i += 1
                } else {
                    print("❌ --log-level requires a value: minimal|normal|debug")
                    return true
                }
                
            case "--daemon-console":
                if i + 1 < args.count {
                    let value = args[i + 1]
                    setDaemonConsole(value: value)
                    i += 1
                } else {
                    print("❌ --daemon-console requires a value: on|off")
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
                
            case "-j":
                if i + 1 < args.count {
                    customComment = args[i + 1]
                    i += 1
                } else {
                    print("❌ -j requires a comment string")
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
                    
                    addSecrets(allSecrets, mechanism: mechanism, comment: customComment)
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
                print("❌ --daemon mode should be handled by claudesecrets, not claudesecrets-cli")
                return false
                
            case "-R", "--restore":
                restoreOriginalConfig()
                return true
                
            case "--migrate":
                if i + 1 < args.count {
                    let migrationType = args[i + 1]
                    if migrationType == "file-to-keychain" {
                        // Check for --emptysecretfile flag
                        let emptysecretfile = (i + 2 < args.count && args[i + 2] == "--emptysecretfile")
                        migrateSecretsFileToKeychain(emptysecretfile: emptysecretfile)
                        i += emptysecretfile ? 2 : 1
                    } else if migrationType == "--file" {
                        // Bulk import from specific file
                        if i + 2 < args.count {
                            let filePath = args[i + 2]
                            bulkImportFromFile(filePath: filePath)
                            i += 2
                        } else {
                            print("❌ --migrate --file requires a file path")
                            return true
                        }
                    } else {
                        print("❌ --migrate requires: file-to-keychain [--emptysecretfile] | --file <path>")
                        return true
                    }
                } else {
                    print("❌ --migrate requires migration type: file-to-keychain [--emptysecretfile] | --file <path>")
                    return true
                }
                return true
                
            case "--noclaudesecrets":
                emergencyDisableClaudeSecrets()
                return true
                
            case "--wipesecrets":
                wipeAllSecrets()
                return true
                
            case "-u", "--upgrade":
                // Check for --export or --import flags
                if i + 1 < args.count {
                    let nextArg = args[i + 1]
                    if nextArg == "--export" {
                        exportSecretsForUpgrade()
                        i += 1
                        return true
                    } else if nextArg == "--import" {
                        importSecretsFromUpgrade()
                        i += 1
                        return true
                    }
                }
                
                // Block standalone --upgrade calls to encourage proper migration workflow
                print("❌ --upgrade requires either --export or --import flag")
                print("")
                print("💡 For package installation migration:")
                print("   --upgrade --export   # Export secrets before installation")
                print("   --upgrade --import   # Import secrets after installation")
                print("")
                print("💡 For manual keychain ownership transfer:")
                print("   Use claudesecrets-cli directly without --upgrade")
                print("   or use: --migrate file-to-keychain")
                print("")
                print("🔧 For emergency manual upgrade (may prompt for keychain access):")
                print("   CLAUDE_FORCE_UPGRADE=1 claudesecrets-cli --upgrade")
                
                // Allow override with environment variable for emergency manual upgrade
                if ProcessInfo.processInfo.environment["CLAUDE_FORCE_UPGRADE"] == "1" {
                    print("")
                    print("⚠️  Forcing manual upgrade due to CLAUDE_FORCE_UPGRADE=1")
                    upgradeKeychainOwnership()
                } else {
                    exit(1)
                }
                
                return true
                
            case "--check-upgrade-needed":
                // Check if keychain entries need upgrade, exit with appropriate code
                // Exit 0: no upgrade needed, Exit 1: upgrade needed, Exit >1: error
                checkUpgradeNeeded()
                return true
                
            case "-g", "--generate-config":
                if i + 2 < args.count {
                    let templatePath = args[i + 1]
                    let outputPath = args[i + 2]
                    generateConfig(templatePath: templatePath, outputPath: outputPath)
                    i += 2
                } else {
                    print("❌ --generate-config requires templatePath and outputPath")
                    return true
                }
                return true
                
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
        let defaults = UserDefaults(suiteName: SharedConstants.suiteName) ?? UserDefaults.standard
        defaults.set(enabled, forKey: "voice_notifications")
        print("🔊 Voice notifications: \(enabled ? "ENABLED" : "DISABLED")")
    }
    
    static func setMacOSNotifications(enabled: Bool) {
        let defaults = UserDefaults(suiteName: SharedConstants.suiteName) ?? UserDefaults.standard
        defaults.set(enabled, forKey: "macos_notifications")
        print("📱 macOS notifications: \(enabled ? "ENABLED" : "DISABLED")")
    }
    
    static func setDaemonConsole(value: String) {
        let defaults = UserDefaults(suiteName: SharedConstants.suiteName) ?? UserDefaults.standard
        
        let enabled: Bool
        switch value.lowercased() {
        case "on", "true", "yes", "1":
            enabled = true
        case "off", "false", "no", "0":
            enabled = false
        default:
            print("❌ Invalid daemon console setting: \(value)")
            print("   Valid options: on, off")
            return
        }
        
        defaults.set(enabled, forKey: "daemon_console")
        print("📺 Daemon console output: \(enabled ? "ENABLED" : "DISABLED")")
        print("   \(enabled ? "Daemon will show logs in console" : "Daemon will be silent (logs to file only)")")
    }
    
    static func setLogLevel(value: String) {
        let defaults = UserDefaults(suiteName: SharedConstants.suiteName) ?? UserDefaults.standard
        
        let logLevel: Int
        switch value.lowercased() {
        case "minimal", "min", "0":
            logLevel = 0
        case "normal", "norm", "1":
            logLevel = 1
        case "debug", "verbose", "2":
            logLevel = 2
        default:
            print("❌ Invalid log level: \(value)")
            print("   Valid options: minimal, normal, debug")
            return
        }
        
        defaults.set(logLevel, forKey: "log_level")
        let levelName = LogLevel(rawValue: logLevel)?.description ?? "unknown"
        print("📊 Log level set to: \(levelName.uppercased())")
        
        // Show what each level includes
        switch logLevel {
        case 0:
            print("   Shows: Essential results only")
        case 1:
            print("   Shows: Operational info + progress")
        case 2:
            print("   Shows: Full debugging + internal details")
        default:
            break
        }
    }
    
    static func addSecrets(_ secrets: [String: String], mechanism: String, comment: String? = nil) {
        print("🔐 Processing \(secrets.count) secret(s) using \(mechanism) mechanism...")
        
        if mechanism == "file" {
            addSecretsToFile(secrets)
        } else {
            addSecretsToKeychain(secrets, comment: comment)
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
    
    static func addSecretsToKeychain(_ secrets: [String: String], comment: String? = nil) {
        var addedCount = 0
        var modifiedCount = 0
        
        for (key, value) in secrets {
            do {
                if KeychainManager.exists(account: key) {
                    try KeychainManager.store(account: key, value: value, comment: comment)
                    print("  ✅ Modified: \(key)")
                    modifiedCount += 1
                } else {
                    try KeychainManager.store(account: key, value: value, comment: comment)
                    print("  ✅ Added: \(key)")
                    addedCount += 1
                }
            } catch {
                print("  ❌ Failed to store \(key): \(error.localizedDescription)")
                continue
            }
        }
        
        // Show appropriate success message
        if addedCount > 0 && modifiedCount > 0 {
            print("✅ Successfully added \(addedCount) and modified \(modifiedCount) secret(s) in keychain")
        } else if addedCount > 0 {
            print("✅ Successfully added \(addedCount) secret(s) to keychain")
        } else if modifiedCount > 0 {
            print("✅ Successfully modified \(modifiedCount) secret(s) in keychain")
        }
    }
    
    static func deleteSecretsFromKeychain(_ variables: [String]) {
        var deletedCount = 0
        var notFoundCount = 0
        
        for variable in variables {
            do {
                try KeychainManager.delete(account: variable)
                print("  ✅ Deleted: \(variable)")
                deletedCount += 1
            } catch KeychainError.itemNotFound {
                print("  ⚠️  Not found: \(variable)")
                notFoundCount += 1
            } catch {
                print("  ❌ Failed to delete \(variable): \(error.localizedDescription)")
                continue
            }
        }
        
        if deletedCount > 0 {
            print("✅ Successfully deleted \(deletedCount) variable(s) from keychain")
        }
        if notFoundCount > 0 {
            print("ℹ️  \(notFoundCount) variable(s) were not found in keychain")
        }
    }
    
    static func createTemplateFromCurrentConfig() {
        print("📄 Creating template from current Claude Desktop config...")
        
        let configPath = SharedConstants.outputPath.expandingTildeInPath
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
        print("🔄 Resetting Claude Secrets Manager to defaults...")
        
        let defaults = UserDefaults(suiteName: SharedConstants.suiteName) ?? UserDefaults.standard
        defaults.removePersistentDomain(forName: SharedConstants.suiteName)
        
        print("✅ Configuration reset to defaults")
        print("   Note: You may need to run setup again")
    }
    
    static func showStatus() {
        print("📊 Claude Secrets Manager Status")
        print(String(repeating: "=", count: 40))
        
        // Check if daemon is running
        let daemonRunning = isDaemonRunning()
        print("🔄 Daemon Status: \(daemonRunning ? "RUNNING" : "STOPPED")")
        
        // Check LaunchAgent status
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
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
        print("⚙️  Claude Secrets Manager Configuration")
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
    
    static func listSecrets(mechanism: String) {
        print("🔍 Listing secrets from \(mechanism)")
        print(String(repeating: "=", count: 40))
        
        if mechanism == "file" {
            do {
                let secrets = try SecretsParser.parseSecretsFile(at: Preferences.secretsFile)
                if secrets.isEmpty {
                    print("📄 No secrets found in file")
                } else {
                    print("📄 Found \(secrets.count) secret(s) in file:")
                    for (key, _) in secrets.sorted(by: { $0.key < $1.key }) {
                        print("   • \(key): ****")
                    }
                }
            } catch {
                print("❌ Failed to read secrets file: \(error.localizedDescription)")
            }
        } else {
            do {
                let secrets = try KeychainManager.listAll()
                if secrets.isEmpty {
                    print("🔑 No secrets found in keychain")
                } else {
                    print("🔑 Found \(secrets.count) secret(s) in keychain:")
                    for key in secrets.keys.sorted() {
                        print("   • \(key): ****")
                    }
                }
            } catch {
                print("❌ Failed to read secrets from keychain: \(error.localizedDescription)")
            }
        }
    }
    
    static func isDaemonRunning() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "claudesecrets"]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
    
    static func installLaunchAgent() {
        print("📦 Installing Claude Secrets Manager LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
        let binaryPath = SharedConstants.defaultBinaryPath
        
        // Check if binary exists
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            print("❌ claudesecrets binary not found at: \(binaryPath)")
            print("   Please install the binary first or check the installation path")
            return
        }
        
        let plistContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(SharedConstants.launchAgentIdentifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(binaryPath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>
            <key>StandardOutPath</key>
            <string>\(NSHomeDirectory())/Library/Logs/claudesecrets/claudesecrets.log</string>
            <key>StandardErrorPath</key>
            <string>\(NSHomeDirectory())/Library/Logs/claudesecrets/claudesecrets.error.log</string>
        </dict>
        </plist>
        """
        
        do {
            // Create LaunchAgents directory if needed
            let launchAgentsDir = "\(NSHomeDirectory())/Library/LaunchAgents"
            try FileManager.default.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true, attributes: nil)
            
            // Write plist file
            try plistContent.write(toFile: launchAgentPath, atomically: true, encoding: String.Encoding.utf8)
            
            print("✅ LaunchAgent plist installed: \(launchAgentPath)")
            print("📋 Use --enable to start the daemon")
            
        } catch {
            print("❌ Failed to install LaunchAgent: \(error.localizedDescription)")
        }
    }
    
    static func uninstallLaunchAgent() {
        print("🗑️  Uninstalling Claude Secrets Manager LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
        
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
        print("🚀 Enabling Claude Secrets Manager LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
        
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
        print("🛑 Disabling Claude Secrets Manager LaunchAgent...")
        
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
        
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
        
        let configPath = SharedConstants.outputPath.expandingTildeInPath
        let backupPath = SharedConstants.backupPath.expandingTildeInPath
        
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
    
    static func migrateSecretsFileToKeychain(emptysecretfile: Bool = false) {
        print("🔄 Migrating secrets from file to keychain")
        print(String(repeating: "=", count: 50))
        
        do {
            // Read secrets from file
            let fileSecrets = try SecretsParser.parseSecretsFile(at: Preferences.secretsFile)
            
            if fileSecrets.isEmpty {
                print("ℹ️  No secrets found in file to migrate")
                return
            }
            
            print("📄 Found \(fileSecrets.count) secret(s) in file:")
            for key in fileSecrets.keys.sorted() {
                print("   • \(key)")
            }
            
            print("\n🔑 Migrating to keychain...")
            
            var successCount = 0
            var failCount = 0
            
            for (key, value) in fileSecrets {
                do {
                    try KeychainManager.store(account: key, value: value)
                    print("  ✅ Migrated: \(key)")
                    successCount += 1
                } catch {
                    print("  ❌ Failed to migrate \(key): \(error.localizedDescription)")
                    failCount += 1
                }
            }
            
            print("\n📊 Migration Results:")
            print("   ✅ Successfully migrated: \(successCount)")
            if failCount > 0 {
                print("   ❌ Failed to migrate: \(failCount)")
            }
            
            if successCount > 0 {
                print("\n🔧 Next Steps:")
                print("   1. Set mechanism to keychain:")
                print("      defaults write com.oemden.claudesecrets secrets_mechanism \"keychain\"")
                print("   2. Test keychain access:")
                print("      claudesecrets-cli --list-secrets keychain")
                print("   3. Verify daemon works with keychain:")
                print("      claudesecrets-cli --status")
                
                if successCount == fileSecrets.count {
                    print("\n💡 Migration complete!")
                    
                    if emptysecretfile {
                        // Empty the secrets file
                        print("🗂️  Emptying secrets file as requested...")
                        do {
                            let secretsFilePath = Preferences.secretsFile.expandingTildeInPath
                            
                            // Create backup first
                            let backupPath = secretsFilePath + ".migrated.backup.\(Int(Date().timeIntervalSince1970))"
                            try FileManager.default.copyItem(atPath: secretsFilePath, toPath: backupPath)
                            print("   📋 Backup created: \(backupPath)")
                            
                            // Write empty file (keep the file but remove contents)
                            try "# Claude Secrets File\n# This file was emptied after migration to keychain\n# Original contents backed up to: \(URL(fileURLWithPath: backupPath).lastPathComponent)\n".write(toFile: secretsFilePath, atomically: true, encoding: .utf8)
                            
                            print("   ✅ Secrets file emptied (backup preserved)")
                        } catch {
                            print("   ❌ Failed to empty secrets file: \(error.localizedDescription)")
                            print("   💡 You can manually empty it after verifying keychain migration")
                        }
                    } else {
                        print("   💡 Consider backing up your secrets file before deletion:")
                        print("   cp \(Preferences.secretsFile.expandingTildeInPath) \(Preferences.secretsFile.expandingTildeInPath).backup")
                        print("   💡 Or use --emptysecretfile flag next time to auto-empty the file")
                    }
                }
            }
            
        } catch {
            print("❌ Failed to read secrets file: \(error.localizedDescription)")
            print("   Make sure the file exists: \(Preferences.secretsFile)")
        }
    }
    
    /// Bulk import secrets from specified file to keychain
    static func bulkImportFromFile(filePath: String) {
        Logger.minimal("📦 Bulk Import: Loading secrets from file")
        Logger.normal(String(repeating: "=", count: 50))
        Logger.normal("📁 Source file: \(filePath)")
        
        do {
            // Validate file exists
            let expandedPath = filePath.expandingTildeInPath
            guard FileManager.default.fileExists(atPath: expandedPath) else {
                Logger.always("❌ File not found: \(expandedPath)")
                exit(1)
            }
            
            // Parse secrets from the specified file
            let secrets = try SecretsParser.parseSecretsFile(at: filePath)
            
            if secrets.isEmpty {
                Logger.always("ℹ️  No valid secrets found in file")
                Logger.normal("   Expected format: KEY=VALUE or export KEY=VALUE")
                return
            }
            
            Logger.normal("🔍 Found \(secrets.count) secret(s) in file:")
            for key in secrets.keys.sorted() {
                Logger.normal("   • \(key)")
            }
            
            Logger.minimal("🔑 Importing to keychain...")
            
            var successCount = 0
            var failCount = 0
            var updatedCount = 0
            
            for (key, value) in secrets {
                do {
                    if KeychainManager.exists(account: key) {
                        try KeychainManager.store(account: key, value: value)
                        Logger.normal("  🔄 Updated: \(key)")
                        updatedCount += 1
                    } else {
                        try KeychainManager.store(account: key, value: value)
                        Logger.normal("  ✅ Added: \(key)")
                        successCount += 1
                    }
                } catch {
                    Logger.always("  ❌ Failed to import \(key): \(error.localizedDescription)")
                    failCount += 1
                }
            }
            
            // Summary
            Logger.minimal("📊 Bulk Import Results:")
            if successCount > 0 {
                Logger.minimal("   ✅ New secrets added: \(successCount)")
            }
            if updatedCount > 0 {
                Logger.minimal("   🔄 Existing secrets updated: \(updatedCount)")
            }
            if failCount > 0 {
                Logger.minimal("   ❌ Failed imports: \(failCount)")
            }
            
            let totalSuccess = successCount + updatedCount
            if totalSuccess == secrets.count {
                Logger.minimal("🎉 All secrets successfully imported to keychain!")
                Logger.normal("   You can now use keychain storage mechanism")
                Logger.normal("   Run: defaults write com.oemden.claudesecrets secrets_mechanism \"keychain\"")
            } else if totalSuccess > 0 {
                Logger.minimal("⚠️  Partial import completed (\(totalSuccess)/\(secrets.count))")
                Logger.normal("   Some secrets may need manual attention")
            } else {
                Logger.always("❌ Bulk import failed for all secrets")
                Logger.normal("   Check file format and keychain access permissions")
                exit(1)
            }
            
        } catch {
            Logger.always("❌ Failed to process secrets file: \(error.localizedDescription)")
            Logger.normal("💡 Expected file format:")
            Logger.normal("   KEY1=value1")
            Logger.normal("   export KEY2=value2")
            Logger.normal("   # Comments are supported")
            Logger.normal("   KEY3=complex_value_with_special_chars")
            exit(1)
        }
    }
    
    /// Emergency disable function - stops daemon, disables LaunchAgent, restores config
    static func emergencyDisableClaudeSecrets() {
        print("🚨 Emergency Recovery: Disabling Claude Secrets Manager")
        print(String(repeating: "=", count: 60))
        
        var actionsPerformed: [String] = []
        var warnings: [String] = []
        
        // 1. Stop the daemon
        print("🛑 Stopping daemon...")
        let launchAgentPath = "\(NSHomeDirectory())/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)"
        
        let stopProcess = Process()
        stopProcess.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        stopProcess.arguments = ["unload", launchAgentPath]
        
        do {
            try stopProcess.run()
            stopProcess.waitUntilExit()
            
            if stopProcess.terminationStatus == 0 {
                print("  ✅ Daemon stopped")
                actionsPerformed.append("Daemon stopped")
            } else {
                print("  ⚠️  Could not stop daemon (may not be running)")
                warnings.append("Daemon stop failed or wasn't running")
            }
        } catch {
            print("  ❌ Failed to stop daemon: \(error.localizedDescription)")
            warnings.append("Daemon stop failed: \(error.localizedDescription)")
        }
        
        // 2. Disable LaunchAgent plist
        print("📝 Disabling LaunchAgent...")
        let plistPath = "~/Library/LaunchAgents/\(SharedConstants.launchAgentPlistName)".expandingTildeInPath
        
        if FileManager.default.fileExists(atPath: plistPath) {
            do {
                // Read current plist
                let plistData = try Data(contentsOf: URL(fileURLWithPath: plistPath))
                if var plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                    // Add Disabled key
                    plist["Disabled"] = true
                    
                    // Write back
                    let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                    try updatedData.write(to: URL(fileURLWithPath: plistPath))
                    
                    print("  ✅ LaunchAgent disabled")
                    actionsPerformed.append("LaunchAgent disabled")
                } else {
                    throw NSError(domain: "InvalidPlist", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid plist format"])
                }
            } catch {
                print("  ❌ Failed to disable LaunchAgent: \(error.localizedDescription)")
                warnings.append("LaunchAgent disable failed")
            }
        } else {
            print("  ℹ️  LaunchAgent plist not found")
            warnings.append("LaunchAgent plist not found")
        }
        
        // 3. Restore original config
        print("📂 Restoring original configuration...")
        let configPath = SharedConstants.outputPath.expandingTildeInPath
        
        // Try multiple backup file names (order of preference)
        let possibleBackupPaths = [
            SharedConstants.backupPath.expandingTildeInPath,  // firstrun.backup.json
            "\(SharedConstants.claudeConfigDir.expandingTildeInPath)/claude_desktop_config.backup.json", // backup.json
            "\(SharedConstants.claudeConfigDir.expandingTildeInPath)/claude_desktop_config.original.json" // original.json
        ]
        
        var backupRestored = false
        for backupPath in possibleBackupPaths {
            if FileManager.default.fileExists(atPath: backupPath) {
                do {
                    if FileManager.default.fileExists(atPath: configPath) {
                        try FileManager.default.removeItem(atPath: configPath)
                    }
                    try FileManager.default.copyItem(atPath: backupPath, toPath: configPath)
                    print("  ✅ Original configuration restored from: \(URL(fileURLWithPath: backupPath).lastPathComponent)")
                    actionsPerformed.append("Configuration restored from backup")
                    backupRestored = true
                    break
                } catch {
                    print("  ❌ Failed to restore from \(URL(fileURLWithPath: backupPath).lastPathComponent): \(error.localizedDescription)")
                    continue
                }
            }
        }
        
        if !backupRestored {
            print("  ⚠️  No backup found to restore")
            print("     Searched for:")
            for backupPath in possibleBackupPaths {
                print("     • \(backupPath)")
            }
            warnings.append("No backup file found")
        }
        
        // 4. Ask about secrets
        print("\n🤔 What to do with stored secrets?")
        print("   Your secrets are still stored and can be accessed by:")
        if Preferences.secretsMechanism == "keychain" {
            print("   • claudesecrets-cli --list-secrets keychain")
        } else {
            print("   • claudesecrets-cli --list-secrets file")
        }
        print("\n   To completely remove all secrets, run:")
        print("   • claudesecrets-cli --wipesecrets")
        
        // Summary
        print("\n📊 Recovery Summary:")
        if !actionsPerformed.isEmpty {
            print("✅ Actions completed:")
            for action in actionsPerformed {
                print("   • \(action)")
            }
        }
        
        if !warnings.isEmpty {
            print("⚠️  Warnings:")
            for warning in warnings {
                print("   • \(warning)")
            }
        }
        
        print("\n✨ Claude Secrets Manager has been disabled")
        print("   Claude Desktop will now use its original configuration")
        print("   To re-enable later, run: claudesecrets-cli --enable")
    }
    
    /// Wipe all secrets from both file and keychain storage
    static func wipeAllSecrets() {
        print("🗑️  Secret Cleanup: Removing all stored secrets")
        print(String(repeating: "=", count: 50))
        
        print("⚠️  WARNING: This will permanently delete ALL secrets!")
        print("   This affects both file and keychain storage")
        print("   This action cannot be undone\n")
        
        print("Type 'DELETE' to confirm secret deletion: ", terminator: "")
        guard let confirmation = readLine(), confirmation == "DELETE" else {
            print("❌ Deletion cancelled")
            return
        }
        
        var deletedCount = 0
        var errors: [String] = []
        
        // 1. Clean keychain secrets
        print("\n🔑 Cleaning keychain secrets...")
        do {
            let keychainSecrets = try KeychainManager.listAll()
            if !keychainSecrets.isEmpty {
                for account in keychainSecrets.keys {
                    do {
                        try KeychainManager.delete(account: account)
                        print("  ✅ Deleted keychain: \(account)")
                        deletedCount += 1
                    } catch {
                        print("  ❌ Failed to delete keychain \(account): \(error.localizedDescription)")
                        errors.append("Keychain \(account): \(error.localizedDescription)")
                    }
                }
            } else {
                print("  ℹ️  No keychain secrets found")
            }
        } catch {
            print("  ❌ Failed to list keychain secrets: \(error.localizedDescription)")
            errors.append("Keychain listing: \(error.localizedDescription)")
        }
        
        // 2. Clean file secrets
        print("\n📄 Cleaning file secrets...")
        let secretsFilePath = Preferences.secretsFile.expandingTildeInPath
        
        if FileManager.default.fileExists(atPath: secretsFilePath) {
            do {
                // Read file to count entries before deletion
                let fileSecrets = try SecretsParser.parseSecretsFile(at: Preferences.secretsFile)
                let fileCount = fileSecrets.count
                
                // Create backup first
                let backupPath = secretsFilePath + ".wiped.backup.\(Int(Date().timeIntervalSince1970))"
                try FileManager.default.copyItem(atPath: secretsFilePath, toPath: backupPath)
                print("  📋 Backup created: \(backupPath)")
                
                // Delete original file
                try FileManager.default.removeItem(atPath: secretsFilePath)
                print("  ✅ Deleted file with \(fileCount) secret(s)")
                deletedCount += fileCount
                
            } catch {
                print("  ❌ Failed to delete secrets file: \(error.localizedDescription)")
                errors.append("File deletion: \(error.localizedDescription)")
            }
        } else {
            print("  ℹ️  No secrets file found")
        }
        
        // 3. Clean secrets directory if empty
        let secretsDirPath = (Preferences.secretsFile as NSString).deletingLastPathComponent.expandingTildeInPath
        if FileManager.default.fileExists(atPath: secretsDirPath) {
            do {
                let contents = try FileManager.default.contentsOfDirectory(atPath: secretsDirPath)
                let nonBackupFiles = contents.filter { !$0.contains(".backup") }
                
                if nonBackupFiles.isEmpty {
                    print("  🗂️  Secrets directory is empty (keeping backup files)")
                } else {
                    print("  📁 Secrets directory contains other files, keeping it")
                }
            } catch {
                print("  ⚠️  Could not check secrets directory contents")
            }
        }
        
        // Summary
        print("\n📊 Cleanup Summary:")
        if deletedCount > 0 {
            print("✅ Successfully deleted \(deletedCount) secret(s)")
        } else {
            print("ℹ️  No secrets were found to delete")
        }
        
        if !errors.isEmpty {
            print("❌ Errors encountered:")
            for error in errors {
                print("   • \(error)")
            }
        }
        
        print("\n🧹 Secret cleanup complete")
        print("   All secrets have been removed from both storage mechanisms")
        print("   Backup files (if any) have been preserved")
    }
    
    /// Generate configuration file from template and secrets
    static func generateConfig(templatePath: String, outputPath: String) {
        print("🔄 Generating config from template...")
        print("📄 Template: \(templatePath)")
        print("💾 Output: \(outputPath)")
        
        // Validate and create missing files (template, secrets) before processing
        if !Preferences.validateAndCreateFiles() {
            print("❌ Failed to validate and create required files")
            exit(1)
        }
        
        do {
            // Load secrets based on configured mechanism
            let mechanism = Preferences.secretsMechanism
            print("🔐 Loading secrets using \(mechanism) mechanism")
            
            let secrets: [String: String]
            
            if mechanism == "keychain" {
                secrets = try KeychainManager.listAll()
                print("🔑 Loaded \(secrets.count) secrets from keychain")
            } else {
                // Default to file mechanism
                let secretsPath = Preferences.secretsFile
                print("📄 Loading from file: \(secretsPath)")
                secrets = try SecretsParser.parseSecretsFile(at: secretsPath)
                print("📄 Loaded \(secrets.count) secrets from file")
            }
            
            // Process template with secrets
            try TemplateProcessor.processTemplate(
                templatePath: templatePath,
                outputPath: outputPath,
                secrets: secrets
            )
            
            print("✅ Config generation completed successfully")
            
        } catch {
            print("❌ Failed to generate config: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    /// Export keychain secrets to encrypted tmp file for package installation
    static func exportSecretsForUpgrade() {
        print("🔐 Exporting keychain secrets for package upgrade...")
        
        do {
            // 1. Get all existing keychain entries
            let secrets = try KeychainManager.listAll()
            print("🔍 Found \(secrets.count) keychain entries to export")
            
            if secrets.isEmpty {
                print("ℹ️  No keychain entries found - nothing to export")
                return
            }
            
            // 2. Create temporary directory using mktemp
            let process = Process()
            let pipe = Pipe()
            process.standardOutput = pipe
            process.executableURL = URL(fileURLWithPath: "/usr/bin/mktemp")
            process.arguments = ["-d", "-t", "claudesecrets_migration"]
            
            try process.run()
            process.waitUntilExit()
            
            guard process.terminationStatus == 0 else {
                print("❌ Failed to create temporary directory")
                exit(1)
            }
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let tmpDir = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                print("❌ Failed to read temporary directory path")
                exit(1)
            }
            
            // 3. Encrypt secrets
            let encryptedData = try EncryptionManager.encrypt(secrets: secrets)
            
            // 4. Write to secure tmp file
            let tmpFile = "\(tmpDir)/claudesecrets_export.enc"
            try encryptedData.write(to: URL(fileURLWithPath: tmpFile))
            
            // Set restrictive permissions (600)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: tmpFile
            )
            
            // 5. Store tmp directory path for post-install script
            let pathFile = "/tmp/claudesecrets_migration_path"
            try tmpDir.write(toFile: pathFile, atomically: true, encoding: .utf8)
            
            print("✅ Exported \(secrets.count) secrets to: \(tmpFile)")
            print("📁 Migration path stored: \(pathFile)")
            
            // 6. Log obfuscated secret names (for debugging)
            let secretNames = secrets.keys.sorted()
            for name in secretNames {
                print("  📦 Exported: \(name)")
            }
            
        } catch {
            print("❌ Failed to export secrets: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    /// Import keychain secrets from encrypted tmp file after package installation
    static func importSecretsFromUpgrade() {
        print("🔐 Importing keychain secrets after package upgrade...")
        
        do {
            // 1. Read tmp directory path
            let pathFile = "/tmp/claudesecrets_migration_path"
            guard FileManager.default.fileExists(atPath: pathFile) else {
                print("ℹ️  No migration path found - nothing to import")
                return
            }
            
            let tmpDir = try String(contentsOfFile: pathFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 2. Read encrypted file
            let tmpFile = "\(tmpDir)/claudesecrets_export.enc"
            guard FileManager.default.fileExists(atPath: tmpFile) else {
                print("ℹ️  No export file found - nothing to import")
                // Clean up path file
                try? FileManager.default.removeItem(atPath: pathFile)
                return
            }
            
            let encryptedData = try Data(contentsOf: URL(fileURLWithPath: tmpFile))
            print("🔍 Found encrypted export file: \(tmpFile)")
            
            // 3. Decrypt secrets
            let secrets = try EncryptionManager.decrypt(data: encryptedData)
            print("🔓 Decrypted \(secrets.count) secrets")
            
            // 4. Import secrets with new binary ownership
            var successCount = 0
            var failureCount = 0
            
            for (key, value) in secrets {
                do {
                    // Store with new binary (current binary becomes owner)
                    try KeychainManager.store(account: key, value: value)
                    let obfuscatedValue = String(repeating: "*", count: min(value.count, 8))
                    print("  ✅ Imported: \(key) = \(obfuscatedValue)...")
                    successCount += 1
                } catch {
                    print("  ❌ Failed to import \(key): \(error.localizedDescription)")
                    failureCount += 1
                }
            }
            
            // 5. Clean up tmp files
            do {
                try FileManager.default.removeItem(atPath: tmpDir)
                try FileManager.default.removeItem(atPath: pathFile)
                print("🧹 Temporary files cleaned up")
            } catch {
                print("⚠️  Failed to clean up tmp files: \(error.localizedDescription)")
                print("   Manual cleanup: rm -rf \(tmpDir) \(pathFile)")
            }
            
            // 6. Report results
            print("\n📊 Import Summary:")
            print("   ✅ Successfully imported: \(successCount)")
            if failureCount > 0 {
                print("   ❌ Failed to import: \(failureCount)")
            }
            
            if successCount == secrets.count {
                print("\n🎉 All keychain entries successfully migrated to new binary!")
                print("   Claude Desktop will now work without keychain prompts")
            } else if successCount > 0 {
                print("\n⚠️  Partial import completed")
                print("   Some entries may still require manual attention")
            } else {
                print("\n❌ Import failed for all entries")
                print("   Check keychain access permissions")
                exit(1)
            }
            
        } catch {
            print("❌ Failed to import secrets: \(error.localizedDescription)")
            exit(1)
        }
    }
    
    /// Transfer keychain ownership to current binary (for new builds/packages)
    static func upgradeKeychainOwnership() {
        print("🔄 Upgrading keychain ownership to current binary...")
        
        do {
            // 1. Get all existing entries
            let entries = try KeychainManager.listAll()
            print("🔍 Found \(entries.count) keychain entries to upgrade")
            
            if entries.isEmpty {
                print("ℹ️  No keychain entries found - nothing to upgrade")
                return
            }
            
            var successCount = 0
            var failureCount = 0
            
            // 2. Loop through each entry - recreate with new binary ownership + MD5 comment
            for (key, value) in entries {
                do {
                    // 3. Delete old entry (created by previous binary)
                    try KeychainManager.delete(account: key)
                    
                    // 4. Recreate with same values (new binary becomes owner)
                    //    Note: store() automatically adds MD5+version comment for tracking
                    try KeychainManager.store(account: key, value: value)
                    
                    // 5. Log with obfuscated value (security: never log actual secrets)
                    let obfuscatedValue = String(repeating: "*", count: min(value.count, 8))
                    print("  ✅ Upgraded: \(key) = \(obfuscatedValue)... (binary ownership transferred)")
                    successCount += 1
                    
                } catch {
                    print("  ❌ Failed to upgrade \(key): \(error.localizedDescription)")
                    failureCount += 1
                }
            }
            
            // 6. Report results
            print("\n📊 Upgrade Summary:")
            print("   ✅ Successfully upgraded: \(successCount)")
            if failureCount > 0 {
                print("   ❌ Failed to upgrade: \(failureCount)")
            }
            
            if successCount == entries.count {
                print("\n🎉 All keychain entries successfully transferred to new binary!")
                print("   Claude Desktop will now work without keychain prompts")
            } else if successCount > 0 {
                print("\n⚠️  Partial upgrade completed")
                print("   Some entries may still require manual attention")
            } else {
                print("\n❌ Upgrade failed for all entries")
                print("   Check keychain access permissions")
                exit(1)
            }
            
        } catch {
            print("❌ Failed to list keychain entries: \(error.localizedDescription)")
            print("   Make sure the keychain is accessible and not locked")
            exit(1)
        }
    }
    
    /// Check if keychain entries need upgrade (used by daemon)
    /// Exits with code 0 if no upgrade needed, 1 if upgrade needed
    static func checkUpgradeNeeded() {
        // Get list of entries that need upgrade
        let entriesNeedingUpgrade = KeychainManager.getEntriesNeedingUpgrade()
        
        if entriesNeedingUpgrade.isEmpty {
            // No upgrade needed - exit with code 0
            print("✅ All keychain entries are current")
            exit(0)
        } else {
            // Upgrade needed - exit with code 1
            print("🔄 Found \(entriesNeedingUpgrade.count) entries needing upgrade")
            print("   Entries: \(entriesNeedingUpgrade.joined(separator: ", "))")
            exit(1)
        }
    }
}

// MARK: - Main Entry Point
let arguments = Array(CommandLine.arguments.dropFirst())
let _ = CLICommands.parseArguments(arguments)