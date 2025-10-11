# Migration: LocalStack EKS to kind

## Why the Change?

During implementation, we discovered that **LocalStack's EKS service requires a Pro license** (paid subscription). The community/free edition does not include EKS support.

## Solution: kind Instead

We've replaced LocalStack EKS with **kind** (Kubernetes in Docker), which provides:

✅ **Real Kubernetes cluster** (not a simulation)  
✅ **Completely free and open source**  
✅ **Faster startup** (~15 seconds vs minutes)  
✅ **Lower resource usage** (~1 GB vs ~2 GB)  
✅ **EKS-like configuration** with appropriate labels  
✅ **Full Kubernetes API compatibility**  

## What Changed

### Removed
- LocalStack container and docker-compose configuration
- AWS CLI and awscli-local tools
- eksctl tool
- AWS environment variables
- LocalStack health checks and EKS cluster creation

### Added
- kind installation in Dockerfile
- Simple kind cluster creation
- EKS-like labels on nodes:
  - `eks.amazonaws.com/nodegroup`
  - `eks.amazonaws.com/capacityType`
  - `topology.kubernetes.io/region`
  - `topology.kubernetes.io/zone`

## Comparison

| Feature | LocalStack EKS (Pro) | kind |
|---------|---------------------|------|
| **Cost** | $$ (requires Pro license) | Free |
| **Type** | EKS simulation | Real Kubernetes |
| **Startup** | 2-3 minutes | 15-30 seconds |
| **Memory** | ~2 GB | ~1 GB |
| **AWS API** | Yes (simulated) | No |
| **Kubernetes API** | Limited | Full |
| **EKS Features** | Some | Labels only |
| **Production Parity** | Medium | High (for K8s) |

## Usage

### Before (LocalStack)
```bash
# Start LocalStack
docker-compose up -d

# Create EKS cluster
awslocal eks create-cluster --name eks-local ...

# Update kubeconfig
awslocal eks update-kubeconfig --name eks-local

# Switch context
kubectl config use-context arn:aws:eks:us-east-1:000000000000:cluster/eks-local
```

### After (kind)
```bash
# Create kind cluster
kind create cluster --name eks-local

# Context is automatically configured
kubectl config use-context eks-local

# Cluster is ready immediately
kubectl get nodes
```

## EKS-like Features

The kind cluster is configured with EKS-like labels:

```bash
$ kubectl get nodes --show-labels
NAME                      STATUS   ROLES           AGE   LABELS
eks-local-control-plane   Ready    control-plane   1m    eks.amazonaws.com/capacityType=ON_DEMAND,
                                                          eks.amazonaws.com/nodegroup=eks-local-nodegroup,
                                                          topology.kubernetes.io/region=us-east-1,
                                                          topology.kubernetes.io/zone=us-east-1a,
                                                          ...
```

This allows testing of workloads that rely on EKS-specific node labels.

## What You Can Still Do

### With kind ✅
- Test Kubernetes workloads
- Develop and debug applications
- Test Helm charts
- Practice kubectl commands
- Test node selectors and affinity rules
- Simulate multi-region with labels
- Test EKS-compatible workloads

### Not Available ❌
- AWS EKS API calls (CreateCluster, DescribeCluster, etc.)
- AWS IAM for service accounts (IRSA)
- AWS-specific integrations (ALB, EBS, EFS)
- EKS-managed node groups
- EKS add-ons

## If You Need Real EKS

If you need actual AWS EKS features:

### Option 1: Use Real AWS EKS
```bash
# Install eksctl
eksctl create cluster --name my-cluster --region us-east-1

# Costs apply for AWS resources
```

### Option 2: Purchase LocalStack Pro
- Visit: https://localstack.cloud/pricing
- Pro plan includes EKS support
- Update docker-compose to use Pro image
- Add LocalStack API key

### Option 3: Use EKS Anywhere
- On-premises EKS distribution
- Free for development
- More complex setup

## Migration for Existing Users

If you were expecting LocalStack EKS:

1. **No action needed** - kind works automatically
2. **Update scripts** - Replace `awslocal eks` with `kubectl`
3. **Update contexts** - Use `eks-local` instead of ARN
4. **Remove AWS CLI** - No longer needed for cluster management

## Benefits of This Change

1. **Lower barrier to entry** - No paid license required
2. **Faster development** - Quicker cluster startup
3. **Real Kubernetes** - Not a simulation, actual K8s
4. **Better compatibility** - Works with all K8s tools
5. **Simpler setup** - Fewer moving parts

## Technical Details

### Cluster Configuration
- **Name:** eks-local
- **Context:** eks-local
- **Kubernetes Version:** v1.27.3 (latest kind default)
- **Nodes:** 1 control-plane node
- **CNI:** kindnet (default)
- **Storage:** local-path provisioner

### Labels Applied
```yaml
eks.amazonaws.com/nodegroup: eks-local-nodegroup
eks.amazonaws.com/capacityType: ON_DEMAND
topology.kubernetes.io/region: us-east-1
topology.kubernetes.io/zone: us-east-1a
```

### Startup Script
Located at: `.devcontainer/start-eks.sh`

Key operations:
1. Check if cluster exists
2. Create cluster with kind
3. Rename context to `eks-local`
4. Apply EKS-like labels
5. Verify cluster is ready

## Troubleshooting

### Cluster won't start
```bash
# Check Docker
docker ps

# Check kind
kind get clusters

# Recreate cluster
kind delete cluster --name eks-local
bash .devcontainer/start-eks.sh
```

### Context issues
```bash
# List contexts
kubectl config get-contexts

# Switch to eks-local
kubectl config use-context eks-local
```

### Need AWS features
Consider using a real AWS account or LocalStack Pro for actual AWS service testing.

## Conclusion

This change provides a better developer experience:
- ✅ Free and open source
- ✅ Faster and lighter
- ✅ Real Kubernetes cluster
- ✅ EKS-compatible labels
- ✅ Simpler architecture

The trade-off is losing AWS-specific EKS features, but for Kubernetes development and testing, kind is superior and more practical.
