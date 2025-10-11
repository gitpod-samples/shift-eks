# EKS Anywhere in DevContainers - SOLVED ✅

## Problem

EKS Anywhere Docker provider initially failed inside devcontainers with:
```
ERROR: failed to create cluster: error reading file: open eks-local/generated/kind_tmp.yaml: no such file or directory
```

## Root Cause

EKS Anywhere creates a Docker container that runs `kind` to create the Kubernetes cluster. This container needs to access files created by EKS Anywhere, but those files must be in a location accessible to the host Docker daemon.

The issue occurred when using paths like `/home/vscode/clusters` which only exist inside the devcontainer, not on the host.

## Solution ✅

**Use a directory inside the project that is bind-mounted from the host.**

In Gitpod/devcontainers, the project directory (e.g., `/workspaces/shift-eks`) is bind-mounted from the host. By placing EKS Anywhere files inside this directory, both the devcontainer and host Docker containers can access them.

### Implementation

1. **Use project-relative path:**
   ```bash
   CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
   ```

2. **Add to .gitignore:**
   ```
   .eks-clusters/
   ```

3. **Run EKS Anywhere from this directory:**
   ```bash
   cd /workspaces/shift-eks/.eks-clusters
   eksctl anywhere create cluster -f eks-local-config.yaml
   ```

### Why This Works

- `/workspaces/shift-eks` is bind-mounted: `Source: /workspaces/shift-eks → Destination: /workspaces/shift-eks`
- EKS Anywhere mounts this path into its container: `-v /workspaces/shift-eks/.eks-clusters:/workspaces/shift-eks/.eks-clusters`
- The host Docker daemon can access files at this path
- Relative paths inside the EKS Anywhere container resolve correctly

## Verification

```bash
# Check running containers
docker ps | grep eks-local

# Expected output:
# - eks-local-mm9d4 (control plane)
# - eks-local-md-0-* (worker node)
# - eks-local-etcd-* (etcd)
# - eks-local-lb (load balancer)
# - eks-local-eks-a-cluster-control-plane (bootstrap cluster)

# Access cluster
export KUBECONFIG=/workspaces/shift-eks/.eks-clusters/eks-local/eks-local-eks-a-cluster.kubeconfig
kubectl get nodes
```

## Key Learnings

1. **Nested Docker requires careful path management** - Files must be in locations accessible to the host Docker daemon
2. **Use bind-mounted directories** - Project directories are typically bind-mounted and work well
3. **Avoid user home directories** - `/home/vscode/*` paths don't exist on the host
4. **Test with `docker inspect`** - Check mount points to understand what's accessible
