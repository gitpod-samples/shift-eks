# Quick Start Guide

Get up and running with OpenShift (CRC) and EKS (LocalStack) clusters in minutes.

## Step 1: Get Your Red Hat Pull Secret

**Required for OpenShift CRC**

1. Visit: [https://console.redhat.com/openshift/create/local](https://console.redhat.com/openshift/create/local)
2. Create a free Red Hat Developer account (if needed)
3. Click "Download pull secret"
4. Save the file

## Step 2: Rebuild the DevContainer

```bash
# This will install all tools and dependencies
gitpod devcontainer rebuild
```

Wait for the rebuild to complete (~5-10 minutes).

## Step 3: Configure Pull Secret

After the container rebuilds, run:

```bash
./setup-crc-pull-secret.sh
```

Choose option 1 or 2 to provide your pull secret.

## Step 4: Start the Clusters

The clusters should start automatically. If not:

```bash
./cluster-manager.sh start-all
```

**Note:** First-time CRC setup takes 10-15 minutes.

## Step 5: Verify Everything Works

```bash
# Check installation
./verify-setup.sh

# Check cluster status
./cluster-manager.sh status

# Test OpenShift
oc get nodes
oc projects

# Get OpenShift console credentials
crc console --credentials

# Test EKS
kubectl config use-context arn:aws:eks:us-east-1:000000000000:cluster/eks-local
kubectl get nodes
```

## Common Commands

### OpenShift (CRC)

```bash
# Check status
crc status

# Get console URL
crc console --url

# Get credentials
crc console --credentials

# View nodes
oc get nodes

# List projects
oc projects

# Create a new project
oc new-project my-project
```

### EKS (LocalStack)

```bash
# Switch to EKS context
kubectl config use-context arn:aws:eks:us-east-1:000000000000:cluster/eks-local

# List clusters
awslocal eks list-clusters

# Get cluster info
awslocal eks describe-cluster --name eks-local

# View nodes
kubectl get nodes
```

### Switching Between Clusters

```bash
# Using cluster-manager script
./cluster-manager.sh switch-os   # Switch to OpenShift
./cluster-manager.sh switch-eks  # Switch to EKS

# Using kubectx (easier!)
kubectx                          # List all contexts
kubectx kind-eks-local-eks-a-cluster  # Switch to EKS Anywhere
kubectx -                        # Switch to previous context

# Using kubens to switch namespaces
kubens                           # List all namespaces
kubens eksa-system              # Switch to eksa-system namespace
kubens -                         # Switch to previous namespace
```

## Troubleshooting

### CRC won't start

```bash
# Check logs
crc logs

# Try manual start
crc stop
crc start -p ~/.crc/pull-secret.json
```

### Pull secret issues

```bash
# Reconfigure pull secret
./setup-crc-pull-secret.sh

# Or manually
crc start
# Follow prompts
```

### LocalStack not responding

```bash
# Check container
docker ps | grep localstack

# Restart LocalStack
./cluster-manager.sh restart-eks

# View logs
./cluster-manager.sh logs-eks
```

### Out of resources

CRC requires significant resources:
- 16 GB RAM
- 6 CPU cores
- 100 GB disk

Adjust in `.devcontainer/post-create.sh`:
```bash
crc config set memory 12288  # Reduce to 12 GB
crc config set cpus 4        # Reduce to 4 cores
```

Then rebuild the container.

## Next Steps

- **OpenShift Console:** Access the web UI at the URL from `crc console --url`
- **Deploy Applications:** Use `oc new-app` or the web console
- **EKS Testing:** Deploy workloads to test AWS EKS compatibility
- **Multi-cluster:** Practice switching between clusters

## Resources

- [README.md](README.md) - Full documentation
- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [PULL_SECRET.md](PULL_SECRET.md) - Detailed pull secret guide
- [CHANGES.md](CHANGES.md) - What changed from kind to CRC
- [OpenShift Documentation](https://docs.openshift.com/)
- [LocalStack Documentation](https://docs.localstack.cloud/)

## Getting Help

If you encounter issues:

1. Check `./cluster-manager.sh status`
2. Run `./verify-setup.sh`
3. Review logs: `crc logs` or `./cluster-manager.sh logs-eks`
4. Consult the troubleshooting sections in README.md
