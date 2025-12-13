#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ArgoCD Helm chart configuration (must match apps/eu-central-1-dev/platform/argocd.yaml)
ARGOCD_CHART_VERSION="9.1.3"
ARGOCD_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_VALUES="$PROJECT_ROOT/manifests/argocd/eu-central-1-dev/values.yaml"

echo "Bootstrapping ArgoCD..."

# Create argocd namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD using Helm
echo "Installing ArgoCD via Helm (chart version: $ARGOCD_CHART_VERSION)..."
helm upgrade --install argocd argo-cd \
  --repo "$ARGOCD_REPO" \
  --namespace argocd \
  --version "$ARGOCD_CHART_VERSION" \
  --values "$ARGOCD_VALUES" \
  --wait \
  --timeout 10m

echo ""
echo "ArgoCD installed successfully"
echo ""
echo "========================================="
echo "ArgoCD Credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo "========================================="
echo ""
echo "Access ArgoCD UI (after Traefik is deployed):"
echo "  https://argocd.localhost"
echo ""
echo "Or use port-forward while waiting for full stack deployment:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  Then visit: https://localhost:8080"
echo ""
