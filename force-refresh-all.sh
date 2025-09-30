#!/bin/bash
# Force ArgoCD to refresh and apply latest git changes

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "PART 1: Force ArgoCD to refresh from git"
echo "=========================================="

echo "Refreshing redis app to pull latest commit (9c42ece)..."
kubectl patch application redis -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

echo "Refreshing postgresql app to pull latest commit (9c42ece)..."
kubectl patch application postgresql -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

echo "Waiting 10 seconds for git refresh..."
sleep 10

echo ""
echo "=========================================="
echo "PART 2: Delete StatefulSets to force recreation"
echo "=========================================="

echo "Deleting Redis StatefulSet (ArgoCD will recreate with new config)..."
kubectl delete statefulset redis-master -n redis 2>/dev/null || echo "Already deleted"

echo "Deleting PostgreSQL StatefulSet (ArgoCD will recreate with new config)..."
kubectl delete statefulset postgresql -n database 2>/dev/null || echo "Already deleted"

echo "Deleting all PVCs (not needed anymore)..."
kubectl delete pvc --all -n redis 2>/dev/null || echo "No PVCs in redis"
kubectl delete pvc --all -n database 2>/dev/null || echo "No PVCs in database"

echo ""
echo "=========================================="
echo "PART 3: Force sync to recreate with new config"
echo "=========================================="

echo "Syncing redis with latest revision..."
kubectl patch application redis -n argocd --type merge -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}'

echo "Syncing postgresql with latest revision..."
kubectl patch application postgresql -n argocd --type merge -p '{"operation":{"sync":{"prune":true,"syncOptions":["CreateNamespace=true"]}}}'

echo "Waiting 30 seconds for deployments..."
sleep 30

echo ""
echo "=========================================="
echo "PART 4: Check Redis and PostgreSQL status"
echo "=========================================="

echo "Redis pods:"
kubectl get pods -n redis

echo ""
echo "PostgreSQL pods:"
kubectl get pods -n database

echo ""
echo "Redis ArgoCD app:"
kubectl get application redis -n argocd

echo ""
echo "PostgreSQL ArgoCD app:"
kubectl get application postgresql -n argocd

echo ""
echo "=========================================="
echo "PART 5: Fix dev-core ghcr-secret"
echo "=========================================="

echo "Deleting old ghcr-secret in dev-core..."
kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

echo "Creating fresh ghcr-secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created"

echo ""
echo "Deleting dev-core pods to force recreation..."
kubectl delete pods -n dev-core --all

echo "Waiting 20 seconds for pods to start..."
sleep 20

echo ""
echo "=========================================="
echo "PART 6: Final status"
echo "=========================================="

echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "Redis pods:"
kubectl get pods -n redis

echo ""
echo "PostgreSQL pods:"
kubectl get pods -n database

echo ""
echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""
echo "Check pod logs if still failing:"
echo "  kubectl logs -n redis redis-master-0"
echo "  kubectl logs -n database postgresql-0"
echo "  kubectl logs -n dev-core <pod-name>"
echo ""
echo "Check ArgoCD sync status:"
echo "  kubectl get applications -n argocd"
