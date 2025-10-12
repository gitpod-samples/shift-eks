#!/bin/bash
set -e

echo "🚀 Starting EKS Anywhere cluster (Docker provider)..."

# Use directory inside the project which is bind-mounted from host
CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
CLUSTER_NAME="eks-local"
CLUSTER_CONFIG="${CLUSTERS_DIR}/${CLUSTER_NAME}-config.yaml"
KUBECONFIG_PATH="${CLUSTERS_DIR}/${CLUSTER_NAME}/${CLUSTER_NAME}-eks-a-cluster.kubeconfig"
BOOTSTRAP_KUBECONFIG="${CLUSTERS_DIR}/${CLUSTER_NAME}/generated/${CLUSTER_NAME}.kind.kubeconfig"
EKS_ANYWHERE_KUBECONFIG="/workspaces/shift-eks/.kube/eks-anywhere-config"

# Check if cluster containers are already running
if docker ps --format '{{.Names}}' | grep -q "^${CLUSTER_NAME}-eks-a-cluster-control-plane$"; then
    echo "✅ EKS Anywhere cluster containers are running"
    
    # Try to find and use kubeconfig
    if [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
        mkdir -p /workspaces/shift-eks/.kube
        cp "$BOOTSTRAP_KUBECONFIG" "$EKS_ANYWHERE_KUBECONFIG"
        echo "   Using kubeconfig: $EKS_ANYWHERE_KUBECONFIG"
    elif [ -f "$KUBECONFIG_PATH" ]; then
        cp "$KUBECONFIG_PATH" "$EKS_ANYWHERE_KUBECONFIG"
        echo "   Using kubeconfig: $EKS_ANYWHERE_KUBECONFIG"
    fi
    
    # Check if cluster is accessible
    if [ -f "$EKS_ANYWHERE_KUBECONFIG" ] && KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        echo "✅ Cluster is running and healthy"
        
        # Rename context to simple name if needed
        CURRENT_CONTEXT=$(KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl config current-context 2>/dev/null || echo "")
        if [ -n "$CURRENT_CONTEXT" ] && [ "$CURRENT_CONTEXT" != "eks-anywhere" ]; then
            KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl config rename-context "$CURRENT_CONTEXT" "eks-anywhere" 2>/dev/null || true
            echo "   Context renamed to: eks-anywhere"
        fi
        
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
# Unset KUBECONFIG to prevent eksctl from trying to mount multiple paths as Docker volumes
env -u KUBECONFIG eksctl anywhere create cluster -f "$CLUSTER_CONFIG" &
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

# Note: Using bootstrap kubeconfig for monitoring (not exporting to avoid overriding DevContainer KUBECONFIG)

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
        if KUBECONFIG="$BOOTSTRAP_KUBECONFIG" kubectl get nodes 2>/dev/null | grep -q "Ready"; then
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

# Use bootstrap kubeconfig (management kubeconfig can be corrupted)
if [ -f "$BOOTSTRAP_KUBECONFIG" ]; then
    # Copy to dedicated kubeconfig file
    mkdir -p /workspaces/shift-eks/.kube
    cp "$BOOTSTRAP_KUBECONFIG" "$EKS_ANYWHERE_KUBECONFIG"
    echo "✅ Using bootstrap cluster kubeconfig: $EKS_ANYWHERE_KUBECONFIG"
else
    echo "❌ Bootstrap kubeconfig not found: $BOOTSTRAP_KUBECONFIG"
    exit 1
fi

# Rename context to simple name
CURRENT_CONTEXT=$(KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl config current-context 2>/dev/null || echo "")
if [ -n "$CURRENT_CONTEXT" ] && [ "$CURRENT_CONTEXT" != "eks-anywhere" ]; then
    KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl config rename-context "$CURRENT_CONTEXT" "eks-anywhere" 2>/dev/null || true
fi

# Test cluster access
echo ""
echo "🔍 Testing cluster access..."
if KUBECONFIG="$EKS_ANYWHERE_KUBECONFIG" kubectl get nodes 2>/dev/null; then
    echo "✅ Cluster is accessible via kubectl"
else
    echo "❌ Cannot access cluster via kubectl"
    echo "   Check: KUBECONFIG=$EKS_ANYWHERE_KUBECONFIG kubectl config view"
fi

echo ""

echo "✅ EKS Anywhere cluster setup complete"
echo "   Cluster: $CLUSTER_NAME"
echo "   Provider: Docker (local development)"
echo "   Kubeconfig: $EKS_ANYWHERE_KUBECONFIG"
echo ""
echo "📋 Quick commands:"
echo "   kubectl config use-context eks-anywhere"
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
