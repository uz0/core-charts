#!/bin/bash
# Final deployment: Fix secrets and restart all pods

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "Step 1: Create ghcr-secret in dev-core"
echo "=========================================="

kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created in dev-core"

echo ""
echo "=========================================="
echo "Step 2: Create ghcr-secret in prod-core"
echo "=========================================="

kubectl delete secret ghcr-secret -n prod-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n prod-core

echo "✓ ghcr-secret created in prod-core"

echo ""
echo "=========================================="
echo "Step 3: Restart dev-core pods"
echo "=========================================="

kubectl delete pods -n dev-core --all

echo "✓ dev-core pods deleted, waiting for recreation..."

sleep 45

echo ""
echo "Dev-core pods status:"
kubectl get pods -n dev-core

echo ""
echo "=========================================="
echo "Step 4: Check dev-core application logs"
echo "=========================================="

DEV_POD=$(kubectl get pods -n dev-core -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$DEV_POD" ]; then
  echo "Checking logs for: $DEV_POD"
  echo ""
  kubectl logs -n dev-core $DEV_POD --tail=50 | grep -E "Starting Nest application|TypeOrmModule|Redis|PostgreSQL|Application startup|error|FATAL" || echo "Checking..."
fi

echo ""
echo "=========================================="
echo "Step 5: Restart prod-core pods"
echo "=========================================="

kubectl delete pods -n prod-core --all

echo "✓ prod-core pods deleted, waiting for recreation..."

sleep 45

echo ""
echo "Prod-core pods status:"
kubectl get pods -n prod-core

echo ""
echo "=========================================="
echo "Step 6: Final Status Check"
echo "=========================================="

echo "PostgreSQL:"
kubectl get pods -n database

echo ""
echo "Redis:"
kubectl get pods -n redis

echo ""
echo "Dev-core:"
kubectl get pods -n dev-core

echo ""
echo "Prod-core:"
kubectl get pods -n prod-core

echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd | grep -E "NAME|core-pipeline|redis|postgresql"

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "If all pods are Running (1/1):"
echo "  - Access dev: https://core-pipeline.dev.theedgestory.org"
echo "  - Access prod: https://core-pipeline.theedgestory.org"
echo ""
echo "To check application health:"
echo "  curl -k https://core-pipeline.dev.theedgestory.org/health"
echo "  curl -k https://core-pipeline.theedgestory.org/health"
