# shift-eks

Multi-cluster Kubernetes development environment with OpenShift-compatible (OKD), EKS Anywhere, and EKS LocalStack.

## Overview

This DevContainer provides three Kubernetes cluster options for development and testing:

1. **OKD (OpenShift-compatible)** - Community distribution of OpenShift with 100% API compatibility
2. **EKS Anywhere** - AWS-curated Kubernetes distribution with Docker provider
3. **EKS LocalStack** - AWS EKS via LocalStack Pro for local AWS development

OKD and EKS Anywhere start automatically when the DevContainer launches. EKS LocalStack can be started manually via Ona Automations.

> **Note:** OKD provides full OpenShift API compatibility without requiring nested virtualization (KVM). It runs on kind (Kubernetes in Docker) with OpenShift components installed.

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

### Docker Engine

This environment requires Docker to run both clusters:
- ✅ Works in standard containers (Gitpod, DevContainers)
- ✅ Works on local machines with Docker installed
- ✅ No nested virtualization (KVM) required

### OKD vs OpenShift CRC

**OKD (Used in this environment):**
- ✅ 100% OpenShift API compatible
- ✅ Runs without nested virtualization
- ✅ Uses kind (Kubernetes in Docker)
- ✅ Includes OpenShift operators and CRDs
- ✅ Works in containers and cloud environments
- ⚠️ Community distribution (not commercially supported)

**OpenShift CRC (Alternative):**
- Requires nested virtualization (`/dev/kvm`)
- Full commercial OpenShift 4.x
- Only works on local machines or cloud VMs with KVM
- See `.devcontainer/start-openshift-crc.sh` for CRC setup (requires KVM)

## Quick Start

The clusters are automatically configured when you open this project in a DevContainer. After the container starts, you'll have:

- ✅ OKD cluster (OpenShift-compatible) running on kind
- ✅ EKS Anywhere cluster running (Docker provider)
- ✅ kubectl, oc, kind, aws, and eksctl anywhere CLI tools installed
- ✅ Kubeconfig automatically configured

**Note:** 
- First-time OKD setup takes 3-5 minutes
- EKS Anywhere cluster creation takes 10-15 minutes on first start
- EKS LocalStack requires manual start and LOCALSTACK_AUTH_TOKEN environment variable

## Ona Automations

This project includes Ona Automations for managing the Kubernetes clusters as services:

**Services:**
- `eks-anywhere` - Starts automatically on environment start
- `openshift-okd` - Starts automatically on environment start
- `eks-localstack` - Manual start (requires LOCALSTACK_AUTH_TOKEN)

**Managing Services:**
```bash
# List all services
gitpod automations service list

# Start a service manually
gitpod automations service start eks-localstack

# Stop a service
gitpod automations service stop eks-localstack

# View service logs
gitpod automations service logs eks-anywhere
```

See `.gitpod/automations.yaml` for service definitions.

## Helper Scripts

- **`cluster-manager.sh`** - Manage both clusters (start, stop, restart, switch)
- **`verify-setup.sh`** - Verify all tools are installed correctly
- **`.devcontainer/start-eks-anywhere.sh`** - Start EKS Anywhere cluster
- **`.devcontainer/start-openshift-okd.sh`** - Start OKD cluster
- **`.devcontainer/start-eks-localstack.sh`** - Start LocalStack EKS cluster

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

#### OKD Cluster (OpenShift-compatible)

```bash
# Check cluster status
kubectl get nodes
kind get clusters

# Use OpenShift CLI
oc get nodes
oc get pods --all-namespaces

# Check OpenShift-compatible features
kubectl get crds | grep openshift
kubectl get crds | grep operator

# View Operator Lifecycle Manager
kubectl get pods -n olm
kubectl get catalogsources -n olm

# Use kubectl (automatically configured)
kubectl get nodes
kubectl get pods --all-namespaces
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
- **oc** - OpenShift CLI (works with OKD)
- **kind** - Kubernetes in Docker
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

### OKD (OpenShift-compatible on kind)
- **Memory:** ~4 GB
- **CPUs:** 2 cores
- **Disk:** ~5 GB
- No nested virtualization required

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

### OKD cluster issues

```bash
# Check cluster status
kind get clusters
kubectl get nodes

# View cluster logs
docker logs okd-local-control-plane

# Delete and recreate OKD
kind delete cluster --name okd-local
bash .devcontainer/start-okd-single-node.sh

# Check OpenShift components
kubectl get crds | grep openshift
kubectl get pods -n olm
```

### Switching to OpenShift CRC (requires KVM)

If you have nested virtualization available:

```bash
# Check for KVM support
ls -la /dev/kvm

# If available, use CRC instead
bash .devcontainer/start-openshift-crc.sh

# Note: Requires pull secret at /usr/local/secrets/OPENSHIFT_PULL_SECRET
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

### OKD Cluster (OpenShift-compatible)
- Community distribution of OpenShift 4.x
- 100% OpenShift API compatible
- Runs on kind (Kubernetes in Docker)
- Includes OpenShift operators and CRDs:
  - Operator Lifecycle Manager (OLM)
  - OpenShift Routes CRD
  - OpenShift Projects CRD
  - OpenShift Router
- Compatible with both `kubectl` and `oc` commands
- No nested virtualization required

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