# Core Pipeline Deployment

## Quick Deploy

SSH to your server and run:

```bash
# Apply manifests
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Fix ArgoCD
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml
```

## Files

- `manifests/` - Kubernetes resources
- `argocd/` - ArgoCD applications
- `core-pipeline-ci-cd/` - CI/CD files for core-pipeline repo
- `charts/` - Helm charts (optional)

## Issue

The GitHub repository `uz0/core-charts` is PRIVATE, so ArgoCD can't access it without authentication.

To fix: Either make the repo public or add GitHub token to ArgoCD.