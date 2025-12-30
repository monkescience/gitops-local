# ArgoCD Applications

This directory contains ArgoCD Application manifests organized by cluster and layer.

## Directory Structure

```
apps/
├── management-eu-central-1/
│   └── platform/          # Platform components for management cluster
├── dev-eu-central-1/
│   └── platform/          # Platform components for dev cluster
└── prod-eu-central-1/
    └── platform/          # Platform components for prod cluster
```

## Sync Wave Strategy

Applications are deployed sequentially using ArgoCD sync waves. Each component has its own unique wave number for precise ordering control.

### Numbering Scheme

- **Hundreds digit** = Group (0xx = Bootstrap, 1xx = Security, etc.)
- **Tens digit** = Component within group
- **Ones digit** = Extension (+1 after base component)

This allows:
- 9 slots between components for future additions
- 100 slots per group for expansion
- Clear group identification by first digit

## Groups Overview

| Range | Group | Description |
|-------|-------|-------------|
| 0xx | Bootstrap | CRDs and prerequisites |
| 1xx | Security | Certificate and secret management |
| 2xx | Cluster Metrics | Kubernetes metrics infrastructure |
| 3xx | GitOps | Declarative deployment controllers |
| 4xx | Service Mesh | Istio networking and security |
| 5xx | Delivery | Progressive delivery and promotion |
| 6xx | Observability | Storage and backends for telemetry |
| 7xx | Collectors | Telemetry collection agents |
| 8xx | Dashboards | Visualization and UI |

## Component Reference

### 0xx - Bootstrap

CRDs and prerequisites that must exist first.

| Wave | Component | Description |
|------|-----------|-------------|
| 0 | prometheus-operator-crds | CRDs for ServiceMonitor, PodMonitor, etc. |
| 10 | gateway-api | Gateway API CRDs |
| 20 | namespaces | Namespace definitions |
| 30 | admission-policies | Pod security and admission policies |

### 1xx - Security

Certificate and secret management.

| Wave | Component | Description |
|------|-----------|-------------|
| 100 | cert-manager | Certificate management |
| 101 | cert-manager-extension | ClusterIssuers and certificates |
| 110 | sealed-secrets | Secret encryption (management only) |

### 2xx - Cluster Metrics

Kubernetes metrics infrastructure.

| Wave | Component | Description |
|------|-----------|-------------|
| 200 | metrics-server | Kubernetes metrics API |
| 210 | kube-state-metrics | Kubernetes state metrics exporter |

### 3xx - GitOps

Declarative deployment controllers.

| Wave | Component | Description |
|------|-----------|-------------|
| 300 | argocd | ArgoCD server and controllers |
| 301 | argocd-extension | ArgoCD projects and RBAC |

### 4xx - Service Mesh

Istio networking and security.

| Wave | Component | Description |
|------|-----------|-------------|
| 400 | istio-base | Istio CRDs and base resources |
| 410 | istio-cni | Istio CNI plugin |
| 420 | istiod | Istio control plane |
| 430 | ztunnel | Istio ambient mesh tunnel |
| 440 | istio-gateway | Istio ingress gateway |

### 5xx - Delivery

Progressive delivery and promotion.

| Wave | Component | Description |
|------|-----------|-------------|
| 500 | argo-rollouts | Canary and blue-green deployments (dev/prod only) |
| 510 | kargo | Kargo progressive delivery |
| 511 | kargo-extension | Kargo projects and configuration (management only) |

### 6xx - Observability

Storage and backends for telemetry.

| Wave | Component | Description |
|------|-----------|-------------|
| 600 | minio | S3-compatible object storage (management only) |
| 610 | loki | Log aggregation |
| 611 | loki-extension | Loki configuration |
| 620 | mimir | Metrics storage |
| 621 | mimir-extension | Mimir configuration |
| 630 | tempo | Distributed tracing |
| 631 | tempo-extension | Tempo configuration |

### 7xx - Collectors

Telemetry collection agents.

| Wave | Component | Description |
|------|-----------|-------------|
| 700 | alloy | Grafana Alloy telemetry collector |
| 701 | alloy-extension | Alloy configuration |

### 8xx - Dashboards

Visualization and UI.

| Wave | Component | Description |
|------|-----------|-------------|
| 800 | grafana-operator | Grafana operator (management only) |
| 801 | grafana-extension | Grafana instance, datasources, configuration |
| 810 | kiali | Istio service mesh UI |
| 811 | kiali-extension | Kiali configuration |
| 820 | gitops-mixin | Grafana dashboards and Prometheus alerts (management only) |

## Adding New Components

When adding a new component:

1. Identify the appropriate group based on dependencies
2. Use an unused wave number within that group (multiples of 10 for base, +1 for extension)
3. Add retry configuration for external Helm charts:

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  retry:
    limit: 5
    backoff:
      duration: 5s
      factor: 2
      maxDuration: 3m
  syncOptions:
    - ApplyOutOfSyncOnly=true
```

## Cluster Differences

| Component | Management | Dev | Prod |
|-----------|:----------:|:---:|:----:|
| sealed-secrets | Yes | No | No |
| minio | Yes | No | No |
| loki/mimir/tempo | Yes | No | No |
| grafana | Yes | No | No |
| gitops-mixin | Yes | No | No |
| argo-rollouts | No | Yes | Yes |
| kargo-extension | Yes | No | No |

Dev and Prod clusters send telemetry to the Management cluster's observability stack.
