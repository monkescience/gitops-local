#!/usr/bin/env bash
# Network utilities for cluster communication

get_cluster_ip_on_network() {
  local cluster_name=$1
  local container_name="$cluster_name-control-plane"

  # Use 'kind' network IP as it's included in the API server certificate SANs
  docker inspect "$container_name" --format '{{(index .NetworkSettings.Networks "kind").IPAddress}}' 2>/dev/null
}
