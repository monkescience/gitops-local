#!/usr/bin/env bash
# Stack deployment commands for multi-cluster setup

stack_deploy() {
  local target=${1:-all}

  info "Deploying GitOps stack via ArgoCD..."

  case "$target" in
    all)
      # Deploy all stacks: each cluster has its own ArgoCD
      kubectl config use-context "kind-management-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/management-eu-central-1.yaml"
      success "Root ArgoCD application 'management-eu-central-1' created on management cluster"

      kubectl config use-context "kind-dev-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/dev-eu-central-1.yaml"
      success "Root ArgoCD application 'dev-eu-central-1' created on dev cluster"

      kubectl config use-context "kind-prod-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/prod-eu-central-1.yaml"
      success "Root ArgoCD application 'prod-eu-central-1' created on prod cluster"

      success "Root ArgoCD applications created for all clusters"
      ;;
    management)
      kubectl config use-context "kind-management-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/management-eu-central-1.yaml"
      success "Root ArgoCD application 'management-eu-central-1' created"
      ;;
    dev)
      kubectl config use-context "kind-dev-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/dev-eu-central-1.yaml"
      success "Root ArgoCD application 'dev-eu-central-1' created"
      ;;
    prod)
      kubectl config use-context "kind-prod-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/prod-eu-central-1.yaml"
      success "Root ArgoCD application 'prod-eu-central-1' created"
      ;;
    *)
      error "Unknown target: $target"
      echo "  Valid targets: all, management, dev, prod"
      exit 1
      ;;
  esac
}
