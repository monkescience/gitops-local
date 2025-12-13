#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "K3d GitOps Stack - Teardown"
echo "========================================="
echo ""
echo "This will delete the k3d cluster 'gitops-local'"
echo "and all resources within it."
echo ""

read -p "Are you sure? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Deleting k3d cluster 'gitops-local'..."

if k3d cluster list | grep -q gitops-local; then
    k3d cluster delete gitops-local
    echo ""
    echo "✓ Cluster deleted successfully"
else
    echo "Cluster 'gitops-local' not found. Nothing to delete."
fi
