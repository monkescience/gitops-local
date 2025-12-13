#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Creating k3d cluster with GitOps configuration..."

# Check if cluster already exists
if k3d cluster list | grep -q gitops-local; then
    echo "Cluster 'gitops-local' already exists. Delete it first with: k3d cluster delete gitops-local"
    exit 1
fi

# Create cluster
k3d cluster create --config "$PROJECT_ROOT/k3d-cluster.yaml"

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s

echo ""
echo "✓ K3d cluster 'gitops-local' created successfully"
echo ""
echo "Cluster info:"
kubectl cluster-info
echo ""
echo "Nodes:"
kubectl get nodes
