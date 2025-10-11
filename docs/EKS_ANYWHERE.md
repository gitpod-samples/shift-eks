# EKS Anywhere (EKS-A)

This document explains EKS Anywhere and why we use it for the second cluster.

## What is EKS Anywhere?

**EKS Anywhere** is AWS's official distribution of Kubernetes for on-premises and edge deployments. It's the same Kubernetes distribution that powers AWS EKS, but designed to run anywhere.

### Key Features

- **AWS-curated Kubernetes** - Security patches and updates from AWS
- **Multiple providers** - vSphere, Bare Metal, CloudStack, Nutanix, Snow, Docker
- **Curated packages** - Pre-tested add-ons (Harbor, Prometheus, MetalLB, etc.)
- **Lifecycle management** - Automated upgrades and cluster management
- **GitOps support** - Built-in Flux integration
- **EKS Console integration** - Optional connection to AWS EKS console

## Docker Provider

For local development, EKS Anywhere supports a **Docker provider** that runs the cluster in Docker containers (similar to kind).

### Benefits of Docker Provider

✅ **Free** - No license required for development use  
✅ **Fast** - Cluster creation in 5-10 minutes  
✅ **Lightweight** - Runs on laptop/workstation  
✅ **Full features** - All EKS Anywhere capabilities  
✅ **Production parity** - Same distribution as production  

### Limitations

⚠️ **Development only** - Not for production use  
⚠️ **Single node** - Limited scalability  
⚠️ **No HA** - No high availability  

## Why EKS Anywhere vs Alternatives?

### vs LocalStack EKS

| Feature | LocalStack EKS | EKS Anywhere |
|---------|---------------|--------------|
| **Cost** | Pro license required ($) | Free (Docker provider) |
| **Type** | Simulation | Real AWS distribution |
| **AWS API** | Simulated | N/A (not cloud EKS) |
| **Kubernetes** | Standard | AWS-curated |
| **Production use** | No | Yes (with other providers) |

### vs kind

| Feature | kind | EKS Anywhere |
|---------|------|--------------|
| **Cost** | Free | Free (Docker provider) |
| **Type** | Generic K8s | AWS-curated K8s |
| **Lifecycle** | Manual | Automated (eksctl) |
| **Packages** | Manual | Curated packages |
| **Upgrades** | Recreate cluster | In-place upgrades |
| **Production path** | None | Migrate to other providers |

### vs Minikube

| Feature | Minikube | EKS Anywhere |
|---------|----------|--------------|
| **Cost** | Free | Free (Docker provider) |
| **Purpose** | Learning/dev | Dev + Production |
| **Distribution** | Generic | AWS-curated |
| **Features** | Basic | Enterprise-grade |
| **Scalability** | Limited | Production-ready |

## Architecture

### Cluster Components

```
┌─────────────────────────────────────────┐
│ EKS Anywhere Cluster (Docker Provider)  │
├─────────────────────────────────────────┤
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Control Plane Node (Container)   │  │
│  │  - API Server                    │  │
│  │  - Controller Manager            │  │
│  │  - Scheduler                     │  │
│  │  - etcd                          │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Worker Node (Container)          │  │
│  │  - kubelet                       │  │
│  │  - Container runtime             │  │
│  │  - CNI (Cilium)                  │  │
│  └──────────────────────────────────┘  │
│                                         │
└─────────────────────────────────────────┘
```

### Management

- **eksctl anywhere** - CLI for cluster lifecycle
- **Cluster API** - Underlying cluster management
- **Cilium** - Default CNI (Container Network Interface)
- **Bottlerocket/Ubuntu** - Node OS options

## Usage

### Basic Commands

```bash
# List clusters
eksctl anywhere get clusters

# Get cluster info
eksctl anywhere describe cluster eks-local

# Upgrade cluster
eksctl anywhere upgrade cluster -f ~/clusters/eks-local-config.yaml

# Delete cluster
eksctl anywhere delete cluster eks-local
```

### Kubeconfig

EKS Anywhere creates a separate kubeconfig file:

```bash
# Set kubeconfig
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig

# Use kubectl
kubectl get nodes
kubectl get pods -A
```

### Cluster Configuration

The cluster is defined in a YAML file:

```yaml
apiVersion: anywhere.eks.amazonaws.com/v1alpha1
kind: Cluster
metadata:
  name: eks-local
spec:
  kubernetesVersion: "1.28"
  controlPlaneConfiguration:
    count: 1
  workerNodeGroupConfigurations:
  - count: 1
    name: md-0
  datacenterRef:
    kind: DockerDatacenterConfig
    name: eks-local
  clusterNetwork:
    cniConfig:
      cilium: {}
```

## Curated Packages

EKS Anywhere includes curated packages that are pre-tested and supported:

### Available Packages

- **Harbor** - Container registry
- **Prometheus** - Monitoring
- **MetalLB** - Load balancer
- **Cert-Manager** - Certificate management
- **ADOT** - AWS Distro for OpenTelemetry
- **Emissary** - API Gateway
- **Cluster Autoscaler** - Auto-scaling

### Installing Packages

```bash
# List available packages
eksctl anywhere list packages

# Install a package
eksctl anywhere create package harbor \
  --cluster eks-local \
  -f harbor-config.yaml
```

## Lifecycle Management

### Upgrades

EKS Anywhere supports in-place cluster upgrades:

```bash
# Edit cluster config to new version
vim ~/clusters/eks-local-config.yaml
# Change kubernetesVersion: "1.29"

# Upgrade cluster
eksctl anywhere upgrade cluster -f ~/clusters/eks-local-config.yaml
```

### Scaling

```bash
# Edit worker count in config
vim ~/clusters/eks-local-config.yaml
# Change workerNodeGroupConfigurations[0].count: 3

# Apply changes
eksctl anywhere upgrade cluster -f ~/clusters/eks-local-config.yaml
```

## Production Migration

The Docker provider is for development. For production, migrate to:

### vSphere Provider
- VMware vSphere infrastructure
- Enterprise-grade
- Most common production provider

### Bare Metal Provider
- Physical servers
- Maximum performance
- Edge deployments

### CloudStack Provider
- Apache CloudStack
- Private cloud

### Nutanix Provider
- Nutanix AHV
- Hyperconverged infrastructure

### Snow Provider
- AWS Snowball Edge
- Disconnected environments

## Comparison with Cloud EKS

| Feature | Cloud EKS | EKS Anywhere |
|---------|-----------|--------------|
| **Location** | AWS Cloud | On-premises/Edge |
| **Management** | AWS-managed | Self-managed |
| **Control plane** | AWS-managed | Customer-managed |
| **Kubernetes** | AWS-curated | AWS-curated |
| **Updates** | Automatic | Manual (eksctl) |
| **Cost** | Per hour | License (prod) |
| **Networking** | VPC | Customer network |
| **Storage** | EBS/EFS | Customer storage |

## Resources

### Documentation
- [EKS Anywhere Docs](https://anywhere.eks.amazonaws.com/docs/)
- [Docker Provider Guide](https://anywhere.eks.amazonaws.com/docs/getting-started/docker/)
- [Curated Packages](https://anywhere.eks.amazonaws.com/docs/packages/)

### GitHub
- [EKS Anywhere](https://github.com/aws/eks-anywhere)
- [EKS Distro](https://github.com/aws/eks-distro)

### Community
- [EKS Anywhere Slack](https://eksanywhere.slack.com/)
- [AWS Containers Blog](https://aws.amazon.com/blogs/containers/)

## Troubleshooting

### Cluster won't start

```bash
# Check Docker resources
docker stats

# Check Docker containers
docker ps --filter "name=eks-local"

# View logs
docker logs <container-name>

# Check eksctl logs
cat /tmp/eksa-create.log
```

### Kubeconfig issues

```bash
# Verify kubeconfig exists
ls -la ~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig

# Set kubeconfig
export KUBECONFIG=~/clusters/eks-local/eks-local-eks-a-cluster.kubeconfig

# Test connection
kubectl get nodes
```

### Resource constraints

EKS Anywhere Docker provider needs:
- **4 GB RAM minimum** (8 GB recommended)
- **2 CPU cores minimum** (4 cores recommended)
- **10 GB disk space**

Adjust Docker Desktop resources if needed.

## Best Practices

### Development

1. **Use Docker provider** for local development
2. **Test upgrades** before production
3. **Practice with curated packages**
4. **Learn eksctl commands**

### Configuration

1. **Version control** cluster configs
2. **Document customizations**
3. **Test backup/restore**
4. **Monitor resource usage**

### Migration

1. **Start with Docker** provider
2. **Test workloads** thoroughly
3. **Plan production provider**
4. **Practice migration** process

## Conclusion

EKS Anywhere with Docker provider provides:

✅ **Real AWS distribution** - Not a simulation  
✅ **Free for development** - No license costs  
✅ **Production parity** - Same as production EKS-A  
✅ **Full features** - Upgrades, packages, GitOps  
✅ **Learning platform** - Practice for production  

It's the ideal choice for developing and testing workloads that will run on EKS Anywhere in production.
