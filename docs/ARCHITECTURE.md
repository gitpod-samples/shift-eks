# Architecture

This document explains the structure and organization of the shift-eks project.

## Overview

The project provides a DevContainer-based environment with two Kubernetes clusters:
1. **OpenShift** via CodeReady Containers (CRC)
2. **EKS** via LocalStack

## Directory Structure

```
shift-eks/
├── .devcontainer/
│   ├── devcontainer.json      # DevContainer configuration
│   ├── Dockerfile              # Container image with all tools
│   ├── post-create.sh          # Configuration (runs once)
│   ├── start-clusters.sh       # Orchestrator for both clusters
│   ├── start-crc.sh            # CRC startup logic
│   └── start-eks.sh            # EKS/LocalStack startup logic
├── cluster-manager.sh          # CLI tool for cluster management
├── setup-crc-pull-secret.sh    # Interactive pull secret setup
├── verify-setup.sh             # Verify installation
└── Documentation files
```

## Component Responsibilities

### Build Time (Dockerfile)

**Purpose:** Install all tools and dependencies

**What it does:**
- Installs system packages (libvirt, qemu, networking tools)
- Installs CRC binary
- Installs OpenShift CLI (oc)
- Installs LocalStack and awscli-local
- Installs eksctl
- Creates necessary directories

**Why:** Installing at build time means:
- Faster container startup
- Consistent tool versions
- No network dependencies at runtime
- Immutable infrastructure

### Configuration Time (post-create.sh)

**Purpose:** Configure the environment (runs once per container)

**What it does:**
- Configures CRC settings (memory, CPU, disk)
- Creates LocalStack docker-compose configuration
- Sets up directory structure

**Why:** Separating configuration from installation allows:
- Easy customization without rebuilding
- User-specific settings
- Dynamic configuration based on environment

### Startup Time (start-*.sh)

**Purpose:** Start and configure clusters (runs on every container start)

#### start-clusters.sh (Orchestrator)
- Calls start-eks.sh
- Calls start-crc.sh
- Displays summary

#### start-crc.sh
- Checks if CRC is running
- Runs `crc setup` if needed
- Starts CRC with pull secret
- Configures kubeconfig
- Logs in to cluster

#### start-eks.sh
- Starts LocalStack container
- Waits for LocalStack to be ready
- Creates EKS cluster
- Updates kubeconfig

**Why separate scripts:**
- Modular and maintainable
- Can be run independently
- Easier to debug
- Clear separation of concerns

## Lifecycle Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Container Build (Dockerfile)                             │
│    - Install all tools                                       │
│    - Set up base environment                                 │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Container Creation (post-create.sh)                      │
│    - Configure CRC settings                                  │
│    - Create LocalStack config                                │
│    - One-time setup                                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Container Start (start-clusters.sh)                      │
│    ├─→ start-eks.sh                                         │
│    │   - Start LocalStack                                    │
│    │   - Create EKS cluster                                  │
│    └─→ start-crc.sh                                         │
│        - Start CRC                                           │
│        - Login to OpenShift                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. Ready for Use                                            │
│    - Both clusters running                                   │
│    - Kubeconfig configured                                   │
│    - Ready for development                                   │
└─────────────────────────────────────────────────────────────┘
```

## DevContainer Features

The project uses official DevContainer features for common tools:

### docker-outside-of-docker
- Installs Docker CLI in the container
- Connects to host Docker daemon (not Docker-in-Docker)
- Automatically mounts `/var/run/docker.sock`
- Less resource usage than DinD
- Required for CRC and EKS Anywhere to create containers

**Why not Docker-in-Docker?**
- DinD creates a separate Docker daemon (redundant)
- More resource intensive
- CRC and EKS-A work fine with host Docker
- Simpler architecture

### kubectl-helm-minikube
- Installs kubectl and helm
- Provides Kubernetes CLI tools
- Version: latest

## Environment Variables

Set in `devcontainer.json`:

```json
"remoteEnv": {
  "AWS_ACCESS_KEY_ID": "test",
  "AWS_SECRET_ACCESS_KEY": "test",
  "AWS_DEFAULT_REGION": "us-east-1"
}
```

These configure the AWS CLI to work with LocalStack.

## Cluster Management

### cluster-manager.sh

A convenience script that wraps common operations:

```bash
./cluster-manager.sh status      # Check both clusters
./cluster-manager.sh switch-os   # Switch to OpenShift
./cluster-manager.sh switch-eks  # Switch to EKS
./cluster-manager.sh restart-os  # Restart CRC
./cluster-manager.sh restart-eks # Restart LocalStack
./cluster-manager.sh stop-all    # Stop both clusters
./cluster-manager.sh start-all   # Start both clusters
```

Internally, it uses the same start-*.sh scripts for consistency.

## Configuration Customization

### Adjusting CRC Resources

Edit `.devcontainer/post-create.sh`:

```bash
crc config set memory 12288   # 12 GB instead of 16 GB
crc config set cpus 4         # 4 cores instead of 6
crc config set disk-size 80   # 80 GB instead of 100 GB
```

### Adjusting LocalStack Services

Edit the docker-compose configuration in `post-create.sh`:

```yaml
environment:
  - SERVICES=eks,ec2,iam,sts,cloudformation,s3,dynamodb
```

### Changing Tool Versions

Edit `.devcontainer/Dockerfile`:

```dockerfile
ARG CRC_VERSION=2.42.0  # Update version
```

Then rebuild the container.

## Error Handling

Each script includes error handling:

- **start-crc.sh**: Checks for pull secret, provides helpful messages
- **start-eks.sh**: Waits for LocalStack health, retries operations
- **start-clusters.sh**: Reports status of each cluster independently

Scripts use exit codes:
- `0`: Success
- `1`: Failure

The orchestrator continues even if one cluster fails, allowing partial functionality.

## Debugging

### Check Individual Components

```bash
# Test CRC startup
bash .devcontainer/start-crc.sh

# Test EKS startup
bash .devcontainer/start-eks.sh

# Check tool installations
./verify-setup.sh
```

### View Logs

```bash
# CRC logs
crc logs

# LocalStack logs
docker logs localstack-eks

# Docker logs
docker ps -a
```

### Manual Operations

All scripts can be run manually for testing:

```bash
# Configuration
bash .devcontainer/post-create.sh

# Start clusters
bash .devcontainer/start-clusters.sh

# Individual clusters
bash .devcontainer/start-crc.sh
bash .devcontainer/start-eks.sh
```

## Design Principles

1. **Separation of Concerns**
   - Build vs Configure vs Start
   - CRC vs EKS logic separated

2. **Idempotency**
   - Scripts can be run multiple times safely
   - Check before creating/starting

3. **Fail-Safe**
   - One cluster failure doesn't block the other
   - Helpful error messages

4. **Modularity**
   - Each script has a single responsibility
   - Can be used independently

5. **Maintainability**
   - Clear file organization
   - Documented configuration
   - Consistent patterns

## Future Enhancements

Possible improvements:

- Parallel cluster startup
- Health check endpoints
- Automatic retry logic
- Cluster state persistence
- Multi-cluster configurations
- Alternative OpenShift options (OKD, Microshift)
