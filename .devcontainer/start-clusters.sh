#!/bin/bash
# Orchestrator script to start both CRC and EKS clusters

echo "🚀 Starting Kubernetes clusters..."
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Start EKS (faster, start first)
bash "$SCRIPT_DIR/start-eks-anywhere.sh"
EKS_STATUS=$?

echo ""

# Start CRC (slower, start second)
bash "$SCRIPT_DIR/start-openshift-crc.sh"
CRC_STATUS=$?

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 Cluster Startup Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Display summary
if [ $CRC_STATUS -eq 0 ]; then
    echo "✅ OpenShift (CRC): Running"
else
    echo "❌ OpenShift (CRC): Failed to start"
fi

if [ $EKS_STATUS -eq 0 ]; then
    echo "✅ EKS-like (kind): Running"
else
    echo "❌ EKS-like (kind): Failed to start"
fi

echo ""
echo "📋 Quick commands:"
echo "   ./cluster-manager.sh status          # Check cluster status"
echo "   crc console --credentials            # Get OpenShift credentials"
echo "   oc get nodes                         # Check OpenShift nodes"
echo "   kubectl config get-contexts          # List all contexts"
echo "   kind get clusters                    # List kind clusters"
echo ""
echo "📚 Documentation:"
echo "   README.md                            # Full documentation"
echo "   QUICKSTART.md                        # Quick start guide"
echo ""
echo "═══════════════════════════════════════════════════════════"

# Set default context to OpenShift CRC if available
if [ $CRC_STATUS -eq 0 ]; then
    oc config use-context $(oc config current-context 2>/dev/null) 2>/dev/null || true
fi
