#!/usr/bin/env bash
# Sealed secrets management commands

SEALED_SECRETS_KEY="$PROJECT_ROOT/.sealed-secrets-key.yaml"
SECRETS_NAMESPACE="sealed-secrets"
SECRETS_LABEL_SELECTOR="sealedsecrets.bitnami.com/sealed-secrets-key=active"

secrets_backup() {
  info "Backing up Sealed Secrets master key..."

  if ! kubectl get namespace "$SECRETS_NAMESPACE" >/dev/null 2>&1; then
    error "Namespace '$SECRETS_NAMESPACE' does not exist"
    echo "  Make sure sealed-secrets is deployed first"
    exit 1
  fi

  local secret_count
  secret_count=$(kubectl get secret -n "$SECRETS_NAMESPACE" -l "$SECRETS_LABEL_SELECTOR" --no-headers 2>/dev/null | wc -l | tr -d ' ')

  if [[ "$secret_count" -eq 0 ]]; then
    error "No active sealed secrets key found"
    echo "  Label selector: $SECRETS_LABEL_SELECTOR"
    exit 1
  fi

  kubectl get secret -n "$SECRETS_NAMESPACE" -l "$SECRETS_LABEL_SELECTOR" -o yaml > "$SEALED_SECRETS_KEY"
  success "Sealed Secrets key backed up to $SEALED_SECRETS_KEY"
}

secrets_restore() {
  if [[ ! -f "$SEALED_SECRETS_KEY" ]]; then
    warn "No backup file found at $SEALED_SECRETS_KEY"
    echo "  This is expected for first-time setup"
    return 0
  fi

  info "Restoring Sealed Secrets master key from backup..."
  ensure_namespace "$SECRETS_NAMESPACE"
  kubectl apply -f "$SEALED_SECRETS_KEY"
  success "Sealed Secrets key restored"
}

secrets_status() {
  header "Sealed Secrets Status"

  echo "Backup file: $SEALED_SECRETS_KEY"
  if [[ -f "$SEALED_SECRETS_KEY" ]]; then
    success "Backup exists"
    local backup_date
    backup_date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$SEALED_SECRETS_KEY" 2>/dev/null || stat -c "%y" "$SEALED_SECRETS_KEY" 2>/dev/null | cut -d'.' -f1)
    echo "  Last modified: $backup_date"
  else
    warn "No backup found"
  fi

  echo ""
  echo "Cluster status:"
  if kubectl get namespace "$SECRETS_NAMESPACE" >/dev/null 2>&1; then
    success "Namespace '$SECRETS_NAMESPACE' exists"
    local secret_count
    secret_count=$(kubectl get secret -n "$SECRETS_NAMESPACE" -l "$SECRETS_LABEL_SELECTOR" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$secret_count" -gt 0 ]]; then
      success "Active key found in cluster ($secret_count secret(s))"
    else
      warn "No active key in cluster"
    fi
  else
    warn "Namespace '$SECRETS_NAMESPACE' does not exist"
  fi
}
