#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Deploying GitOps stack via ArgoCD..."

kubectl apply -f "$PROJECT_ROOT/apps/eu-central-1-dev.yaml"

echo ""
echo "✓ Root ArgoCD application 'eu-central-1-dev' created"
echo ""
