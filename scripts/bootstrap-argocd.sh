#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ARGOCD_APP_FILE="$PROJECT_ROOT/apps/eu-central-1-dev/platform/argocd.yaml"
ARGOCD_CHART_VERSION=$(yq 'select(document_index == 0) | .spec.sources[0].targetRevision' "$ARGOCD_APP_FILE")
ARGOCD_REPO="https://argoproj.github.io/argo-helm"
ARGOCD_VALUES="$PROJECT_ROOT/manifests/argocd/eu-central-1-dev/values.yaml"
SEALED_SECRETS_KEY="$PROJECT_ROOT/.sealed-secrets-key.yaml"

restore_sealed_secrets_key() {
  if [ -f "$SEALED_SECRETS_KEY" ]; then
    echo "Restoring Sealed Secrets master key from backup..."
    kubectl create namespace sealed-secrets --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
    kubectl apply -f "$SEALED_SECRETS_KEY"
    echo "Sealed Secrets key restored"
  else
    echo "No Sealed Secrets key backup found (first time setup)"
  fi
}

backup_sealed_secrets_key() {
  echo "Backing up Sealed Secrets master key..."
  kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key=active -o yaml > "$SEALED_SECRETS_KEY"
  echo "Sealed Secrets key backed up to $SEALED_SECRETS_KEY"
}

echo "Bootstrapping ArgoCD..."

restore_sealed_secrets_key

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

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
echo "========================================="
echo "Sealed Secrets:"
echo "  After sealed-secrets is deployed, backup the key with:"
echo "  $0 --backup-sealed-secrets-key"
echo "========================================="

if [ "${1:-}" = "--backup-sealed-secrets-key" ]; then
  backup_sealed_secrets_key
fi
