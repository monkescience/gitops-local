#!/usr/bin/env bash
# Cluster management commands

cluster_create() {
  info "Creating Kind cluster with GitOps configuration..."

  if kind get clusters 2>/dev/null | grep -q "^gitops-local$"; then
    error "Cluster 'gitops-local' already exists"
    echo "  Delete it first with: gitops teardown"
    exit 1
  fi

  export PROJECT_ROOT
  envsubst < "$PROJECT_ROOT/kind-cluster.yaml.tmpl" > "$PROJECT_ROOT/kind-cluster.yaml"

  kind create cluster --config "$PROJECT_ROOT/kind-cluster.yaml"

  info "Waiting for cluster to be ready..."
  kubectl wait --for=condition=Ready nodes --all --timeout=300s

  success "Kind cluster 'gitops-local' created successfully"
  echo ""
  echo "Cluster info:"
  kubectl cluster-info
  echo ""
  echo "Nodes:"
  kubectl get nodes
}

cluster_delete() {
  header "Kind GitOps Stack - Teardown"
  echo "This will delete the Kind cluster 'gitops-local'"
  echo "and all resources within it."
  echo ""

  read -p "Are you sure? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Teardown cancelled."
    exit 0
  fi

  echo ""
  info "Deleting Kind cluster 'gitops-local'..."

  if kind get clusters 2>/dev/null | grep -q "^gitops-local$"; then
    kind delete cluster --name gitops-local
    success "Cluster deleted successfully"
  else
    warn "Cluster 'gitops-local' not found. Nothing to delete."
  fi
}
