#!/bin/bash
# Cluster management helper script

set -e

CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
EKS_CLUSTER_NAME="eks-local"
EKS_KUBECONFIG="${CLUSTERS_DIR}/${EKS_CLUSTER_NAME}/${EKS_CLUSTER_NAME}-eks-a-cluster.kubeconfig"

show_help() {
    cat <<EOF
Cluster Manager - Manage OpenShift (CRC) and EKS Anywhere clusters

Usage: ./cluster-manager.sh [command]

Commands:
    status          Show status of both clusters
    switch-os       Switch to OpenShift cluster
    switch-eks      Switch to EKS Anywhere cluster
    restart-os      Restart OpenShift CRC cluster
    restart-eks     Restart EKS Anywhere cluster
    stop-all        Stop all clusters
    start-all       Start all clusters
    logs-eks        Show EKS Anywhere logs
    help            Show this help message

Examples:
    ./cluster-manager.sh status
    ./cluster-manager.sh switch-os
    ./cluster-manager.sh restart-eks

Note: CRC requires a Red Hat pull secret on first start.
      Run ./setup-crc-pull-secret.sh to configure it.
      Get your pull secret from: https://console.redhat.com/openshift/create/local
EOF
}

check_status() {
    echo "═══════════════════════════════════════════════════════════"
    echo "📊 Cluster Status"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    
    # Check OpenShift CRC
    echo "🔴 OpenShift (CRC):"
    CRC_STATUS=$(crc status 2>&1 || echo "not-installed")
    if echo "$CRC_STATUS" | grep -q "Running"; then
        echo "   Status: ✅ Running"
        echo "   Console: $(crc console --url 2>/dev/null || echo 'N/A')"
        oc get nodes 2>/dev/null | tail -n +2 | sed 's/^/   /' || echo "   Nodes: ⚠️  Unable to connect"
    elif echo "$CRC_STATUS" | grep -q "Stopped"; then
        echo "   Status: ⚠️  Stopped"
    else
        echo "   Status: ❌ Not running"
    fi
    echo ""
    
    # Check EKS Anywhere cluster
    echo "🚀 EKS Anywhere (Docker):"
    if eksctl anywhere get clusters 2>/dev/null | grep -q "$EKS_CLUSTER_NAME"; then
        echo "   Status: ✅ Running"
        if [ -f "$EKS_KUBECONFIG" ]; then
            KUBECONFIG="$EKS_KUBECONFIG" kubectl get nodes 2>/dev/null | tail -n +2 | sed 's/^/   /' || echo "   Nodes: ⚠️  Unable to connect"
        else
            echo "   Kubeconfig: ⚠️  Not found"
        fi
    else
        echo "   Status: ❌ Not running"
    fi
    echo ""
    
    # Current context
    echo "📍 Current context:"
    oc config current-context 2>/dev/null || kubectl config current-context 2>/dev/null || echo "   None"
    echo ""
}

switch_openshift() {
    echo "🔄 Switching to OpenShift cluster..."
    OPENSHIFT_CONTEXT=$(oc config current-context 2>/dev/null)
    if [ -n "$OPENSHIFT_CONTEXT" ]; then
        oc config use-context "$OPENSHIFT_CONTEXT"
        echo "✅ Switched to OpenShift (context: $OPENSHIFT_CONTEXT)"
    else
        echo "❌ OpenShift context not found. Is CRC running?"
        exit 1
    fi
}

switch_eks() {
    echo "🔄 Switching to EKS Anywhere cluster..."
    if [ -f "$EKS_KUBECONFIG" ]; then
        export KUBECONFIG="$EKS_KUBECONFIG"
        echo "✅ Switched to EKS Anywhere"
        echo "   Run: export KUBECONFIG=$EKS_KUBECONFIG"
        echo "   Context: $(kubectl config current-context 2>/dev/null)"
    else
        echo "❌ EKS Anywhere kubeconfig not found"
        echo "   Expected: $EKS_KUBECONFIG"
        exit 1
    fi
}

restart_openshift() {
    echo "🔄 Restarting OpenShift CRC cluster..."
    crc stop 2>/dev/null || true
    sleep 5
    
    # Get script directory and use start-openshift-crc.sh
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/.devcontainer/start-openshift-crc.sh"
}

restart_eks() {
    echo "🔄 Restarting EKS Anywhere cluster..."
    
    # Delete existing cluster
    if eksctl anywhere get clusters 2>/dev/null | grep -q "$EKS_CLUSTER_NAME"; then
        echo "🗑️  Deleting existing cluster..."
        cd "${CLUSTERS_DIR}"
        eksctl anywhere delete cluster "$EKS_CLUSTER_NAME" 2>/dev/null || true
    fi
    
    sleep 2
    
    # Get script directory and use start-eks-anywhere.sh
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/.devcontainer/start-eks-anywhere.sh"
}

stop_all() {
    echo "🛑 Stopping all clusters..."
    crc stop 2>/dev/null || true
    
    if eksctl anywhere get clusters 2>/dev/null | grep -q "$EKS_CLUSTER_NAME"; then
        cd "${CLUSTERS_DIR}"
        eksctl anywhere delete cluster "$EKS_CLUSTER_NAME" 2>/dev/null || true
    fi
    
    echo "✅ All clusters stopped"
}

start_all() {
    echo "🚀 Starting all clusters..."
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Start both clusters
    bash "$SCRIPT_DIR/.devcontainer/start-eks-anywhere.sh"
    echo ""
    bash "$SCRIPT_DIR/.devcontainer/start-openshift-crc.sh"
    
    echo ""
    echo "✅ All clusters started"
}

show_logs() {
    echo "📋 EKS Anywhere cluster logs:"
    echo ""
    echo "Docker containers:"
    docker ps --filter "name=eks-local" --format "table {{.Names}}\t{{.Status}}"
    echo ""
    echo "To view logs for a specific container:"
    echo "  docker logs <container-name>"
    echo ""
    echo "Available containers:"
    docker ps --filter "name=eks-local" --format "{{.Names}}"
}

case "${1:-help}" in
    status)
        check_status
        ;;
    switch-os)
        switch_openshift
        ;;
    switch-eks)
        switch_eks
        ;;
    restart-os)
        restart_openshift
        ;;
    restart-eks)
        restart_eks
        ;;
    stop-all)
        stop_all
        ;;
    start-all)
        start_all
        ;;
    logs-eks)
        show_logs
        ;;
    help|*)
        show_help
        ;;
esac
