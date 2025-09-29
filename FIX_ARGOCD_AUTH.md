# Fix ArgoCD Repository Authentication

## Problem
ArgoCD cannot access the PRIVATE repository `https://github.com/uz0/core-charts`

## Solution Options

### Option 1: Add GitHub Token to ArgoCD (Recommended)

1. **Connect to server:**
```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
# Password: 123454
```

2. **Create a GitHub Personal Access Token:**
- Go to: https://github.com/settings/tokens
- Click "Generate new token (classic)"
- Give it `repo` scope
- Copy the token

3. **Add repository credentials to ArgoCD:**
```bash
# Replace YOUR_GITHUB_TOKEN with your actual token
kubectl create secret generic repo-core-charts-auth \
  -n argocd \
  --from-literal=type=git \
  --from-literal=url=https://github.com/uz0/core-charts \
  --from-literal=username=uz0 \
  --from-literal=password=YOUR_GITHUB_TOKEN

# Label it for ArgoCD
kubectl label secret repo-core-charts-auth -n argocd \
  argocd.argoproj.io/secret-type=repository
```

4. **Restart ArgoCD to pick up credentials:**
```bash
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd
```

5. **Wait for pods to restart:**
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=120s
```

6. **Force refresh applications:**
```bash
kubectl patch application core-pipeline-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl patch application core-pipeline-prod -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
```

### Option 2: Make Repository Public

1. Go to: https://github.com/uz0/core-charts/settings
2. Scroll to "Danger Zone"
3. Click "Change visibility"
4. Make it Public
5. Then refresh ArgoCD applications

### Option 3: Deploy Directly Without ArgoCD (Quick Fix)

If you don't want to deal with authentication, run this on the server:

```bash
# Delete broken ArgoCD apps
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Deploy directly
curl -sL https://raw.githubusercontent.com/uz0/core-charts/main/DEPLOY_NOW.sh | bash
```

This will deploy all resources directly to Kubernetes without using ArgoCD sync.

## Verification

After fixing, check:
```bash
# Check ArgoCD sync status
kubectl get applications -n argocd | grep core-pipeline

# Check deployed resources
kubectl get all -n dev-core
kubectl get all -n prod-core
```

You should see:
- Sync Status: "Synced" (not "Unknown")
- Health Status: "Healthy"
- Resources in ArgoCD UI at http://46.62.223.198:30113/applications