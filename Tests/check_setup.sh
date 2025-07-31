#!/bin/bash
# Quick test script to verify paths and files

echo "🔍 Checking paths..."

# Check secrets file
if [ -f ~/.claudesecrets/claude_secrets ]; then
    echo "✅ Secrets file exists"
else
    echo "❌ Secrets file NOT found at: ~/.claudesecrets/claude_secrets"
fi

# Check template file
if [ -f ~/Library/Application\ Support/Claude/claude_desktop_config_template.json ]; then
    echo "✅ Template file exists"
else
    echo "❌ Template file NOT found at: ~/Library/Application Support/Claude/claude_desktop_config_template.json"
fi

# Check output directory
if [ -d ~/Library/Application\ Support/Claude ]; then
    echo "✅ Claude directory exists"
else
    echo "❌ Claude directory NOT found"
fi

echo ""
echo "📝 Current directory contents:"
ls -la ~/Library/Application\ Support/Claude/
