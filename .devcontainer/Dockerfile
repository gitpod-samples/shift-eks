FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

# Install system dependencies including CRC requirements
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    curl \
    wget \
    git \
    jq \
    ca-certificates \
    gnupg \
    lsb-release \
    python3 \
    python3-pip \
    python3-venv \
    qemu-kvm \
    libvirt-daemon \
    libvirt-daemon-system \
    libvirt-clients \
    bridge-utils \
    dnsmasq \
    network-manager \
    apt-transport-https \
    software-properties-common \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install Docker CLI (not daemon - will use host Docker)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli docker-compose-plugin docker-buildx-plugin \
    && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Add user to docker and libvirt groups
RUN usermod -aG docker vscode || true \
    && usermod -aG libvirt vscode || true

# Install CodeReady Containers (CRC)
ARG CRC_VERSION=2.41.0
RUN curl -Lo /tmp/crc-linux-amd64.tar.xz \
    "https://developers.redhat.com/content-gateway/rest/mirror/pub/openshift-v4/clients/crc/${CRC_VERSION}/crc-linux-amd64.tar.xz" \
    && tar -xf /tmp/crc-linux-amd64.tar.xz -C /tmp \
    && mv /tmp/crc-linux-${CRC_VERSION}-amd64/crc /usr/local/bin/crc \
    && chmod +x /usr/local/bin/crc \
    && rm -rf /tmp/crc-linux-*

# Install OpenShift CLI (oc)
RUN curl -Lo /tmp/openshift-client-linux.tar.gz \
    https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable/openshift-client-linux.tar.gz \
    && tar -xzf /tmp/openshift-client-linux.tar.gz -C /tmp \
    && mv /tmp/oc /usr/local/bin/oc \
    && chmod +x /usr/local/bin/oc \
    && rm -f /tmp/openshift-client-linux.tar.gz /tmp/kubectl /tmp/README.md

# Install eksctl (required for eksctl-anywhere plugin)
RUN curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" \
    | tar xz -C /tmp \
    && mv /tmp/eksctl /usr/local/bin/eksctl \
    && chmod +x /usr/local/bin/eksctl

# Install eksctl-anywhere plugin
ARG EKSA_VERSION=0.23.3
RUN curl -Lo /tmp/eksctl-anywhere.tar.gz \
    "https://github.com/aws/eks-anywhere/releases/download/v${EKSA_VERSION}/eksctl-anywhere-v${EKSA_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/eksctl-anywhere.tar.gz -C /tmp \
    && mv /tmp/eksctl-anywhere /usr/local/bin/eksctl-anywhere \
    && chmod +x /usr/local/bin/eksctl-anywhere \
    && rm -f /tmp/eksctl-anywhere.tar.gz

# Install kubectx and kubens for easy context and namespace switching
RUN curl -Lo /usr/local/bin/kubectx https://raw.githubusercontent.com/ahmetb/kubectx/master/kubectx \
    && curl -Lo /usr/local/bin/kubens https://raw.githubusercontent.com/ahmetb/kubectx/master/kubens \
    && chmod +x /usr/local/bin/kubectx /usr/local/bin/kubens

# Install kind (Kubernetes in Docker) for OKD
ARG KIND_VERSION=v0.20.0
RUN curl -Lo /usr/local/bin/kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" \
    && chmod +x /usr/local/bin/kind

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/awscliv2.zip /tmp/aws

# Install LocalStack CLI and awslocal wrapper
RUN pip3 install --no-cache-dir --break-system-packages localstack awscli-local

# Create necessary directories
RUN mkdir -p /home/vscode/.kube /home/vscode/clusters /home/vscode/.crc \
    && chown -R vscode:vscode /home/vscode/.kube /home/vscode/clusters /home/vscode/.crc \
    && chmod 1777 /tmp
