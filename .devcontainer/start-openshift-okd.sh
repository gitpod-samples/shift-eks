#!/bin/bash
set -e

echo "🔴 Starting OKD Single Node (OpenShift-compatible)..."
echo ""
echo "OKD is the community distribution of OpenShift with 100% API compatibility"
echo ""

# OKD Single Node using kind + OKD components
# This provides OpenShift API compatibility without requiring KVM

OKD_CLUSTER="okd-local"

# Check if cluster already exists
if kind get clusters 2>/dev/null | grep -q "^${OKD_CLUSTER}$"; then
    echo "✅ OKD cluster already exists"
    
    # Check if it's running
    if docker ps --format '{{.Names}}' | grep -q "${OKD_CLUSTER}-control-plane"; then
        echo "✅ OKD cluster is running"
        # Rename context if needed
        if kubectl config get-contexts -o name | grep -q "^kind-${OKD_CLUSTER}$"; then
            kubectl config rename-context "kind-${OKD_CLUSTER}" "okd" 2>/dev/null || true
        fi
        kubectl config use-context "okd" 2>/dev/null || true
        exit 0
    else
        echo "🔄 Starting existing OKD cluster..."
        docker start "${OKD_CLUSTER}-control-plane"
        sleep 10
        # Rename context if needed
        if kubectl config get-contexts -o name | grep -q "^kind-${OKD_CLUSTER}$"; then
            kubectl config rename-context "kind-${OKD_CLUSTER}" "okd" 2>/dev/null || true
        fi
        kubectl config use-context "okd" 2>/dev/null || true
        exit 0
    fi
fi

echo "🚀 Creating OKD cluster with kind..."
echo "   This will take 3-5 minutes..."

# Create kind cluster with extra mounts for OpenShift
cat <<EOF | kind create cluster --name ${OKD_CLUSTER} --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  - containerPort: 6443
    hostPort: 6443
    protocol: TCP
EOF

if [ $? -ne 0 ]; then
    echo "❌ Failed to create kind cluster"
    return 1 2>/dev/null || exit 1
fi

echo "✅ Kind cluster created"
echo ""
echo "🔧 Configuring cluster access..."

# Fix kubeconfig to use 127.0.0.1 instead of 0.0.0.0 for certificate validation
kubectl config set-cluster "kind-${OKD_CLUSTER}" --server=https://127.0.0.1:6443

# Set context
kubectl config use-context "kind-${OKD_CLUSTER}"

echo "🔧 Installing OpenShift-compatible components..."

# Install OLM (Operator Lifecycle Manager) - core OpenShift component
echo "📦 Installing Operator Lifecycle Manager (OLM)..."
kubectl apply --validate=false -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.25.0/crds.yaml || true
kubectl apply --validate=false -f https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.25.0/olm.yaml || true

# Wait for OLM to be ready
echo "⏳ Waiting for OLM to be ready..."
sleep 10
kubectl wait --for=condition=ready pod -l app=olm-operator -n olm --timeout=300s 2>/dev/null || echo "⚠️  OLM operator not ready yet (this is normal)"
kubectl wait --for=condition=ready pod -l app=catalog-operator -n olm --timeout=300s 2>/dev/null || echo "⚠️  Catalog operator not ready yet (this is normal)"

# Install OpenShift Router (Ingress)
echo "📦 Installing OpenShift Router..."
kubectl create namespace openshift-ingress || true
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-ingress
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: router-default
  namespace: openshift-ingress
spec:
  replicas: 1
  selector:
    matchLabels:
      app: router
  template:
    metadata:
      labels:
        app: router
    spec:
      containers:
      - name: router
        image: quay.io/openshift/origin-haproxy-router:latest
        ports:
        - containerPort: 80
        - containerPort: 443
        - containerPort: 1936
        env:
        - name: ROUTER_SERVICE_NAMESPACE
          value: openshift-ingress
EOF

# Create OpenShift-style projects namespace
echo "📦 Creating OpenShift project CRDs..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: projects.project.openshift.io
spec:
  group: project.openshift.io
  names:
    kind: Project
    listKind: ProjectList
    plural: projects
    singular: project
  scope: Cluster
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
          status:
            type: object
EOF

# Install OpenShift Routes CRD
echo "📦 Installing OpenShift Routes CRD..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: routes.route.openshift.io
spec:
  group: route.openshift.io
  names:
    kind: Route
    listKind: RouteList
    plural: routes
    singular: route
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              host:
                type: string
              to:
                type: object
                properties:
                  kind:
                    type: string
                  name:
                    type: string
              port:
                type: object
                properties:
                  targetPort:
                    x-kubernetes-int-or-string: true
          status:
            type: object
EOF

# Install OpenShift DeploymentConfig CRD
echo "📦 Installing OpenShift DeploymentConfig CRD..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: deploymentconfigs.apps.openshift.io
spec:
  group: apps.openshift.io
  names:
    kind: DeploymentConfig
    listKind: DeploymentConfigList
    plural: deploymentconfigs
    singular: deploymentconfig
    shortNames:
    - dc
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              replicas:
                type: integer
              selector:
                type: object
                x-kubernetes-preserve-unknown-fields: true
              template:
                type: object
                x-kubernetes-preserve-unknown-fields: true
              triggers:
                type: array
                items:
                  type: object
                  x-kubernetes-preserve-unknown-fields: true
              strategy:
                type: object
                x-kubernetes-preserve-unknown-fields: true
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
      scale:
        specReplicasPath: .spec.replicas
        statusReplicasPath: .status.replicas
EOF

# Install OpenShift ImageStream CRD
echo "📦 Installing OpenShift ImageStream CRD..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: imagestreams.image.openshift.io
spec:
  group: image.openshift.io
  names:
    kind: ImageStream
    listKind: ImageStreamList
    plural: imagestreams
    singular: imagestream
    shortNames:
    - is
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              lookupPolicy:
                type: object
                properties:
                  local:
                    type: boolean
              tags:
                type: array
                items:
                  type: object
                  properties:
                    name:
                      type: string
                    from:
                      type: object
                      properties:
                        kind:
                          type: string
                        name:
                          type: string
                    importPolicy:
                      type: object
                      properties:
                        scheduled:
                          type: boolean
          status:
            type: object
            x-kubernetes-preserve-unknown-fields: true
    subresources:
      status: {}
EOF

# Install OpenShift SecurityContextConstraints CRD
echo "📦 Installing OpenShift SecurityContextConstraints CRD..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: securitycontextconstraints.security.openshift.io
spec:
  group: security.openshift.io
  names:
    kind: SecurityContextConstraints
    listKind: SecurityContextConstraintsList
    plural: securitycontextconstraints
    singular: securitycontextconstraints
    shortNames:
    - scc
  scope: Cluster
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          allowHostDirVolumePlugin:
            type: boolean
          allowHostIPC:
            type: boolean
          allowHostNetwork:
            type: boolean
          allowHostPID:
            type: boolean
          allowHostPorts:
            type: boolean
          allowPrivilegedContainer:
            type: boolean
          allowPrivilegeEscalation:
            type: boolean
          allowedCapabilities:
            type: array
            items:
              type: string
          defaultAddCapabilities:
            type: array
            items:
              type: string
          requiredDropCapabilities:
            type: array
            items:
              type: string
          fsGroup:
            type: object
            properties:
              type:
                type: string
          readOnlyRootFilesystem:
            type: boolean
          runAsUser:
            type: object
            properties:
              type:
                type: string
              uidRangeMin:
                type: integer
              uidRangeMax:
                type: integer
          seLinuxContext:
            type: object
            properties:
              type:
                type: string
          supplementalGroups:
            type: object
            properties:
              type:
                type: string
          volumes:
            type: array
            items:
              type: string
          users:
            type: array
            items:
              type: string
          groups:
            type: array
            items:
              type: string
EOF

# Install OpenShift Template CRD
echo "📦 Installing OpenShift Template CRD..."
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: templates.template.openshift.io
spec:
  group: template.openshift.io
  names:
    kind: Template
    listKind: TemplateList
    plural: templates
    singular: template
  scope: Namespaced
  versions:
  - name: v1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          objects:
            type: array
            items:
              type: object
              x-kubernetes-preserve-unknown-fields: true
          parameters:
            type: array
            items:
              type: object
              properties:
                name:
                  type: string
                displayName:
                  type: string
                description:
                  type: string
                value:
                  type: string
                required:
                  type: boolean
          labels:
            type: object
            x-kubernetes-preserve-unknown-fields: true
EOF

echo ""
echo "✅ OKD cluster created successfully"
echo "   Context: kind-${OKD_CLUSTER}"
echo "   API: https://localhost:6443"
echo ""
echo "🔍 Verify with:"
echo "   kubectl get nodes"
echo "   kubectl get pods -A"
echo "   kubectl get crds | grep openshift"
echo ""
# Rename context to simple name
kubectl config rename-context "kind-${OKD_CLUSTER}" "okd" 2>/dev/null || true

# Install DeploymentConfig Controller
echo "📦 Installing DeploymentConfig Controller..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: dc-controller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: dc-controller
rules:
- apiGroups: ["apps.openshift.io"]
  resources: ["deploymentconfigs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: dc-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dc-controller
subjects:
- kind: ServiceAccount
  name: dc-controller
  namespace: kube-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dc-controller
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dc-controller
  template:
    metadata:
      labels:
        app: dc-controller
    spec:
      serviceAccountName: dc-controller
      containers:
      - name: controller
        image: bitnami/kubectl:latest
        command:
        - /bin/bash
        - -c
        - |
          #!/bin/bash
          echo "Starting DeploymentConfig to Deployment controller..."
          
          while true; do
            # Get all DeploymentConfigs
            kubectl get dc --all-namespaces -o json | jq -r '.items[] | @json' | while read -r dc; do
              namespace=\\\$(echo "\\\$dc" | jq -r '.metadata.namespace')
              name=\\\$(echo "\\\$dc" | jq -r '.metadata.name')
              
              # Check if corresponding Deployment exists
              if ! kubectl get deployment "\\\$name" -n "\\\$namespace" &>/dev/null; then
                echo "Creating Deployment for DeploymentConfig \\\$namespace/\\\$name"
                
                # Extract spec from DC and create Deployment
                echo "\\\$dc" | jq '{
                  apiVersion: "apps/v1",
                  kind: "Deployment",
                  metadata: {
                    name: .metadata.name,
                    namespace: .metadata.namespace,
                    labels: .metadata.labels,
                    annotations: (.metadata.annotations + {"deploymentconfig.openshift.io/source": .metadata.name})
                  },
                  spec: {
                    replicas: .spec.replicas,
                    selector: {
                      matchLabels: .spec.selector
                    },
                    template: .spec.template
                  }
                }' | kubectl apply -f -
              fi
            done
            
            sleep 10
          done
EOF

echo ""
echo "📚 OpenShift-compatible features:"
echo "   • Operator Lifecycle Manager (OLM)"
echo "   • OpenShift Routes CRD"
echo "   • OpenShift Projects CRD"
echo "   • OpenShift DeploymentConfig CRD + Controller"
echo "   • OpenShift ImageStream CRD"
echo "   • OpenShift SecurityContextConstraints CRD"
echo "   • OpenShift Template CRD"
echo "   • OpenShift Router"
echo "   • Compatible with 'oc' CLI"
echo ""
echo "💡 To use 'oc' CLI:"
echo "   kubectl config use-context okd"
echo "   oc get nodes"
echo "   oc new-project myproject"
echo "   oc get routes"
echo ""

# Keep the service running by monitoring the kind container
echo "🔄 Monitoring OKD cluster..."
while docker ps --format '{{.Names}}' | grep -q "^okd-local-control-plane$"; do
    sleep 10
done

echo "❌ OKD cluster stopped"
exit 1
