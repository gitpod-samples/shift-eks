# Docker Configuration

This document explains the Docker setup in the DevContainer.

## Configuration Choice

We use **Docker CLI with host socket mount** (not docker-in-docker or docker-outside-of-docker feature).

### What This Means

```
┌─────────────────────────────────────────┐
│ Host Machine                            │
│                                         │
│  ┌────────────────────────────────┐    │
│  │ Docker Daemon (Host)           │    │
│  └────────────────────────────────┘    │
│           ↑                             │
│           │ /var/run/docker.sock        │
│           │                             │
│  ┌────────┴───────────────────────┐    │
│  │ DevContainer                   │    │
│  │                                │    │
│  │  - Docker CLI installed        │    │
│  │  - Socket mounted from host    │    │
│  │  - Uses host Docker daemon     │    │
│  │                                │    │
│  │  ┌──────────────────────────┐  │    │
│  │  │ CRC / EKS-A containers   │  │    │
│  │  │ (run on host Docker)     │  │    │
│  │  └──────────────────────────┘  │    │
│  └────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Why Not Docker-in-Docker?

### Docker-in-Docker (DinD) Issues

❌ **Redundant** - Creates a separate Docker daemon inside the container  
❌ **Resource intensive** - Two Docker daemons running  
❌ **Complex** - Nested container management  
❌ **Storage issues** - Separate image storage  
❌ **Networking complexity** - Additional network layers  

### Docker-outside-of-Docker Benefits

✅ **Efficient** - Single Docker daemon (host)  
✅ **Simple** - Direct access to host Docker  
✅ **Shared images** - No duplicate image storage  
✅ **Better performance** - No nested virtualization  
✅ **Easier debugging** - `docker ps` shows all containers  

## How It Works

### Manual Docker Installation

Instead of using a feature (which had build issues), we install Docker CLI directly in the Dockerfile:

```dockerfile
# Install Docker CLI (not daemon - will use host Docker)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*
```

This installs:
1. Docker CLI (docker-ce-cli)
2. Docker Compose v2 (docker-compose-plugin)
3. Docker Buildx (docker-buildx-plugin)

Then we mount the socket in devcontainer.json:

```json
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
]
```

### Clean Configuration

**Before (redundant):**
```json
"features": {
  "ghcr.io/devcontainers/features/docker-in-docker:2": {}
},
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
]
```

**After (correct):**
```json
// Docker CLI installed in Dockerfile
"mounts": [
  "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
]
```

**Why not use docker-outside-of-docker feature?**
- The feature had build issues with /tmp permissions in some environments
- Manual installation is more reliable and explicit
- We have full control over what gets installed
- Same end result: Docker CLI using host daemon

## Impact on CRC and EKS Anywhere

### CRC (CodeReady Containers)

CRC creates containers/VMs for the OpenShift cluster:

```bash
# CRC containers run on host Docker
$ docker ps
CONTAINER ID   IMAGE                    NAMES
abc123...      quay.io/crc/...         crc-xxxxx
```

**Benefits:**
- CRC containers visible from host
- Can inspect/debug from host
- Shared network with host
- No nested virtualization

### EKS Anywhere

EKS-A Docker provider creates containers for cluster nodes:

```bash
# EKS-A containers run on host Docker
$ docker ps
CONTAINER ID   IMAGE                           NAMES
def456...      public.ecr.aws/eks-anywhere/... eks-local-control-plane
ghi789...      public.ecr.aws/eks-anywhere/... eks-local-md-0-xxx
```

**Benefits:**
- All cluster containers on host
- Easy to view logs: `docker logs <container>`
- Network accessible from host
- Efficient resource usage

## Privileged Mode

We still use `--privileged` mode:

```json
"runArgs": [
  "--privileged"
]
```

**Why?**
- CRC requires privileged mode for nested virtualization features
- EKS-A may need it for certain operations
- Allows full container capabilities

**Note:** This is safe in a development environment but should be reviewed for production use.

## Verification

After container starts, verify Docker setup:

```bash
# Check Docker is accessible
docker version

# Should show:
# Client: Docker CLI in container
# Server: Docker daemon on host

# Check containers
docker ps

# Should show CRC and EKS-A containers
```

## Troubleshooting

### Docker socket permission denied

```bash
# Check socket permissions
ls -la /var/run/docker.sock

# Should be accessible by vscode user
# Feature should handle this automatically
```

### Can't see containers

```bash
# Verify socket is mounted
mount | grep docker.sock

# Should show:
# /var/run/docker.sock on /var/run/docker.sock type socket
```

### Docker daemon not responding

```bash
# Check host Docker is running
docker info

# If fails, Docker daemon on host may be stopped
# Restart Docker Desktop or Docker service on host
```

## Comparison Table

| Feature | Docker-in-Docker | Docker-outside-of-Docker |
|---------|------------------|--------------------------|
| **Docker Daemon** | Separate (in container) | Host daemon |
| **Resource Usage** | High (2 daemons) | Low (1 daemon) |
| **Image Storage** | Duplicate | Shared |
| **Container Visibility** | Isolated | Visible from host |
| **Setup Complexity** | Complex | Simple |
| **Performance** | Slower (nested) | Faster (direct) |
| **Debugging** | Harder | Easier |
| **Use Case** | CI/CD isolation | Development |

## Best Practices

### Do ✅

- Use docker-outside-of-docker for development
- Let the feature handle socket mounting
- Use `docker ps` to see all containers
- Debug containers from host if needed

### Don't ❌

- Don't manually mount docker socket (feature does it)
- Don't use docker-in-docker unless you need isolation
- Don't mix DinD and socket mounting (redundant)
- Don't run production workloads this way

## Security Considerations

### Development Environment

✅ **Acceptable:**
- Sharing host Docker socket
- Running privileged containers
- Direct host Docker access

### Production Environment

⚠️ **Review needed:**
- Sharing Docker socket is a security risk
- Privileged mode should be avoided
- Consider proper isolation
- Use dedicated infrastructure

## Alternative: True Docker-in-Docker

If you need true isolation (e.g., for CI/CD):

```json
{
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {
      "moby": true,
      "dockerDashComposeVersion": "v2"
    }
  },
  "runArgs": ["--privileged"]
  // No socket mount
}
```

**When to use:**
- CI/CD pipelines
- Need container isolation
- Testing Docker itself
- Security requirements

**Trade-offs:**
- Higher resource usage
- Slower performance
- More complex setup
- Duplicate image storage

## Conclusion

For this project:
- ✅ **docker-outside-of-docker** is the right choice
- ✅ Efficient resource usage
- ✅ Simple architecture
- ✅ Works perfectly with CRC and EKS-A
- ✅ Easy debugging and management

The previous configuration with both DinD and socket mount was redundant and has been corrected.
