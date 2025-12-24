#!/usr/bin/env bash
# ArgoCD management commands for multi-cluster setup

argocd_bootstrap() {
  local ARGOCD_APP_FILE="$PROJECT_ROOT/apps/eu-central-1-management/platform/argocd.yaml"
  local ARGOCD_CHART_VERSION
  ARGOCD_CHART_VERSION=$(yq 'select(document_index == 0) | .spec.sources[0].targetRevision' "$ARGOCD_APP_FILE")
  local ARGOCD_REPO="https://argoproj.github.io/argo-helm"
  local ARGOCD_VALUES="$PROJECT_ROOT/manifests/argocd/eu-central-1-management/values.yaml"

  info "Bootstrapping ArgoCD on management cluster..."

  # Ensure we're on management cluster
  kubectl config use-context "kind-eu-central-1-management"

  # Restore sealed secrets key if backup exists
  secrets_restore

  ensure_namespace argocd

  info "Installing ArgoCD via Helm (chart version: $ARGOCD_CHART_VERSION)..."
  helm upgrade --install argocd argo-cd \
    --repo "$ARGOCD_REPO" \
    --namespace argocd \
    --version "$ARGOCD_CHART_VERSION" \
    --values "$ARGOCD_VALUES" \
    --wait \
    --timeout 10m

  success "ArgoCD installed successfully on management cluster"

  header "ArgoCD Credentials"
  echo "  Username: admin"
  echo "  Password: admin"

  echo ""
  echo "Access ArgoCD UI (after Istio Gateway is deployed):"
  echo "  https://argocd.localhost"
  echo ""
  echo "Or use port-forward while waiting for full stack deployment:"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "  Then visit: https://localhost:8080"

  header "Sealed Secrets"
  echo "After sealed-secrets is deployed, backup the key with:"
  echo "  gitops secrets backup"
}
