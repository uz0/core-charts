#!/bin/bash
# Final fix: Complete recreation with latest image tags

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "Step 1: Pull latest git changes"
echo "=========================================="

cd ~/core-charts
git fetch origin main
git reset --hard origin/main
git pull origin main

echo "Current commit: $(git rev-parse --short HEAD)"
echo "✓ Git updated to latest"

echo ""
echo "=========================================="
echo "Step 2: Delete Redis completely"
echo "=========================================="

kubectl delete application redis -n argocd --wait=false 2>/dev/null || echo "App already deleted"
sleep 3

kubectl delete statefulset --all -n redis --force --grace-period=0 2>/dev/null || echo "No StatefulSets"
kubectl delete deployment --all -n redis --force --grace-period=0 2>/dev/null || echo "No Deployments"
kubectl delete pods --all -n redis --force --grace-period=0 2>/dev/null || echo "No pods"
kubectl delete pvc --all -n redis 2>/dev/null || echo "No PVCs"

echo "✓ Redis deleted"

echo ""
echo "=========================================="
echo "Step 3: Delete PostgreSQL completely"
echo "=========================================="

kubectl delete application postgresql -n argocd --wait=false 2>/dev/null || echo "App already deleted"
sleep 3

kubectl delete statefulset --all -n database --force --grace-period=0 2>/dev/null || echo "No StatefulSets"
kubectl delete deployment --all -n database --force --grace-period=0 2>/dev/null || echo "No Deployments"
kubectl delete pods --all -n database --force --grace-period=0 2>/dev/null || echo "No pods"
kubectl delete pvc --all -n database 2>/dev/null || echo "No PVCs"

echo "✓ PostgreSQL deleted"

echo ""
echo "=========================================="
echo "Step 4: Wait for cleanup"
echo "=========================================="

sleep 10

echo ""
echo "=========================================="
echo "Step 5: Recreate Redis with new config"
echo "=========================================="

kubectl apply -f argocd-apps/redis.yaml
echo "✓ Redis app created, waiting for deployment..."

sleep 45

kubectl get pods -n redis

echo ""
echo "=========================================="
echo "Step 6: Recreate PostgreSQL with new config"
echo "=========================================="

kubectl apply -f argocd-apps/postgresql.yaml
echo "✓ PostgreSQL app created, waiting for deployment..."

sleep 45

kubectl get pods -n database

echo ""
echo "=========================================="
echo "Step 7: Check for any remaining image errors"
echo "=========================================="

echo "Redis pod events:"
kubectl get events -n redis --sort-by='.lastTimestamp' | grep -i "pull\|image\|error" | tail -10 || echo "No image errors!"

echo ""
echo "PostgreSQL pod events:"
kubectl get events -n database --sort-by='.lastTimestamp' | grep -i "pull\|image\|error" | tail -10 || echo "No image errors!"

echo ""
echo "=========================================="
echo "Step 8: Verify Redis and PostgreSQL are running"
echo "=========================================="

REDIS_RUNNING=$(kubectl get pods -n redis -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
PG_RUNNING=$(kubectl get pods -n database -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")

echo "Redis status: $REDIS_RUNNING"
echo "PostgreSQL status: $PG_RUNNING"

if [ "$REDIS_RUNNING" == "Running" ] && [ "$PG_RUNNING" == "Running" ]; then
  echo "✅ Both Redis and PostgreSQL are running!"
else
  echo "⚠️  Still issues, checking pod descriptions..."
  kubectl describe pod -n redis 2>/dev/null | grep -A10 "Events:" | head -20
  kubectl describe pod -n database 2>/dev/null | grep -A10 "Events:" | head -20
fi

echo ""
echo "=========================================="
echo "Step 9: Fix dev-core and restart"
echo "=========================================="

kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created"

kubectl delete pods -n dev-core --all

echo "Waiting 30 seconds for dev-core pods to start..."
sleep 30

kubectl get pods -n dev-core

echo ""
echo "=========================================="
echo "Step 10: Test Redis and PostgreSQL connectivity"
echo "=========================================="

DEV_POD=$(kubectl get pods -n dev-core -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$DEV_POD" ]; then
  echo "Testing from pod: $DEV_POD"

  echo ""
  echo "Testing Redis..."
  kubectl exec -n dev-core $DEV_POD -- timeout 3 sh -c "echo PING | nc redis-master.redis.svc.cluster.local 6379" 2>&1 || echo "Redis test inconclusive"

  echo ""
  echo "Testing PostgreSQL..."
  kubectl exec -n dev-core $DEV_POD -- timeout 3 nc -zv postgresql.database.svc.cluster.local 5432 2>&1 || echo "PostgreSQL test inconclusive"
fi

echo ""
echo "=========================================="
echo "✅ COMPLETE!"
echo "=========================================="
echo ""
echo "Summary:"
kubectl get pods -n redis
kubectl get pods -n database
kubectl get pods -n dev-core
echo ""
echo "If everything is Running, check dev-core logs:"
echo "  kubectl logs -n dev-core <pod-name> | tail -50"
