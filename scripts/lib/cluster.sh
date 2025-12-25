#!/usr/bin/env bash
# Cluster management commands for multi-cluster setup

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

  # Connect to shared Docker network
  network_connect_cluster "$cluster_name"

  # Connect to local registry
  registry_connect_cluster "$cluster_name"

  success "Kind cluster '$cluster_name' created successfully"
}

cluster_create() {
  local target=${1:-all}

  if [[ "$target" == "all" ]]; then
    # Create network and registry first
    network_create
    registry_create

    for cluster in "${CLUSTERS[@]}"; do
      cluster_create_single "$cluster"
    done

    echo ""
    info "All clusters created. Summary:"
    for cluster in "${CLUSTERS[@]}"; do
      echo "  - $cluster: $(get_cluster_ip_on_network "$cluster")"
    done
  else
    # Validate cluster name
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

    # Ensure network and registry exist
    network_create
    registry_create

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

  if [[ "$target" == "all" ]]; then
    echo "This will delete ALL Kind clusters:"
    for cluster in "${CLUSTERS[@]}"; do
      echo "  - $cluster"
    done
    echo ""
    echo "and the Docker network '$NETWORK_NAME'."
  else
    echo "This will delete the Kind cluster '$target'"
  fi
  echo ""

  read -p "Are you sure? (y/n) " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warn "Teardown cancelled."
    exit 0
  fi

  echo ""

  if [[ "$target" == "all" ]]; then
    for cluster in "${CLUSTERS[@]}"; do
      cluster_delete_single "$cluster"
    done
    network_delete
  else
    cluster_delete_single "$target"
  fi
}

cluster_status() {
  header "Cluster Status"

  for cluster in "${CLUSTERS[@]}"; do
    if cluster_exists "$cluster"; then
      local ip
      ip=$(get_cluster_ip_on_network "$cluster")
      echo -e "${GREEN}✓${NC} $cluster (IP: ${ip:-unknown})"
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
