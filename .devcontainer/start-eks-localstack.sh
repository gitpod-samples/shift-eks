#!/bin/bash
set -e

echo "🟣 Starting LocalStack EKS cluster..."
echo ""

# LocalStack EKS requires Pro/Ultimate plan
LOCALSTACK_CONTAINER="localstack-main"
EKS_CLUSTER_NAME="eks-localstack"
AWS_REGION="us-east-1"

# Check for LocalStack auth token
if [ -z "$LOCALSTACK_AUTH_TOKEN" ]; then
    echo "❌ LOCALSTACK_AUTH_TOKEN environment variable not set"
    echo ""
    echo "📋 LocalStack EKS requires Pro or Ultimate plan"
    echo ""
    echo "To set up:"
    echo "  1. Get your auth token from: https://app.localstack.cloud/workspace/auth-token"
    echo "  2. Set environment variable: export LOCALSTACK_AUTH_TOKEN=your-token"
    echo "  3. Or add to your shell profile (~/.bashrc, ~/.zshrc)"
    echo ""
    return 1 2>/dev/null || exit 1
fi

# Check if LocalStack container is already running
if docker ps --format '{{.Names}}' | grep -q "^${LOCALSTACK_CONTAINER}$"; then
    echo "✅ LocalStack container already running"
else
    # Check if container exists but is stopped
    if docker ps -a --format '{{.Names}}' | grep -q "^${LOCALSTACK_CONTAINER}$"; then
        echo "🔄 Starting existing LocalStack container..."
        docker start ${LOCALSTACK_CONTAINER}
        sleep 5
    else
        echo "🚀 Starting LocalStack container..."
        echo "   This will take 1-2 minutes..."
        
        docker run -d \
            --name ${LOCALSTACK_CONTAINER} \
            -p 4566:4566 \
            -p 4510-4559:4510-4559 \
            -e LOCALSTACK_AUTH_TOKEN="${LOCALSTACK_AUTH_TOKEN}" \
            -e DEBUG=1 \
            -e SERVICES=eks,ec2,iam,sts \
            -e DOCKER_HOST=unix:///var/run/docker.sock \
            -v /var/run/docker.sock:/var/run/docker.sock \
            localstack/localstack-pro:latest
        
        echo "⏳ Waiting for LocalStack to be ready..."
        sleep 30
    fi
fi

# Wait for LocalStack to be ready
echo "⏳ Checking LocalStack health..."
for i in {1..60}; do
    if curl -s http://localhost:4566/_localstack/health 2>/dev/null | grep -q "pro\|community"; then
        echo "✅ LocalStack is ready"
        break
    fi
    if [ $i -eq 60 ]; then
        echo "❌ Timeout waiting for LocalStack to be ready"
        echo "   Check logs: docker logs ${LOCALSTACK_CONTAINER}"
        return 1 2>/dev/null || exit 1
    fi
    sleep 2
done

# Configure AWS CLI for LocalStack
echo "🔧 Configuring AWS CLI for LocalStack..."
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=${AWS_REGION}
export AWS_ENDPOINT_URL=http://localhost:4566

# Configure awslocal (it automatically uses localhost:4566)
mkdir -p ~/.aws
cat > ~/.aws/config <<EOF
[default]
region = ${AWS_REGION}
output = json
EOF

cat > ~/.aws/credentials <<EOF
[default]
aws_access_key_id = test
aws_secret_access_key = test
EOF

# Check if EKS cluster already exists
echo "🔍 Checking for existing EKS cluster..."
if awslocal eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} 2>/dev/null | grep -q "ACTIVE"; then
    echo "✅ EKS cluster '${EKS_CLUSTER_NAME}' already exists and is active"
else
    echo "🚀 Creating EKS cluster..."
    echo "   This will take 2-3 minutes..."
    
    # Create VPC and subnets (required for EKS)
    echo "📦 Creating VPC..."
    VPC_ID=$(awslocal ec2 create-vpc --cidr-block 10.0.0.0/16 --region ${AWS_REGION} --query 'Vpc.VpcId' --output text)
    echo "   VPC ID: ${VPC_ID}"
    
    echo "📦 Creating subnets..."
    SUBNET1_ID=$(awslocal ec2 create-subnet --vpc-id ${VPC_ID} --cidr-block 10.0.1.0/24 --availability-zone ${AWS_REGION}a --region ${AWS_REGION} --query 'Subnet.SubnetId' --output text)
    SUBNET2_ID=$(awslocal ec2 create-subnet --vpc-id ${VPC_ID} --cidr-block 10.0.2.0/24 --availability-zone ${AWS_REGION}b --region ${AWS_REGION} --query 'Subnet.SubnetId' --output text)
    echo "   Subnet 1: ${SUBNET1_ID}"
    echo "   Subnet 2: ${SUBNET2_ID}"
    
    # Create IAM role for EKS
    echo "📦 Creating IAM role..."
    awslocal iam create-role \
        --role-name eks-cluster-role \
        --assume-role-policy-document '{
            "Version": "2012-10-17",
            "Statement": [{
                "Effect": "Allow",
                "Principal": {"Service": "eks.amazonaws.com"},
                "Action": "sts:AssumeRole"
            }]
        }' --region ${AWS_REGION} 2>/dev/null || echo "   Role may already exist"
    
    ROLE_ARN=$(awslocal iam get-role --role-name eks-cluster-role --region ${AWS_REGION} --query 'Role.Arn' --output text)
    echo "   Role ARN: ${ROLE_ARN}"
    
    # Create EKS cluster
    echo "📦 Creating EKS cluster '${EKS_CLUSTER_NAME}'..."
    awslocal eks create-cluster \
        --name ${EKS_CLUSTER_NAME} \
        --role-arn ${ROLE_ARN} \
        --resources-vpc-config subnetIds=${SUBNET1_ID},${SUBNET2_ID} \
        --region ${AWS_REGION}
    
    # Wait for cluster to be active
    echo "⏳ Waiting for cluster to be active..."
    for i in {1..60}; do
        STATUS=$(awslocal eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query 'cluster.status' --output text 2>/dev/null || echo "CREATING")
        if [ "$STATUS" = "ACTIVE" ]; then
            echo "✅ Cluster is active"
            break
        fi
        if [ $i -eq 60 ]; then
            echo "⚠️  Cluster creation is taking longer than expected"
            echo "   Status: ${STATUS}"
        fi
        sleep 3
    done
fi

# Extract kubeconfig from k3d inside LocalStack
echo "🔧 Extracting kubeconfig from k3d cluster..."
mkdir -p "${CLUSTERS_DIR}/eks-localstack"
docker exec ${LOCALSTACK_CONTAINER} /var/lib/localstack/lib/k3d/v5.8.3/k3d-linux-amd64 kubeconfig write eks-localstack -o - > "${KUBECONFIG_PATH}"

# Get the actual Kubernetes API endpoint
K8S_ENDPOINT=$(awslocal eks describe-cluster --name ${EKS_CLUSTER_NAME} --region ${AWS_REGION} --query 'cluster.endpoint' --output text)
echo "   Kubernetes API: ${K8S_ENDPOINT}"
echo "   Kubeconfig: ${KUBECONFIG_PATH}"

# Set KUBECONFIG environment variable
export KUBECONFIG="${KUBECONFIG_PATH}"

echo ""
echo "✅ LocalStack EKS cluster ready"
echo "   Cluster: ${EKS_CLUSTER_NAME}"
echo "   Region: ${AWS_REGION}"
echo "   Endpoint: http://localhost:4566"
echo ""
echo "🔍 Verify with:"
echo "   kubectl get nodes"
echo "   awslocal eks describe-cluster --name ${EKS_CLUSTER_NAME}"
echo "   kubectl cluster-info"
echo ""
echo "📚 LocalStack EKS features:"
echo "   • Full EKS API compatibility"
echo "   • Local development without AWS costs"
echo "   • Fast cluster creation (2-3 minutes)"
echo "   • Works with standard kubectl and AWS CLI"
echo ""
echo "💡 Useful commands:"
echo "   docker logs ${LOCALSTACK_CONTAINER}  # View LocalStack logs"
echo "   awslocal eks list-clusters           # List all clusters"
echo ""

# Keep the service running by monitoring the LocalStack container
echo "🔄 Monitoring LocalStack container..."
while docker ps --format '{{.Names}}' | grep -q "^${LOCALSTACK_CONTAINER}$"; do
    sleep 10
done

echo "❌ LocalStack container stopped"
return 1 2>/dev/null || exit 1
