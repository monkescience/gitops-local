# Manifests

Helm values and Kustomize overlays for all components, organized by component and cluster.

## Directory Structure

```
manifests/
├── {component}/
│   ├── management-eu-central-1/
│   │   └── values.yaml
│   ├── dev-eu-central-1/
│   │   └── values.yaml
│   └── prod-eu-central-1/
│       └── values.yaml
├── {component}-extension/
│   └── {cluster}/
│       └── *.yaml            # Kustomize resources
├── kargo-{service}/
│   └── management-eu-central-1/
│       └── *.yaml            # Kargo pipeline definitions
└── {service}/
    └── {cluster}/
        ├── version.yaml      # Chart version (Kargo-managed)
        └── values.yaml       # Helm values
```

## Patterns

### Component + Extension

Most platform components follow a two-part deployment:

1. **Base** (`{component}/`): Helm chart values
2. **Extension** (`{component}-extension/`): Post-install resources (HTTPRoutes, configs)

Example:
```
manifests/
├── argocd/
│   └── dev-eu-central-1/
│       └── values.yaml           # Helm values for ArgoCD chart
└── argocd-extension/
    └── dev-eu-central-1/
        ├── kustomization.yaml
        └── http-route-argocd.yaml  # HTTPRoute for ingress
```

### Services (Kargo-managed)

Services use version files managed by Kargo for progressive delivery:

```
manifests/
├── phasor/
│   ├── dev-eu-central-1/
│   │   ├── version.yaml    # "version: 0.4.0" - updated by Kargo
│   │   └── values.yaml     # Environment-specific overrides
│   └── prod-eu-central-1/
│       ├── version.yaml
│       └── values.yaml
└── kargo-phasor/
    └── management-eu-central-1/
        ├── project.yaml
        ├── project-config.yaml
        ├── warehouse.yaml
        ├── stage-dev-eu-central-1.yaml
        ├── stage-prod-eu-central-1.yaml
        └── promotion-task.yaml
```

## Components

### Platform Components

| Component | Clusters | Description |
|-----------|----------|-------------|
| admission-policies | all | Pod security policies |
| alloy | all | Grafana Alloy telemetry collector |
| argo-rollouts | dev, prod | Canary/blue-green deployments |
| argocd | all | GitOps continuous delivery |
| cert-manager | all | Certificate management |
| grafana-operator | management | Grafana instance management |
| gitops-mixin | management | Grafana dashboards and alerts |
| istio-cni | all | Istio CNI plugin |
| istiod | all | Istio control plane |
| kargo | all | Progressive delivery controller |
| kiali | all | Istio service mesh UI |
| kube-state-metrics | all | Kubernetes state metrics |
| loki | management | Log aggregation backend |
| metrics-server | all | Kubernetes metrics API |
| mimir | management | Metrics storage backend |
| minio | management | S3-compatible object storage |
| namespaces | all | Namespace definitions |
| sealed-secrets | management | Secret encryption |
| tempo | management | Distributed tracing backend |
| ztunnel | all | Istio ambient mesh tunnel |

### Services

| Service | Description |
|---------|-------------|
| phasor | Example application for demonstrating progressive delivery |

## Cluster-Specific Notes

### Management Cluster

- Runs observability backends (Mimir, Loki, Tempo, Grafana)
- Hosts Kargo API and pipelines
- No application services deployed here

### Dev/Prod Clusters

- Run as Kargo shards (controller only, no API)
- Send telemetry to management cluster
- Deploy application services via Kargo promotion
- Kargo runs as root for hostPath write access (see scripts/README.md)

## Related Documentation

- [apps/README.md](../apps/README.md) - ArgoCD Application structure and sync waves
- [scripts/README.md](../scripts/README.md) - Automation scripts
