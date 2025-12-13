#!/usr/bin/env bash
set -euo pipefail

echo "========================================="
echo "Kind GitOps Stack - Teardown"
echo "========================================="
echo ""
echo "This will delete the kind cluster 'gitops-local'"
echo "and all resources within it."
echo ""

read -p "Are you sure? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo "Deleting kind cluster 'gitops-local'..."

if kind get clusters 2>/dev/null | grep -q "^gitops-local$"; then
    kind delete cluster --name gitops-local
    echo ""
    echo "✓ Cluster deleted successfully"
else
    echo "Cluster 'gitops-local' not found. Nothing to delete."
fi
