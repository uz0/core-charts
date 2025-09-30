#!/bin/bash
# Fix remaining prod-core issues

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "Step 1: Fix ghcr-secret in prod-core"
echo "=========================================="

# Delete existing secret if it exists
kubectl delete secret ghcr-secret -n prod-core 2>/dev/null && echo "Old secret deleted" || echo "No old secret found"

# Create new secret with valid token
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n prod-core

echo "✓ ghcr-secret created in prod-core"

echo ""
echo "=========================================="
echo "Step 2: Verify all-credentials secret in prod-core"
echo "=========================================="
kubectl get secret all-credentials -n prod-core -o yaml | grep -A5 "^data:" || {
  echo "⚠️  all-credentials secret missing or invalid in prod-core"
  echo "Checking if it exists in dev-core to copy..."
  if kubectl get secret all-credentials -n dev-core >/dev/null 2>&1; then
    echo "Copying all-credentials from dev-core to prod-core..."
    kubectl get secret all-credentials -n dev-core -o yaml | \
      sed 's/namespace: dev-core/namespace: prod-core/' | \
      kubectl apply -f -
    echo "✓ Copied all-credentials to prod-core"
  else
    echo "⚠️  all-credentials not found in dev-core either"
  fi
}

echo ""
echo "=========================================="
echo "Step 3: Delete old failing deployments"
echo "=========================================="
for deployment in $(kubectl get deployments -n prod-core -o name | grep -v "core-pipeline-prod"); do
  echo "Deleting old deployment: $deployment"
  kubectl delete $deployment -n prod-core
done

echo ""
echo "=========================================="
echo "Step 4: Delete all old pods to force fresh start"
echo "=========================================="
kubectl delete pods -n prod-core --all --grace-period=30

echo ""
echo "=========================================="
echo "Step 5: Remove infrastructure app finalizer"
echo "=========================================="
if kubectl get application infrastructure -n argocd 2>/dev/null; then
  echo "Infrastructure app still exists, removing finalizer..."
  kubectl patch application infrastructure -n argocd -p '{"metadata":{"finalizers":null}}' --type merge
  kubectl delete application infrastructure -n argocd --force --grace-period=0 2>/dev/null || echo "Already deleted"
else
  echo "Infrastructure app not found (good)"
fi

echo ""
echo "=========================================="
echo "Step 6: Force sync ArgoCD applications"
echo "=========================================="
echo "Syncing core-pipeline-dev to latest commit..."
kubectl patch application core-pipeline-dev -n argocd --type merge -p '{"operation":{"sync":{"revision":"96dff45ae3d62e9481d67bd3416ae8a7d4c0eecc"}}}'

echo "Syncing core-pipeline-prod to latest commit..."
kubectl patch application core-pipeline-prod -n argocd --type merge -p '{"operation":{"sync":{"revision":"96dff45ae3d62e9481d67bd3416ae8a7d4c0eecc"}}}'

echo "Syncing postgresql..."
kubectl patch application postgresql -n argocd --type merge -p '{"operation":{"sync":{}}}'

echo "Syncing redis..."
kubectl patch application redis -n argocd --type merge -p '{"operation":{"sync":{}}}'

echo ""
echo "=========================================="
echo "Step 7: Wait for pods to start (30 seconds)"
echo "=========================================="
sleep 30

echo ""
echo "=========================================="
echo "Step 8: Check pod status"
echo "=========================================="
echo "Dev-core pods:"
kubectl get pods -n dev-core
echo ""
echo "Prod-core pods:"
kubectl get pods -n prod-core
echo ""
echo "Database pods:"
kubectl get pods -n database
echo ""
echo "Redis pods:"
kubectl get pods -n redis | head -10

echo ""
echo "=========================================="
echo "Step 9: Final ArgoCD status"
echo "=========================================="
kubectl get applications -n argocd

echo ""
echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "If prod-core pods are still failing, check logs with:"
echo "  kubectl logs -n prod-core \$(kubectl get pods -n prod-core -l app.kubernetes.io/name=core-pipeline -o name | head -1)"
echo ""
echo "If still ImagePullBackOff, verify secret:"
echo "  kubectl get secret ghcr-secret -n prod-core -o yaml"
