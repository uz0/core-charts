#!/bin/bash
# Fix all-credentials secret with correct passwords from Redis and PostgreSQL

set -e

echo "=========================================="
echo "Fetching Real Passwords from Infrastructure"
echo "=========================================="

# Get Redis password
REDIS_PASSWORD=$(kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d)
echo "✓ Got Redis password: ${REDIS_PASSWORD:0:5}..."

# Get PostgreSQL passwords
POSTGRES_PASSWORD=$(kubectl get secret postgresql -n database -o jsonpath='{.data.postgres-password}' | base64 -d)
echo "✓ Got PostgreSQL admin password: ${POSTGRES_PASSWORD:0:5}..."

# Get core_user password for dev (secret name format: postgres-{dbname}-secret)
DB_PASSWORD_DEV=$(kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d 2>/dev/null || echo "")
if [ -z "$DB_PASSWORD_DEV" ]; then
  echo "⚠ postgres-core-pipeline-dev-secret not found, using postgres password"
  DB_PASSWORD_DEV="$POSTGRES_PASSWORD"
fi
echo "✓ Got Dev DB password: ${DB_PASSWORD_DEV:0:5}..."

# Get core_user password for prod
DB_PASSWORD_PROD=$(kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d 2>/dev/null || echo "")
if [ -z "$DB_PASSWORD_PROD" ]; then
  echo "⚠ postgres-core-pipeline-prod-secret not found, using postgres password"
  DB_PASSWORD_PROD="$POSTGRES_PASSWORD"
fi
echo "✓ Got Prod DB password: ${DB_PASSWORD_PROD:0:5}..."

echo ""
echo "=========================================="
echo "Updating all-credentials in dev-core"
echo "=========================================="

kubectl delete secret all-credentials -n dev-core 2>/dev/null || echo "No old secret"

kubectl create secret generic all-credentials -n dev-core \
  --from-literal=DB_HOST="postgresql.database.svc.cluster.local" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="core_user" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD_DEV" \
  --from-literal=DB_NAME="core_pipeline_dev" \
  --from-literal=REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=REDIS_PORT="6379" \
  --from-literal=REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=BULL_REDIS_HOST="redis-master.redis.svc.cluster.local" \
  --from-literal=BULL_REDIS_PORT="6379" \
  --from-literal=BULL_REDIS_PASSWORD="$REDIS_PASSWORD" \
  --from-literal=KAFKA_BROKERS="kafka.kafka.svc.cluster.local:9092"

echo "✓ Updated all-credentials in dev-core"

echo ""
echo "=========================================="
echo "Updating all-credentials in prod-core"
echo "=========================================="

kubectl delete secret all-credentials -n prod-core 2>/dev/null || echo "No old secret"

kubectl create secret generic all-credentials -n prod-core \
  --from-literal=DB_HOST="postgresql.database.svc.cluster.local" \
  --from-literal=DB_PORT="5432" \
  --from-literal=DB_USER="core_user" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD_PROD" \
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
echo "=========================================="
echo "Restarting Application Pods"
echo "=========================================="

kubectl delete pods -n dev-core -l app.kubernetes.io/name=core-pipeline
kubectl delete pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo "✓ Pods restarted"

echo ""
echo "=========================================="
echo "Waiting 30 seconds for pods to restart..."
echo "=========================================="
sleep 30

echo ""
echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "Prod-core pods:"
kubectl get pods -n prod-core

echo ""
echo "=========================================="
echo "Checking Dev Logs"
echo "=========================================="
DEV_POD=$(kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -n "$DEV_POD" ]; then
  echo "Logs from $DEV_POD:"
  kubectl logs -n dev-core $DEV_POD --tail=30 | grep -E "Redis|PostgreSQL|TypeOrmModule|Application|error|WRONGPASS|password authentication" || echo "No connection errors found - looks good!"
fi

echo ""
echo "✅ Credentials fixed!"
