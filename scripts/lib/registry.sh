#!/usr/bin/env bash
# Local container registry for Kind clusters

REGISTRY_NAME="kind-registry"
REGISTRY_PORT="5000"

registry_running() {
  docker inspect "$REGISTRY_NAME" >/dev/null 2>&1
}

registry_create() {
  if registry_running; then
    success "Local registry '$REGISTRY_NAME' already running"
    return 0
  fi

  info "Creating local container registry..."

  docker run -d --restart=always \
    --name "$REGISTRY_NAME" \
    --network bridge \
    -p "127.0.0.1:${REGISTRY_PORT}:5000" \
    -v kind-registry:/var/lib/registry \
    registry:2

  success "Local registry created at localhost:${REGISTRY_PORT}"
}

registry_connect_cluster() {
  local cluster_name=$1

  if ! registry_running; then
    warn "Registry not running, skipping connection"
    return 0
  fi

  # Connect registry to the cluster network if not already connected
  if ! docker network inspect kind | grep -q "\"$REGISTRY_NAME\""; then
    docker network connect kind "$REGISTRY_NAME" 2>/dev/null || true
  fi

  # Document the registry for the cluster
  kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${REGISTRY_PORT}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

  success "Registry connected to cluster '$cluster_name'"
}
