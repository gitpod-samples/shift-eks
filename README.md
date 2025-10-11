# shift-eks

Multi-cluster Kubernetes development environment with OpenShift (CRC) and EKS Anywhere.

## Overview

This DevContainer provides two Kubernetes clusters for development and testing:

1. **OpenShift** - Full OpenShift 4.x cluster via CodeReady Containers (CRC)
2. **EKS Anywhere** - AWS-curated Kubernetes distribution with Docker provider

Both clusters start automatically when the DevContainer launches.

> **Note:** EKS Anywhere is AWS's official on-premises Kubernetes distribution. We use the Docker provider for local development, which is free and provides the same EKS Anywhere experience.

**📚 Documentation:**
- **[docs/FINAL_SUMMARY.md](docs/FINAL_SUMMARY.md)** - ⭐ Complete overview and summary
- **[docs/QUICKSTART.md](docs/QUICKSTART.md)** - Step-by-step getting started guide
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Technical architecture and design
- **[docs/EKS_ANYWHERE.md](docs/EKS_ANYWHERE.md)** - Complete guide to EKS Anywhere
- **[docs/EKS-ANYWHERE-SUCCESS.md](docs/EKS-ANYWHERE-SUCCESS.md)** - EKS Anywhere setup solution
- **[docs/DOCKER_SETUP.md](docs/DOCKER_SETUP.md)** - Docker configuration explained
- **[docs/PULL_SECRET.md](docs/PULL_SECRET.md)** - Red Hat pull secret setup

## Prerequisites

### Red Hat Pull Secret (Required for OpenShift)

CRC requires a pull secret from Red Hat. See [docs/PULL_SECRET.md](docs/PULL_SECRET.md) for detailed instructions.

**Quick Setup:**
```bash
# Run the helper script
./setup-crc-pull-secret.sh

# Or let CRC prompt you during first start
crc start
```

Get your free pull secret from: [https://console.redhat.com/openshift/create/local](https://console.redhat.com/openshift/create/local)

## Quick Start

The clusters are automatically configured when you open this project in a DevContainer. After the container starts, you'll have:

- ✅ OpenShift cluster (CRC) running
- ✅ EKS Anywhere cluster running (Docker provider)
- ✅ kubectl, oc, crc, and eksctl anywhere CLI tools installed
- ✅ Kubeconfig automatically configured

**Note:** 
- First-time CRC setup may take 10-15 minutes and requires a Red Hat pull secret
- EKS Anywhere cluster creation takes 10-15 minutes on first start

## Helper Scripts

- **`cluster-manager.sh`** - Manage both clusters (start, stop, restart, switch)
- **`setup-crc-pull-secret.sh`** - Interactive setup for Red Hat pull secret
- **`verify-setup.sh`** - Verify all tools are installed correctly

## Cluster Management

### Using the Cluster Manager

A helper script is provided for common operations:

```bash
# Check cluster status
./cluster-manager.sh status

# Switch between clusters
./cluster-manager.sh switch-os      # Switch to OpenShift
./cluster-manager.sh switch-eks     # Switch to EKS

# Restart clusters
./cluster-manager.sh restart-os     # Restart OpenShift
./cluster-manager.sh restart-eks    # Restart EKS/LocalStack

# Stop/Start all clusters
./cluster-manager.sh stop-all
./cluster-manager.sh start-all

# View LocalStack logs
./cluster-manager.sh logs-eks
```

### Manual Commands

#### OpenShift Cluster (CRC)

```bash
# Check CRC status
crc status

# Get console URL and credentials
crc console --credentials
crc console --url

# Use OpenShift CLI
oc get nodes
oc get pods --all-namespaces
oc projects

# Use kubectl (automatically configured)
kubectl get nodes
kubectl get pods --all-namespaces

# Access the web console
# URL: https://console-openshift-console.apps-crc.testing
# User: kubeadmin
# Password: (get from `crc console --credentials`)
```

#### EKS Anywhere Cluster

```bash
# Set kubeconfig
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig

# Use kubectl
kubectl get nodes
kubectl get pods --all-namespaces

# View cluster info
eksctl anywhere get clusters
kubectl cluster-info

# Upgrade cluster
eksctl anywhere upgrade cluster -f ~/clusters/eks-local-config.yaml
```

## Available Tools

- **kubectl** - Kubernetes CLI
- **oc** - OpenShift CLI
- **crc** - CodeReady Containers CLI
- **eksctl** - EKS Anywhere CLI (eksctl anywhere)
- **kubectx** - Switch between kubectl contexts easily
- **kubens** - Switch between Kubernetes namespaces easily
- **docker** - Docker CLI
- **docker-compose** - Docker Compose

### Context and Namespace Switching

Use `kubectx` and `kubens` for easy switching:

```bash
# List all contexts
kubectx

# Switch to a context
kubectx kind-eks-local-eks-a-cluster

# Switch to previous context
kubectx -

# List all namespaces
kubens

# Switch to a namespace
kubens eksa-system

# Switch to previous namespace
kubens -
```

## Configuration Files

- `.devcontainer/devcontainer.json` - DevContainer configuration with features
- `.devcontainer/Dockerfile` - Container image with all tools pre-installed
- `.devcontainer/post-create.sh` - Configuration script (runs once on container creation)
- `.devcontainer/start-clusters.sh` - Orchestrator for starting both clusters
- `.devcontainer/start-openshift-crc.sh` - OpenShift CRC startup script
- `.devcontainer/start-eks-anywhere.sh` - EKS Anywhere cluster startup script
- `~/.crc/` - CRC configuration directory
- `~/clusters/eks-local-config.yaml` - EKS Anywhere cluster configuration
- `~/clusters/eks-local/` - EKS Anywhere cluster files and kubeconfig

## Resource Requirements

### OpenShift (CRC)
- **Memory:** 16 GB (configured)
- **CPUs:** 6 cores (configured)
- **Disk:** 100 GB (configured)

These settings can be adjusted in `.devcontainer/post-create.sh` using `crc config set` commands.

### EKS Anywhere (Docker provider)
- **Memory:** ~4 GB
- **CPUs:** 2 cores
- **Disk:** ~5 GB

## Troubleshooting

### Clusters not starting

```bash
# Check Docker
docker ps

# Restart all clusters
./cluster-manager.sh stop-all
./cluster-manager.sh start-all
```

### EKS Anywhere cluster issues

```bash
# Check clusters
eksctl anywhere get clusters

# View cluster info
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig
kubectl cluster-info

# Restart cluster
./cluster-manager.sh restart-eks

# Delete and recreate
eksctl anywhere delete cluster eks-local
bash .devcontainer/start-eks-anywhere.sh

# Check Docker containers
docker ps --filter "name=eks-local"
```

### OpenShift CRC issues

```bash
# Check CRC status
crc status

# View CRC logs
crc logs

# Delete and recreate CRC
crc delete
crc setup
crc start

# Restart OpenShift
./cluster-manager.sh restart-os
```

### Pull secret issues

If CRC fails to start due to pull secret issues:

```bash
# Get your pull secret from https://console.redhat.com/openshift/create/local
# Then start CRC manually
crc start
# Follow the prompts to provide the pull secret
```

### Context issues

```bash
# List all contexts
kubectl config get-contexts
oc config get-contexts

# View current context
oc config current-context

# Switch context manually
# For OpenShift (context name varies)
oc config use-context $(oc config get-contexts -o name | grep crc)

# For EKS
kubectl config use-context arn:aws:eks:us-east-1:000000000000:cluster/eks-local
```

## Architecture

### OpenShift Cluster (CRC)
- Full OpenShift 4.x cluster via CodeReady Containers
- Single-node cluster optimized for local development
- Includes OpenShift web console
- Full OpenShift API and features
- Compatible with both `kubectl` and `oc` commands
- Requires Red Hat pull secret (free with Red Hat Developer account)

### EKS Anywhere Cluster
- AWS's official on-premises Kubernetes distribution
- Uses Docker provider for local development
- Same distribution used in production EKS Anywhere deployments
- AWS-curated Kubernetes with security patches
- Supports EKS Anywhere features (upgrades, packages, etc.)
- Can be upgraded to production providers (vSphere, Bare Metal, etc.)
- Free for development use

## Why EKS Anywhere?

EKS Anywhere is AWS's official on-premises Kubernetes distribution:

**Benefits:**
- ✅ **Official AWS distribution** - Same Kubernetes used in production EKS Anywhere
- ✅ **AWS-curated** - Security patches and updates from AWS
- ✅ **Free for development** - Docker provider is free (production providers require license)
- ✅ **Feature-complete** - Supports upgrades, curated packages, GitOps
- ✅ **Production parity** - Test code that will run on real EKS Anywhere
- ✅ **Upgrade path** - Can migrate to production providers later

**vs LocalStack EKS:**
- LocalStack EKS requires Pro license ($)
- EKS Anywhere is free for Docker provider
- EKS Anywhere is the real AWS distribution

**vs kind:**
- kind is generic Kubernetes
- EKS Anywhere is AWS-curated with EKS features
- EKS Anywhere supports AWS tooling and packages