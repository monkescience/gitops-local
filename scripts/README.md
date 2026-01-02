# Scripts

Bash automation for managing the local GitOps development environment.

## Main Entry Point

All operations are performed through the main `gitops` script:

```bash
./scripts/gitops <command> [subcommand]
```

## Command Reference

### Full Lifecycle

| Command | Description |
|---------|-------------|
| `./scripts/gitops setup` | Complete setup of all clusters and stack (15-20 min) |
| `./scripts/gitops teardown` | Delete all clusters and resources |

### Cluster Management

| Command | Description |
|---------|-------------|
| `./scripts/gitops cluster status` | Show status of all clusters |
| `./scripts/gitops context <cluster>` | Switch kubectl context (management, dev, prod) |

### Istio Certificates

| Command | Description |
|---------|-------------|
| `./scripts/gitops istio setup-certs` | Regenerate Istio mTLS certificates for all clusters |

### Sealed Secrets

| Command | Description |
|---------|-------------|
| `./scripts/gitops secrets backup` | Backup sealed secrets encryption key |
| `./scripts/gitops secrets restore` | Restore encryption key from `.sealed-secrets-key.yaml` |
| `./scripts/gitops secrets status` | Show sealed secrets controller status |

### Help

| Command | Description |
|---------|-------------|
| `./scripts/gitops help` | Show usage information |

## Prerequisites

The setup command checks for these tools:

| Tool | Install Command |
|------|-----------------|
| kind | `brew install kind` |
| kubectl | `brew install kubectl` |
| helm | `brew install helm` |
| yq | `brew install yq` |
| openssl | Pre-installed on macOS |

## Resource Requirements

- **CPU**: 6 cores recommended
- **RAM**: 24 GB recommended
- **Disk**: 40 GB free space
- **Time**: 15-20 minutes for full setup

## Library Modules

The `lib/` directory contains modular bash libraries sourced by the main script:

| Module | Description |
|--------|-------------|
| `utils.sh` | Utility functions: `header`, `info`, `warn`, `error`, `success`, `require_command` |
| `network.sh` | Network and DNS configuration utilities |
| `cluster.sh` | Kind cluster creation, deletion, and status checking |
| `argocd.sh` | ArgoCD bootstrap on clusters |
| `istio-certs.sh` | Istio mTLS certificate generation with shared root CA |
| `kargo-shards.sh` | Kargo controller shard configuration for multi-cluster |
| `stack.sh` | Stack deployment (creates root ArgoCD Application) |
| `secrets.sh` | Sealed Secrets encryption key backup and restore |

## Additional Scripts

| Script | Description |
|--------|-------------|
| `seal-kargo-secret.sh` | Manual utility for sealing Kargo secrets |

## Examples

```bash
# Complete setup from scratch
./scripts/gitops setup

# Check cluster health
./scripts/gitops cluster status

# Switch to dev cluster
./scripts/gitops context dev

# Backup sealed secrets before teardown
./scripts/gitops secrets backup

# Teardown everything
./scripts/gitops teardown

# Restore and setup again
./scripts/gitops secrets restore
./scripts/gitops setup
```

## Related Documentation

- [Root README](../README.md) - Repository overview
- [apps/README.md](../apps/README.md) - ArgoCD Application structure
- [manifests/README.md](../manifests/README.md) - Component manifests
