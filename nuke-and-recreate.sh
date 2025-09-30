#!/bin/bash
# Nuclear option: Delete and recreate Redis/PostgreSQL completely

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "PART 1: Complete deletion of Redis"
echo "=========================================="

echo "Deleting Redis ArgoCD application..."
kubectl delete application redis -n argocd --wait=false 2>/dev/null || echo "Already deleted"

echo "Waiting 5 seconds..."
sleep 5

echo "Deleting all Redis resources..."
kubectl delete statefulset --all -n redis 2>/dev/null || echo "No StatefulSets"
kubectl delete deployment --all -n redis 2>/dev/null || echo "No Deployments"
kubectl delete pods --all -n redis --grace-period=0 --force 2>/dev/null || echo "No pods"
kubectl delete pvc --all -n redis 2>/dev/null || echo "No PVCs"
kubectl delete svc --all -n redis 2>/dev/null || echo "No services"

echo "✓ Redis completely deleted"

echo ""
echo "=========================================="
echo "PART 2: Complete deletion of PostgreSQL"
echo "=========================================="

echo "Deleting PostgreSQL ArgoCD application..."
kubectl delete application postgresql -n argocd --wait=false 2>/dev/null || echo "Already deleted"

echo "Waiting 5 seconds..."
sleep 5

echo "Deleting all PostgreSQL resources..."
kubectl delete statefulset --all -n database 2>/dev/null || echo "No StatefulSets"
kubectl delete deployment --all -n database 2>/dev/null || echo "No Deployments"
kubectl delete pods --all -n database --grace-period=0 --force 2>/dev/null || echo "No pods"
kubectl delete pvc --all -n database 2>/dev/null || echo "No PVCs"
kubectl delete svc --all -n database 2>/dev/null || echo "No services"

echo "✓ PostgreSQL completely deleted"

echo ""
echo "=========================================="
echo "PART 3: Pull latest git changes"
echo "=========================================="

cd ~/core-charts
git fetch origin main
git reset --hard origin/main

echo "Current commit: $(git rev-parse HEAD)"
echo "Should be: c19d433 or later"

echo ""
echo "Verifying configuration changes..."
echo "Redis volumePermissions disabled: $(grep -A2 'volumePermissions:' charts/infrastructure/redis/values.yaml | grep enabled || echo 'NOT FOUND (good)')"
echo "PostgreSQL volumePermissions: $(grep -A1 'volumePermissions:' charts/infrastructure/postgresql/values.yaml | grep enabled)"
echo "PostgreSQL persistence: $(grep -A1 'persistence:' charts/infrastructure/postgresql/values.yaml | head -2 | tail -1)"

echo ""
echo "=========================================="
echo "PART 4: Recreate Redis from latest config"
echo "=========================================="

echo "Applying Redis ArgoCD application from file..."
kubectl apply -f argocd-apps/redis.yaml

echo "Waiting 30 seconds for Redis to deploy..."
sleep 30

echo ""
echo "Redis pods:"
kubectl get pods -n redis

echo ""
echo "Redis ArgoCD status:"
kubectl get application redis -n argocd

echo ""
echo "=========================================="
echo "PART 5: Recreate PostgreSQL from latest config"
echo "=========================================="

echo "Applying PostgreSQL ArgoCD application from file..."
kubectl apply -f argocd-apps/postgresql.yaml

echo "Waiting 30 seconds for PostgreSQL to deploy..."
sleep 30

echo ""
echo "PostgreSQL pods:"
kubectl get pods -n database

echo ""
echo "PostgreSQL ArgoCD status:"
kubectl get application postgresql -n argocd

echo ""
echo "=========================================="
echo "PART 6: Check for image pull issues"
echo "=========================================="

echo "Checking Redis pod events..."
REDIS_POD=$(kubectl get pods -n redis -o name | head -1 | cut -d/ -f2)
if [ -n "$REDIS_POD" ]; then
  kubectl get events -n redis --field-selector involvedObject.name=$REDIS_POD | tail -10
else
  echo "No Redis pods found"
fi

echo ""
echo "Checking PostgreSQL pod events..."
PG_POD=$(kubectl get pods -n database -o name | head -1 | cut -d/ -f2)
if [ -n "$PG_POD" ]; then
  kubectl get events -n database --field-selector involvedObject.name=$PG_POD | tail -10
else
  echo "No PostgreSQL pods found"
fi

echo ""
echo "=========================================="
echo "PART 7: Fix dev-core ghcr-secret"
echo "=========================================="

echo "Deleting old ghcr-secret..."
kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

echo "Creating fresh ghcr-secret..."
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created"

echo ""
echo "Deleting dev-core pods..."
kubectl delete pods -n dev-core --all

echo "Waiting 20 seconds for pods to start..."
sleep 20

echo ""
echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "=========================================="
echo "Complete!"
echo "=========================================="
echo ""
echo "If STILL failing, check what images are being pulled:"
echo "  kubectl describe pod -n database <pod-name> | grep -A5 'Image'"
echo "  kubectl describe pod -n redis <pod-name> | grep -A5 'Image'"
echo ""
echo "Check StatefulSet images:"
echo "  kubectl get statefulset redis-master -n redis -o yaml | grep image:"
echo "  kubectl get statefulset postgresql -n database -o yaml | grep image:"
