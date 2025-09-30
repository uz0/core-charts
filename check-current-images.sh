#!/bin/bash
# Check what images are currently being pulled

echo "=========================================="
echo "Current Git Commit"
echo "=========================================="
cd ~/core-charts
git log -1 --oneline
echo ""

echo "=========================================="
echo "Redis Configuration in values.yaml"
echo "=========================================="
grep -A3 "image:" charts/infrastructure/redis/values.yaml | head -5

echo ""
echo "=========================================="
echo "PostgreSQL Configuration in values.yaml"
echo "=========================================="
grep -A3 "image:" charts/infrastructure/postgresql/values.yaml | head -5

echo ""
echo "=========================================="
echo "Redis Actual Images Being Pulled"
echo "=========================================="
kubectl describe pod -n redis 2>/dev/null | grep "Image:" || echo "No Redis pods"

echo ""
echo "=========================================="
echo "PostgreSQL Actual Images Being Pulled"
echo "=========================================="
kubectl describe pod -n database 2>/dev/null | grep "Image:" || echo "No PostgreSQL pods"

echo ""
echo "=========================================="
echo "Redis Pod Events"
echo "=========================================="
kubectl describe pod -n redis 2>/dev/null | grep -A3 "Failed to pull" | tail -10

echo ""
echo "=========================================="
echo "PostgreSQL Pod Events"
echo "=========================================="
kubectl describe pod -n database 2>/dev/null | grep -A3 "Failed to pull" | tail -10
