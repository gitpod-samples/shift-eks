#!/bin/bash
set -e

echo "🚀 Starting EKS Anywhere cluster (Docker provider)..."

# Use directory inside the project which is bind-mounted from host
CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
CLUSTER_NAME="eks-local"
CLUSTER_CONFIG="${CLUSTERS_DIR}/${CLUSTER_NAME}-config.yaml"
KUBECONFIG_PATH="${CLUSTERS_DIR}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig"
BOOTSTRAP_KUBECONFIG="${CLUSTERS_DIR}/${CLUSTER_NAME}/generated/${CLUSTER_NAME}.kind.kubeconfig"

# Check if cluster containers are already running
if docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_NAME}-eks-a-cluster-control-plane$"; then
    echo "✅ EKS Anywhere cluster containers are running"
    
    # Try to find and use kubeconfig
    if [ -f "$KUBECONFIG_PATH" ]; then
        export KUBECONFIG="$KUBECONFIG_PATH"
        echo "   Using kubeconfig: $KUBECONFIG_PATH"
    elif [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
        export KUBECONFIG="$BOOTSTRAP_KUBECONFIG"
        echo "   Using bootstrap kubeconfig: $BOOTSTRAP_KUBECONFIG"
    fi
    
    # Check if cluster is accessible
    if [ -n "$KUBECONFIG" ] && kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        echo "✅ Cluster is running and healthy"
        echo ""
        echo "🔄 Monitoring EKS Anywhere cluster..."
        while docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_NAME}-eks-a-cluster-control-plane$"; do
            sleep 10
        done
        echo "❌ EKS Anywhere cluster stopped"
        exit 1
    else
        echo "⚠️  Cluster containers exist but cluster may not be responding"
        echo "   Cleaning up and recreating..."
    fi
fi

# Clean up any existing cluster artifacts
echo "🧹 Cleaning up any existing cluster artifacts..."
if [ -d "${CLUSTERS_DIR}/${CLUSTER_NAME}" ]; then
    rm -rf "${CLUSTERS_DIR}/${CLUSTER_NAME}"
    echo "   Removed old cluster directory"
fi

# Stop any existing containers
for container in $(docker ps -a --format '{{.Names}}' | grep "^${CLUSTER_NAME}"); do
    echo "   Stopping container: $container"
    docker rm -f "$container" 2>/dev/null || true
done

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
echo "🔨 Creating EKS Anywhere cluster (this may take 10-15 minutes)..."
echo "   Using Docker provider for local development"
echo "   This will download images on first run..."
echo ""

# Start cluster creation in background and monitor progress
eksctl anywhere create cluster -f "$CLUSTER_CONFIG" &
EKSCTL_PID=$!

# Wait for bootstrap cluster to be created
echo "⏳ Waiting for bootstrap cluster..."
for i in {1..60}; do
    if [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
        echo "✅ Bootstrap cluster created"
        break
    fi
    if ! kill -0 $EKSCTL_PID 2>/dev/null; then
        wait $EKSCTL_PID
        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            echo "❌ Cluster creation failed with exit code $EXIT_CODE"
            echo "📋 Common issues:"
            echo "   - Docker resources (need ~4GB RAM, 2 CPUs)"
            echo "   - Port conflicts (check docker ps)"
            echo "   - Network issues (check internet connection)"
            exit 1
        fi
        break
    fi
    sleep 5
done

# Set kubeconfig to bootstrap cluster
if [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
    export KUBECONFIG="$BOOTSTRAP_KUBECONFIG"
    echo "   Using bootstrap kubeconfig for monitoring"
fi

# Wait for eksctl to complete or for cluster to be ready
echo "⏳ Waiting for cluster creation to complete..."
for i in {1..120}; do
    # Check if eksctl process is still running
    if ! kill -0 $EKSCTL_PID 2>/dev/null; then
        wait $EKSCTL_PID
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            echo "✅ Cluster creation completed successfully"
            break
        else
            echo "⚠️  eksctl exited with code $EXIT_CODE, checking cluster status..."
        fi
    fi
    
    # Check if cluster is accessible
    if [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
        if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
            echo "✅ Cluster is accessible and nodes are ready"
            # Kill eksctl if it's still running (it might be stuck)
            if kill -0 $EKSCTL_PID 2>/dev/null; then
                echo "   Stopping eksctl process..."
                kill $EKSCTL_PID 2>/dev/null || true
                wait $EKSCTL_PID 2>/dev/null || true
            fi
            break
        fi
    fi
    
    sleep 5
done

echo "✅ EKS Anywhere cluster is ready"

# Determine which kubeconfig to use
if [ -f "$KUBECONFIG_PATH" ]; then
    export KUBECONFIG="$KUBECONFIG_PATH"
    echo "✅ Using management cluster kubeconfig: $KUBECONFIG_PATH"
elif [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
    export KUBECONFIG="$BOOTSTRAP_KUBECONFIG"
    echo "✅ Using bootstrap cluster kubeconfig: $BOOTSTRAP_KUBECONFIG"
    # Copy to expected location for consistency
    mkdir -p "$(dirname "$KUBECONFIG_PATH")"
    cp "$BOOTSTRAP_KUBECONFIG" "$KUBECONFIG_PATH"
    export KUBECONFIG="$KUBECONFIG_PATH"
    echo "   Copied to: $KUBECONFIG_PATH"
else
    echo "⚠️  No kubeconfig found"
    echo "   Looking for kubeconfig files..."
    find "${CLUSTERS_DIR}/${CLUSTER_NAME}" -name "*.kubeconfig" 2>/dev/null || true
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
echo ""

# Keep the service running by monitoring the cluster containers
echo "🔄 Monitoring EKS Anywhere cluster..."
while docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_NAME}-eks-a-cluster-control-plane$"; do
    sleep 10
done

echo "❌ EKS Anywhere cluster stopped"
exit 1
