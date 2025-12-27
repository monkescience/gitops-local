#!/usr/bin/env bash

CERTS_DIR="$PROJECT_ROOT/.istio-certs"
ROOT_CA_DAYS=3650
INTERMEDIATE_CA_DAYS=730
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

