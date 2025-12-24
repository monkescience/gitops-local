#!/usr/bin/env bash
# ArgoCD cluster registration for multi-cluster setup

ARGOCD_NAMESPACE="argocd"
ARGOCD_SA_NAME="argocd-manager"

# Create ServiceAccount and ClusterRoleBinding in target cluster for ArgoCD access
create_argocd_sa_in_cluster() {
  local cluster_name=$1

  info "Creating ArgoCD service account in cluster '$cluster_name'..."

  kubectl config use-context "kind-${cluster_name}"

  # Create namespace if needed
  kubectl create namespace kube-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

  # Create ServiceAccount
  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ARGOCD_SA_NAME}
  namespace: kube-system
EOF

  # Create ClusterRoleBinding
  kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ${ARGOCD_SA_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: ${ARGOCD_SA_NAME}
    namespace: kube-system
EOF

  # Create long-lived token secret
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${ARGOCD_SA_NAME}-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: ${ARGOCD_SA_NAME}
type: kubernetes.io/service-account-token
EOF

  success "ArgoCD service account created in cluster '$cluster_name'"
}

# Get bearer token for ArgoCD access
get_cluster_token() {
  local cluster_name=$1

  kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1
  kubectl get secret "${ARGOCD_SA_NAME}-token" -n kube-system -o jsonpath='{.data.token}' | base64 -d
}

# Get CA certificate for cluster
get_cluster_ca() {
  local cluster_name=$1

  kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1
  kubectl get secret "${ARGOCD_SA_NAME}-token" -n kube-system -o jsonpath='{.data.ca\.crt}'
}

# Register a cluster with ArgoCD on management cluster
register_cluster_with_argocd() {
  local cluster_name=$1
  local cluster_ip

  info "Registering cluster '$cluster_name' with ArgoCD..."

  # Get cluster IP on the shared network
  cluster_ip=$(get_cluster_ip_on_network "$cluster_name")
  if [[ -z "$cluster_ip" ]]; then
    error "Could not get IP for cluster '$cluster_name'"
    return 1
  fi

  # Create SA in target cluster first
  create_argocd_sa_in_cluster "$cluster_name"

  # Get credentials
  local token ca_cert
  token=$(get_cluster_token "$cluster_name")
  ca_cert=$(get_cluster_ca "$cluster_name")

  # Switch to management cluster
  kubectl config use-context "kind-eu-central-1-management"

  # Create cluster secret in ArgoCD namespace
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: cluster-${cluster_name}
  namespace: ${ARGOCD_NAMESPACE}
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: ${cluster_name}
  server: https://${cluster_ip}:6443
  config: |
    {
      "bearerToken": "${token}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${ca_cert}"
      }
    }
EOF

  success "Cluster '$cluster_name' registered with ArgoCD"
}

# Register all workload clusters with ArgoCD
argocd_register_clusters() {
  header "Registering Workload Clusters with ArgoCD"

  # Ensure we're on management cluster and ArgoCD is running
  kubectl config use-context "kind-eu-central-1-management"

  if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    error "ArgoCD namespace not found. Bootstrap ArgoCD first."
    exit 1
  fi

  # Register dev and prod clusters
  for cluster in "eu-central-1-dev" "eu-central-1-prod"; do
    if cluster_exists "$cluster"; then
      register_cluster_with_argocd "$cluster"
    else
      warn "Cluster '$cluster' not running, skipping registration"
    fi
  done

  # Switch back to management context
  kubectl config use-context "kind-eu-central-1-management"

  success "All workload clusters registered with ArgoCD"

  echo ""
  info "Registered clusters:"
  kubectl get secrets -n "$ARGOCD_NAMESPACE" -l argocd.argoproj.io/secret-type=cluster -o jsonpath='{range .items[*]}{.data.name}{"\n"}{end}' | while read -r name; do
    echo "  - $(echo "$name" | base64 -d)"
  done
}
