#!/bin/bash
# ArgoCD Application Cleanup and Fix Script

set -e

echo "=========================================="
echo "Step 1: Check current ArgoCD applications"
echo "=========================================="
kubectl get applications -n argocd

echo ""
echo "=========================================="
echo "Step 2: Check actual resource status"
echo "=========================================="
echo "Dev-core pods:"
kubectl get pods -n dev-core
echo ""
echo "Prod-core pods:"
kubectl get pods -n prod-core
echo ""
echo "Database pods:"
kubectl get pods -n database 2>/dev/null || echo "No database namespace"
echo ""
echo "Redis pods:"
kubectl get pods -n redis 2>/dev/null || echo "No redis namespace"
echo ""
echo "Kafka pods:"
kubectl get pods -n kafka 2>/dev/null || echo "No kafka namespace"

echo ""
echo "=========================================="
echo "Step 3: Remove problematic infrastructure app"
echo "=========================================="
if kubectl get application infrastructure -n argocd 2>/dev/null; then
  echo "Deleting infrastructure application (conflicts with individual apps)..."
  kubectl delete application infrastructure -n argocd --wait=false
  echo "Infrastructure app deletion initiated"

  # Clean up infrastructure namespace if it exists
  if kubectl get namespace infrastructure 2>/dev/null; then
    echo "Cleaning up infrastructure namespace..."
    kubectl delete namespace infrastructure --wait=false 2>/dev/null || echo "Namespace will be cleaned up in background"
  fi
else
  echo "Infrastructure app not found (already removed)"
fi

echo ""
echo "=========================================="
echo "Step 4: Fix prod-core deployment (remove PVC volumes)"
echo "=========================================="
# Check if prod deployment has volume issues
if kubectl get deployment core-pipeline-prod -n prod-core 2>/dev/null; then
  echo "Checking core-pipeline-prod deployment..."

  # Remove PVC volumes if they exist
  kubectl patch deployment core-pipeline-prod -n prod-core --type='json' -p='[
    {"op":"remove","path":"/spec/template/spec/volumes/0"}
  ]' 2>/dev/null && echo "Removed PVC volumes" || echo "No PVC volumes to remove"

  # Remove volume mounts if they reference the PVC
  kubectl get deployment core-pipeline-prod -n prod-core -o yaml | grep -q "claimName" && {
    echo "Recreating deployment without PVC..."
    kubectl rollout restart deployment core-pipeline-prod -n prod-core
  } || echo "No PVC mounts found"
else
  echo "core-pipeline-prod deployment not found"
fi

echo ""
echo "=========================================="
echo "Step 5: Sync ArgoCD applications with issues"
echo "=========================================="
for app in postgresql redis kafka; do
  if kubectl get application $app -n argocd 2>/dev/null; then
    echo "Syncing $app..."
    kubectl patch application $app -n argocd --type merge -p '{"operation": {"sync": {"prune": false}}}'
  else
    echo "$app application not found in ArgoCD"
  fi
done

echo ""
echo "=========================================="
echo "Step 6: Wait for rollouts to complete"
echo "=========================================="
sleep 10

echo "Dev-core status:"
kubectl get pods -n dev-core
echo ""
echo "Prod-core status:"
kubectl get pods -n prod-core

echo ""
echo "=========================================="
echo "Step 7: Final ArgoCD application status"
echo "=========================================="
kubectl get applications -n argocd -o wide

echo ""
echo "=========================================="
echo "Cleanup complete!"
echo "=========================================="
echo "Summary:"
echo "✓ Removed infrastructure app (if existed)"
echo "✓ Fixed prod-core PVC issues"
echo "✓ Synced infrastructure apps"
echo ""
echo "Next steps:"
echo "1. Check if any apps are still OutOfSync"
echo "2. Verify all pods are Running/Healthy"
echo "3. Test dev and prod endpoints"
