#!/usr/bin/env bash
# Istio certificate management for multi-cluster mTLS

CERTS_DIR="$PROJECT_ROOT/.istio-certs"
ROOT_CA_DAYS=3650
INTERMEDIATE_CA_DAYS=730

# Generate root CA for mesh-wide trust
generate_root_ca() {
  info "Generating Istio root CA..."

  mkdir -p "$CERTS_DIR"

  # Generate root CA key
  openssl genrsa -out "$CERTS_DIR/root-key.pem" 4096

  # Generate root CA certificate
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

# Generate intermediate CA for a specific cluster
generate_cluster_ca() {
  local cluster_name=$1

  info "Generating intermediate CA for cluster '$cluster_name'..."

  local cluster_dir="$CERTS_DIR/$cluster_name"
  mkdir -p "$cluster_dir"

  # Generate intermediate CA key
  openssl genrsa -out "$cluster_dir/ca-key.pem" 4096

  # Generate CSR
  openssl req -new \
    -key "$cluster_dir/ca-key.pem" \
    -out "$cluster_dir/ca-csr.pem" \
    -subj "/O=Istio/CN=Intermediate CA - ${cluster_name}"

  # Sign intermediate CA with root CA
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

  # Create cert chain (intermediate + root)
  cat "$cluster_dir/ca-cert.pem" "$CERTS_DIR/root-cert.pem" > "$cluster_dir/cert-chain.pem"

  # Copy root cert for verification
  cp "$CERTS_DIR/root-cert.pem" "$cluster_dir/root-cert.pem"

  rm -f "$cluster_dir/ca-csr.pem"

  success "Intermediate CA for '$cluster_name' generated"
}

# Create Kubernetes secret with Istio certs in a cluster
install_certs_in_cluster() {
  local cluster_name=$1

  info "Installing Istio certificates in cluster '$cluster_name'..."

  kubectl config use-context "kind-${cluster_name}"

  # Create istio-system namespace if not exists
  kubectl create namespace istio-system --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

  local cluster_dir="$CERTS_DIR/$cluster_name"

  # Create cacerts secret
  kubectl create secret generic cacerts -n istio-system \
    --from-file=ca-cert.pem="$cluster_dir/ca-cert.pem" \
    --from-file=ca-key.pem="$cluster_dir/ca-key.pem" \
    --from-file=root-cert.pem="$cluster_dir/root-cert.pem" \
    --from-file=cert-chain.pem="$cluster_dir/cert-chain.pem" \
    --dry-run=client -o yaml | kubectl apply -f -

  success "Istio certificates installed in cluster '$cluster_name'"
}

# Generate and distribute certs to all clusters
istio_setup_certs() {
  header "Setting up Istio Multi-Cluster Certificates"

  # Check if root CA exists
  if [[ ! -f "$CERTS_DIR/root-cert.pem" ]]; then
    generate_root_ca
  else
    info "Using existing root CA from $CERTS_DIR"
  fi

  # Generate and install certs for each cluster
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

  # Switch back to management context
  kubectl config use-context "kind-eu-central-1-management"

  success "Istio certificates configured for all clusters"
}

# Create remote secret for cluster discovery
create_istio_remote_secret() {
  local source_cluster=$1
  local target_cluster=$2

  info "Creating Istio remote secret for '$source_cluster' to discover '$target_cluster'..."

  # Get target cluster credentials
  kubectl config use-context "kind-${target_cluster}"

  local server_ip
  server_ip=$(get_cluster_ip_on_network "$target_cluster")

  # Create kubeconfig for target cluster
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

  # Apply remote secret to source cluster
  kubectl config use-context "kind-${source_cluster}"

  kubectl create secret generic "istio-remote-secret-${target_cluster}" \
    -n istio-system \
    --from-literal="${target_cluster}=${kubeconfig}" \
    --dry-run=client -o yaml | kubectl apply -f -

  # Label for Istio discovery
  kubectl label secret "istio-remote-secret-${target_cluster}" \
    -n istio-system \
    istio/multiCluster=true \
    --overwrite

  success "Remote secret created for '$source_cluster' to discover '$target_cluster'"
}

# Setup all remote secrets for multi-cluster discovery
istio_setup_remote_secrets() {
  header "Setting up Istio Remote Secrets for Multi-Cluster Discovery"

  # Management discovers dev and prod
  if cluster_exists "eu-central-1-management"; then
    for target in "eu-central-1-dev" "eu-central-1-prod"; do
      if cluster_exists "$target"; then
        create_istio_remote_secret "eu-central-1-management" "$target"
      fi
    done
  fi

  # Dev and prod discover management (for cross-cluster service access)
  for source in "eu-central-1-dev" "eu-central-1-prod"; do
    if cluster_exists "$source" && cluster_exists "eu-central-1-management"; then
      create_istio_remote_secret "$source" "eu-central-1-management"
    fi
  done

  # Switch back to management context
  kubectl config use-context "kind-eu-central-1-management"

  success "Istio remote secrets configured for all clusters"
}
