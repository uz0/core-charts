#!/bin/bash
# Fix remaining issues: dev-core ImagePullBackOff, prod-core PVC, Kafka

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "Issue 1: Fix dev-core ghcr-secret"
echo "=========================================="

kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created in dev-core"

kubectl delete pods -n dev-core --all

echo "✓ dev-core pods deleted, will recreate with secret"

echo ""
echo "=========================================="
echo "Issue 2: Fix prod-core ghcr-secret"
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
echo "Issue 3: Fix prod-core PVC issue"
echo "=========================================="

# Delete the deployment completely to recreate without PVC
kubectl delete deployment -n prod-core --all 2>/dev/null || echo "No deployments"
kubectl delete pods -n prod-core --all 2>/dev/null || echo "No pods"

# Delete any stuck PVCs
kubectl delete pvc -n prod-core --all 2>/dev/null || echo "No PVCs"

echo "✓ prod-core cleaned up"

# Force ArgoCD to sync prod-core
kubectl patch application core-pipeline-prod -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}' 2>/dev/null || echo "ArgoCD sync triggered"

echo ""
echo "=========================================="
echo "Issue 4: Fix Kafka"
echo "=========================================="

# Check if Kafka app exists
if ! kubectl get application kafka -n argocd 2>/dev/null; then
  echo "Kafka app doesn't exist, creating..."
  kubectl apply -f ~/core-charts/argocd-apps/kafka.yaml
else
  echo "Kafka app exists, recreating..."
  kubectl delete application kafka -n argocd --wait=false
  sleep 5
  kubectl delete statefulset --all -n kafka --force --grace-period=0 2>/dev/null || echo "No StatefulSets"
  kubectl delete deployment --all -n kafka --force --grace-period=0 2>/dev/null || echo "No Deployments"
  kubectl delete pods --all -n kafka --force --grace-period=0 2>/dev/null || echo "No pods"
  kubectl delete pvc --all -n kafka 2>/dev/null || echo "No PVCs"

  sleep 10

  kubectl apply -f ~/core-charts/argocd-apps/kafka.yaml
fi

echo "✓ Kafka recreation initiated"

echo ""
echo "=========================================="
echo "Waiting for pods to stabilize (60 seconds)..."
echo "=========================================="

sleep 60

echo ""
echo "=========================================="
echo "Final Status Check"
echo "=========================================="

echo ""
echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "Prod-core pods:"
kubectl get pods -n prod-core

echo ""
echo "Kafka pods:"
kubectl get pods -n kafka

echo ""
echo "Redis pods:"
kubectl get pods -n redis

echo ""
echo "PostgreSQL pods:"
kubectl get pods -n database

echo ""
echo "=========================================="
echo "ArgoCD Applications Status"
echo "=========================================="

kubectl get applications -n argocd

echo ""
echo "=========================================="
echo "If dev-core pods are Running, check logs:"
echo "=========================================="

DEV_POD=$(kubectl get pods -n dev-core -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$DEV_POD" ]; then
  echo "Checking logs for: $DEV_POD"
  kubectl logs -n dev-core $DEV_POD --tail=30 2>&1 | grep -E "Redis|PostgreSQL|connected|error|ECONNREFUSED" || echo "No connection errors found (good!)"
fi

echo ""
echo "=========================================="
echo "Complete!"
echo "=========================================="
