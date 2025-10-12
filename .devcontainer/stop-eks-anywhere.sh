#!/bin/bash
set -e

CLUSTER_NAME="eks-local"

echo "🛑 Stopping EKS Anywhere cluster..."

# Try to delete cluster using eksctl
if command -v eksctl >/dev/null 2>&1; then
    eksctl anywhere delete cluster ${CLUSTER_NAME} 2>/dev/null || true
fi

# Stop and remove any containers
for container in $(docker ps -aq --filter "name=${CLUSTER_NAME}"); do
    docker rm -f "$container" 2>/dev/null || true
done

echo "✅ EKS Anywhere cluster stopped"
