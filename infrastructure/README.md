# Infrastructure Configuration

Complete Kubernetes infrastructure configuration for theedgestory.org

## Directory Structure

```
infrastructure/
├── argocd/
│   ├── argocd-applications.yaml  # All ArgoCD app definitions
│   └── argocd-status.yaml        # Status configmap
├── ingress/
│   └── ingresses.yaml            # All ingress configurations
└── monitoring/
    └── (monitoring stack configs)
```

## Active Services

| Service | URL | Purpose |
|---------|-----|---------|
| ArgoCD | https://argo.dev.theedgestory.org | GitOps deployment |
| Grafana | https://grafana.dev.theedgestory.org | Monitoring dashboards |
| Prometheus | https://prometheus.dev.theedgestory.org | Metrics collection |
| Kafka UI | https://kafka.dev.theedgestory.org | Kafka management |
| Core Pipeline | https://core-pipeline.dev.theedgestory.org | Application |

## Credentials

- ArgoCD: admin / R4otxHVXnNIiBODS
- Grafana: admin / admin123

## Deployment

All applications are managed through ArgoCD with GitOps principles.
