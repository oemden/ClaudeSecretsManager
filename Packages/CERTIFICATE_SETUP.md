# Claude Secrets Manager - Certificate Setup Guide

This guide explains how to set up Developer ID certificates for signing the Claude Secrets Manager package installer.

## 🏆 Certificate Requirements

### Required Certificates
1. **Developer ID Application Certificate** - Signs the app binaries
2. **Developer ID Installer Certificate** - Signs the .pkg installer package

### Apple Developer Account
- Active Apple Developer Program membership required ($99/year)
- Individual or Organization account both work
- Account must be in good standing

## 🔧 Certificate Setup Process

### Step 1: Create Certificate Signing Request (CSR)

1. Open **Keychain Access** application
2. Go to **Keychain Access > Certificate Assistant > Request a Certificate From a Certificate Authority**
3. Fill in the form:
   - **User Email Address**: Your Apple ID email
   - **Common Name**: Your name or organization name
   - **CA Email Address**: Leave blank
   - **Request is**: Saved to disk
   - **Let me specify key pair information**: Check this
4. Click **Continue**
5. Choose key size: **2048 bits**
6. Algorithm: **RSA**
7. Save the CSR file to your desktop

### Step 2: Generate Developer ID Application Certificate

1. Log in to [Apple Developer Portal](https://developer.apple.com/account/)
2. Go to **Certificates, Identifiers & Profiles**
3. Click **Certificates** in the sidebar
4. Click the **+** button to create a new certificate
5. Under **Software**, select **Developer ID Application**
6. Click **Continue**
7. Upload your CSR file
8. Click **Continue**
9. Download the certificate file
10. Double-click to install in Keychain Access

### Step 3: Generate Developer ID Installer Certificate

1. In Apple Developer Portal, click **+** for new certificate
2. Under **Software**, select **Developer ID Installer**
3. Click **Continue**
4. Upload the same CSR file
5. Click **Continue**
6. Download the certificate file
7. Double-click to install in Keychain Access

### Step 4: Verify Certificate Installation

Open **Keychain Access** and check for:
- `Developer ID Application: [Your Name] ([Team ID])`
- `Developer ID Installer: [Your Name] ([Team ID])`

Both should be in the **login** keychain with valid private keys.

## 📦 Packages App Configuration

### Setting Up Certificate in Packages

1. Open **Packages.app**
2. Open your `ClaudeSecretsManager.pkgproj` file
3. Go to **Project Settings**
4. Under **Build Settings**, find **Certificate**
5. Select your **Developer ID Installer** certificate from the dropdown
6. Ensure **Certificate of Authenticity** is enabled

### Package Signing Settings

In the Packages project settings:
```xml
<key>CERTIFICATE</key>
<string>Developer ID Installer: [Your Name] ([Team ID])</string>
<key>CERTIFICATE_PATH</key>
<string>/path/to/certificate</string>
```

## 🔐 Code Signing Setup

### Sign Binaries Before Packaging

Before building the package, sign your binaries:

```bash
# Sign the daemon binary
codesign --sign "Developer ID Application: [Your Name]" \
         --timestamp \
         --options runtime \
         /usr/local/bin/claudesecrets

# Sign the CLI binary  
codesign --sign "Developer ID Application: [Your Name]" \
         --timestamp \
         --options runtime \
         /usr/local/bin/claudesecrets-cli

# Verify signatures
codesign --verify --verbose /usr/local/bin/claudesecrets
codesign --verify --verbose /usr/local/bin/claudesecrets-cli
```

### Package Signing

Packages.app will automatically sign the .pkg with your Developer ID Installer certificate.

You can also sign manually:
```bash
productsign --sign "Developer ID Installer: [Your Name]" \
            ClaudeSecretsManager-unsigned.pkg \
            ClaudeSecretsManager.pkg
```

## 🚀 Notarization (Recommended)

### Why Notarize
- Required for distribution on macOS 10.15+
- Prevents Gatekeeper warnings
- Provides additional security validation

### Notarization Process

1. **Create App-Specific Password**:
   - Go to [appleid.apple.com](https://appleid.apple.com)
   - Sign in with your Apple ID
   - Generate app-specific password for "Notarization"

2. **Submit for Notarization**:
   ```bash
   xcrun notarytool submit ClaudeSecretsManager.pkg \
                   --apple-id your@email.com \
                   --team-id YOUR_TEAM_ID \
                   --password "app-specific-password" \
                   --wait
   ```

3. **Staple Notarization Ticket**:
   ```bash
   xcrun stapler staple ClaudeSecretsManager.pkg
   ```

4. **Verify Notarization**:
   ```bash
   xcrun stapler validate ClaudeSecretsManager.pkg
   ```

## 🔍 Troubleshooting

### Common Issues

#### "Certificate not found"
- Ensure certificates are in the **login** keychain
- Check that private keys are present
- Verify certificate validity dates

#### "Code signing failed"
- Check certificate names match exactly
- Ensure Xcode command line tools are installed
- Verify certificate chain is complete

#### "Notarization failed"
- Ensure hardened runtime is enabled (`--options runtime`)
- Check for unsigned dependencies
- Review notarization log for specific errors

### Verification Commands

```bash
# List available certificates
security find-identity -v -p codesigning

# Check certificate details
security find-certificate -c "Developer ID Application" -p | openssl x509 -text

# Verify code signature
codesign --verify --deep --strict --verbose=2 /path/to/binary

# Check package signature
pkgutil --check-signature ClaudeSecretsManager.pkg
```

## 📋 Certificate Management

### Certificate Renewal
- Developer ID certificates expire after 5 years
- Renew before expiration to avoid distribution issues
- Old certificates can continue to validate existing installations

### Team Management
- Organization accounts can have multiple team members
- Each member can create their own certificates
- Use consistent certificate naming for team projects

### Security Best Practices
- Store certificates securely in Keychain
- Never share private keys
- Use different certificates for different projects if needed
- Keep Xcode and command line tools updated

## 🎯 Integration with Build Process

### Automated Signing Script

Create `sign_and_package.sh`:
```bash
#!/bin/bash
set -e

# Build binaries
swift build -c release

# Sign binaries
codesign --sign "Developer ID Application: [Your Name]" \
         --timestamp --options runtime \
         .build/release/claudesecrets

codesign --sign "Developer ID Application: [Your Name]" \
         --timestamp --options runtime \
         .build/release/claudesecrets-cli

# Build package with Packages.app
# (Certificate configured in project settings)

# Notarize if needed
xcrun notarytool submit build/ClaudeSecretsManager.pkg \
         --apple-id your@email.com \
         --team-id YOUR_TEAM_ID \
         --password "app-specific-password" \
         --wait

# Staple notarization
xcrun stapler staple build/ClaudeSecretsManager.pkg

echo "✅ Signed and notarized package ready for distribution"
```

This setup ensures your Claude Secrets Manager package will install without Gatekeeper warnings and provides users with confidence in the software's authenticity.