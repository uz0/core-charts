# Deploy Core Pipeline to Server

## Prerequisites
1. SSH access to server: `46.62.223.198`
2. GitHub token (optional, for private repo access)

## Step 1: Connect to Server
```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
# Enter password when prompted
```

## Step 2: Deploy Resources

Run these commands on the server:

```bash
# 1. Apply Kubernetes manifests directly
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# 2. Remove old ArgoCD applications (if they exist)
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# 3. Create new ArgoCD applications
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

# 4. Check deployment status
echo "=== Dev Environment ==="
kubectl get all -n dev-core

echo "=== Prod Environment ==="
kubectl get all -n prod-core

echo "=== ArgoCD Applications ==="
kubectl get applications -n argocd | grep core-pipeline
```

## Step 3: Verify in ArgoCD UI

1. Open: http://46.62.223.198:30113/applications
2. Look for `core-pipeline-dev` and `core-pipeline-prod`
3. You should see resources (even if sync fails due to private repo)

## Expected Resources

### Dev Environment (dev-core namespace):
- 1 Deployment (1 replica)
- 1 Service
- 1 ConfigMap
- 1 Secret
- 1 Ingress

### Prod Environment (prod-core namespace):
- 1 Deployment (2 replicas)
- 1 Service  
- 1 ConfigMap
- 1 Secret
- 1 Ingress
- 1 HorizontalPodAutoscaler
- 1 PodDisruptionBudget

## Troubleshooting

### If ArgoCD shows "Repository not found":
This is because the repository is private. Solutions:
1. Make the repository public on GitHub
2. Or add GitHub token to ArgoCD:
```bash
kubectl create secret generic repo-core-charts \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/uz0/core-charts \
  --from-literal=username=YOUR_GITHUB_USERNAME \
  --from-literal=password=YOUR_GITHUB_TOKEN

kubectl label secret repo-core-charts -n argocd \
  argocd.argoproj.io/secret-type=repository
```

### If pods show ImagePullBackOff:
The image `ghcr.io/uz0/core-pipeline` doesn't exist yet. The manifests currently use `nginx` as placeholder.

## CI/CD Setup

To enable automatic deployments:

1. Copy CI/CD files to `core-pipeline` repository:
   - `.github/workflows/deploy.yaml`
   - `Dockerfile`

2. Add secret to `core-pipeline` repo:
   - `CHARTS_GITHUB_TOKEN` - with `repo` scope

3. Push code:
   - `develop` branch → deploys to dev-core
   - `main` branch → deploys to prod-core