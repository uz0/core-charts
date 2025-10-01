#!/bin/bash
set -e

echo "========================================"
echo "COMPLETE FIX FOR PASSWORD SYNC ISSUES"
echo "========================================"

echo ""
echo "=== Step 1: Force delete stuck PostgreSQL init Job ==="
kubectl delete job postgresql-db-init -n database --force --grace-period=0 2>/dev/null || echo "Job already deleted"

echo ""
echo "=== Step 2: Check PostgreSQL service name ==="
PG_SERVICE=$(kubectl get svc -n database -l app.kubernetes.io/name=postgresql -o jsonpath='{.items[0].metadata.name}')
echo "PostgreSQL service name: $PG_SERVICE"

echo ""
echo "=== Step 3: Upgrade PostgreSQL chart (will recreate init Job) ==="
cd ~/core-charts
helm upgrade postgresql charts/infrastructure/postgresql \
  --namespace database \
  --install

echo ""
echo "=== Step 4: Wait for init Job to complete ==="
echo "Waiting up to 2 minutes..."
kubectl wait --for=condition=complete --timeout=120s job/postgresql-db-init -n database || {
  echo "Job did not complete in time, checking logs..."
  kubectl logs job/postgresql-db-init -n database --tail=50
  exit 1
}

echo ""
echo "=== Step 5: Check init Job logs ==="
kubectl logs job/postgresql-db-init -n database

echo ""
echo "=== Step 6: Verify database users were created ==="
POSTGRES_PW=$(kubectl get secret postgresql -n database -o jsonpath='{.data.postgres-password}' | base64 -d)
kubectl run psql-check --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$POSTGRES_PW' psql -h $PG_SERVICE.database.svc.cluster.local -U postgres -c \"SELECT usename FROM pg_user WHERE usename = 'core_user';\""

echo ""
echo "=== Step 7: Sync passwords to application namespaces ==="
cd ~/core-charts

# Get infrastructure passwords
REDIS_PASSWORD=$(kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
PG_DEV_PASSWORD=$(kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
PG_PROD_PASSWORD=$(kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

echo "Syncing passwords:"
echo "  Redis: ${#REDIS_PASSWORD} chars"
echo "  PostgreSQL Dev: ${#PG_DEV_PASSWORD} chars"
echo "  PostgreSQL Prod: ${#PG_PROD_PASSWORD} chars"

# Update dev-core all-credentials
kubectl delete secret all-credentials -n dev-core 2>/dev/null || echo "No old secret in dev-core"
kubectl create secret generic all-credentials -n dev-core \
  --from-literal=DB_HOST="$PG_SERVICE.database.svc.cluster.local" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="core_user" \
  --from-literal=DB_PASSWORD="$PG_DEV_PASSWORD" \
  --from-literal=DB_NAME="core_pipeline_dev" \
  --from-literal=REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=BULL_REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=BULL_REDIS_PORT="6379" \
  --from-literal=BULL_REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=KAFKA_BROKERS="kafka.kafka.svc.cluster.local:9092"

echo "✓ Updated all-credentials in dev-core"

# Update prod-core all-credentials
kubectl delete secret all-credentials -n prod-core 2>/dev/null || echo "No old secret in prod-core"
kubectl create secret generic all-credentials -n prod-core \
  --from-literal=DB_HOST="$PG_SERVICE.database.svc.cluster.local" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="core_user" \
  --from-literal=DB_PASSWORD="$PG_PROD_PASSWORD" \
  --from-literal=DB_NAME="core_pipeline_prod" \
  --from-literal=REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=BULL_REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=BULL_REDIS_PORT="6379" \
  --from-literal=BULL_REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=KAFKA_BROKERS="kafka.kafka.svc.cluster.local:9092"

echo "✓ Updated all-credentials in prod-core"

echo ""
echo "=== Step 8: Restart application pods ==="
kubectl delete pods -n dev-core -l app.kubernetes.io/name=core-pipeline
kubectl delete pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "=== Step 9: Wait for new pods to start ==="
sleep 10

echo ""
echo "Dev pods:"
kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "Prod pods:"
kubectl get pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "=== Step 10: Check application logs (dev) ==="
echo "Waiting for dev pod to start..."
sleep 20
kubectl logs -n dev-core -l app.kubernetes.io/name=core-pipeline --tail=50 --all-containers=true

echo ""
echo "========================================"
echo "FIX COMPLETE"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Check if pods are running: kubectl get pods -n dev-core -n prod-core"
echo "2. Test dev swagger: curl https://core-pipeline.dev.theedgestory.org/swagger"
echo "3. Test prod swagger: curl https://core-pipeline.theedgestory.org/swagger"
