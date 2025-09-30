#!/bin/bash
# Diagnose PostgreSQL crash and fix dev-core image pull

GITHUB_TOKEN="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"

echo "=========================================="
echo "Part 1: Diagnose PostgreSQL crash"
echo "=========================================="

echo "Checking current PostgreSQL pod status..."
kubectl get pods -n database

echo ""
echo "Checking PostgreSQL events..."
kubectl get events -n database --sort-by='.lastTimestamp' | tail -20

echo ""
echo "Checking PostgreSQL logs (current)..."
kubectl logs -n database postgresql-0 --tail=100 2>&1 || echo "Current logs not available"

echo ""
echo "Checking PostgreSQL logs (previous)..."
kubectl logs -n database postgresql-0 --previous --tail=100 2>&1 || echo "Previous logs not available"

echo ""
echo "Checking init-scripts ConfigMap..."
kubectl get configmap postgresql-postgresql-init -n database -o yaml 2>&1 | head -50

echo ""
echo "=========================================="
echo "Part 2: Fix dev-core ImagePullBackOff"
echo "=========================================="

echo "Creating ghcr-secret in dev-core..."
kubectl delete secret ghcr-secret -n dev-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created"

echo ""
echo "Creating ghcr-secret in prod-core..."
kubectl delete secret ghcr-secret -n prod-core 2>/dev/null || echo "No old secret"

kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n prod-core

echo "✓ ghcr-secret created"

echo ""
echo "Deleting dev-core pods..."
kubectl delete pods -n dev-core --all

echo ""
echo "Deleting prod-core pods..."
kubectl delete pods -n prod-core --all

echo ""
echo "Waiting 30 seconds..."
sleep 30

echo ""
echo "=========================================="
echo "Final Status"
echo "=========================================="

echo "PostgreSQL:"
kubectl get pods -n database

echo ""
echo "Dev-core:"
kubectl get pods -n dev-core

echo ""
echo "Prod-core:"
kubectl get pods -n prod-core
