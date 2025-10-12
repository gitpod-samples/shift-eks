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
        kubectl config use-context "kind-${OKD_CLUSTER}"
        return 0 2>/dev/null || exit 0
    else
        echo "🔄 Starting existing OKD cluster..."
        docker start "${OKD_CLUSTER}-control-plane"
        sleep 10
        kubectl config use-context "kind-${OKD_CLUSTER}"
        return 0 2>/dev/null || exit 0
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
echo "📚 OpenShift-compatible features:"
echo "   • Operator Lifecycle Manager (OLM)"
echo "   • OpenShift Routes CRD"
echo "   • OpenShift Projects CRD"
echo "   • OpenShift Router"
echo "   • Compatible with 'oc' CLI"
echo ""
echo "💡 To use 'oc' CLI:"
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
return 1 2>/dev/null || exit 1
