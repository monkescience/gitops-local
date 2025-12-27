#!/usr/bin/env bash
# Docker network management for multi-cluster setup

NETWORK_NAME="gitops-kind"

network_create() {
  info "Creating Docker network for multi-cluster communication..."

  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    success "Docker network '$NETWORK_NAME' already exists"
    return 0
  fi

  docker network create "$NETWORK_NAME"
  success "Docker network '$NETWORK_NAME' created successfully"
}

network_delete() {
  info "Deleting Docker network '$NETWORK_NAME'..."

  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    warn "Docker network '$NETWORK_NAME' not found. Nothing to delete."
    return 0
  fi

  docker network rm "$NETWORK_NAME"
  success "Docker network '$NETWORK_NAME' deleted successfully"
}

network_connect_cluster() {
  local cluster_name=$1
  local container_name="$cluster_name-control-plane"

  if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    error "Docker network '$NETWORK_NAME' does not exist. Create it first."
    return 1
  fi

  if docker network inspect "$NETWORK_NAME" | grep -q "\"$container_name\""; then
    success "Container '$container_name' already connected to '$NETWORK_NAME'"
    return 0
  fi

  docker network connect "$NETWORK_NAME" "$container_name"
  success "Connected '$container_name' to Docker network '$NETWORK_NAME'"
}

get_cluster_ip_on_network() {
  local cluster_name=$1
  local container_name="$cluster_name-control-plane"

  # Use 'kind' network IP as it's included in the API server certificate SANs
  docker inspect "$container_name" --format '{{(index .NetworkSettings.Networks "kind").IPAddress}}' 2>/dev/null
}
