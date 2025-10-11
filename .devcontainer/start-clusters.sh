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

# Start OKD (OpenShift-compatible, slower, start second)
bash "$SCRIPT_DIR/start-openshift-okd.sh"
OKD_STATUS=$?

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "🎉 Cluster Startup Complete"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Display summary
if [ $OKD_STATUS -eq 0 ]; then
    echo "✅ OpenShift-compatible (OKD): Running"
else
    echo "❌ OpenShift-compatible (OKD): Failed to start"
fi

if [ $EKS_STATUS -eq 0 ]; then
    echo "✅ EKS-like (kind): Running"
else
    echo "❌ EKS-like (kind): Failed to start"
fi

echo ""
echo "📋 Quick commands:"
echo "   ./cluster-manager.sh status          # Check cluster status"
echo "   oc get nodes                         # Check OKD nodes"
echo "   kubectl config get-contexts          # List all contexts"
echo "   kind get clusters                    # List kind clusters"
echo "   kubectl get crds | grep openshift    # Check OpenShift CRDs"
echo ""
echo "📚 Documentation:"
echo "   README.md                            # Full documentation"
echo "   QUICKSTART.md                        # Quick start guide"
echo ""
echo "═══════════════════════════════════════════════════════════"

# Set default context to OKD if available
if [ $OKD_STATUS -eq 0 ]; then
    kubectl config use-context kind-okd-local 2>/dev/null || true
fi
