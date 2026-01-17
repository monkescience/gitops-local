#!/usr/bin/env bash
# Cluster management commands

CLUSTERS=("management-eu-central-1" "dev-eu-central-1" "prod-eu-central-1")

cluster_exists() {
  local cluster_name=$1
  kind get clusters 2>/dev/null | grep -q "^${cluster_name}$"
}

cluster_create_single() {
  local cluster_name=$1

  info "Creating Kind cluster '$cluster_name'..."

  if cluster_exists "$cluster_name"; then
    warn "Cluster '$cluster_name' already exists, skipping"
    return 0
  fi

  local template="$PROJECT_ROOT/kind-cluster-${cluster_name}.yaml.tmpl"
  local config="$PROJECT_ROOT/kind-cluster-${cluster_name}.yaml"

  if [[ ! -f "$template" ]]; then
    error "Cluster template not found: $template"
    return 1
  fi

  export PROJECT_ROOT
  envsubst < "$template" > "$config"

  kind create cluster --config "$config"

  info "Waiting for cluster '$cluster_name' to be ready..."
  kubectl config use-context "kind-${cluster_name}"
  kubectl wait --for=condition=Ready nodes --all --timeout=300s

  success "Kind cluster '$cluster_name' created successfully"
}

cluster_create() {
  local target=${1:-all}

  if [[ "$target" == "all" ]]; then
    for cluster in "${CLUSTERS[@]}"; do
      cluster_create_single "$cluster"
    done
    success "All clusters created"
  else
    local valid=false
    for cluster in "${CLUSTERS[@]}"; do
      if [[ "$cluster" == "$target" ]]; then
        valid=true
        break
      fi
    done

    if [[ "$valid" != "true" ]]; then
      error "Invalid cluster name: $target"
      echo "  Valid clusters: ${CLUSTERS[*]}"
      exit 1
    fi

    cluster_create_single "$target"
  fi
}

cluster_delete_single() {
  local cluster_name=$1

  info "Deleting Kind cluster '$cluster_name'..."

  if cluster_exists "$cluster_name"; then
    kind delete cluster --name "$cluster_name"
    success "Cluster '$cluster_name' deleted successfully"
  else
    warn "Cluster '$cluster_name' not found. Nothing to delete."
  fi
}

cluster_delete() {
  local target=${1:-all}

  header "Kind GitOps Stack - Teardown"

  echo "This will delete ALL Kind clusters:"
  for cluster in "${CLUSTERS[@]}"; do
    echo "  - $cluster"
  done
  echo ""

  read -p "Are you sure? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Teardown cancelled."
    exit 0
  fi

  echo ""

  for ((i=${#CLUSTERS[@]}-1; i>=0; i--)); do
    cluster_delete_single "${CLUSTERS[$i]}"
  done

  success "All clusters deleted"
}

cluster_status() {
  header "Cluster Status"

  for cluster in "${CLUSTERS[@]}"; do
    if cluster_exists "$cluster"; then
      echo -e "${GREEN}✓${NC} $cluster"
    else
      echo -e "${RED}✗${NC} $cluster (not running)"
    fi
  done
}

switch_context() {
  local cluster_name=$1

  if [[ -z "$cluster_name" ]]; then
    error "Cluster name required"
    echo "  Usage: gitops context <cluster-name>"
    echo "  Available: ${CLUSTERS[*]}"
    exit 1
  fi

  if ! cluster_exists "$cluster_name"; then
    error "Cluster '$cluster_name' does not exist"
    exit 1
  fi

  kubectl config use-context "kind-${cluster_name}"
  success "Switched to context 'kind-${cluster_name}'"
}
