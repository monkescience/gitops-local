#!/usr/bin/env bash

ARGOCD_NAMESPACE="argocd"
ARGOCD_SA_NAME="argocd-manager"

create_argocd_sa_in_cluster() {
  local cluster_name=$1

  info "Creating ArgoCD service account in cluster '$cluster_name'..."

  kubectl config use-context "kind-${cluster_name}"

  ensure_namespace kube-system

  kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${ARGOCD_SA_NAME}
  namespace: kube-system
EOF

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

get_cluster_token() {
  local cluster_name=$1

  kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1
  kubectl get secret "${ARGOCD_SA_NAME}-token" -n kube-system -o jsonpath='{.data.token}' | base64 -d
}

get_cluster_ca() {
  local cluster_name=$1

  kubectl config use-context "kind-${cluster_name}" >/dev/null 2>&1
  kubectl get secret "${ARGOCD_SA_NAME}-token" -n kube-system -o jsonpath='{.data.ca\.crt}'
}

register_cluster_with_argocd() {
  local cluster_name=$1
  local cluster_ip

  info "Registering cluster '$cluster_name' with ArgoCD..."

  cluster_ip=$(get_cluster_ip_on_network "$cluster_name")
  if [[ -z "$cluster_ip" ]]; then
    error "Could not get IP for cluster '$cluster_name'"
    return 1
  fi

  create_argocd_sa_in_cluster "$cluster_name"

  local token ca_cert
  token=$(get_cluster_token "$cluster_name")
  ca_cert=$(get_cluster_ca "$cluster_name")

  kubectl config use-context "kind-management-eu-central-1"

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
        "insecure": true
      }
    }
EOF

  success "Cluster '$cluster_name' registered with ArgoCD"
}

argocd_register_clusters() {
  header "Registering Workload Clusters with ArgoCD"

  kubectl config use-context "kind-management-eu-central-1"

  if ! kubectl get namespace "$ARGOCD_NAMESPACE" >/dev/null 2>&1; then
    error "ArgoCD namespace not found. Bootstrap ArgoCD first."
    exit 1
  fi

  for cluster in "dev-eu-central-1" "prod-eu-central-1"; do
    if cluster_exists "$cluster"; then
      register_cluster_with_argocd "$cluster"
    else
      warn "Cluster '$cluster' not running, skipping registration"
    fi
  done

  kubectl config use-context "kind-management-eu-central-1"

  success "All workload clusters registered with ArgoCD"

  echo ""
  info "Registered clusters:"
  kubectl get secrets -n "$ARGOCD_NAMESPACE" -l argocd.argoproj.io/secret-type=cluster -o jsonpath='{range .items[*]}{.data.name}{"\n"}{end}' | while read -r name; do
    echo "  - $(echo "$name" | base64 -d)"
  done
}
