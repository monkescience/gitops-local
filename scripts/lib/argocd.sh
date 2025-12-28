#!/usr/bin/env bash

argocd_bootstrap() {
  local cluster=${1:-management-eu-central-1}
  local ARGOCD_APP_FILE="$PROJECT_ROOT/apps/$cluster/platform/argocd.yaml"
  local ARGOCD_CHART_VERSION
  ARGOCD_CHART_VERSION=$(yq 'select(document_index == 0) | .spec.sources[0].targetRevision' "$ARGOCD_APP_FILE")
  local ARGOCD_REPO="https://argoproj.github.io/argo-helm"
  local ARGOCD_VALUES="$PROJECT_ROOT/manifests/argocd/$cluster/values.yaml"

  info "Bootstrapping ArgoCD on $cluster cluster..."

  kubectl config use-context "k3d-$cluster"

  # Restore sealed secrets key if backup exists (only on management)
  if [[ "$cluster" == "management-eu-central-1" ]]; then
    secrets_restore
  fi

  ensure_namespace argocd

  info "Installing ArgoCD via Helm (chart version: $ARGOCD_CHART_VERSION)..."
  helm upgrade --install argocd argo-cd \
    --repo "$ARGOCD_REPO" \
    --namespace argocd \
    --version "$ARGOCD_CHART_VERSION" \
    --values "$ARGOCD_VALUES" \
    --wait \
    --timeout 10m

  success "ArgoCD installed successfully on $cluster cluster"

  # Bootstrap: AppProjects must exist before platform apps can sync.
  # ArgoCD will continue managing this via argocd-extension after initial sync.
  info "Creating ArgoCD AppProjects (bootstrap)..."
  kubectl apply -f "$PROJECT_ROOT/manifests/argocd-extension/$cluster/projects.yaml"
  success "ArgoCD AppProjects created"

  header "ArgoCD Credentials"
  echo "  Username: admin"
  echo "  Password: admin"

  if [[ "$cluster" == "management-eu-central-1" ]]; then
    header "Sealed Secrets"
    echo "After sealed-secrets is deployed, backup the key with:"
    echo "  gitops secrets backup"
  fi
}
