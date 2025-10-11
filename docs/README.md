# Documentation

This directory contains all documentation for the shift-eks project.

## Getting Started

- **[QUICKSTART.md](QUICKSTART.md)** - Quick start guide for new users
- **[PULL_SECRET.md](PULL_SECRET.md)** - How to set up Red Hat pull secret for OpenShift
- **[KUBECTX-KUBENS.md](KUBECTX-KUBENS.md)** - Quick reference for context and namespace switching

## Architecture & Design

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System architecture and design decisions
- **[DOCKER_SETUP.md](DOCKER_SETUP.md)** - Docker configuration and setup details
- **[REFACTORING.md](REFACTORING.md)** - Code refactoring and improvements

## EKS Anywhere

- **[EKS_ANYWHERE.md](EKS_ANYWHERE.md)** - Complete guide to EKS Anywhere
- **[EKS-ANYWHERE-SUCCESS.md](EKS-ANYWHERE-SUCCESS.md)** - ✅ How we made EKS Anywhere work in devcontainers
- **[EKS-ANYWHERE-ISSUE.md](EKS-ANYWHERE-ISSUE.md)** - Problem analysis and solution

## Project History

- **[FINAL_SUMMARY.md](FINAL_SUMMARY.md)** - ⭐ Complete project overview and summary
- **[CHANGES.md](CHANGES.md)** - Change log and modifications
- **[LOCALSTACK_TO_KIND.md](LOCALSTACK_TO_KIND.md)** - Migration from LocalStack to kind
- **[CRC_VS_KIND.md](CRC_VS_KIND.md)** - Comparison of CRC and kind
- **[VALIDATION_RESULTS.md](VALIDATION_RESULTS.md)** - Testing and validation results
- **[NEXT_STEPS.md](NEXT_STEPS.md)** - Future improvements and roadmap

## Key Insights

### EKS Anywhere in DevContainers

The most significant technical achievement was getting EKS Anywhere to work inside devcontainers. The key insight:

**Use a directory inside the project that is bind-mounted from the host.**

```bash
# This works because /workspaces/shift-eks is bind-mounted from host
CLUSTERS_DIR="/workspaces/shift-eks/.eks-clusters"
```

This allows both the devcontainer and host Docker daemon to access the same files, enabling EKS Anywhere's nested Docker architecture to function correctly.

See [EKS-ANYWHERE-SUCCESS.md](EKS-ANYWHERE-SUCCESS.md) for complete details.

### Docker Configuration

The project uses a clean Docker setup:
- Docker CLI installed in devcontainer
- Docker socket mounted from host: `/var/run/docker.sock`
- No docker-in-docker complexity
- Privileged mode for CRC requirements

See [DOCKER_SETUP.md](DOCKER_SETUP.md) for details.

## Contributing

When adding new documentation:
1. Place files in this `docs/` directory
2. Update this README.md with a link
3. Update the main README.md if it's user-facing documentation
4. Use clear, descriptive filenames in UPPERCASE with hyphens
