#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================="
echo "K3d GitOps Stack - Complete Setup"
echo "========================================="
echo ""

# Check prerequisites
echo "Checking prerequisites..."
command -v k3d >/dev/null 2>&1 || { echo "Error: k3d not found. Install: brew install k3d"; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "Error: kubectl not found. Install: brew install kubectl"; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "Error: helm not found. Install: brew install helm"; exit 1; }

K3D_VERSION=$(k3d version | head -1 | awk '{print $3}')
KUBECTL_VERSION=$(kubectl version --client -o yaml | grep gitVersion | awk '{print $2}')
HELM_VERSION=$(helm version --short | cut -d'+' -f1)
echo "✓ k3d $K3D_VERSION"
echo "✓ kubectl $KUBECTL_VERSION"
echo "✓ helm $HELM_VERSION"
echo ""

# Warning about resources
echo "========================================="
echo "Resource Requirements:"
echo "  - CPU: 4 cores recommended"
echo "  - RAM: 12 GB recommended"
echo "  - Disk: 20 GB free space"
echo "  - Time: 10-15 minutes"
echo "========================================="
echo ""

read -p "Do you want to continue? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Starting setup..."
echo ""

# Step 1: Create cluster
echo "========================================="
echo "Step 1/3: Creating k3d cluster"
echo "========================================="
"$SCRIPT_DIR/create-cluster.sh"
echo ""

# Step 2: Bootstrap ArgoCD
echo "========================================="
echo "Step 2/3: Bootstrapping ArgoCD"
echo "========================================="
"$SCRIPT_DIR/bootstrap-argocd.sh"
echo ""

# Step 3: Deploy stack
echo "========================================="
echo "Step 3/3: Deploy GitOps Stack"
echo "========================================="
echo ""
"$SCRIPT_DIR/deploy-stack.sh"

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "The stack is deploying in the background."
echo ""
echo "Quick commands:"
echo "  Watch deployment:  kubectl get applications -n argocd -w"
echo "  Check pods:        kubectl get pods -A"
echo ""

echo "========================================="
echo "Service Access (after deployment completes)"
echo "========================================="
echo ""
echo "ArgoCD:"
echo "  URL:      https://argocd.localhost"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Grafana:"
echo "  URL:      https://grafana.localhost"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Kargo:"
echo "  URL:      https://kargo.localhost"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Note: Browser will show certificate warning (self-signed)."
echo "      Click 'Advanced' -> 'Proceed' to continue."
echo ""
