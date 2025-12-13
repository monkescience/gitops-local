#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Creating kind cluster with GitOps configuration..."

if kind get clusters 2>/dev/null | grep -q "^gitops-local$"; then
    echo "Cluster 'gitops-local' already exists. Delete it first with: kind delete cluster --name gitops-local"
    exit 1
fi

export PROJECT_ROOT
envsubst < "$PROJECT_ROOT/kind-cluster.yaml.tmpl" > "$PROJECT_ROOT/kind-cluster.yaml"

kind create cluster --config "$PROJECT_ROOT/kind-cluster.yaml"

echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo ""
echo "✓ Kind cluster 'gitops-local' created successfully"
echo ""
echo "Cluster info:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes
