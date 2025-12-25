#!/usr/bin/env bash
# Kargo shard controller setup for multi-cluster topology

KARGO_SA_NAME="kargo-controller-shard"
KARGO_NAMESPACE="kargo"

# Create ServiceAccount and RBAC in management cluster for shard controllers
create_kargo_shard_sa() {
  info "Creating Kargo shard ServiceAccount in management cluster..."

  kubectl config use-context "kind-management-eu-central-1"

  # Create ServiceAccount in kargo namespace
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${KARGO_SA_NAME}
  namespace: ${KARGO_NAMESPACE}
EOF

  # Create ClusterRole for Kargo shard access
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: ${KARGO_SA_NAME}
rules:
  # Full access to Kargo resources
  - apiGroups: ["kargo.akuity.io"]
    resources: ["*"]
    verbs: ["*"]
  # Read access to secrets for credentials
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "watch"]
  # Read access to namespaces
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
  # Events for status updates
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "patch"]
EOF

  # Create ClusterRoleBinding
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${KARGO_SA_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: ${KARGO_SA_NAME}
subjects:
  - kind: ServiceAccount
    name: ${KARGO_SA_NAME}
    namespace: ${KARGO_NAMESPACE}
EOF

  # Create long-lived token secret
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${KARGO_SA_NAME}-token
  namespace: ${KARGO_NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: ${KARGO_SA_NAME}
type: kubernetes.io/service-account-token
EOF

  success "Kargo shard ServiceAccount created in management cluster"
}

# Get bearer token for shard controller access
get_kargo_shard_token() {
  kubectl config use-context "kind-management-eu-central-1" >/dev/null 2>&1
  kubectl get secret "${KARGO_SA_NAME}-token" -n "${KARGO_NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d
}

# Get CA certificate for management cluster
get_management_ca() {
  kubectl config use-context "kind-management-eu-central-1" >/dev/null 2>&1
  kubectl get secret "${KARGO_SA_NAME}-token" -n "${KARGO_NAMESPACE}" -o jsonpath='{.data.ca\.crt}' | base64 -d
}

# Create kubeconfig secret in a shard cluster
create_shard_kubeconfig_secret() {
  local cluster_name=$1
  local management_ip

  info "Creating kubeconfig secret in cluster '$cluster_name' for Kargo shard..."

  # Get management cluster IP on the shared network
  management_ip=$(get_cluster_ip_on_network "management-eu-central-1")
  if [[ -z "$management_ip" ]]; then
    error "Could not get IP for management cluster"
    return 1
  fi

  # Get credentials from management cluster
  local token ca_cert
  token=$(get_kargo_shard_token)
  ca_cert=$(get_management_ca)

  # Switch to shard cluster
  kubectl config use-context "kind-${cluster_name}"

  # Ensure kargo namespace exists
  kubectl create namespace "${KARGO_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

  # Create kubeconfig secret
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: kargo-management-kubeconfig
  namespace: ${KARGO_NAMESPACE}
type: Opaque
stringData:
  kubeconfig: |
    apiVersion: v1
    kind: Config
    clusters:
      - name: management
        cluster:
          server: https://${management_ip}:6443
          certificate-authority-data: $(echo -n "$ca_cert" | base64 | tr -d '\n')
    contexts:
      - name: management
        context:
          cluster: management
          user: kargo-shard
    current-context: management
    users:
      - name: kargo-shard
        user:
          token: ${token}
EOF

  success "Kubeconfig secret created in cluster '$cluster_name'"
}

# Setup Kargo shards for all workload clusters
kargo_setup_shards() {
  header "Setting up Kargo Controller Shards"

  # Ensure management cluster has Kargo running
  kubectl config use-context "kind-management-eu-central-1"
  if ! kubectl get namespace "${KARGO_NAMESPACE}" >/dev/null 2>&1; then
    error "Kargo namespace not found on management. Deploy Kargo first."
    exit 1
  fi

  # Create ServiceAccount for shard controllers
  create_kargo_shard_sa

  # Wait for token to be populated
  info "Waiting for ServiceAccount token..."
  sleep 3

  # Create kubeconfig secrets in shard clusters
  for cluster in "dev-eu-central-1" "prod-eu-central-1"; do
    if cluster_exists "$cluster"; then
      create_shard_kubeconfig_secret "$cluster"
    else
      warn "Cluster '$cluster' not running, skipping"
    fi
  done

  # Switch back to management context
  kubectl config use-context "kind-management-eu-central-1"

  success "Kargo shard setup complete"

  echo ""
  info "Shard kubeconfig secrets created in:"
  echo "  - dev-eu-central-1/kargo/kargo-management-kubeconfig"
  echo "  - prod-eu-central-1/kargo/kargo-management-kubeconfig"
  echo ""
  echo "The Kargo controller shards will use these to access the management cluster."
}
