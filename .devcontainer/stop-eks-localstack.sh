#!/bin/bash
set -e

LOCALSTACK_CONTAINER="localstack-main"
EKS_CLUSTER_NAME="eks-localstack"
AWS_REGION="us-east-1"

echo "🛑 Stopping EKS LocalStack cluster..."

# Configure AWS CLI for LocalStack
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=${AWS_REGION}

# Try to delete EKS cluster
if docker ps --format '{{.Names}}' | grep -q "^${LOCALSTACK_CONTAINER}$"; then
    awslocal eks delete-cluster --name ${EKS_CLUSTER_NAME} 2>/dev/null || true
fi

# Stop and remove LocalStack container
docker stop ${LOCALSTACK_CONTAINER} 2>/dev/null || true
docker rm ${LOCALSTACK_CONTAINER} 2>/dev/null || true

echo "✅ EKS LocalStack cluster stopped"
