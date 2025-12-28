#!/usr/bin/env bash
# Network utilities for cluster communication

get_cluster_ip_on_network() {
  local cluster_name=$1
  local container_name="k3d-${cluster_name}-server-0"
  local network_name="k3d-management-eu-central-1"

  # Use management network IP for inter-cluster communication (Kargo shards).
  # All clusters are connected to this network via ensure_cross_cluster_network().
  docker inspect "$container_name" --format "{{(index .NetworkSettings.Networks \"$network_name\").IPAddress}}" 2>/dev/null
}
