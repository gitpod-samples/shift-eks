# Next Steps

Your multi-cluster Kubernetes environment is configured and ready to build!

## Immediate Actions

### 1. Rebuild the DevContainer

```bash
gitpod devcontainer rebuild
```

**What this does:**
- Builds new Docker image with all tools
- Installs CRC, eksctl-anywhere, Docker CLI, etc.
- Takes ~5-10 minutes

**Expected output:**
- Image build completes successfully
- Container starts
- post-create.sh runs (configures CRC)
- start-clusters.sh runs (starts both clusters)

### 2. Get Red Hat Pull Secret

While the container is building, get your pull secret:

1. Visit: https://console.redhat.com/openshift/create/local
2. Create free Red Hat Developer account (if needed)
3. Click "Download pull secret"
4. Save the file

### 3. Configure Pull Secret

After container starts:

```bash
./setup-crc-pull-secret.sh
```

Follow the prompts to provide your pull secret.

### 4. Wait for Clusters

**First-time startup times:**
- EKS Anywhere: 5-10 minutes
- OpenShift CRC: 10-15 minutes

**Watch progress:**
```bash
# In one terminal
./cluster-manager.sh status

# Or watch Docker containers
docker ps --watch
```

### 5. Verify Everything Works

```bash
# Check installation
./verify-setup.sh

# Check cluster status
./cluster-manager.sh status

# Test OpenShift
oc get nodes

# Test EKS Anywhere
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig
kubectl get nodes
```

## Expected Timeline

```
T+0:00  - Start rebuild
T+0:05  - Image build complete
T+0:06  - Container starts
T+0:07  - post-create.sh completes
T+0:08  - start-clusters.sh begins
T+0:10  - EKS Anywhere starting
T+0:15  - EKS Anywhere ready
T+0:16  - OpenShift CRC starting
T+0:30  - OpenShift CRC ready
T+0:31  - Both clusters ready! 🎉
```

## What to Expect

### During Build

```
Building image...
[+] Building 300.0s
 => [1/7] FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04
 => [2/7] RUN apt-get update && apt-get install...
 => [3/7] RUN install Docker CLI...
 => [4/7] RUN install CRC...
 => [5/7] RUN install oc...
 => [6/7] RUN install eksctl-anywhere...
 => [7/7] RUN create directories...
```

### During First Start

```
🔧 Configuring environment...
⚙️  Configuring CRC...
✅ Configuration complete!

🚀 Starting Kubernetes clusters...
☸️  Starting EKS-like cluster (kind)...
📝 Generating EKS Anywhere cluster configuration...
🔨 Creating EKS Anywhere cluster (this may take 5-10 minutes)...
✅ Cluster created successfully

🔴 Starting OpenShift CRC cluster...
🚀 Starting CRC cluster (this may take several minutes)...
⚙️  Setting up CRC for the first time...
✅ CRC cluster started successfully
```

## If Something Goes Wrong

### Build Fails

```bash
# Check error message
# Common issues:
# - Network timeout: Retry rebuild
# - Permission error: Check Docker permissions
# - Disk space: Free up space

# Retry
gitpod devcontainer rebuild
```

### CRC Won't Start (No Pull Secret)

```bash
# Configure pull secret
./setup-crc-pull-secret.sh

# Or manually start
crc start
# Follow prompts
```

### EKS Anywhere Fails

```bash
# Check Docker resources
docker info

# Check logs
cat /tmp/eksa-create.log

# Retry
bash .devcontainer/start-eks.sh
```

### Out of Resources

```bash
# Check available resources
docker stats

# Reduce CRC resources
# Edit .devcontainer/post-create.sh:
crc config set memory 12288  # 12 GB instead of 16
crc config set cpus 4        # 4 cores instead of 6

# Rebuild
gitpod devcontainer rebuild
```

## After Everything Works

### Explore OpenShift

```bash
# Get console credentials
crc console --credentials

# Open web console
crc console --url

# Create a project
oc new-project demo

# Deploy an app
oc new-app httpd~https://github.com/sclorg/httpd-ex
```

### Explore EKS Anywhere

```bash
# Set kubeconfig
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig

# Check cluster
kubectl get nodes
kubectl get pods -A

# Deploy an app
kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --type=NodePort
```

### Test Multi-Cluster

```bash
# Deploy to OpenShift
oc config use-context openshift
kubectl create deployment app1 --image=nginx

# Deploy to EKS Anywhere
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig
kubectl create deployment app2 --image=nginx

# View both
./cluster-manager.sh status
```

## Useful Commands

### Cluster Management

```bash
# Status
./cluster-manager.sh status

# Switch clusters
./cluster-manager.sh switch-os
./cluster-manager.sh switch-eks

# Restart
./cluster-manager.sh restart-os
./cluster-manager.sh restart-eks

# Stop all
./cluster-manager.sh stop-all
```

### Docker

```bash
# View all containers
docker ps

# View specific cluster
docker ps --filter "name=crc"
docker ps --filter "name=eks-local"

# View logs
docker logs <container-name>
```

### Debugging

```bash
# Verify tools
which crc oc eksctl-anywhere kubectl docker

# Check versions
crc version
oc version
eksctl-anywhere version
kubectl version
docker version

# Check clusters
crc status
eksctl-anywhere get clusters
```

## Documentation to Read

1. **[FINAL_SUMMARY.md](FINAL_SUMMARY.md)** - Complete overview
2. **[QUICKSTART.md](QUICKSTART.md)** - Detailed getting started
3. **[EKS_ANYWHERE.md](EKS_ANYWHERE.md)** - EKS-A deep dive
4. **[DOCKER_SETUP.md](DOCKER_SETUP.md)** - Docker configuration

## Getting Help

### Check Status First

```bash
./cluster-manager.sh status
./verify-setup.sh
```

### Check Logs

```bash
# CRC logs
crc logs

# EKS-A logs
cat /tmp/eksa-create.log

# Docker logs
docker logs <container-name>
```

### Common Issues

See troubleshooting sections in:
- README.md
- FINAL_SUMMARY.md
- EKS_ANYWHERE.md

## Success Criteria

You'll know everything is working when:

✅ `./cluster-manager.sh status` shows both clusters running  
✅ `oc get nodes` shows OpenShift nodes  
✅ `kubectl get nodes` (with EKS-A kubeconfig) shows EKS nodes  
✅ `docker ps` shows containers for both clusters  
✅ No error messages in cluster startup  

## Ready?

**Run this command to start:**

```bash
gitpod devcontainer rebuild
```

Then follow the steps above. Good luck! 🚀
