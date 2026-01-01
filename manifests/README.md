# Manifests

This directory contains Helm values and Kustomize overlays for all components deployed via ArgoCD.

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
```

Each component has environment-specific subdirectories containing Helm values overrides.

## Environments

| Environment | Description | HTTPS Port |
|-------------|-------------|------------|
| `management-eu-central-1` | Control plane: ArgoCD, Kargo, Grafana, observability stack | 8443 |
| `dev-eu-central-1` | Development workloads | 9443 |
| `prod-eu-central-1` | Production-like workloads | 10443 |

## Components by Category

### Security

| Component | Description |
|-----------|-------------|
| cert-manager | Certificate management controller |
| cert-manager-extension | ClusterIssuers and certificate resources |
| sealed-secrets | Secret encryption at rest (management only) |

### Cluster Operations

| Component | Description |
|-----------|-------------|
| admission-policies | Pod security and admission policies |
| metrics-server | Kubernetes metrics API |
| kube-state-metrics | Kubernetes state metrics exporter |
| namespaces | Namespace definitions |

### GitOps

| Component | Description |
|-----------|-------------|
| argocd | ArgoCD server and controllers |
| argocd-extension | ArgoCD projects and RBAC |

### Service Mesh

| Component | Description |
|-----------|-------------|
| istio-cni | Istio CNI plugin |
| istiod | Istio control plane |
| ztunnel | Istio ambient mesh tunnel |
| istio-gateway-extension | Istio ingress gateway configuration |

### Progressive Delivery

| Component | Description |
|-----------|-------------|
| argo-rollouts | Canary and blue-green deployments (dev/prod only) |
| kargo | Progressive delivery controller |
| kargo-extension | Kargo projects and configuration (management only) |

### Observability Storage

| Component | Description |
|-----------|-------------|
| minio | S3-compatible object storage (management only) |
| loki | Log aggregation backend |
| loki-extension | Loki configuration |
| mimir | Metrics storage backend |
| mimir-extension | Mimir configuration |
| tempo | Distributed tracing backend |
| tempo-extension | Tempo configuration |

### Observability Collection

| Component | Description |
|-----------|-------------|
| alloy | Grafana Alloy telemetry collector |
| alloy-extension | Alloy configuration |

### Visualization

| Component | Description |
|-----------|-------------|
| grafana-operator | Grafana operator (management only) |
| grafana-operator-extension | Grafana instance and datasources |
| kiali | Istio service mesh UI |
| kiali-extension | Kiali configuration |
| gitops-mixin | Grafana dashboards and Prometheus alerts (management only) |

### Applications

| Component | Description |
|-----------|-------------|
| phasor | Example application deployment |
| phasor-kargo | Kargo pipeline for phasor promotion |

## How Values Are Used

ArgoCD Applications use multi-source configuration to combine external Helm charts with local values:

```yaml
sources:
  - repoURL: https://charts.example.com
    chart: component-name
    targetRevision: 1.0.0
    helm:
      valueFiles:
        - $values/manifests/component-name/management-eu-central-1/values.yaml
  - repoURL: file:///gitops
    ref: values
```

The `$values` reference points to the local repository mounted at `/gitops` in the Kind clusters.

## Adding a New Component

1. Create the component directory structure:
   ```bash
   mkdir -p manifests/my-component/{management,dev,prod}-eu-central-1
   ```

2. Add environment-specific values files:
   ```bash
   touch manifests/my-component/management-eu-central-1/values.yaml
   touch manifests/my-component/dev-eu-central-1/values.yaml
   touch manifests/my-component/prod-eu-central-1/values.yaml
   ```

3. Create the ArgoCD Application in `apps/{cluster}/platform/`:
   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: my-component
     annotations:
       argocd.argoproj.io/sync-wave: "XXX"  # See apps/README.md for wave numbers
   spec:
     sources:
       - repoURL: https://charts.example.com
         chart: my-component
         targetRevision: 1.0.0
         helm:
           valueFiles:
             - $values/manifests/my-component/management-eu-central-1/values.yaml
       - repoURL: file:///gitops
         ref: values
     # ... rest of Application spec
   ```

4. See [apps/README.md](../apps/README.md) for sync wave numbering and Application configuration details.

## Related Documentation

- [Root README](../README.md) - Repository overview
- [apps/README.md](../apps/README.md) - ArgoCD Application structure and sync waves
- [scripts/README.md](../scripts/README.md) - Automation scripts
