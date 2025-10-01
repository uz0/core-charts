#!/bin/bash
set -e

echo "========================================"
echo "FULL DIAGNOSTIC OF PASSWORD STATE"
echo "========================================"

echo ""
echo "=== 1. PostgreSQL Init Job Status ==="
kubectl get job postgresql-db-init -n database -o wide 2>/dev/null || echo "Job not found"

echo ""
echo "=== 2. Init Job Logs (last 100 lines) ==="
kubectl logs job/postgresql-db-init -n database --tail=100 2>/dev/null || echo "Job logs not available or job failed"

echo ""
echo "=== 3. Infrastructure Secrets (Source of Truth) ==="
REDIS_PW=$(kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
PG_DEV_PW=$(kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
PG_PROD_PW=$(kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

echo "Redis password: ${#REDIS_PW} chars, starts with '${REDIS_PW:0:1}', ends with '${REDIS_PW: -1}'"
echo "PostgreSQL dev password: ${#PG_DEV_PW} chars, starts with '${PG_DEV_PW:0:1}', ends with '${PG_DEV_PW: -1}'"
echo "PostgreSQL prod password: ${#PG_PROD_PW} chars, starts with '${PG_PROD_PW:0:1}', ends with '${PG_PROD_PW: -1}'"

echo ""
echo "=== 4. Application Secret (dev-core) ==="
if kubectl get secret all-credentials -n dev-core &>/dev/null; then
  APP_REDIS_PW=$(kubectl get secret all-credentials -n dev-core -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)
  APP_DB_PW=$(kubectl get secret all-credentials -n dev-core -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
  echo "App Redis password: ${#APP_REDIS_PW} chars, starts with '${APP_REDIS_PW:0:1}', ends with '${APP_REDIS_PW: -1}'"
  echo "App DB password: ${#APP_DB_PW} chars, starts with '${APP_DB_PW:0:1}', ends with '${APP_DB_PW: -1}'"

  echo ""
  echo "=== PASSWORD MATCH STATUS (dev-core) ==="
  if [ "$REDIS_PW" = "$APP_REDIS_PW" ]; then
    echo "✓ Redis passwords MATCH"
  else
    echo "✗ Redis passwords MISMATCH (Infrastructure: $REDIS_PW vs App: $APP_REDIS_PW)"
  fi

  if [ "$PG_DEV_PW" = "$APP_DB_PW" ]; then
    echo "✓ PostgreSQL passwords MATCH"
  else
    echo "✗ PostgreSQL passwords MISMATCH (Infrastructure: $PG_DEV_PW vs App: $APP_DB_PW)"
  fi
else
  echo "all-credentials secret NOT FOUND in dev-core"
fi

echo ""
echo "=== 5. Application Secret (prod-core) ==="
if kubectl get secret all-credentials -n prod-core &>/dev/null; then
  APP_REDIS_PW_PROD=$(kubectl get secret all-credentials -n prod-core -o jsonpath='{.data.REDIS_PASSWORD}' | base64 -d)
  APP_DB_PW_PROD=$(kubectl get secret all-credentials -n prod-core -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
  echo "App Redis password: ${#APP_REDIS_PW_PROD} chars, starts with '${APP_REDIS_PW_PROD:0:1}', ends with '${APP_REDIS_PW_PROD: -1}'"
  echo "App DB password: ${#APP_DB_PW_PROD} chars, starts with '${APP_DB_PW_PROD:0:1}', ends with '${APP_DB_PW_PROD: -1}'"

  echo ""
  echo "=== PASSWORD MATCH STATUS (prod-core) ==="
  if [ "$REDIS_PW" = "$APP_REDIS_PW_PROD" ]; then
    echo "✓ Redis passwords MATCH"
  else
    echo "✗ Redis passwords MISMATCH (Infrastructure: $REDIS_PW vs App: $APP_REDIS_PW_PROD)"
  fi

  if [ "$PG_PROD_PW" = "$APP_DB_PW_PROD" ]; then
    echo "✓ PostgreSQL passwords MATCH"
  else
    echo "✗ PostgreSQL passwords MISMATCH (Infrastructure: $PG_PROD_PW vs App: $APP_DB_PW_PROD)"
  fi
else
  echo "all-credentials secret NOT FOUND in prod-core"
fi

echo ""
echo "=== 6. Check if database users exist ==="
POSTGRES_PW=$(kubectl get secret postgresql -n database -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl run psql-test --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$POSTGRES_PW' psql -h postgresql-postgresql.database.svc.cluster.local -U postgres -c \"SELECT usename FROM pg_user WHERE usename = 'core_user';\"" 2>/dev/null || echo "Failed to query PostgreSQL"

echo ""
echo "=== 7. Application Pod Status ==="
echo "Dev pods:"
kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline
echo ""
echo "Prod pods:"
kubectl get pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "========================================"
echo "DIAGNOSTIC COMPLETE"
echo "========================================"
