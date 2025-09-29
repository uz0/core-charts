# Complete Setup for Core-Pipeline with ArgoCD

## Prerequisites
1. GitHub Personal Access Token with `repo` scope
2. SSH access to server (46.62.223.198)
3. The core-pipeline repository with CI/CD workflow

## Step 1: Create GitHub Token
1. Go to: https://github.com/settings/tokens/new
2. Name: "ArgoCD-CoreCharts"
3. Scope: ✅ `repo` (Full control of private repositories)
4. Generate and copy token

## Step 2: SSH to Server and Configure ArgoCD

```bash
ssh -i ~/.ssh/uz0 root@46.62.223.198
```

Then run these commands:

```bash
# Set your GitHub credentials
GITHUB_USER="uz0"
GITHUB_TOKEN="your_token_here"  # Replace with your actual token

# Add repository credentials to ArgoCD
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-core-charts-private
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/uz0/core-charts
  username: ${GITHUB_USER}
  password: ${GITHUB_TOKEN}
EOF

# Restart ArgoCD to pick up credentials
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd

# Wait for restart
sleep 15

# Delete old applications
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Apply ArgoCD applications
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

# Create image pull secrets for ghcr.io
kubectl create namespace dev-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace prod-core --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=${GITHUB_TOKEN} \
  -n dev-core --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=${GITHUB_USER} \
  --docker-password=${GITHUB_TOKEN} \
  -n prod-core --dry-run=client -o yaml | kubectl apply -f -

# Force ArgoCD to sync
kubectl patch application core-pipeline-dev -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'

kubectl patch application core-pipeline-prod -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"main"}}}'
```

## Step 3: Check Status

```bash
# Check ArgoCD applications
kubectl get applications -n argocd | grep core-pipeline

# Check sync status
kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.status.sync.status}'
echo
kubectl get application core-pipeline-prod -n argocd -o jsonpath='{.status.sync.status}'
echo

# Check deployments
kubectl get all -n dev-core
kubectl get all -n prod-core
```

## Step 4: Trigger Initial Deployment

Since the image might not exist yet, push to the core-pipeline repository to trigger the CI/CD:

```bash
# In core-pipeline repository
git commit --allow-empty -m "Trigger deployment"
git push origin main
```

This will:
1. Build the Docker image
2. Push to ghcr.io
3. Update values in core-charts
4. ArgoCD will detect and deploy

## Expected Results

After successful setup:
- ArgoCD shows "Synced" status (not "Unknown")
- Pods running in dev-core and prod-core namespaces
- Applications accessible at:
  - https://core-pipeline.dev.theedgestory.org
  - https://core-pipeline.prod.theedgestory.org

## Troubleshooting

### If sync still shows "Repository not found"
- Verify token has `repo` scope
- Check secret: `kubectl get secret repo-core-charts-private -n argocd -o yaml`
- Restart ArgoCD again

### If pods show ImagePullBackOff
- The image doesn't exist yet - trigger CI/CD in core-pipeline repo
- Check image pull secret: `kubectl get secret ghcr-secret -n dev-core -o yaml`

### Check ArgoCD logs
```bash
kubectl logs -n argocd deployment/argocd-repo-server --tail=50
kubectl logs -n argocd deployment/argocd-application-controller --tail=50
```