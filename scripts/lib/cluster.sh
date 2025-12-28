#!/usr/bin/env bash
# Cluster management commands

CLUSTERS=("management-eu-central-1" "dev-eu-central-1" "prod-eu-central-1")

cluster_exists() {
  local cluster_name=$1
  k3d cluster list -o json 2>/dev/null | jq -e --arg name "$cluster_name" '.[] | select(.name == $name)' >/dev/null 2>&1
}

cluster_create_single() {
  local cluster_name=$1

  info "Creating k3d cluster '$cluster_name'..."

  if cluster_exists "$cluster_name"; then
    warn "Cluster '$cluster_name' already exists, skipping"
    return 0
  fi

  local template="$PROJECT_ROOT/k3d-cluster-${cluster_name}.yaml.tmpl"
  local config="$PROJECT_ROOT/k3d-cluster-${cluster_name}.yaml"

  if [[ ! -f "$template" ]]; then
    error "Cluster template not found: $template"
    return 1
  fi

  export PROJECT_ROOT
  envsubst < "$template" > "$config"

  k3d cluster create --config "$config"

  info "Waiting for cluster '$cluster_name' to be ready..."
  kubectl config use-context "k3d-${cluster_name}"
  kubectl wait --for=condition=Ready nodes --all --timeout=300s

  success "k3d cluster '$cluster_name' created successfully"
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

  info "Deleting k3d cluster '$cluster_name'..."

  if cluster_exists "$cluster_name"; then
    k3d cluster delete "$cluster_name"
    success "Cluster '$cluster_name' deleted successfully"
  else
    warn "Cluster '$cluster_name' not found. Nothing to delete."
  fi
}

cluster_delete() {
  local target=${1:-all}

  header "k3d GitOps Stack - Teardown"

  echo "This will delete ALL k3d clusters:"
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

  info "Deleting all k3d clusters in parallel..."
  k3d cluster delete "${CLUSTERS[@]}" 2>/dev/null || true

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

  kubectl config use-context "k3d-${cluster_name}"
  success "Switched to context 'k3d-${cluster_name}'"
}

ensure_cross_cluster_network() {
  local management_network="k3d-management-eu-central-1"

  if ! docker network inspect "$management_network" >/dev/null 2>&1; then
    warn "Management network not found, skipping cross-cluster setup"
    return 0
  fi

  info "Connecting clusters to shared network for inter-cluster communication..."

  for cluster in "dev-eu-central-1" "prod-eu-central-1"; do
    if cluster_exists "$cluster"; then
      for container in "k3d-${cluster}-server-0" "k3d-${cluster}-agent-0" "k3d-${cluster}-serverlb"; do
        if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
          if ! docker network inspect "$management_network" --format '{{range .Containers}}{{.Name}} {{end}}' | grep -q "$container"; then
            docker network connect "$management_network" "$container" 2>/dev/null || true
          fi
        fi
      done
    fi
  done

  success "Cross-cluster network configured"
}
