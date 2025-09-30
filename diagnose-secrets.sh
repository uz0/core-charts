#!/bin/bash
# Diagnose secret issues

echo "=========================================="
echo "Checking all PostgreSQL secrets"
echo "=========================================="
kubectl get secrets -n database | grep -E "NAME|postgres"

echo ""
echo "=========================================="
echo "Checking postgres-core-pipeline-dev-secret"
echo "=========================================="
if kubectl get secret postgres-core-pipeline-dev-secret -n database 2>/dev/null; then
  echo "Secret EXISTS"
  echo "DB_PASSWORD:"
  kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
  echo ""
  echo "DB_USERNAME:"
  kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_USERNAME}' | base64 -d
  echo ""
else
  echo "Secret DOES NOT EXIST"
fi

echo ""
echo "=========================================="
echo "Checking postgres-core-pipeline-prod-secret"
echo "=========================================="
if kubectl get secret postgres-core-pipeline-prod-secret -n database 2>/dev/null; then
  echo "Secret EXISTS"
  echo "DB_PASSWORD:"
  kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
  echo ""
  echo "DB_USERNAME:"
  kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_USERNAME}' | base64 -d
  echo ""
else
  echo "Secret DOES NOT EXIST"
fi

echo ""
echo "=========================================="
echo "Checking Redis secret"
echo "=========================================="
kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d
echo ""

echo ""
echo "=========================================="
echo "Checking all-credentials in dev-core"
echo "=========================================="
echo "DB_PASSWORD:"
kubectl get secret all-credentials -n dev-core -o jsonpath='{.data.DB_PASSWORD}' | base64 -d
echo ""
echo "REDIS_PASSWORD:"
kubectl get secret all-credentials -n dev-core -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d
echo ""

echo ""
echo "=========================================="
echo "Testing PostgreSQL connection with postgres user"
echo "=========================================="
POSTGRES_PASS=$(kubectl get secret postgresql -n database -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl exec -n database postgresql-0 -- psql -U postgres -c "\du" 2>&1 | head -20

echo ""
echo "=========================================="
echo "Checking if core_user exists in PostgreSQL"
echo "=========================================="
kubectl exec -n database postgresql-0 -- bash -c "PGPASSWORD='$POSTGRES_PASS' psql -U postgres -c \"SELECT usename, valuntil FROM pg_user WHERE usename='core_user';\"" 2>&1

echo ""
echo "=========================================="
echo "Checking if databases exist"
echo "=========================================="
kubectl exec -n database postgresql-0 -- bash -c "PGPASSWORD='$POSTGRES_PASS' psql -U postgres -c \"\l\" | grep core_pipeline" 2>&1

echo ""
echo "Done!"
