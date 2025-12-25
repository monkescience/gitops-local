#!/usr/bin/env bash
# ArgoCD management commands for multi-cluster setup

argocd_bootstrap() {
  local cluster=${1:-management-eu-central-1}
  local ARGOCD_APP_FILE="$PROJECT_ROOT/apps/$cluster/platform/argocd.yaml"
  local ARGOCD_CHART_VERSION
  ARGOCD_CHART_VERSION=$(yq 'select(document_index == 0) | .spec.sources[0].targetRevision' "$ARGOCD_APP_FILE")
  local ARGOCD_REPO="https://argoproj.github.io/argo-helm"
  local ARGOCD_VALUES="$PROJECT_ROOT/manifests/argocd/$cluster/values.yaml"

  info "Bootstrapping ArgoCD on $cluster cluster..."

  kubectl config use-context "kind-$cluster"

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

  info "Creating ArgoCD AppProjects..."
  kubectl apply -f "$PROJECT_ROOT/manifests/argocd-extension/$cluster/projects.yaml"
  success "ArgoCD AppProjects created"

  header "ArgoCD Credentials"
  echo "  Username: admin"
  echo "  Password: admin"

  case "$cluster" in
    management-eu-central-1)
      echo ""
      echo "Access ArgoCD UI (after Istio Gateway is deployed):"
      echo "  https://argocd.localhost"
      ;;
    dev-eu-central-1)
      echo ""
      echo "Access ArgoCD UI (after Istio Gateway is deployed):"
      echo "  https://argocd-dev.localhost"
      ;;
    prod-eu-central-1)
      echo ""
      echo "Access ArgoCD UI (after Istio Gateway is deployed):"
      echo "  https://argocd-prod.localhost"
      ;;
  esac

  echo ""
  echo "Or use port-forward while waiting for full stack deployment:"
  echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
  echo "  Then visit: https://localhost:8080"

  if [[ "$cluster" == "management-eu-central-1" ]]; then
    header "Sealed Secrets"
    echo "After sealed-secrets is deployed, backup the key with:"
    echo "  gitops secrets backup"
  fi
}

argocd_bootstrap_all() {
  info "Bootstrapping ArgoCD on all clusters with immediate root app deployment..."

  # Management: bootstrap ArgoCD + deploy root app immediately
  # This allows management apps to start syncing while we bootstrap dev
  argocd_bootstrap management-eu-central-1
  info "Deploying root app on management cluster (apps will sync in background)..."
  stack_deploy_single management-eu-central-1

  # Dev: bootstrap ArgoCD + deploy root app immediately
  # This allows dev apps to start syncing while we bootstrap prod
  argocd_bootstrap dev-eu-central-1
  info "Deploying root app on dev cluster (apps will sync in background)..."
  stack_deploy_single dev-eu-central-1

  # Prod: bootstrap ArgoCD + deploy root app
  argocd_bootstrap prod-eu-central-1
  info "Deploying root app on prod cluster (apps will sync in background)..."
  stack_deploy_single prod-eu-central-1

  success "ArgoCD bootstrapped and root apps deployed on all clusters"
}
