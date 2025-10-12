# OpenShift Task Manager

A demonstration application showcasing OpenShift-specific features that require migration changes when moving to Amazon EKS.

## Overview

This is a lightweight web-based task management application built with Python Flask. It was intentionally designed to use OpenShift-specific features to demonstrate the challenges and requirements of migrating from OpenShift to Amazon EKS.

## Features

- ✅ Create, view, complete, and delete tasks
- ✅ Real-time task statistics
- ✅ Responsive web interface
- ✅ RESTful API
- ✅ Health check endpoint
- ✅ OpenShift-native deployment

## Technology Stack

- **Backend:** Python 3.11, Flask 3.0, Gunicorn
- **Frontend:** HTML5, CSS3, Vanilla JavaScript
- **Container:** Docker
- **Orchestration:** Kubernetes/OpenShift
- **Deployment:** Helm Chart

## OpenShift-Specific Features

This application uses the following OpenShift-specific features that are **NOT compatible** with standard Kubernetes or Amazon EKS:

1. **Routes** - OpenShift's ingress mechanism (`route.openshift.io/v1`)
2. **DeploymentConfig** - OpenShift's deployment resource (`apps.openshift.io/v1`)
3. **ImageStreams** - OpenShift's image management (`image.openshift.io/v1`)
4. **SecurityContextConstraints (SCC)** - OpenShift's security policies (`security.openshift.io/v1`)
5. **BuildConfig** - OpenShift's build automation (`build.openshift.io/v1`)
6. **Templates** - OpenShift's resource templating (`template.openshift.io/v1`)

For detailed migration guidance, see [OPENSHIFT_TO_EKS_MIGRATION.md](./OPENSHIFT_TO_EKS_MIGRATION.md).

## Project Structure

```
openshift-task-manager/
├── app/
│   ├── app.py              # Flask application
│   └── requirements.txt    # Python dependencies
├── helm/
│   └── task-manager/       # Helm chart
│       ├── Chart.yaml
│       ├── values.yaml
│       └── templates/
│           ├── deployment.yaml
│           ├── deploymentconfig.yaml
│           ├── service.yaml
│           ├── route.yaml
│           ├── imagestream.yaml
│           ├── buildconfig.yaml
│           ├── scc.yaml
│           └── template.yaml
├── openshift-resources/    # Standalone OpenShift resources
│   ├── deploymentconfig.yaml
│   ├── imagestream.yaml
│   ├── buildconfig.yaml
│   ├── scc.yaml
│   ├── template.yaml
│   └── project.yaml
├── Dockerfile
├── .dockerignore
├── README.md
└── OPENSHIFT_TO_EKS_MIGRATION.md
```

## Quick Start

### Prerequisites

- OpenShift OKD cluster or OpenShift 4.x
- `oc` CLI tool
- `kubectl` CLI tool
- `helm` 3.x
- Docker (for building images)

### Deploy to OpenShift

1. **Build the container image:**
   ```bash
   docker build -t task-manager:latest .
   ```

2. **Load image into cluster (for kind/OKD local):**
   ```bash
   docker save task-manager:latest | docker exec -i okd-local-control-plane ctr -n k8s.io images import -
   ```

3. **Create namespace:**
   ```bash
   kubectl create namespace task-manager
   ```

4. **Deploy with Helm:**
   ```bash
   helm install task-manager ./helm/task-manager -n task-manager
   ```

5. **Verify deployment:**
   ```bash
   kubectl get all -n task-manager
   kubectl get route -n task-manager
   ```

### Access the Application

**Via Route (OpenShift):**
```bash
# Get the route URL
oc get route task-manager -n task-manager -o jsonpath='{.spec.host}'

# Access in browser
https://<route-host>
```

**Via Port Forward (for testing):**
```bash
kubectl port-forward -n task-manager svc/task-manager 8080:8080
# Access at http://localhost:8080
```

**Via kubectl proxy:**
```bash
kubectl proxy --port=8001
# Access at http://localhost:8001/api/v1/namespaces/task-manager/services/task-manager:8080/proxy/
```

## API Endpoints

### Health Check
```bash
GET /health
```

Response:
```json
{
  "status": "healthy",
  "service": "openshift-task-manager",
  "openshift_features": [
    "Routes",
    "DeploymentConfig",
    "ImageStreams",
    "SecurityContextConstraints",
    "BuildConfig",
    "Templates"
  ]
}
```

### Get All Tasks
```bash
GET /api/tasks
```

### Create Task
```bash
POST /api/tasks
Content-Type: application/json

{
  "title": "My new task"
}
```

### Complete Task
```bash
PUT /api/tasks/{id}/complete
```

### Delete Task
```bash
DELETE /api/tasks/{id}
```

## Testing

### Test API from within cluster:
```bash
kubectl run -n task-manager test-curl --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -s http://task-manager:8080/health
```

### Create and manage tasks:
```bash
kubectl run -n task-manager test-api --image=curlimages/curl:latest --rm -i --restart=Never -- sh -c '
  # Create tasks
  curl -s -X POST http://task-manager:8080/api/tasks \
    -H "Content-Type: application/json" \
    -d "{\"title\":\"Test Task\"}"
  
  # Get all tasks
  curl -s http://task-manager:8080/api/tasks
  
  # Complete task
  curl -s -X PUT http://task-manager:8080/api/tasks/1/complete
'
```

## Configuration

### Helm Values

Key configuration options in `helm/task-manager/values.yaml`:

```yaml
replicaCount: 2

image:
  repository: task-manager
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080

route:
  enabled: true
  tls:
    enabled: true
    termination: edge

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

openshift:
  useDeploymentConfig: false  # Set to true for DeploymentConfig
  useImageStream: false        # Set to true for ImageStream
  useBuildConfig: false        # Set to true for BuildConfig
  scc:
    enabled: false             # Set to true for custom SCC
```

### Environment Variables

The application supports the following environment variables:

- `PORT` - Server port (default: 8080)

## Development

### Local Development

1. **Install dependencies:**
   ```bash
   cd app
   pip install -r requirements.txt
   ```

2. **Run locally:**
   ```bash
   python app.py
   ```

3. **Access at:** http://localhost:8080

### Build Container

```bash
docker build -t task-manager:latest .
docker run -p 8080:8080 task-manager:latest
```

## Migration to EKS

This application uses OpenShift-specific features that require changes for EKS deployment. See the comprehensive migration guide:

📖 **[OPENSHIFT_TO_EKS_MIGRATION.md](./OPENSHIFT_TO_EKS_MIGRATION.md)**

The guide covers:
- Detailed explanation of each OpenShift feature
- Why they don't work on EKS
- Step-by-step migration instructions
- Code examples for EKS equivalents
- Migration effort estimates
- Complete checklist

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n task-manager -l app.kubernetes.io/name=task-manager
kubectl logs -n task-manager -l app.kubernetes.io/name=task-manager
```

### Route not accessible
```bash
kubectl get route -n task-manager
kubectl describe route task-manager -n task-manager
```

### Image pull errors
```bash
# For local development, ensure image is loaded into cluster
docker save task-manager:latest | docker exec -i okd-local-control-plane ctr -n k8s.io images import -
```

### OpenShift resources not applying
Some OpenShift CRDs may not be available in all OKD installations. Check available APIs:
```bash
kubectl api-resources | grep openshift
```

## Security

- Application runs as non-root user (UID 1001)
- All capabilities dropped
- No privilege escalation allowed
- Read-only root filesystem (optional)
- Security context constraints enforced (OpenShift)

## License

This is a demonstration application for educational purposes.

## Contributing

This is a demo application. For production use, consider:
- Adding persistent storage for tasks
- Implementing authentication
- Adding input validation
- Implementing rate limiting
- Adding comprehensive logging
- Setting up monitoring and alerting

## Support

For issues related to:
- **Application:** Check logs and health endpoint
- **OpenShift deployment:** Consult OpenShift documentation
- **EKS migration:** See OPENSHIFT_TO_EKS_MIGRATION.md

## Acknowledgments

Built to demonstrate OpenShift to EKS migration challenges and solutions.
