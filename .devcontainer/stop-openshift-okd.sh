#!/bin/bash
set -e

OKD_CLUSTER="okd-local"

echo "🛑 Stopping OpenShift OKD cluster..."

if kind get clusters 2>/dev/null | grep -q "^${OKD_CLUSTER}$"; then
    kind delete cluster --name ${OKD_CLUSTER}
    echo "✅ OpenShift OKD cluster stopped"
else
    echo "ℹ️  OpenShift OKD cluster not running"
fi
