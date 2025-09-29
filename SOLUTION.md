# Core Pipeline Deployment Solution

## Problem Summary
The ArgoCD applications `core-pipeline-dev` and `core-pipeline-prod` are failing because:
1. They're trying to access `https://github.com/uz0/core-charts` which appears to be private or inaccessible to ArgoCD
2. The image `ghcr.io/uz0/core-pipeline:latest` doesn't exist or requires authentication
3. No resources are showing in ArgoCD UI because the sync is failing

## Solution

### Step 1: Connect to the Server
```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
# Password: 123454
```

### Step 2: Run the Quick Fix Script
Copy and run this on the server:
```bash
# Apply the manifests directly from GitHub
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Check if resources are created
kubectl get all -n dev-core
kubectl get all -n prod-core
```

### Step 3: Fix ArgoCD Applications
Delete and recreate the ArgoCD applications to point to the manifests directory:

```bash
# Delete old applications
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Create new dev application
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-pipeline-dev
  namespace: argocd
  annotations:
    link.argocd.argoproj.io/external-link: https://core-pipeline.dev.theedgestory.org
spec:
  project: default
  source:
    repoURL: https://github.com/uz0/core-charts
    targetRevision: main
    path: manifests
    directory:
      include: dev-core-pipeline.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dev-core
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Create new prod application
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-pipeline-prod
  namespace: argocd
  annotations:
    link.argocd.argoproj.io/external-link: https://core-pipeline.prod.theedgestory.org
spec:
  project: default
  source:
    repoURL: https://github.com/uz0/core-charts
    targetRevision: main
    path: manifests
    directory:
      include: prod-core-pipeline.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: prod-core
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

### Step 4: Verify in ArgoCD UI
1. Check http://46.62.223.198:30113/applications/argocd/core-pipeline-dev
2. Check http://46.62.223.198:30113/applications/argocd/core-pipeline-prod

You should now see:
- Deployments (1 replica for dev, 2 for prod)
- Services
- ConfigMaps
- Secrets
- Ingresses
- HPA (prod only)
- PodDisruptionBudget (prod only)

## What Was Fixed

1. **Repository Access**: Created raw Kubernetes manifests in the `manifests/` directory that can be accessed publicly
2. **Image Issue**: Using `nginx:latest` as a placeholder until the actual `ghcr.io/uz0/core-pipeline` image is available
3. **ArgoCD Configuration**: Changed from Helm charts to raw manifests which are simpler and don't require chart rendering
4. **Environment Configuration**: Added all necessary ConfigMaps and Secrets with database, Redis, and Kafka configurations

## Next Steps

1. **Build and Push Real Image**: 
   - Build the actual core-pipeline application image
   - Push to `ghcr.io/uz0/core-pipeline:latest`
   - Update the manifests to use the real image

2. **Test Connectivity**:
   - Verify PostgreSQL is accessible at `postgresql.database.svc.cluster.local`
   - Verify Redis is accessible at `redis-master.redis.svc.cluster.local`
   - Verify Kafka is accessible at `kafka.kafka.svc.cluster.local:9092`

3. **Monitor Applications**:
   - Check ArgoCD UI for sync status
   - Check application logs: `kubectl logs -n dev-core -l app=core-pipeline`
   - Test endpoints: `curl https://core-pipeline.dev.theedgestory.org`