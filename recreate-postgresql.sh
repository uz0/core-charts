#!/bin/bash
# Recreate PostgreSQL with init scripts to create databases and users

set -e

echo "=========================================="
echo "Recreating PostgreSQL with init scripts"
echo "=========================================="

cd ~/core-charts
git pull origin main

echo "✓ Pulled latest changes (commit a4bf099 with init scripts)"

echo ""
echo "Deleting PostgreSQL application..."
kubectl delete application postgresql -n argocd --wait=false

sleep 5

echo "Deleting PostgreSQL resources..."
kubectl delete statefulset --all -n database --force --grace-period=0
kubectl delete pods --all -n database --force --grace-period=0
kubectl delete pvc --all -n database
kubectl delete configmap -n database -l role=init-scripts 2>/dev/null || echo "No old ConfigMap"

echo "✓ PostgreSQL deleted"

sleep 10

echo ""
echo "Recreating PostgreSQL with init scripts..."
kubectl apply -f argocd-apps/postgresql.yaml

echo "✓ PostgreSQL application created"

echo ""
echo "Waiting 60 seconds for PostgreSQL to start and run init scripts..."
sleep 60

echo ""
echo "=========================================="
echo "PostgreSQL Status"
echo "=========================================="

kubectl get pods -n database

echo ""
echo "Checking PostgreSQL logs for database creation..."
kubectl logs -n database postgresql-0 --tail=50 | grep -E "Creating databases|Created database|Database initialization" || echo "Init script logs not found yet"

echo ""
echo "=========================================="
echo "Testing database connection"
echo "=========================================="

echo "Checking if core_user exists..."
kubectl exec -n database postgresql-0 -- psql -U postgres -c "\du" | grep core_user || echo "⚠️ core_user not found"

echo ""
echo "Checking if core_pipeline_dev database exists..."
kubectl exec -n database postgresql-0 -- psql -U postgres -c "\l" | grep core_pipeline_dev || echo "⚠️ core_pipeline_dev database not found"

echo ""
echo "=========================================="
echo "Restarting dev-core pods"
echo "=========================================="

kubectl delete pods -n dev-core --all

sleep 30

kubectl get pods -n dev-core

echo ""
echo "Checking dev-core logs..."
DEV_POD=$(kubectl get pods -n dev-core -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$DEV_POD" ]; then
  kubectl logs -n dev-core $DEV_POD --tail=30 | grep -E "password authentication|TypeOrmModule|connected" || echo "Still checking..."
fi

echo ""
echo "=========================================="
echo "Complete!"
echo "=========================================="
