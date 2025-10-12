# OpenShift to EKS Migration Guide

## Application Overview

**Application Name:** OpenShift Task Manager  
**Purpose:** A web-based task management application demonstrating OpenShift-specific features  
**Technology Stack:** Python Flask, HTML/CSS/JavaScript  
**Deployment:** Helm Chart with OpenShift-specific resources

## OpenShift-Specific Features Used

This application was intentionally designed to use OpenShift-specific features that are **NOT compatible with standard Kubernetes or Amazon EKS**. Below are the five key features that require code changes before migrating to EKS.

---

## 1. Routes (OpenShift Ingress)

### What It Is
OpenShift Routes are a proprietary ingress mechanism that provides HTTP/HTTPS routing to services. Routes are simpler than Kubernetes Ingress and are deeply integrated with OpenShift's HAProxy-based router.

### Why It Won't Work on EKS
- **API Version:** `route.openshift.io/v1` is OpenShift-specific and not available in standard Kubernetes
- **CRD Not Available:** EKS does not have the Route Custom Resource Definition (CRD)
- **Router Component:** OpenShift's router component doesn't exist in EKS

### Current Implementation
```yaml
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: task-manager
spec:
  host: task-manager.apps.okd-local.example.com
  to:
    kind: Service
    name: task-manager
  port:
    targetPort: http
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
```

### Required Changes for EKS
Replace with Kubernetes Ingress using AWS Load Balancer Controller:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: task-manager
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:region:account:certificate/xxx
    alb.ingress.kubernetes.io/ssl-redirect: '443'
spec:
  ingressClassName: alb
  rules:
  - host: task-manager.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: task-manager
            port:
              number: 8080
```

**Migration Effort:** Medium  
**Prerequisites:** Install AWS Load Balancer Controller, configure ACM certificate

---

## 2. DeploymentConfig

### What It Is
DeploymentConfig is OpenShift's proprietary deployment mechanism that predates Kubernetes Deployments. It provides additional features like automatic rollbacks, custom deployment strategies, and lifecycle hooks.

### Why It Won't Work on EKS
- **API Version:** `apps.openshift.io/v1` is OpenShift-specific
- **CRD Not Available:** EKS does not have the DeploymentConfig CRD
- **Trigger Mechanisms:** OpenShift-specific triggers (ImageChange, ConfigChange) don't exist in Kubernetes

### Current Implementation
```yaml
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: task-manager
spec:
  replicas: 2
  triggers:
    - type: ConfigChange
    - type: ImageChange
      imageChangeParams:
        automatic: true
        containerNames:
          - task-manager
        from:
          kind: ImageStreamTag
          name: task-manager:latest
  strategy:
    type: Rolling
    rollingParams:
      updatePeriodSeconds: 1
      intervalSeconds: 1
```

### Required Changes for EKS
Replace with standard Kubernetes Deployment:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: task-manager
spec:
  replicas: 2
  selector:
    matchLabels:
      app: task-manager
  template:
    metadata:
      labels:
        app: task-manager
    spec:
      containers:
      - name: task-manager
        image: <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
        # ... rest of container spec
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
```

**Migration Effort:** Low  
**Prerequisites:** None (standard Kubernetes resource)

---

## 3. ImageStreams

### What It Is
ImageStreams are OpenShift's abstraction for managing container images. They provide a stable reference to images, automatic updates when new images are pushed, and integration with OpenShift's internal registry.

### Why It Won't Work on EKS
- **API Version:** `image.openshift.io/v1` is OpenShift-specific
- **CRD Not Available:** EKS does not have the ImageStream CRD
- **Internal Registry:** OpenShift's integrated container registry doesn't exist in EKS
- **Image Triggers:** Automatic deployment triggers based on image changes are OpenShift-specific

### Current Implementation
```yaml
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata:
  name: task-manager
spec:
  lookupPolicy:
    local: true
  tags:
    - name: latest
      from:
        kind: DockerImage
        name: task-manager:latest
      importPolicy:
        scheduled: true
```

### Required Changes for EKS
1. **Use Amazon ECR (Elastic Container Registry):**
   ```bash
   # Create ECR repository
   aws ecr create-repository --repository-name task-manager
   
   # Build and push image
   docker build -t task-manager:latest .
   docker tag task-manager:latest <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
   aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
   docker push <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
   ```

2. **Update Deployment to reference ECR:**
   ```yaml
   spec:
     containers:
     - name: task-manager
       image: <account-id>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
   ```

3. **Configure IAM permissions for ECR access:**
   - Attach `AmazonEC2ContainerRegistryReadOnly` policy to node IAM role
   - Or use IRSA (IAM Roles for Service Accounts) for pod-level permissions

**Migration Effort:** Medium  
**Prerequisites:** ECR repository, IAM permissions, CI/CD pipeline updates

---

## 4. SecurityContextConstraints (SCC)

### What It Is
SecurityContextConstraints (SCC) are OpenShift's security policy mechanism that controls what pods can do and what resources they can access. SCCs are more granular and OpenShift-specific compared to Kubernetes Pod Security Standards.

### Why It Won't Work on EKS
- **API Version:** `security.openshift.io/v1` is OpenShift-specific
- **CRD Not Available:** EKS does not have the SCC CRD
- **Different Security Model:** EKS uses Pod Security Standards (PSS) and Pod Security Admission (PSA)
- **User/Group Handling:** OpenShift's user/group management differs from standard Kubernetes

### Current Implementation
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: task-manager-scc
allowHostDirVolumePlugin: false
allowHostIPC: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegedContainer: false
allowPrivilegeEscalation: false
requiredDropCapabilities:
  - ALL
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 2000
seLinuxContext:
  type: MustRunAs
fsGroup:
  type: MustRunAs
users:
  - system:serviceaccount:task-manager:task-manager
```

### Required Changes for EKS
1. **Use Pod Security Standards:**
   ```yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: task-manager
     labels:
       pod-security.kubernetes.io/enforce: restricted
       pod-security.kubernetes.io/audit: restricted
       pod-security.kubernetes.io/warn: restricted
   ```

2. **Update Pod SecurityContext:**
   ```yaml
   spec:
     securityContext:
       runAsNonRoot: true
       runAsUser: 1001
       fsGroup: 1001
       seccompProfile:
         type: RuntimeDefault
     containers:
     - name: task-manager
       securityContext:
         allowPrivilegeEscalation: false
         capabilities:
           drop:
           - ALL
         readOnlyRootFilesystem: false
   ```

3. **Optional: Use OPA Gatekeeper or Kyverno for advanced policies:**
   ```yaml
   apiVersion: kyverno.io/v1
   kind: ClusterPolicy
   metadata:
     name: require-non-root
   spec:
     validationFailureAction: enforce
     rules:
     - name: check-runAsNonRoot
       match:
         resources:
           kinds:
           - Pod
       validate:
         message: "Pods must run as non-root"
         pattern:
           spec:
             securityContext:
               runAsNonRoot: true
   ```

**Migration Effort:** Medium to High  
**Prerequisites:** Understanding of Pod Security Standards, possible policy engine installation

---

## 5. BuildConfig (Source-to-Image)

### What It Is
BuildConfig is OpenShift's native build automation system that supports Source-to-Image (S2I), Docker builds, and custom build strategies. It automatically builds container images from source code and pushes them to the internal registry.

### Why It Won't Work on EKS
- **API Version:** `build.openshift.io/v1` is OpenShift-specific
- **CRD Not Available:** EKS does not have the BuildConfig CRD
- **Build Infrastructure:** OpenShift's build pods and S2I builders don't exist in EKS
- **Integrated Registry:** Depends on OpenShift's internal container registry

### Current Implementation
```yaml
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: task-manager
spec:
  output:
    to:
      kind: ImageStreamTag
      name: task-manager:latest
  source:
    type: Git
    git:
      uri: https://github.com/example/task-manager.git
      ref: main
    contextDir: /
  strategy:
    type: Docker
    dockerStrategy:
      dockerfilePath: Dockerfile
  triggers:
    - type: ConfigChange
    - type: ImageChange
```

### Required Changes for EKS
Replace with external CI/CD pipeline (multiple options):

**Option 1: AWS CodePipeline + CodeBuild**
```yaml
# buildspec.yml
version: 0.2
phases:
  pre_build:
    commands:
      - echo Logging in to Amazon ECR...
      - aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
  build:
    commands:
      - echo Build started on `date`
      - docker build -t task-manager:$CODEBUILD_RESOLVED_SOURCE_VERSION .
      - docker tag task-manager:$CODEBUILD_RESOLVED_SOURCE_VERSION $ECR_REGISTRY/task-manager:latest
  post_build:
    commands:
      - docker push $ECR_REGISTRY/task-manager:latest
      - echo Build completed on `date`
```

**Option 2: GitHub Actions**
```yaml
name: Build and Push to ECR
on:
  push:
    branches: [main]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v1
      - name: Build and push
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
        run: |
          docker build -t $ECR_REGISTRY/task-manager:latest .
          docker push $ECR_REGISTRY/task-manager:latest
```

**Option 3: Tekton Pipelines (Kubernetes-native)**
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: task-manager-build
spec:
  params:
    - name: git-url
    - name: image-name
  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
    - name: build-push
      taskRef:
        name: kaniko
      params:
        - name: IMAGE
          value: $(params.image-name)
```

**Migration Effort:** High  
**Prerequisites:** CI/CD pipeline setup, ECR repository, IAM permissions, webhook configuration

---

## 6. Templates (Bonus Feature)

### What It Is
OpenShift Templates provide a way to parameterize and instantiate multiple Kubernetes resources with variable substitution. They're similar to Helm but are OpenShift-native.

### Why It Won't Work on EKS
- **API Version:** `template.openshift.io/v1` is OpenShift-specific
- **CRD Not Available:** EKS does not have the Template CRD
- **Processing Engine:** OpenShift's template processing doesn't exist in EKS

### Current Implementation
```yaml
apiVersion: template.openshift.io/v1
kind: Template
metadata:
  name: task-manager-template
parameters:
  - name: APP_NAME
    value: "task-manager"
  - name: REPLICA_COUNT
    value: "2"
objects:
  - apiVersion: apps.openshift.io/v1
    kind: DeploymentConfig
    metadata:
      name: ${APP_NAME}
    spec:
      replicas: ${{REPLICA_COUNT}}
```

### Required Changes for EKS
Replace with Helm Charts (already done in this project):

```bash
# Install with Helm
helm install task-manager ./helm/task-manager \
  --set replicaCount=2 \
  --set image.repository=<account-id>.dkr.ecr.<region>.amazonaws.com/task-manager
```

**Migration Effort:** Low (if already using Helm)  
**Prerequisites:** Helm 3.x installed

---

## Migration Summary

| Feature | OpenShift API | EKS Replacement | Effort | Breaking Change |
|---------|---------------|-----------------|--------|-----------------|
| Routes | `route.openshift.io/v1` | Kubernetes Ingress + AWS LB Controller | Medium | Yes |
| DeploymentConfig | `apps.openshift.io/v1` | Standard Deployment | Low | Yes |
| ImageStreams | `image.openshift.io/v1` | Amazon ECR | Medium | Yes |
| SecurityContextConstraints | `security.openshift.io/v1` | Pod Security Standards | Medium-High | Yes |
| BuildConfig | `build.openshift.io/v1` | CI/CD Pipeline (CodePipeline/GitHub Actions) | High | Yes |
| Templates | `template.openshift.io/v1` | Helm Charts | Low | Yes |

---

## Migration Checklist

### Pre-Migration
- [ ] Audit all OpenShift-specific resources in the application
- [ ] Set up Amazon ECR repository
- [ ] Configure AWS Load Balancer Controller in EKS cluster
- [ ] Set up CI/CD pipeline (CodePipeline, GitHub Actions, etc.)
- [ ] Review and plan security policies (PSS/PSA)
- [ ] Update Helm charts to remove OpenShift-specific resources

### During Migration
- [ ] Convert Routes to Ingress resources
- [ ] Convert DeploymentConfigs to Deployments
- [ ] Migrate images from OpenShift registry to ECR
- [ ] Replace SCCs with Pod Security Standards
- [ ] Set up external build pipeline
- [ ] Update image references to ECR URLs
- [ ] Test application in EKS environment

### Post-Migration
- [ ] Verify all application functionality
- [ ] Monitor application performance and logs
- [ ] Update documentation
- [ ] Train team on EKS-specific features
- [ ] Set up monitoring and alerting (CloudWatch, Prometheus)
- [ ] Implement backup and disaster recovery

---

## Additional Considerations

### Networking
- **OpenShift:** Uses OVN-Kubernetes or OpenShift SDN
- **EKS:** Uses Amazon VPC CNI plugin
- **Impact:** Different network policies and IP address management

### Storage
- **OpenShift:** Supports various storage classes including OpenShift Container Storage
- **EKS:** Uses EBS, EFS, or FSx via CSI drivers
- **Impact:** May need to update PersistentVolumeClaims

### Monitoring
- **OpenShift:** Built-in Prometheus and Grafana
- **EKS:** Requires separate installation or use CloudWatch Container Insights
- **Impact:** Need to set up monitoring stack

### Authentication
- **OpenShift:** Integrated OAuth server
- **EKS:** Uses AWS IAM Authenticator
- **Impact:** Different authentication mechanisms for cluster access

### Service Mesh
- **OpenShift:** OpenShift Service Mesh (based on Istio)
- **EKS:** Can use AWS App Mesh or install Istio separately
- **Impact:** Service mesh configuration may need updates

---

## Conclusion

Migrating from OpenShift to EKS requires careful planning and execution. The five main OpenShift-specific features (Routes, DeploymentConfig, ImageStreams, SecurityContextConstraints, and BuildConfig) all require code changes and infrastructure updates. 

The migration effort ranges from low (DeploymentConfig) to high (BuildConfig), with a total estimated effort of **2-4 weeks** for a typical application, depending on complexity and team familiarity with AWS services.

**Key Success Factors:**
1. Thorough inventory of OpenShift-specific resources
2. Proper AWS infrastructure setup (ECR, Load Balancer Controller, IAM)
3. Robust CI/CD pipeline implementation
4. Comprehensive testing in EKS environment
5. Team training on AWS and EKS-specific features

**Recommended Approach:**
1. Start with a non-production environment
2. Migrate one feature at a time
3. Test thoroughly after each change
4. Use feature flags for gradual rollout
5. Keep OpenShift environment running until EKS is fully validated
