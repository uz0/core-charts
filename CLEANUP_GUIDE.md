# ArgoCD Cleanup and Fix Guide

## Problem Summary
- ✅ **core-pipeline-dev**: Working fine!
- ❌ **infrastructure app**: Conflicts with individual apps (postgresql, redis, kafka)
- ❌ **core-pipeline-prod**: Has PVC volume issues causing Pending pods
- ⚠️ **Individual infrastructure apps**: Showing OutOfSync status

## Solution: Run Cleanup Script on Server

### Step 1: SSH to your server
```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
```

### Step 2: Pull latest changes
```bash
cd ~/core-charts
git pull origin main
```

### Step 3: Run the cleanup script
```bash
chmod +x cleanup-argocd-apps.sh
./cleanup-argocd-apps.sh
```

### What the script does:
1. ✅ Shows current state of all ArgoCD applications
2. ✅ Checks all pod statuses across namespaces
3. ✅ Deletes the problematic `infrastructure` app (conflicts resolved)
4. ✅ Fixes prod-core PVC volume issues
5. ✅ Syncs individual infrastructure apps (postgresql, redis, kafka)
6. ✅ Shows final status

### Step 4: Verify webhook deployment
After running the script, trigger a webhook deployment to apply the ArgoCD app removal:
```bash
# Your webhook should automatically detect the git push and apply changes
# Or manually trigger if needed:
kubectl delete application infrastructure -n argocd 2>/dev/null || echo "Already removed"
```

## Expected Results

### Before:
```
NAME             HEALTH   STATUS      SYNC
infrastructure   Missing  OutOfSync   (conflicts)
postgresql       Healthy  OutOfSync
redis            Healthy  OutOfSync
kafka            Unknown  OutOfSync
```

### After:
```
NAME                   HEALTH   STATUS   SYNC
core-pipeline-dev      Healthy  Synced   ✅
core-pipeline-prod     Healthy  Synced   ✅
postgresql             Healthy  Synced   ✅
redis                  Healthy  Synced   ✅
kafka                  Healthy  Synced   ✅
cert-manager          Healthy  Synced   ✅
grafana               Healthy  Synced   ✅
loki-stack            Healthy  Synced   ✅
tempo                 Healthy  Synced   ✅
kafka-ui              Healthy  Synced   ✅
```

## Manual Verification Commands

### Check ArgoCD apps:
```bash
kubectl get applications -n argocd
```

### Check all core pods:
```bash
# Dev environment
kubectl get pods -n dev-core

# Prod environment
kubectl get pods -n prod-core

# Infrastructure services
kubectl get pods -n database
kubectl get pods -n redis
kubectl get pods -n kafka
```

### Test endpoints:
```bash
# Dev health check
kubectl exec -n dev-core $(kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline -o name | head -1) -- curl -s http://localhost:3000/health

# Prod health check
kubectl exec -n prod-core $(kubectl get pods -n prod-core -l app.kubernetes.io/name=core-pipeline -o name | head -1) -- curl -s http://localhost:3000/health
```

## Troubleshooting

### If infrastructure app won't delete:
```bash
kubectl patch application infrastructure -n argocd -p '{"metadata":{"finalizers":null}}' --type merge
kubectl delete application infrastructure -n argocd --force --grace-period=0
```

### If prod pods still Pending:
```bash
# Check events
kubectl describe pod -n prod-core $(kubectl get pods -n prod-core -o name | head -1)

# Force recreate
kubectl delete pods -n prod-core --all
```

### If PostgreSQL/Redis/Kafka show OutOfSync:
```bash
# Manual sync with prune
kubectl patch application postgresql -n argocd --type merge -p '{"operation": {"sync": {"prune": true}}}'
kubectl patch application redis -n argocd --type merge -p '{"operation": {"sync": {"prune": true}}}'
kubectl patch application kafka -n argocd --type merge -p '{"operation": {"sync": {"prune": true}}}'
```

## Why This Fixes the Issues

1. **Infrastructure App Removal**: The umbrella chart tried to manage PostgreSQL, Redis, and Kafka, but you already have individual ArgoCD apps for each. This caused resource conflicts and sync issues.

2. **Individual Apps Work Better**: Each service (postgresql, redis, kafka) has its own ArgoCD application, making them easier to manage, troubleshoot, and upgrade independently.

3. **PVC Fix**: Prod deployment had a PersistentVolumeClaim that wasn't being fulfilled, causing pods to stay Pending. The script removes these volume requirements.

4. **Clean State**: After cleanup, all apps should be in sync with their Git definitions, and ArgoCD's auto-sync will keep them healthy going forward.
