# Changes: Migrated from kind to CodeReady Containers (CRC)

## Summary

The OpenShift cluster implementation has been migrated from kind (Kubernetes in Docker) to CodeReady Containers (CRC), providing a full OpenShift 4.x environment.

## What Changed

### Replaced Components

| Before | After |
|--------|-------|
| kind (Kubernetes in Docker) | CodeReady Containers (CRC) |
| Simulated OpenShift | Full OpenShift 4.x cluster |
| Basic Kubernetes | Complete OpenShift features |
| No web console | OpenShift web console included |

### New Requirements

1. **Red Hat Pull Secret** (free)
   - Required for CRC to download OpenShift images
   - Get from: https://console.redhat.com/openshift/create/local
   - Helper script provided: `./setup-crc-pull-secret.sh`

2. **Increased Resources**
   - Memory: 16 GB (was minimal with kind)
   - CPUs: 6 cores (was 2 with kind)
   - Disk: 100 GB (was ~10 GB with kind)

### Updated Files

1. **`.devcontainer/Dockerfile`**
   - Added libvirt, qemu-kvm for CRC virtualization
   - Added network-manager, dnsmasq for CRC networking
   - **All tool installations moved here** (CRC, oc, LocalStack, eksctl)
   - Tools installed at build time for faster container startup

2. **`.devcontainer/devcontainer.json`**
   - Updated to use post-create.sh for configuration
   - Added environment variables for AWS/LocalStack
   - Uses DevContainer features for kubectl, Docker, AWS CLI

3. **`.devcontainer/post-create.sh`** (new)
   - Configuration only (no installations)
   - Sets CRC resource limits
   - Creates LocalStack docker-compose file

4. **`.devcontainer/start-clusters.sh`**
   - Now an orchestrator that calls separate scripts
   - Cleaner separation of concerns

5. **`.devcontainer/start-crc.sh`** (new)
   - Dedicated CRC startup logic
   - Pull secret handling
   - CRC login automation

6. **`.devcontainer/start-eks.sh`** (new)
   - Dedicated EKS/LocalStack startup logic
   - Health checks and cluster creation

4. **`cluster-manager.sh`**
   - Updated all OpenShift operations to use CRC commands
   - Changed status checks from kind to CRC
   - Updated restart logic for CRC

5. **`README.md`**
   - Updated all documentation for CRC
   - Added prerequisites section for pull secret
   - Updated resource requirements
   - Added CRC-specific troubleshooting

6. **`verify-setup.sh`**
   - Replaced kind checks with CRC checks
   - Added CRC version verification

### New Files

1. **`setup-crc-pull-secret.sh`**
   - Interactive helper for pull secret setup
   - Supports pasting content or file path
   - Validates and saves to `~/.crc/pull-secret.json`

2. **`PULL_SECRET.md`**
   - Comprehensive guide for obtaining and configuring pull secret
   - Multiple setup options documented
   - Troubleshooting section

3. **`CHANGES.md`** (this file)
   - Documents the migration from kind to CRC

## Benefits of CRC

### Advantages

1. **Full OpenShift Experience**
   - Complete OpenShift 4.x cluster
   - All OpenShift-specific features available
   - OpenShift web console
   - OpenShift operators and catalog

2. **Production Parity**
   - Closer to production OpenShift environments
   - Better testing of OpenShift-specific features
   - Authentic OpenShift API behavior

3. **Developer Tools**
   - Built-in monitoring and logging
   - OpenShift developer perspective
   - Integrated CI/CD tools

### Trade-offs

1. **Resource Usage**
   - Higher memory requirement (16 GB vs ~2 GB)
   - More CPU cores needed (6 vs 2)
   - Larger disk footprint (100 GB vs ~10 GB)

2. **Startup Time**
   - First-time setup: 10-15 minutes
   - Subsequent starts: 3-5 minutes
   - kind was faster (~1 minute)

3. **Additional Setup**
   - Requires Red Hat pull secret (free)
   - More complex initial configuration
   - kind required no external accounts

## Migration Steps for Users

If you were using the previous kind-based setup:

1. **Rebuild the DevContainer**
   ```bash
   gitpod devcontainer rebuild
   ```

2. **Get Red Hat Pull Secret**
   - Visit: https://console.redhat.com/openshift/create/local
   - Download pull secret
   - Run: `./setup-crc-pull-secret.sh`

3. **Start Clusters**
   ```bash
   ./cluster-manager.sh start-all
   ```

4. **Update Context References**
   - Old: `kubectl config use-context openshift`
   - New: Use `oc` commands or get context from `crc status`

## Rollback (if needed)

If you need to revert to kind:

1. Check out the previous commit before CRC migration
2. Rebuild the DevContainer
3. The kind-based setup will be restored

## Support

- CRC Documentation: https://access.redhat.com/documentation/en-us/red_hat_openshift_local/
- CRC GitHub: https://github.com/crc-org/crc
- Red Hat Developer: https://developers.redhat.com/
