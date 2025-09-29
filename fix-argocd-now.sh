#!/bin/bash
# Fix ArgoCD to properly sync from the now-public core-charts repository

echo "====================================="
echo "Fixing ArgoCD Applications"
echo "====================================="

# Delete old broken applications
echo "Removing old applications..."
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Wait a moment
sleep 2

# Apply the updated ArgoCD applications
echo "Creating new ArgoCD applications..."
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

# Force refresh to pick up the public repository
echo "Forcing refresh..."
kubectl patch application core-pipeline-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl patch application core-pipeline-prod -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Wait for sync
echo "Waiting for sync..."
sleep 10

# Check status
echo ""
echo "====================================="
echo "ArgoCD Application Status:"
echo "====================================="
kubectl get applications -n argocd | grep -E "NAME|core-pipeline"

echo ""
echo "====================================="
echo "Checking sync status..."
echo "====================================="
kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.metadata.name}: {.status.sync.status} - {.status.health.status}' && echo
kubectl get application core-pipeline-prod -n argocd -o jsonpath='{.metadata.name}: {.status.sync.status} - {.status.health.status}' && echo

echo ""
echo "====================================="
echo "Resources in namespaces:"
echo "====================================="
echo "Dev environment:"
kubectl get all -n dev-core

echo ""
echo "Prod environment:"
kubectl get all -n prod-core