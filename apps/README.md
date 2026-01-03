# ArgoCD Applications

This directory contains ArgoCD Application manifests organized by cluster and layer.

## Directory Structure

```
apps/
├── management-eu-central-1/
│   └── platform/          # Platform components for management cluster
├── dev-eu-central-1/
│   ├── platform/          # Platform components for dev cluster
│   └── services/          # Application services (ApplicationSets)
└── prod-eu-central-1/
    ├── platform/          # Platform components for prod cluster
    └── services/          # Application services (ApplicationSets)
```

Note: The management cluster has no `services/` folder - it only runs platform components. Services are deployed to dev/prod clusters and promoted via Kargo.

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
| 801 | grafana-operator-extension | Grafana instance, datasources, configuration |
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
| kargo-phasor | Yes | No | No |
| services/ folder | No | Yes | Yes |

Dev and Prod clusters send telemetry to the Management cluster's observability stack.

## Services Pattern (ApplicationSet + Kargo)

Services use a different pattern than platform components. Instead of static Applications, they use ApplicationSets combined with Kargo for progressive delivery.

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│ Management Cluster                                                      │
│                                                                         │
│  ┌──────────────┐    ┌─────────────┐    ┌─────────────────────────────┐ │
│  │  Warehouse   │───▶│   Stages    │───▶│     PromotionTask           │ │
│  │              │    │             │    │                             │ │
│  │ Watches OCI  │    │ dev → prod  │    │ 1. git-clone                │ │
│  │ registry for │    │             │    │ 2. yaml-update version.yaml │ │
│  │ new versions │    │ Auto: dev   │    │ 3. git-commit               │ │
│  │              │    │ Manual: prod│    │ 4. git-push                 │ │
│  └──────────────┘    └─────────────┘    │ 5. argocd-update            │ │
│                                         └─────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   │ Updates version.yaml
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ Dev/Prod Clusters                                                       │
│                                                                         │
│  ┌───────────────────┐         ┌──────────────────────────────────────┐ │
│  │  ApplicationSet   │────────▶│  Generated Application               │ │
│  │                   │         │                                      │ │
│  │  Git generator    │         │  targetRevision: "{{ version }}"     │ │
│  │  reads version.yaml         │  from version.yaml                   │ │
│  └───────────────────┘         └──────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### File Structure

```
apps/{cluster}/services/
└── phasor.yaml              # ApplicationSet (not Application)

manifests/phasor/{cluster}/
├── version.yaml             # Chart version (managed by Kargo)
└── values.yaml              # Helm values overrides

manifests/kargo-phasor/management-eu-central-1/
├── warehouse.yaml           # Watches OCI registry for new chart versions
├── project.yaml             # Kargo project definition
├── project-config.yaml      # Auto-promotion policies
├── stage-dev-eu-central-1.yaml
├── stage-prod-eu-central-1.yaml
└── promotion-task.yaml      # Steps to update version.yaml and sync
```

### ApplicationSet Template

Services use ApplicationSet with a Git file generator to read the version:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: phasor
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: file:///gitops
        revision: HEAD
        files:
          - path: manifests/phasor/dev-eu-central-1/version.yaml
  template:
    metadata:
      annotations:
        argocd.argoproj.io/sync-wave: "0"
        kargo.akuity.io/authorized-stage: phasor:dev-eu-central-1  # Allows Kargo to trigger sync
      name: phasor
      namespace: argocd
    spec:
      sources:
        - repoURL: ghcr.io/monkescience/helm-charts
          chart: phasor
          targetRevision: "{{ version }}"  # From version.yaml
          helm:
            valueFiles:
              - $values/manifests/phasor/dev-eu-central-1/values.yaml
        - repoURL: file:///gitops
          ref: values
```

### Version File

The version.yaml file is simple - just the chart version:

```yaml
version: 0.4.0
```

Kargo updates this file during promotion, triggering the ApplicationSet to regenerate the Application with the new version.

### Promotion Flow

1. **New chart published** → Warehouse detects it and creates Freight
2. **Dev stage** → Auto-promotes (ProjectConfig: `autoPromotionEnabled: true`)
3. **PromotionTask runs**:
   - Clones gitops repo
   - Updates `manifests/phasor/dev-eu-central-1/version.yaml`
   - Commits and pushes
   - Triggers ArgoCD sync
4. **Prod stage** → Requires manual approval in Kargo UI
5. **After approval** → Same PromotionTask updates prod version.yaml

### Adding a New Service

1. Create the ApplicationSet in `apps/{cluster}/services/`:
   ```yaml
   # apps/dev-eu-central-1/services/my-service.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: ApplicationSet
   metadata:
     name: my-service
   spec:
     generators:
       - git:
           repoURL: file:///gitops
           files:
             - path: manifests/my-service/dev-eu-central-1/version.yaml
     template:
       metadata:
         annotations:
           kargo.akuity.io/authorized-stage: my-service:dev-eu-central-1
       # ... rest of template
   ```

2. Create version and values files:
   ```bash
   mkdir -p manifests/my-service/{dev,prod}-eu-central-1
   echo "version: 1.0.0" > manifests/my-service/dev-eu-central-1/version.yaml
   echo "version: 1.0.0" > manifests/my-service/prod-eu-central-1/version.yaml
   touch manifests/my-service/{dev,prod}-eu-central-1/values.yaml
   ```

3. Create Kargo pipeline in `manifests/kargo-{service}/management-eu-central-1/`:
   - warehouse.yaml (watch your chart registry)
   - project.yaml
   - project-config.yaml (auto-promotion policies)
   - stage-dev-eu-central-1.yaml
   - stage-prod-eu-central-1.yaml
   - promotion-task.yaml

4. Add the Kargo pipeline Application in `apps/management-eu-central-1/platform/`:
   ```yaml
   # apps/management-eu-central-1/platform/kargo-my-service.yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: kargo-my-service
     annotations:
       argocd.argoproj.io/sync-wave: "512"
   spec:
     project: platform
     source:
       repoURL: file:///gitops
       path: manifests/kargo-my-service/management-eu-central-1
   ```
