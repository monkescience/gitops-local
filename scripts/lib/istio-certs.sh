#!/usr/bin/env bash

CERTS_DIR="$PROJECT_ROOT/.istio-certs"
ROOT_CA_DAYS=3650
INTERMEDIATE_CA_DAYS=730
ISTIO_SA_NAME="istio-manager"
ISTIO_NAMESPACE="istio-system"

wait_for_istio_sa() {
  local cluster=$1
  local timeout=${2:-120}
  local interval=5
  local elapsed=0

  info "Waiting for Istio ServiceAccount token in '$cluster'..."

  kubectl config use-context "kind-${cluster}" >/dev/null 2>&1

  while [[ $elapsed -lt $timeout ]]; do
    if kubectl get secret "${ISTIO_SA_NAME}-token" -n "${ISTIO_NAMESPACE}" >/dev/null 2>&1; then
      success "Istio ServiceAccount ready in '$cluster'"
      return 0
    fi

    printf "."
    sleep "$interval"
    elapsed=$((elapsed + interval))
  done

  echo ""
  error "Timeout waiting for Istio ServiceAccount in '$cluster'"
  return 1
}

get_cluster_token() {
  local cluster=$1

  kubectl config use-context "kind-${cluster}" >/dev/null 2>&1
  kubectl get secret "${ISTIO_SA_NAME}-token" -n "${ISTIO_NAMESPACE}" -o jsonpath='{.data.token}' | base64 -d
}

generate_root_ca() {
  info "Generating Istio root CA..."

  mkdir -p "$CERTS_DIR"

  openssl genrsa -out "$CERTS_DIR/root-key.pem" 4096

  openssl req -new -x509 -days $ROOT_CA_DAYS \
    -key "$CERTS_DIR/root-key.pem" \
    -out "$CERTS_DIR/root-cert.pem" \
    -subj "/O=Istio/CN=Root CA" \
    -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[req_distinguished_name]

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF
)

  success "Root CA generated at $CERTS_DIR/root-cert.pem"
}

generate_cluster_ca() {
  local cluster_name=$1

  info "Generating intermediate CA for cluster '$cluster_name'..."

  local cluster_dir="$CERTS_DIR/$cluster_name"
  mkdir -p "$cluster_dir"

  openssl genrsa -out "$cluster_dir/ca-key.pem" 4096

  openssl req -new \
    -key "$cluster_dir/ca-key.pem" \
    -out "$cluster_dir/ca-csr.pem" \
    -subj "/O=Istio/CN=Intermediate CA - ${cluster_name}"

  openssl x509 -req -days $INTERMEDIATE_CA_DAYS \
    -in "$cluster_dir/ca-csr.pem" \
    -CA "$CERTS_DIR/root-cert.pem" \
    -CAkey "$CERTS_DIR/root-key.pem" \
    -CAcreateserial \
    -out "$cluster_dir/ca-cert.pem" \
    -extfile <(cat <<EOF
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF
)

  cat "$cluster_dir/ca-cert.pem" "$CERTS_DIR/root-cert.pem" > "$cluster_dir/cert-chain.pem"

  cp "$CERTS_DIR/root-cert.pem" "$cluster_dir/root-cert.pem"

  rm -f "$cluster_dir/ca-csr.pem"

  success "Intermediate CA for '$cluster_name' generated"
}

install_certs_in_cluster() {
  local cluster_name=$1

  info "Installing Istio certificates in cluster '$cluster_name'..."

  kubectl config use-context "kind-${cluster_name}"

  ensure_namespace istio-system

  local cluster_dir="$CERTS_DIR/$cluster_name"

  kubectl create secret generic cacerts -n istio-system \
    --from-file=ca-cert.pem="$cluster_dir/ca-cert.pem" \
    --from-file=ca-key.pem="$cluster_dir/ca-key.pem" \
    --from-file=root-cert.pem="$cluster_dir/root-cert.pem" \
    --from-file=cert-chain.pem="$cluster_dir/cert-chain.pem" \
    --dry-run=client -o yaml | kubectl apply -f -

  success "Istio certificates installed in cluster '$cluster_name'"
}

istio_setup_certs() {
  header "Setting up Istio Multi-Cluster Certificates"

  if [[ ! -f "$CERTS_DIR/root-cert.pem" ]]; then
    generate_root_ca
  else
    info "Using existing root CA from $CERTS_DIR"
  fi

  for cluster in "${CLUSTERS[@]}"; do
    if cluster_exists "$cluster"; then
      if [[ ! -f "$CERTS_DIR/$cluster/ca-cert.pem" ]]; then
        generate_cluster_ca "$cluster"
      else
        info "Using existing intermediate CA for '$cluster'"
      fi
      install_certs_in_cluster "$cluster"
    else
      warn "Cluster '$cluster' not running, skipping cert installation"
    fi
  done

  kubectl config use-context "kind-management-eu-central-1"

  success "Istio certificates configured for all clusters"
}

create_istio_remote_secret() {
  local source_cluster=$1
  local target_cluster=$2

  info "Creating Istio remote secret for '$source_cluster' to discover '$target_cluster'..."

  kubectl config use-context "kind-${target_cluster}"

  local server_ip
  server_ip=$(get_cluster_ip_on_network "$target_cluster")

  local kubeconfig
  kubeconfig=$(cat <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: ${target_cluster}
    cluster:
      certificate-authority-data: $(kubectl config view --raw -o jsonpath='{.clusters[?(@.name=="kind-'${target_cluster}'")].cluster.certificate-authority-data}')
      server: https://${server_ip}:6443
contexts:
  - name: ${target_cluster}
    context:
      cluster: ${target_cluster}
      user: ${target_cluster}
current-context: ${target_cluster}
users:
  - name: ${target_cluster}
    user:
      token: $(get_cluster_token "$target_cluster")
EOF
)

  kubectl config use-context "kind-${source_cluster}"

  kubectl create secret generic "istio-remote-secret-${target_cluster}" \
    -n istio-system \
    --from-literal="${target_cluster}=${kubeconfig}" \
    --dry-run=client -o yaml | kubectl apply -f -

  kubectl label secret "istio-remote-secret-${target_cluster}" \
    -n istio-system \
    istio/multiCluster=true \
    --overwrite

  success "Remote secret created for '$source_cluster' to discover '$target_cluster'"
}

istio_setup_remote_secrets() {
  header "Setting up Istio Remote Secrets for Multi-Cluster Discovery"

  info "Waiting for Istio ServiceAccounts (synced by ArgoCD)..."
  for cluster in "${CLUSTERS[@]}"; do
    if cluster_exists "$cluster"; then
      wait_for_istio_sa "$cluster"
    fi
  done

  if cluster_exists "management-eu-central-1"; then
    for target in "dev-eu-central-1" "prod-eu-central-1"; do
      if cluster_exists "$target"; then
        create_istio_remote_secret "management-eu-central-1" "$target"
      fi
    done
  fi

  for source in "dev-eu-central-1" "prod-eu-central-1"; do
    if cluster_exists "$source" && cluster_exists "management-eu-central-1"; then
      create_istio_remote_secret "$source" "management-eu-central-1"
    fi
  done

  kubectl config use-context "kind-management-eu-central-1"

  success "Istio remote secrets configured for all clusters"
}
