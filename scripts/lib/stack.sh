#!/usr/bin/env bash
# Stack deployment commands

stack_deploy() {
  info "Deploying GitOps stack via ArgoCD..."

  kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-dev.yaml"

  success "Root ArgoCD application 'eu-central-1-dev' created"
}
