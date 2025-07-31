// KeychainManager.swift
// Keychain Services wrapper for Claude Secrets Manager

import Foundation
import Security
import SharedConstants

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
    /// - Throws: KeychainError on failure
    public static func store(account: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        // Check if item already exists
        if exists(account: account) {
            try update(account: account, value: value)
            return
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
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
    
    // MARK: - Private Helper Methods
    
    /// Update an existing keychain item
    /// - Parameters:
    ///   - account: The variable name
    ///   - value: The new secret value
    /// - Throws: KeychainError on failure
    private static func update(account: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unableToConvertToData
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let updateFields: [String: Any] = [
            kSecValueData as String: valueData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, updateFields as CFDictionary)
        
        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }
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