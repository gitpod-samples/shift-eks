#!/bin/bash
set -e

echo "🔴 Starting OpenShift CRC cluster..."

CRC_STATUS=$(crc status 2>&1 || echo "not-running")

if echo "$CRC_STATUS" | grep -q "Running"; then
    echo "✅ CRC cluster already running"
    return 0 2>/dev/null || exit 0
fi

echo "🚀 Starting CRC cluster (this may take several minutes)..."

# Check if CRC is already set up
if ! crc status 2>&1 | grep -q "CRC VM"; then
    echo "⚙️  Setting up CRC for the first time..."
    crc setup || {
        echo "⚠️  CRC setup encountered issues"
        echo "⚠️  You may need to run: crc setup"
        return 1 2>/dev/null || exit 1
    }
fi

# Start CRC with pull secret if available
if [ -f ~/.crc/pull-secret.json ]; then
    echo "🔑 Using pull secret from ~/.crc/pull-secret.json"
    crc start -p ~/.crc/pull-secret.json || {
        echo "⚠️  CRC start failed"
        echo "⚠️  Try running: crc start -p ~/.crc/pull-secret.json"
        return 1 2>/dev/null || exit 1
    }
else
    echo "⚠️  No pull secret found at ~/.crc/pull-secret.json"
    echo "⚠️  Get your pull secret from: https://console.redhat.com/openshift/create/local"
    echo "⚠️  Run: ./setup-crc-pull-secret.sh to configure it"
    echo "⚠️  Or run: crc start (will prompt for pull secret)"
    
    crc start || {
        echo "⚠️  CRC start failed - pull secret required"
        echo "⚠️  Run: ./setup-crc-pull-secret.sh"
        return 1 2>/dev/null || exit 1
    }
fi

# Wait for cluster to be ready
echo "⏳ Waiting for CRC cluster to be ready..."
sleep 10

# Configure kubectl/oc for CRC
echo "🔧 Configuring kubeconfig for CRC..."
eval $(crc oc-env) 2>/dev/null || true

# Login to CRC cluster
CRC_PASSWORD=$(crc console --credentials 2>/dev/null | grep "kubeadmin" | awk '{print $NF}')
if [ -n "$CRC_PASSWORD" ]; then
    oc login -u kubeadmin -p "$CRC_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true 2>/dev/null || {
        echo "⚠️  Auto-login failed, you may need to login manually"
        echo "⚠️  Run: crc console --credentials"
    }
fi

echo "✅ CRC cluster started successfully"
echo "   Context: $(oc config current-context 2>/dev/null || echo 'crc')"
echo "   Console: $(crc console --url 2>/dev/null || echo 'https://console-openshift-console.apps-crc.testing')"
echo "   Credentials: crc console --credentials"
