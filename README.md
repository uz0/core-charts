# Core Pipeline Infrastructure

## Repository Structure
- `charts/core-pipeline/` - Helm chart for core-pipeline application
- `dev-core-pipeline.yaml` - ArgoCD application for development environment
- `prod-core-pipeline.yaml` - ArgoCD application for production environment

## Server Access
```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
# Passphrase: 123454
```

## Service URLs
- **ArgoCD**: http://46.62.223.198:30113 (admin / use `argocd admin initial-password -n argocd`)
- **Grafana**: http://46.62.223.198:30082 (admin / prom-operator)
- **Prometheus**: http://46.62.223.198:30090
- **Kafka UI**: http://46.62.223.198:30888
- **Loki**: http://46.62.223.198:30324
- **Tempo**: http://46.62.223.198:30317

## Deployed Services
- PostgreSQL (database namespace)
- Redis (redis namespace)
- Kafka (kafka namespace)
- Core Pipeline (dev-core and prod-core namespaces)
- Monitoring Stack (Prometheus, Grafana, Loki, Tempo)
- ArgoCD for GitOps

## Deploy Changes
Push changes to the repository and ArgoCD will automatically sync them.