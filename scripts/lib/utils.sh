#!/usr/bin/env bash
# Shared utility functions for gitops CLI

# Colors (only if terminal supports it)
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  BLUE='\033[0;34m'
  NC='\033[0m' # No Color
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

# Output functions
info() {
  echo -e "${BLUE}$*${NC}"
}

success() {
  echo -e "${GREEN}✓ $*${NC}"
}

warn() {
  echo -e "${YELLOW}⚠ $*${NC}"
}

error() {
  echo -e "${RED}✗ $*${NC}" >&2
}

# Check if a command exists, exit with error if not
require_command() {
  local cmd=$1
  local install_hint=${2:-""}
  if ! command -v "$cmd" >/dev/null 2>&1; then
    error "Required command not found: $cmd"
    if [[ -n "$install_hint" ]]; then
      echo "  Install: $install_hint"
    fi
    exit 1
  fi
}

# Create namespace if it doesn't exist
ensure_namespace() {
  local namespace=$1
  kubectl create namespace "$namespace" --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true
}

# Print a section header
header() {
  echo ""
  echo "========================================="
  echo "$*"
  echo "========================================="
  echo ""
}
