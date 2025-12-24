#!/usr/bin/env bash
# Stack deployment commands for multi-cluster setup

stack_deploy() {
  local target=${1:-all}

  info "Deploying GitOps stack via ArgoCD..."

  case "$target" in
    all)
      # Deploy all stacks: management first, then workload clusters
      kubectl config use-context "kind-eu-central-1-management"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-management.yaml"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-dev.yaml"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-prod.yaml"
      success "Root ArgoCD applications created for all clusters"
      ;;
    management)
      kubectl config use-context "kind-eu-central-1-management"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-management.yaml"
      success "Root ArgoCD application 'eu-central-1-management' created"
      ;;
    dev)
      kubectl config use-context "kind-eu-central-1-management"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-dev.yaml"
      success "Root ArgoCD application 'eu-central-1-dev' created"
      ;;
    prod)
      kubectl config use-context "kind-eu-central-1-management"
      kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-prod.yaml"
      success "Root ArgoCD application 'eu-central-1-prod' created"
      ;;
    *)
      error "Unknown target: $target"
      echo "  Valid targets: all, management, dev, prod"
      exit 1
      ;;
  esac
}
