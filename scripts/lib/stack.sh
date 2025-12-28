#!/usr/bin/env bash

stack_deploy_single() {
  local cluster=$1

  case "$cluster" in
    management-eu-central-1)
      kubectl config use-context "k3d-management-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/management-eu-central-1.yaml"
      success "Root ArgoCD application 'management-eu-central-1' created on management cluster"
      ;;
    dev-eu-central-1)
      kubectl config use-context "k3d-dev-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/dev-eu-central-1.yaml"
      success "Root ArgoCD application 'dev-eu-central-1' created on dev cluster"
      ;;
    prod-eu-central-1)
      kubectl config use-context "k3d-prod-eu-central-1"
      kubectl apply -f "$PROJECT_ROOT/apps/prod-eu-central-1.yaml"
      success "Root ArgoCD application 'prod-eu-central-1' created on prod cluster"
      ;;
    *)
      error "Unknown cluster: $cluster"
      exit 1
      ;;
  esac
}

stack_deploy() {
  local target=${1:-all}

  info "Deploying GitOps stack via ArgoCD..."

  case "$target" in
    all)
      stack_deploy_single management-eu-central-1
      stack_deploy_single dev-eu-central-1
      stack_deploy_single prod-eu-central-1
      success "Root ArgoCD applications created for all clusters"
      ;;
    management)
      stack_deploy_single management-eu-central-1
      ;;
    dev)
      stack_deploy_single dev-eu-central-1
      ;;
    prod)
      stack_deploy_single prod-eu-central-1
      ;;
    *)
      error "Unknown target: $target"
      echo "  Valid targets: all, management, dev, prod"
      exit 1
      ;;
  esac
}
