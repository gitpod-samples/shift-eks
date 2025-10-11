# EKS Anywhere Setup - SUCCESS ✅

## Summary

EKS Anywhere with Docker provider is now working inside the devcontainer!

## Key Solution

The critical fix was using a directory inside the project that is bind-mounted from the host:

```bash
CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
```

This allows both the devcontainer and host Docker daemon to access the same files.

## Installation Details

### Required Components
1. **eksctl** - Main CLI from eksctl-io/eksctl
2. **eksctl-anywhere** - Plugin for EKS Anywhere

Both are installed in the Dockerfile:
```dockerfile
# Install eksctl (required for eksctl-anywhere plugin)
RUN curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
    | tar xz -C /tmp \
    && mv /tmp/eksctl /usr/local/bin/eksctl \
    && chmod +x /usr/local/bin/eksctl

# Install eksctl-anywhere plugin
ARG EKSA_VERSION=0.23.3
RUN curl -Lo /tmp/eksctl-anywhere.tar.gz \
    "https://github.com/aws/eks-anywhere/releases/download/v${EKSA_VERSION}/eksctl-anywhere-v${EKSA_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/eksctl-anywhere.tar.gz -C /tmp \
    && mv /tmp/eksctl-anywhere /usr/local/bin/eksctl-anywhere \
    && chmod +x /usr/local/bin/eksctl-anywhere \
    && rm -f /tmp/eksctl-anywhere.tar.gz
```

## Usage

### Verify Installation
```bash
eksctl anywhere version
```

### Create Cluster
```bash
cd /workspaces/shift-eks/.eks-clusters
eksctl anywhere generate clusterconfig eks-local --provider docker > eks-local-config.yaml
eksctl anywhere create cluster -f eks-local-config.yaml
```

### Access Cluster
```bash
export KUBECONFIG=/workspaces/shift-eks/.eks-clusters/eks-local/eks-local-eks-a-cluster.kubeconfig
kubectl get nodes
kubectl get pods -A
```

### Check Cluster Status
```bash
eksctl anywhere get clusters
docker ps | grep eks-local
```

## Cluster Components

When running, you'll see these Docker containers:
- `eks-local-mm9d4` - Control plane node
- `eks-local-md-0-*` - Worker node(s)
- `eks-local-etcd-*` - External etcd
- `eks-local-lb` - Load balancer (HAProxy)
- `eks-local-eks-a-cluster-control-plane` - Bootstrap cluster (kind)

## Automated Startup

The cluster is automatically started via:
- `.devcontainer/start-eks-anywhere.sh` - Creates/starts EKS Anywhere cluster
- `.devcontainer/start-openshift-crc.sh` - Creates/starts OpenShift CRC cluster
- `.devcontainer/start-clusters.sh` - Orchestrates both CRC and EKS-A startup
- `postStartCommand` in devcontainer.json

## Management

Use the `cluster-manager.sh` script:
```bash
./cluster-manager.sh status        # Check both clusters
./cluster-manager.sh switch-eks    # Switch to EKS Anywhere
./cluster-manager.sh restart-eks   # Restart EKS Anywhere cluster
```

## Technical Notes

### Why This Works
1. Project directory `/workspaces/shift-eks` is bind-mounted from host
2. EKS Anywhere creates files in `/workspaces/shift-eks/.eks-clusters`
3. When EKS Anywhere launches Docker containers, it mounts this path
4. Host Docker daemon can access the bind-mounted directory
5. Relative paths resolve correctly inside nested containers

### Path Resolution
```
Host: /workspaces/shift-eks/.eks-clusters
  ↓ (bind mount)
DevContainer: /workspaces/shift-eks/.eks-clusters
  ↓ (volume mount by EKS Anywhere)
EKS-A Container: /workspaces/shift-eks/.eks-clusters
  ↓ (relative paths)
Kind: eks-local/generated/kind_tmp.yaml ✅
```

### What Doesn't Work
- Using `/home/vscode/clusters` - Not accessible to host Docker
- Using Docker volumes - Path mismatch between devcontainer and host
- Using `/tmp` or other non-mounted paths

## Troubleshooting

### Check if cluster is running
```bash
docker ps | grep eks-local
```

### View EKS Anywhere logs
```bash
ls -la /workspaces/shift-eks/.eks-clusters/eksa-cli-logs/
cat /workspaces/shift-eks/.eks-clusters/eksa-cli-logs/*.log | tail -50
```

### Check kubeconfig
```bash
ls -la /workspaces/shift-eks/.eks-clusters/eks-local/*.kubeconfig
```

### Verify Docker mounts
```bash
docker inspect $(docker ps | grep eksa_ | awk '{print $1}') | jq '.[0].Mounts'
```

## Resources

- [EKS Anywhere Documentation](https://anywhere.eks.amazonaws.com/docs/)
- [Docker Provider Guide](https://anywhere.eks.amazonaws.com/docs/getting-started/docker/)
- [eksctl anywhere CLI Reference](https://anywhere.eks.amazonaws.com/docs/reference/eksctl/)
