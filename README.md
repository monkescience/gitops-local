# gitops-local

Local GitOps development environment using Kind clusters with Argo CD, Kargo, Istio, and a complete observability stack.

## Overview

This repository provides a three-cluster setup that mimics production GitOps infrastructure:

```
                    ┌─────────────────────────────────────┐
                    │     management-eu-central-1         │
                    │                                     │
                    │  ArgoCD, Kargo, Grafana, Mimir,     │
                    │  Loki, Tempo, Kiali, Sealed Secrets │
                    │                                     │
                    │         https://*.localhost:8443    │
                    └─────────────────────────────────────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
                    ▼                                 ▼
     ┌──────────────────────────┐    ┌──────────────────────────┐
     │    dev-eu-central-1      │    │    prod-eu-central-1     │
     │                          │    │                          │
     │  ArgoCD, Istio,          │    │  ArgoCD, Istio,          │
     │  Argo Rollouts, Kiali    │    │  Argo Rollouts, Kiali    │
     │                          │    │                          │
     │  https://*.localhost:9443│    │  https://*.localhost:10443│
     └──────────────────────────┘    └──────────────────────────┘
```

Dev and Prod clusters send telemetry to the Management cluster's observability stack.

## Quick Start

```bash
# Full setup (15-20 minutes)
./scripts/gitops setup

# Check cluster status
./scripts/gitops cluster status

# Teardown
./scripts/gitops teardown
```

## Prerequisites

| Tool | Install |
|------|---------|
| Docker | `brew install docker` and `brew install --cask podman-desktop` |
| kind | `brew install kind` |
| kubectl | `brew install kubectl` |
| helm | `brew install helm` |
| yq | `brew install yq` |

**Resource Requirements:**
- CPU: 6 cores
- RAM: 20 GB
- Disk: 40 GB free space

## Commands

| Command | Description |
|---------|-------------|
| `./scripts/gitops setup` | Full setup (clusters + stack) |
| `./scripts/gitops teardown` | Delete all clusters |
| `./scripts/gitops cluster status` | Show cluster status |
| `./scripts/gitops context <cluster>` | Switch kubectl context |
| `./scripts/gitops istio setup-certs` | Regenerate Istio certificates |
| `./scripts/gitops secrets backup` | Backup sealed secrets key |
| `./scripts/gitops secrets restore` | Restore sealed secrets key |
| `./scripts/gitops secrets status` | Show sealed secrets status |

## Service Access

All services use `admin` / `admin` credentials.

| Service | URL |
|---------|-----|
| ArgoCD (management) | https://argocd.management.eu-central-1.localhost:8443 |
| ArgoCD (dev) | https://argocd.dev.eu-central-1.localhost:9443 |
| ArgoCD (prod) | https://argocd.prod.eu-central-1.localhost:10443 |
| Grafana | https://grafana.management.eu-central-1.localhost:8443 |
| Kargo | https://kargo.management.eu-central-1.localhost:8443 |
| Kiali (management) | https://kiali.management.eu-central-1.localhost:8443 |
| Kiali (dev) | https://kiali.dev.eu-central-1.localhost:9443 |
| Kiali (prod) | https://kiali.prod.eu-central-1.localhost:10443 |

Note: Browser will show a certificate warning (self-signed). Click "Advanced" -> "Proceed" to continue.

## Directory Structure

```
gitops-local/
├── apps/                    # ArgoCD Application manifests
│   ├── management-eu-central-1/
│   ├── dev-eu-central-1/
│   └── prod-eu-central-1/
├── manifests/               # Helm values per component/environment
│   ├── argocd/
│   ├── grafana-operator/
│   ├── istio-*/
│   └── ...
├── scripts/                 # Automation scripts
│   ├── gitops               # Main entry point
│   └── lib/                 # Bash library modules
└── kind-cluster-*.yaml.tmpl # Kind cluster templates
```

## Key Components

| Category | Components |
|----------|------------|
| GitOps | ArgoCD (all clusters), Kargo (management) |
| Service Mesh | Istio CNI, istiod, ztunnel, ingress gateway |
| Progressive Delivery | Kargo (management), Argo Rollouts (dev/prod) |
| Observability | Grafana, Mimir, Loki, Tempo, Alloy, Kiali |
| Security | cert-manager, Sealed Secrets |

## Documentation

| Document | Description |
|----------|-------------|
| [apps/README.md](apps/README.md) | ArgoCD Application structure and sync wave strategy |
| [manifests/README.md](manifests/README.md) | Component manifest organization |
| [scripts/README.md](scripts/README.md) | Script library and command reference |
