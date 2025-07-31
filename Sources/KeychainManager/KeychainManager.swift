// KeychainManager.swift
// Keychain Services wrapper for Claude Secrets Manager

import Foundation
import Security
import SharedConstants
#if canImport(CommonCrypto)
import CommonCrypto
#endif

/// Errors that can occur during keychain operations
public enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case invalidData
    case unexpectedStatus(OSStatus)
    case unableToConvertToString
    case unableToConvertToData
    
    public var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return "Keychain item not found"
        case .duplicateItem:
            return "Keychain item already exists"
        case .invalidData:
            return "Invalid data provided"
        case .unexpectedStatus(let status):
            if let message = SecCopyErrorMessageString(status, nil) {
                return "Keychain error: \(message)"
            }
            return "Keychain error with status: \(status)"
        case .unableToConvertToString:
            return "Unable to convert keychain data to string"
        case .unableToConvertToData:
            return "Unable to convert string to data"
        }
    }
}

/// Keychain manager for Claude Secrets Manager
/// Stores secrets as generic passwords with service "claudesecrets"
public class KeychainManager {
    
    /// Service identifier for all Claude Secrets Manager keychain items
    private static let service = SharedConstants.keychainService
    
    // MARK: - Public Interface
    
    /// Store a secret in the keychain
    /// - Parameters:
    ///   - account: The variable name (e.g., "API_KEY")
    ///   - value: The secret value
    ///   - comment: Optional comment (defaults to binary MD5 + version)
    /// - Throws: KeychainError on failure
    public static func store(account: String, value: String, comment: String? = nil) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        // Generate default comment with binary MD5 + version if not provided
        let finalComment = comment ?? generateDefaultComment()
        
        // Check if item already exists
        if exists(account: account) {
            try update(account: account, value: value, comment: finalComment)
            return
        }
        
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Add comment if provided
        if !finalComment.isEmpty {
            query[kSecAttrComment as String] = finalComment
        }
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Retrieve a secret from the keychain
    /// - Parameter account: The variable name (e.g., "API_KEY")
    /// - Returns: The secret value
    /// - Throws: KeychainError on failure
    public static func retrieve(account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
    
    /// Delete a secret from the keychain
    /// - Parameter account: The variable name (e.g., "API_KEY")
    /// - Throws: KeychainError on failure
    public static func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
    
    /// Check if a secret exists in the keychain
    /// - Parameter account: The variable name (e.g., "API_KEY")
    /// - Returns: true if the item exists, false otherwise
    public static func exists(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]
        
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// List all secrets stored by Claude Secrets Manager
    /// - Returns: Dictionary of account names to values
    /// - Throws: KeychainError on failure
    public static func listAll() throws -> [String: String] {
        // First, get just the account names
        let accountQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        
        var accountResult: AnyObject?
        let accountStatus = SecItemCopyMatching(accountQuery as CFDictionary, &accountResult)
        
        guard accountStatus == errSecSuccess else {
            if accountStatus == errSecItemNotFound {
                return [:] // No items found, return empty dictionary
            }
            throw KeychainError.unexpectedStatus(accountStatus)
        }
        
        var secrets: [String: String] = [:]
        var accounts: [String] = []
        
        // Extract account names
        if let items = accountResult as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String {
                    accounts.append(account)
                }
            }
        } else if let item = accountResult as? [String: Any] {
            if let account = item[kSecAttrAccount as String] as? String {
                accounts.append(account)
            }
        }
        
        // Retrieve each secret individually
        for account in accounts {
            do {
                let value = try retrieve(account: account)
                secrets[account] = value
            } catch {
                // Skip this account if we can't retrieve it
                continue
            }
        }
        
        return secrets
    }
    
    /// Get count of stored secrets
    /// - Returns: Number of secrets stored by Claude Secrets Manager
    public static func count() -> Int {
        do {
            return try listAll().count
        } catch {
            return 0
        }
    }
    
    /// Get comment for a keychain item
    /// - Parameter account: The variable name (e.g., "API_KEY")
    /// - Returns: The comment string, or empty string if none
    public static func getComment(account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let attributes = result as? [String: Any],
              let comment = attributes[kSecAttrComment as String] as? String else {
            return ""
        }
        
        return comment
    }
    
    /// Check if keychain entries need upgrade based on binary MD5
    /// 
    /// This function implements the core logic for silent keychain migration:
    /// 1. Each keychain entry stores a comment with the MD5 hash of the binary that created it
    /// 2. When a new build/package is installed, the binary MD5 changes
    /// 3. macOS keychain only allows the creating binary to access entries without GUI prompts
    /// 4. This function identifies entries created by old binaries that need to be recreated
    /// 5. The daemon uses this to silently upgrade keychain ownership before config generation
    /// 
    /// - Returns: Array of account names that need upgrade (empty array if all current)
    public static func getEntriesNeedingUpgrade() -> [String] {
        do {
            // Get MD5 hash of currently running binary
            let currentMD5 = getCurrentBinaryMD5()
            
            // Get all keychain entries managed by Claude Secrets Manager
            let entries = try listAll()
            
            // Check each entry's comment to see if it was created by current binary
            return entries.keys.compactMap { account in
                let comment = getComment(account: account)
                
                // Check for current binary hash in both old (md5:) and new (sha256:) formats
                // If comment contains current binary's hash, no upgrade needed (return nil)
                // If comment is missing or has different hash, upgrade needed (return account name)
                let hasCurrentHash = comment.contains("md5:\(currentMD5)") || comment.contains("sha256:\(currentMD5)")
                return hasCurrentHash ? nil : account
            }
        } catch {
            // If we can't read keychain, assume no upgrades needed (fail safe)
            return []
        }
    }
    
    // MARK: - Private Helper Methods
    
    /// Update an existing keychain item
    /// - Parameters:
    ///   - account: The variable name
    ///   - value: The new secret value
    ///   - comment: Optional comment to update
    /// - Throws: KeychainError on failure
    private static func update(account: String, value: String, comment: String? = nil) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        var updateFields: [String: Any] = [
            kSecValueData as String: valueData
        ]
        
        // Add comment if provided
        if let comment = comment, !comment.isEmpty {
            updateFields[kSecAttrComment as String] = comment
        }
        
        let status = SecItemUpdate(query as CFDictionary, updateFields as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
    }
    
    /// Generate default comment with binary hash and version
    /// Format: "sha256:a1b2c3d4e5f6... version:0.3.2 created:2025-07-31T22:30:00Z"
    /// Note: Using sha256 prefix for new entries, but still checking md5: for backward compatibility
    private static func generateDefaultComment() -> String {
        let hash = getCurrentBinaryMD5() // Function name kept for compatibility, but returns SHA256
        let version = SharedConstants.version
        let timestamp = ISO8601DateFormatter().string(from: Date())
        return "sha256:\(hash) version:\(version) created:\(timestamp)"
    }
    
    /// Get SHA256 hash of currently running binary
    /// This creates a unique identifier for each build, even with same version number
    /// Using SHA256 instead of deprecated MD5 for future compatibility
    private static func getCurrentBinaryMD5() -> String {
        // Get path to current executable
        guard let executablePath = Bundle.main.executablePath else {
            return "unknown"
        }
        
        // Calculate SHA256 hash of the binary file (keeping MD5 name for compatibility)
        return sha256OfFile(at: executablePath) ?? "unknown"
    }
    
    /// Calculate SHA256 hash of a file
    /// - Parameter path: File path to hash
    /// - Returns: SHA256 hash string or nil if failed
    private static func sha256OfFile(at path: String) -> String? {
        guard let data = FileManager.default.contents(atPath: path) else {
            return nil
        }
        
        // Use CommonCrypto for SHA256 calculation (more secure and not deprecated)
        #if canImport(CommonCrypto)
        
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(data.count), &hash)
        }
        
        return hash.map { String(format: "%02x", $0) }.joined()
        #else
        // Fallback for platforms without CommonCrypto
        return "fallback-\(data.count)-\(path.hash)"
        #endif
    }
}

// MARK: - Convenience Extensions

public extension KeychainManager {
    
    /// Store multiple secrets at once
    /// - Parameter secrets: Dictionary of account names to values
    /// - Throws: KeychainError on first failure (partial success possible)
    static func storeMultiple(_ secrets: [String: String]) throws {
        for (account, value) in secrets {
            try store(account: account, value: value)
        }
    }
    
    /// Delete multiple secrets at once
    /// - Parameter accounts: Array of account names to delete
    /// - Throws: KeychainError on first failure (partial success possible)
    static func deleteMultiple(_ accounts: [String]) throws {
        for account in accounts {
            try delete(account: account)
        }
    }
    
    /// Clear all Claude Secrets Manager keychain items
    /// - Throws: KeychainError on failure
    static func clearAll() throws {
        let secrets = try listAll()
        for account in secrets.keys {
            try delete(account: account)
        }
    }
}