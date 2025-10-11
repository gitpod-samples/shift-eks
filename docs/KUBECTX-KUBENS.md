# kubectx and kubens Quick Reference

Tools for easy Kubernetes context and namespace switching.

## kubectx - Context Switching

### List Contexts

```bash
# List all available contexts
kubectx
```

Example output:
```
kind-eks-local-eks-a-cluster
default/api-crc-testing:6443/kubeadmin
```

### Switch Context

```bash
# Switch to a specific context
kubectx kind-eks-local-eks-a-cluster

# Switch to OpenShift context
kubectx default/api-crc-testing:6443/kubeadmin

# Switch to previous context
kubectx -

# Show current context
kubectx -c
```

### Rename Context

```bash
# Rename a context for easier use
kubectx eks=kind-eks-local-eks-a-cluster
kubectx openshift=default/api-crc-testing:6443/kubeadmin

# Now you can use short names
kubectx eks
kubectx openshift
```

### Delete Context

```bash
# Delete a context
kubectx -d <context-name>

# Delete current context
kubectx -d .
```

## kubens - Namespace Switching

### List Namespaces

```bash
# List all namespaces in current context
kubens
```

Example output (EKS Anywhere):
```
capd-system
capi-kubeadm-bootstrap-system
capi-kubeadm-control-plane-system
capi-system
cert-manager
default
eksa-system
etcdadm-bootstrap-provider-system
etcdadm-controller-system
kube-node-lease
kube-public
kube-system
local-path-storage
```

### Switch Namespace

```bash
# Switch to a specific namespace
kubens eksa-system

# Switch to default namespace
kubens default

# Switch to previous namespace
kubens -

# Show current namespace
kubens -c
```

## Common Workflows

### Working with Multiple Clusters

```bash
# List all contexts
kubectx

# Switch to EKS Anywhere
kubectx kind-eks-local-eks-a-cluster

# Check namespaces
kubens

# Switch to eksa-system namespace
kubens eksa-system

# View pods in current namespace
kubectl get pods

# Switch to OpenShift
kubectx default/api-crc-testing:6443/kubeadmin

# View OpenShift projects (namespaces)
kubens

# Switch to openshift-console namespace
kubens openshift-console

# View pods
kubectl get pods
```

### Quick Context Switching

```bash
# Rename contexts for easier switching
kubectx eks=kind-eks-local-eks-a-cluster
kubectx os=default/api-crc-testing:6443/kubeadmin

# Now switch quickly
kubectx eks    # Switch to EKS Anywhere
kubectx os     # Switch to OpenShift
kubectx -      # Toggle between last two contexts
```

### Namespace Exploration

```bash
# Switch to EKS Anywhere
kubectx eks

# Explore different namespaces
kubens eksa-system && kubectl get pods
kubens capi-system && kubectl get pods
kubens cert-manager && kubectl get pods
kubens kube-system && kubectl get pods

# Return to default
kubens default
```

## Integration with Other Tools

### With kubectl

```bash
# kubectx/kubens set the context/namespace
# Then use kubectl normally
kubectx eks
kubens eksa-system
kubectl get pods
kubectl logs <pod-name>
kubectl describe pod <pod-name>
```

### With oc (OpenShift)

```bash
# Switch to OpenShift context
kubectx os

# Use oc commands (respects kubens)
kubens openshift-console
oc get pods
oc logs <pod-name>
```

### With cluster-manager.sh

```bash
# cluster-manager.sh also switches contexts
./cluster-manager.sh switch-eks

# Verify with kubectx
kubectx -c

# Then use kubens for namespace
kubens eksa-system
```

## Tips and Tricks

### Aliases

Add to your shell profile (`~/.bashrc` or `~/.zshrc`):

```bash
alias kx='kubectx'
alias kn='kubens'
alias k='kubectl'
```

Usage:
```bash
kx eks              # Switch context
kn eksa-system      # Switch namespace
k get pods          # Get pods
```

### Fuzzy Finder (fzf)

If `fzf` is installed, kubectx/kubens provide interactive selection:

```bash
# Interactive context selection
kubectx

# Interactive namespace selection
kubens
```

### Current Context/Namespace in Prompt

Add to your shell prompt to always see current context and namespace:

```bash
# In ~/.bashrc or ~/.zshrc
PS1='$(kubectx -c):$(kubens -c) $ '
```

## Comparison with kubectl

### Context Switching

```bash
# Traditional kubectl
kubectl config get-contexts
kubectl config use-context kind-eks-local-eks-a-cluster

# With kubectx (easier!)
kubectx
kubectx kind-eks-local-eks-a-cluster
```

### Namespace Switching

```bash
# Traditional kubectl
kubectl get namespaces
kubectl config set-context --current --namespace=eksa-system

# With kubens (easier!)
kubens
kubens eksa-system
```

## Troubleshooting

### No contexts listed

```bash
# Check if kubeconfig exists
ls -la ~/.kube/config

# Or check KUBECONFIG environment variable
echo $KUBECONFIG

# Set kubeconfig if needed
export KUBECONFIG=/workspaces/shift-eks/.eks-clusters/eks-local/generated/eks-local.kind.kubeconfig
```

### Context not switching

```bash
# Verify context exists
kubectx

# Check current context
kubectx -c

# Try full kubectl command
kubectl config use-context <context-name>
```

### Namespace not found

```bash
# List available namespaces
kubens

# Verify you're in the right context
kubectx -c

# Check if namespace exists
kubectl get namespaces
```

## Resources

- [kubectx GitHub](https://github.com/ahmetb/kubectx)
- [kubectl Context Documentation](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
