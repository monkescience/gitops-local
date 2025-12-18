#!/usr/bin/env bash
set -euo pipefail

# Seal Kargo GitHub App credentials for gitops-local.
#
# Prerequisites:
#   - kubeseal installed (brew install kubeseal)
#   - Kind cluster running with sealed-secrets deployed
#   - GitHub App credentials ready

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$PROJECT_ROOT/manifests/kargo-extension/eu-central-1-dev/secret.template.yaml"
OUTPUT="$PROJECT_ROOT/manifests/kargo-extension/eu-central-1-dev/secret.yaml"
TEMP_FILE=$(mktemp)

trap "rm -f $TEMP_FILE" EXIT

echo "=== Kargo GitHub App Secret Sealer ==="
echo ""

# Check prerequisites
if ! command -v kubeseal &> /dev/null; then
    echo "Error: kubeseal not found. Install with: brew install kubeseal"
    exit 1
fi

if ! kubectl get namespace sealed-secrets &> /dev/null; then
    echo "Error: sealed-secrets namespace not found. Is the cluster running?"
    exit 1
fi

echo "Enter your GitHub App credentials:"
echo ""

read -p "GitHub App ID (Client ID): " GITHUB_APP_ID
read -p "GitHub App Installation ID: " GITHUB_INSTALLATION_ID
echo "GitHub App Private Key (paste the entire key, then press Enter and Ctrl+D):"
GITHUB_PRIVATE_KEY=$(cat)

# Create temporary secret with real values
cat > "$TEMP_FILE" << EOF
apiVersion: v1
kind: Secret
metadata:
  name: kargo-github-app-credentials
  namespace: kargo
  labels:
    kargo.akuity.io/cred-type: git
type: Opaque
stringData:
  githubAppID: "$GITHUB_APP_ID"
  githubAppPrivateKey: |
$(echo "$GITHUB_PRIVATE_KEY" | sed 's/^/    /')
  githubAppInstallationID: "$GITHUB_INSTALLATION_ID"
  repoURL: "https://github.com/monkescience/gitops-local"
  repoURLIsRegex: "false"
EOF

echo ""
echo "Sealing secret..."

kubeseal --format yaml \
  --controller-name sealed-secrets \
  --controller-namespace sealed-secrets \
  < "$TEMP_FILE" > "$OUTPUT"

echo ""
echo "✓ Sealed secret created: $OUTPUT"
echo ""
echo "Next steps:"
echo "  1. Commit the sealed secret: git add $OUTPUT && git commit -m 'Add Kargo GitHub credentials'"
echo "  2. The secret will be deployed when ArgoCD syncs"
