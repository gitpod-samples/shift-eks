#!/bin/bash
set -e

echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║         OpenShift Task Manager - Web Access Deployment Script           ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="task-manager"
APP_NAME="task-manager"
IMAGE_NAME="task-manager:latest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}📋 Configuration:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  App Name: $APP_NAME"
echo "  Image: $IMAGE_NAME"
echo "  Script Dir: $SCRIPT_DIR"
echo ""

# Step 1: Check if cluster is accessible
echo -e "${BLUE}1️⃣  Checking cluster access...${NC}"
if ! kubectl cluster-info &>/dev/null; then
    echo -e "${RED}❌ Cannot access Kubernetes cluster${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster is accessible${NC}"
echo ""

# Step 2: Build container image
echo -e "${BLUE}2️⃣  Building container image...${NC}"
cd "$SCRIPT_DIR"
if docker build -t "$IMAGE_NAME" . &>/dev/null; then
    echo -e "${GREEN}✅ Image built successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Image may already exist, continuing...${NC}"
fi
echo ""

# Step 3: Load image into cluster
echo -e "${BLUE}3️⃣  Loading image into OKD cluster...${NC}"
if docker save "$IMAGE_NAME" | docker exec -i okd-local-control-plane ctr -n k8s.io images import - &>/dev/null; then
    echo -e "${GREEN}✅ Image loaded into cluster${NC}"
else
    echo -e "${YELLOW}⚠️  Image may already be loaded, continuing...${NC}"
fi
echo ""

# Step 4: Create namespace
echo -e "${BLUE}4️⃣  Creating namespace...${NC}"
if kubectl create namespace "$NAMESPACE" &>/dev/null; then
    echo -e "${GREEN}✅ Namespace created${NC}"
else
    echo -e "${YELLOW}⚠️  Namespace already exists${NC}"
fi
echo ""

# Step 5: Deploy with Helm
echo -e "${BLUE}5️⃣  Deploying application with Helm...${NC}"
if helm upgrade --install "$APP_NAME" "$SCRIPT_DIR/helm/task-manager" \
    --namespace "$NAMESPACE" \
    --set image.repository=task-manager \
    --set image.tag=latest \
    --set image.pullPolicy=IfNotPresent \
    --set replicaCount=1 \
    --wait --timeout=2m; then
    echo -e "${GREEN}✅ Application deployed${NC}"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi
echo ""

# Step 6: Wait for pods to be ready
echo -e "${BLUE}6️⃣  Waiting for pods to be ready...${NC}"
if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=task-manager -n "$NAMESPACE" --timeout=60s &>/dev/null; then
    echo -e "${GREEN}✅ Pods are ready${NC}"
else
    echo -e "${RED}❌ Pods failed to become ready${NC}"
    kubectl get pods -n "$NAMESPACE"
    exit 1
fi
echo ""

# Step 7: Expose service via NodePort
echo -e "${BLUE}7️⃣  Configuring web access...${NC}"
kubectl patch svc "$APP_NAME" -n "$NAMESPACE" -p '{"spec":{"type":"NodePort"}}' &>/dev/null || true
NODE_PORT=$(kubectl get svc "$APP_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].nodePort}')
echo -e "${GREEN}✅ Service exposed on NodePort: $NODE_PORT${NC}"
echo ""

# Step 8: Set up port forwarding for web access
echo -e "${BLUE}8️⃣  Setting up port forwarding for web browser access...${NC}"

# Kill any existing port-forward on port 8080
pkill -f "port-forward.*task-manager.*8080" 2>/dev/null || true
sleep 2

# Start port forwarding in background
kubectl port-forward -n "$NAMESPACE" svc/"$APP_NAME" 8080:8080 &>/dev/null &
PORT_FORWARD_PID=$!
sleep 3

# Verify port forwarding is working
if ps -p $PORT_FORWARD_PID > /dev/null; then
    echo -e "${GREEN}✅ Port forwarding established (PID: $PORT_FORWARD_PID)${NC}"
else
    echo -e "${RED}❌ Port forwarding failed${NC}"
    exit 1
fi
echo ""

# Step 9: Test the application
echo -e "${BLUE}9️⃣  Testing application...${NC}"
sleep 2
if curl -s http://localhost:8080/health | grep -q "healthy"; then
    echo -e "${GREEN}✅ Application is responding${NC}"
else
    echo -e "${RED}❌ Application health check failed${NC}"
    exit 1
fi
echo ""

# Step 10: Display access information
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║                                                                          ║"
echo "║                    ✅ DEPLOYMENT SUCCESSFUL!                             ║"
echo "║                                                                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${GREEN}🌐 Web Access:${NC}"
echo ""
echo -e "  ${BLUE}Application URL:${NC} http://localhost:8080"
echo -e "  ${BLUE}Health Check:${NC}    http://localhost:8080/health"
echo -e "  ${BLUE}API Endpoint:${NC}    http://localhost:8080/api/tasks"
echo ""
echo -e "${YELLOW}📝 Important Notes:${NC}"
echo ""
echo "  • Port forwarding is running in the background (PID: $PORT_FORWARD_PID)"
echo "  • The application is accessible at http://localhost:8080"
echo "  • Open this URL in your web browser to use the Task Manager"
echo ""
echo -e "${BLUE}🛠️  Management Commands:${NC}"
echo ""
echo "  # View application logs"
echo "  kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=task-manager -f"
echo ""
echo "  # View all resources"
echo "  kubectl get all,route -n $NAMESPACE"
echo ""
echo "  # Stop port forwarding"
echo "  kill $PORT_FORWARD_PID"
echo ""
echo "  # Restart port forwarding"
echo "  kubectl port-forward -n $NAMESPACE svc/$APP_NAME 8080:8080"
echo ""
echo "  # Uninstall application"
echo "  helm uninstall $APP_NAME -n $NAMESPACE"
echo ""
echo -e "${GREEN}🎉 Ready to use! Open http://localhost:8080 in your browser${NC}"
echo ""

# Save PID to file for later cleanup
echo "$PORT_FORWARD_PID" > /tmp/task-manager-port-forward.pid
echo -e "${BLUE}💾 Port forward PID saved to: /tmp/task-manager-port-forward.pid${NC}"
echo ""
