#!/bin/bash
set -e

echo "🚀 Starting EKS Anywhere cluster (Docker provider)..."

# Use directory inside the project which is bind-mounted from host
CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
CLUSTER_NAME="eks-local"
CLUSTER_CONFIG="${CLUSTERS_DIR}/${CLUSTER_NAME}-config.yaml"
KUBECONFIG_PATH="${CLUSTERS_DIR}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig"

# Check if cluster already exists
if eksctl anywhere get clusters 2>/dev/null | grep -q "$CLUSTER_NAME"; then
    echo "✅ EKS Anywhere cluster already exists"
    
    # Check if kubeconfig exists
    if [ -f "$KUBECONFIG_PATH" ]; then
        export KUBECONFIG="$KUBECONFIG_PATH"
        
        # Check if cluster is actually running
        if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            echo "✅ Cluster is running and healthy"
            echo "   Kubeconfig: $KUBECONFIG"
            return 0 2>/dev/null || exit 0
        else
            echo "⚠️  Cluster exists but may not be responding"
        fi
    else
        echo "⚠️  Cluster exists but kubeconfig not found at $KUBECONFIG_PATH"
    fi
fi

# Create cluster configuration directory
mkdir -p "${CLUSTERS_DIR}"
cd "${CLUSTERS_DIR}"

# Generate cluster configuration if it doesn't exist
if [ ! -f "$CLUSTER_CONFIG" ]; then
    echo "📝 Generating EKS Anywhere cluster configuration..."
    
    eksctl anywhere generate clusterconfig $CLUSTER_NAME \
        --provider docker \
        > "$CLUSTER_CONFIG"
    
    echo "✅ Configuration generated at $CLUSTER_CONFIG"
fi

# Create the EKS Anywhere cluster
echo "🔨 Creating EKS Anywhere cluster (this may take 5-10 minutes)..."
echo "   Using Docker provider for local development"
echo "   This will download images on first run..."

if ! eksctl anywhere create cluster \
    -f "$CLUSTER_CONFIG" \
    --bundles-override=false; then
    echo "❌ Cluster creation failed"
    echo "📋 Common issues:"
    echo "   - Docker resources (need ~4GB RAM, 2 CPUs)"
    echo "   - Port conflicts (check docker ps)"
    echo "   - Network issues (check internet connection)"
    exit 1
fi

echo "✅ Cluster created successfully"

# Set KUBECONFIG environment variable
if [ -f "$KUBECONFIG_PATH" ]; then
    export KUBECONFIG="$KUBECONFIG_PATH"
    echo "✅ Kubeconfig found at $KUBECONFIG_PATH"
else
    echo "⚠️  Kubeconfig not found at expected location"
    echo "   Looking for kubeconfig files..."
    find "${CLUSTERS_DIR}/${CLUSTER_NAME}" -name "*.kubeconfig" 2>/dev/null || true
fi

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be fully ready..."
if kubectl wait --for=condition=Ready nodes --all --timeout=5m 2>/dev/null; then
    echo "✅ All nodes are ready"
else
    echo "⚠️  Timeout waiting for nodes, but cluster may still be starting"
fi

# Test cluster access
echo ""
echo "🔍 Testing cluster access..."
if kubectl get nodes 2>/dev/null; then
    echo "✅ Cluster is accessible via kubectl"
else
    echo "❌ Cannot access cluster via kubectl"
    echo "   Check: kubectl config view"
fi

echo ""
echo "✅ EKS Anywhere cluster setup complete"
echo "   Cluster: $CLUSTER_NAME"
echo "   Provider: Docker (local development)"
echo "   Kubeconfig: $KUBECONFIG"
echo "   Context: $(kubectl config current-context 2>/dev/null || echo 'unknown')"
echo ""
echo "📋 Quick commands:"
echo "   export KUBECONFIG=$KUBECONFIG"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo "   eksctl anywhere get clusters"
echo ""
echo "ℹ️  Note: This is EKS Anywhere with Docker provider"
echo "   - Real EKS Anywhere distribution"
echo "   - AWS-curated Kubernetes"
echo "   - Supports EKS Anywhere features"
echo "   - Free for development use"
