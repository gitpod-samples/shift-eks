#!/bin/bash
# Helper script to set up CRC pull secret

set -e

echo "═══════════════════════════════════════════════════════════"
echo "🔴 OpenShift CRC Pull Secret Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "To use CodeReady Containers, you need a pull secret from Red Hat."
echo ""
echo "📋 Steps:"
echo "1. Visit: https://console.redhat.com/openshift/create/local"
echo "2. Log in with your Red Hat account (free registration available)"
echo "3. Click 'Download pull secret'"
echo "4. Copy the pull secret content"
echo ""
echo "═══════════════════════════════════════════════════════════"
echo ""

read -p "Do you have your pull secret ready? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Please get your pull secret first, then run this script again."
    echo "Or run: crc start"
    echo "CRC will prompt you for the pull secret during first-time setup."
    exit 0
fi

echo ""
echo "Choose an option:"
echo "1. Paste pull secret content directly"
echo "2. Provide path to pull secret file"
echo ""
read -p "Enter choice (1 or 2): " choice

case $choice in
    1)
        echo ""
        echo "Paste your pull secret content (press Ctrl+D when done):"
        PULL_SECRET=$(cat)
        echo "$PULL_SECRET" > ~/.crc/pull-secret.json
        echo "✅ Pull secret saved to ~/.crc/pull-secret.json"
        ;;
    2)
        echo ""
        read -p "Enter path to pull secret file: " secret_path
        if [ -f "$secret_path" ]; then
            cp "$secret_path" ~/.crc/pull-secret.json
            echo "✅ Pull secret copied to ~/.crc/pull-secret.json"
        else
            echo "❌ File not found: $secret_path"
            exit 1
        fi
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "✅ Pull secret configured!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Now you can start CRC:"
echo "  crc setup"
echo "  crc start -p ~/.crc/pull-secret.json"
echo ""
echo "Or use the cluster manager:"
echo "  ./cluster-manager.sh start-all"
echo ""
