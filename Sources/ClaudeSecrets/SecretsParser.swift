import Foundation

// MARK: - Secrets Parser
struct SecretsParser {
    
    /// Parse secrets file and return key-value dictionary
    static func parseSecretsFile(at path: String) throws -> [String: String] {
        let url = URL(fileURLWithPath: path.expandingTildeInPath)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw SecretsError.fileNotFound(path)
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return parseSecrets(from: content)
    }
    
    /// Parse secrets from string content
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
                    print("📝 Parsed secret: \(key) = \(String(repeating: "*", count: min(value.count, 8)))...")
                }
            }
        }
        
        return secrets
    }
}

// MARK: - Template Processor
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

// MARK: - Errors
enum SecretsError: LocalizedError {
    case fileNotFound(String)
    case templateNotFound(String)
    case parseError(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "Secrets file not found: \(path)"
        case .templateNotFound(let path):
            return "Template file not found: \(path)"
        case .parseError(let message):
            return "Parse error: \(message)"
        }
    }
}

// MARK: - String Extension for Path Expansion
extension String {
    var expandingTildeInPath: String {
        return (self as NSString).expandingTildeInPath
    }
}
