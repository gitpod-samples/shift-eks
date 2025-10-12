# OpenShift-Specific Features That Won't Work on EKS

## Overview

This document provides a concise summary of the OpenShift-specific features used in the **Task Manager** application and explains why each feature is incompatible with Amazon EKS.

**Application Location:** `openshift-task-manager/`  
**Deployment Status:** ✅ Running on OKD cluster  
**Namespace:** task-manager

---

## Summary Table

| # | Feature | OpenShift API | Status | EKS Compatible | Migration Effort |
|---|---------|---------------|--------|----------------|------------------|
| 1 | Routes | `route.openshift.io/v1` | ✅ Deployed | ❌ No | Medium |
| 2 | Projects | `project.openshift.io/v1` | ✅ Deployed | ❌ No | Low |
| 3 | DeploymentConfig | `apps.openshift.io/v1` | 📝 Defined | ❌ No | Low |
| 4 | ImageStreams | `image.openshift.io/v1` | 📝 Defined | ❌ No | Medium |
| 5 | BuildConfig | `build.openshift.io/v1` | 📝 Defined | ❌ No | High |
| 6 | SecurityContextConstraints | `security.openshift.io/v1` | 📝 Defined | ❌ No | Medium-High |
| 7 | Templates | `template.openshift.io/v1` | 📝 Defined | ❌ No | Low |

---

## 1. Routes (route.openshift.io/v1)

### What It Is
OpenShift's proprietary HTTP/HTTPS ingress mechanism that provides routing to services.

### Why It Won't Work on EKS
- **Custom Resource Definition (CRD):** The `route.openshift.io/v1` API is OpenShift-specific and not available in standard Kubernetes
- **Router Component:** Requires OpenShift's HAProxy-based router which doesn't exist in EKS
- **Different Architecture:** Routes are processed by OpenShift's router, not by standard Kubernetes ingress controllers

### EKS Replacement
**Kubernetes Ingress with AWS Load Balancer Controller**

```yaml
# OpenShift Route (won't work on EKS)
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: task-manager
spec:
  host: task-manager.apps.example.com
  to:
    kind: Service
    name: task-manager
  tls:
    termination: edge

# EKS Ingress (replacement)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: task-manager
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:...
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

---

## 2. Projects (project.openshift.io/v1)

### What It Is
OpenShift's enhanced namespace with additional metadata, RBAC, and multi-tenancy features.

### Why It Won't Work on EKS
- **Custom API:** The `project.openshift.io/v1` API is OpenShift-specific
- **Additional Features:** Projects include OpenShift-specific annotations, quotas, and RBAC that don't exist in standard namespaces
- **Web Console Integration:** Projects are tightly integrated with OpenShift's web console

### EKS Replacement
**Standard Kubernetes Namespace**

```yaml
# OpenShift Project (won't work on EKS)
apiVersion: project.openshift.io/v1
kind: Project
metadata:
  name: task-manager
  annotations:
    openshift.io/description: "Task Manager"
    openshift.io/display-name: "Task Manager"

# EKS Namespace (replacement)
apiVersion: v1
kind: Namespace
metadata:
  name: task-manager
  labels:
    name: task-manager
    environment: production
```

---

## 3. DeploymentConfig (apps.openshift.io/v1)

### What It Is
OpenShift's proprietary deployment mechanism with automatic rollbacks, custom strategies, and trigger-based deployments.

### Why It Won't Work on EKS
- **Custom API:** The `apps.openshift.io/v1` API is OpenShift-specific
- **Trigger System:** ImageChange and ConfigChange triggers are OpenShift-specific features
- **Deployment Strategies:** Some deployment strategies are unique to OpenShift
- **Lifecycle Hooks:** OpenShift-specific pre/post deployment hooks

### EKS Replacement
**Standard Kubernetes Deployment**

```yaml
# OpenShift DeploymentConfig (won't work on EKS)
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
        from:
          kind: ImageStreamTag
          name: task-manager:latest

# EKS Deployment (replacement)
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
        image: <account>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
```

---

## 4. ImageStreams (image.openshift.io/v1)

### What It Is
OpenShift's abstraction for managing container images with automatic updates and integration with the internal registry.

### Why It Won't Work on EKS
- **Custom API:** The `image.openshift.io/v1` API is OpenShift-specific
- **Internal Registry:** Depends on OpenShift's integrated container registry
- **Image Triggers:** Automatic deployment triggers based on image changes are OpenShift-specific
- **Tag Management:** OpenShift-specific image tag tracking and management

### EKS Replacement
**Amazon Elastic Container Registry (ECR)**

```yaml
# OpenShift ImageStream (won't work on EKS)
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

# EKS: Use ECR directly in Deployment
# No ImageStream equivalent - reference ECR directly
spec:
  containers:
  - name: task-manager
    image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/task-manager:latest
```

**Setup ECR:**
```bash
aws ecr create-repository --repository-name task-manager
docker tag task-manager:latest <account>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
aws ecr get-login-password | docker login --username AWS --password-stdin <account>.dkr.ecr.<region>.amazonaws.com
docker push <account>.dkr.ecr.<region>.amazonaws.com/task-manager:latest
```

---

## 5. BuildConfig (build.openshift.io/v1)

### What It Is
OpenShift's native build automation supporting Source-to-Image (S2I), Docker builds, and custom strategies.

### Why It Won't Work on EKS
- **Custom API:** The `build.openshift.io/v1` API is OpenShift-specific
- **Build Infrastructure:** Requires OpenShift's build pods and controllers
- **S2I Builders:** Source-to-Image builders are OpenShift-specific
- **Internal Registry Integration:** Builds push to OpenShift's internal registry
- **Webhook Integration:** OpenShift-specific webhook handling

### EKS Replacement
**External CI/CD Pipeline (AWS CodePipeline, GitHub Actions, or Tekton)**

```yaml
# OpenShift BuildConfig (won't work on EKS)
apiVersion: build.openshift.io/v1
kind: BuildConfig
metadata:
  name: task-manager
spec:
  source:
    type: Git
    git:
      uri: https://github.com/example/task-manager.git
  strategy:
    type: Docker
  output:
    to:
      kind: ImageStreamTag
      name: task-manager:latest
  triggers:
    - type: GitHub
    - type: ConfigChange

# EKS: AWS CodeBuild buildspec.yml (replacement)
version: 0.2
phases:
  pre_build:
    commands:
      - aws ecr get-login-password | docker login --username AWS --password-stdin $ECR_REGISTRY
  build:
    commands:
      - docker build -t task-manager:$CODEBUILD_RESOLVED_SOURCE_VERSION .
      - docker tag task-manager:$CODEBUILD_RESOLVED_SOURCE_VERSION $ECR_REGISTRY/task-manager:latest
  post_build:
    commands:
      - docker push $ECR_REGISTRY/task-manager:latest
```

---

## 6. SecurityContextConstraints (security.openshift.io/v1)

### What It Is
OpenShift's fine-grained security policy mechanism controlling pod permissions, capabilities, and resource access.

### Why It Won't Work on EKS
- **Custom API:** The `security.openshift.io/v1` API is OpenShift-specific
- **Different Security Model:** SCCs are more granular than Kubernetes Pod Security Standards
- **User/Group Management:** OpenShift's user and group handling differs from standard Kubernetes
- **SELinux Integration:** OpenShift-specific SELinux context management
- **Priority System:** SCC priority and selection mechanism is OpenShift-specific

### EKS Replacement
**Pod Security Standards (PSS) or Policy Engines (OPA/Kyverno)**

```yaml
# OpenShift SCC (won't work on EKS)
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: task-manager-scc
allowPrivilegedContainer: false
allowPrivilegeEscalation: false
runAsUser:
  type: MustRunAsRange
  uidRangeMin: 1000
  uidRangeMax: 2000
requiredDropCapabilities:
  - ALL
users:
  - system:serviceaccount:task-manager:task-manager

# EKS: Pod Security Standards (replacement)
apiVersion: v1
kind: Namespace
metadata:
  name: task-manager
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# Plus: Update Pod SecurityContext
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
```

---

## 7. Templates (template.openshift.io/v1)

### What It Is
OpenShift's native templating system for parameterizing and instantiating multiple Kubernetes resources.

### Why It Won't Work on EKS
- **Custom API:** The `template.openshift.io/v1` API is OpenShift-specific
- **Processing Engine:** OpenShift's template processor doesn't exist in standard Kubernetes
- **Web Console Integration:** Templates are integrated with OpenShift's web console
- **Parameter System:** OpenShift-specific parameter handling and validation

### EKS Replacement
**Helm Charts**

```yaml
# OpenShift Template (won't work on EKS)
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

# EKS: Helm Chart (replacement)
# values.yaml
replicaCount: 2
image:
  repository: task-manager
  tag: latest

# templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "task-manager.fullname" . }}
spec:
  replicas: {{ .Values.replicaCount }}
```

---

## Migration Effort Summary

### Total Estimated Effort: 2-4 weeks

| Feature | Effort | Complexity | Prerequisites |
|---------|--------|------------|---------------|
| Routes → Ingress | 2-3 days | Medium | AWS LB Controller, ACM certificate |
| Projects → Namespaces | 1 day | Low | None |
| DeploymentConfig → Deployment | 1 day | Low | None |
| ImageStreams → ECR | 2-3 days | Medium | ECR repository, IAM permissions |
| BuildConfig → CI/CD | 5-7 days | High | CodePipeline/GitHub Actions setup |
| SCC → PSS | 2-3 days | Medium-High | Policy engine (optional) |
| Templates → Helm | 1 day | Low | Helm 3.x (already done) |
| Testing & Validation | 3-5 days | Medium | EKS cluster |

---

## Key Takeaways

### Why These Features Don't Work on EKS

1. **Custom APIs:** All OpenShift-specific resources use APIs that don't exist in standard Kubernetes
2. **Missing CRDs:** EKS doesn't have the Custom Resource Definitions for OpenShift resources
3. **Infrastructure Dependencies:** Features like Routes and BuildConfig depend on OpenShift-specific infrastructure
4. **Different Architecture:** OpenShift and EKS have fundamentally different approaches to ingress, security, and builds

### Migration Strategy

1. **Inventory:** Identify all OpenShift-specific resources in your application
2. **Plan:** Map each OpenShift feature to its EKS equivalent
3. **Prepare:** Set up required AWS infrastructure (ECR, Load Balancer Controller, CI/CD)
4. **Convert:** Update manifests and Helm charts to use standard Kubernetes resources
5. **Test:** Thoroughly test in a non-production EKS environment
6. **Deploy:** Gradual rollout to production with monitoring

### Success Factors

✅ **Thorough Planning:** Understand all dependencies and prerequisites  
✅ **AWS Knowledge:** Familiarity with ECR, ALB, IAM, and CodePipeline  
✅ **Testing:** Comprehensive testing in EKS before production  
✅ **Documentation:** Keep detailed migration notes and runbooks  
✅ **Rollback Plan:** Maintain OpenShift environment until EKS is validated  

---

## Additional Resources

- **Application README:** `openshift-task-manager/README.md`
- **Detailed Migration Guide:** `openshift-task-manager/OPENSHIFT_TO_EKS_MIGRATION.md`
- **Deployment Summary:** `openshift-task-manager/DEPLOYMENT_SUMMARY.md`
- **Helm Chart:** `openshift-task-manager/helm/task-manager/`
- **OpenShift Resources:** `openshift-task-manager/openshift-resources/`

---

## Verification

The application is currently running on OKD and demonstrates all these features:

```bash
# Check deployment
kubectl get all,route,project -n task-manager

# Test application
kubectl run -n task-manager test --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://task-manager:8080/health
```

**Result:** All OpenShift-specific features are documented, defined, and ready for migration analysis.

---

**Document Version:** 1.0  
**Last Updated:** October 12, 2025  
**Application:** OpenShift Task Manager  
**Purpose:** OpenShift to EKS Migration Planning
