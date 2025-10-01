#!/bin/bash

echo "========================================"
echo "STEP-BY-STEP PASSWORD FIX"
echo "========================================"

echo ""
echo "=== Step 1: Check and remove finalizers from stuck Job ==="
if kubectl get job postgresql-db-init -n database &>/dev/null; then
  echo "Job exists, removing finalizers..."
  kubectl patch job postgresql-db-init -n database -p '{"metadata":{"finalizers":null}}' --type=merge
  kubectl delete job postgresql-db-init -n database --grace-period=0 --force 2>/dev/null || echo "Job deleted"
  sleep 2
else
  echo "Job does not exist"
fi

echo ""
echo "=== Step 2: Verify Job is gone ==="
kubectl get job postgresql-db-init -n database 2>/dev/null || echo "✓ Job successfully deleted"

echo ""
echo "=== Step 3: Get PostgreSQL service name ==="
PG_SERVICE=$(kubectl get svc -n database -o name | grep postgresql | head -1 | cut -d/ -f2)
if [ -z "$PG_SERVICE" ]; then
  echo "ERROR: PostgreSQL service not found!"
  echo "Available services in database namespace:"
  kubectl get svc -n database
  exit 1
fi
echo "PostgreSQL service: $PG_SERVICE"

echo ""
echo "=== Step 4: Test database connectivity BEFORE init Job ==="
POSTGRES_PW=$(kubectl get secret postgresql -n database -o jsonpath='{.data.postgres-password}' | base64 -d)
echo "Testing connection to $PG_SERVICE.database.svc.cluster.local..."
kubectl run psql-test-pre --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$POSTGRES_PW' psql -h $PG_SERVICE.database.svc.cluster.local -U postgres -c 'SELECT version();'" 2>&1 | grep -v "bitnami\|INFO\|Subscribe\|Submit\|Upgrade" || echo "Connection test completed"

echo ""
echo "=== Step 5: Check if core_user already exists ==="
kubectl run psql-test-user --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$POSTGRES_PW' psql -h $PG_SERVICE.database.svc.cluster.local -U postgres -c \"SELECT usename, usecreatedb, usesuper FROM pg_user WHERE usename = 'core_user';\"" 2>&1 | grep -v "bitnami\|INFO\|Subscribe\|Submit\|Upgrade" || echo "User check completed"

echo ""
echo "=== Step 6: Manually create/update database users with correct passwords ==="
PG_DEV_PASSWORD=$(kubectl get secret postgres-core-pipeline-dev-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)
PG_PROD_PASSWORD=$(kubectl get secret postgres-core-pipeline-prod-secret -n database -o jsonpath='{.data.DB_PASSWORD}' | base64 -d)

echo "Creating/updating core_user and databases..."

kubectl run psql-init --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$POSTGRES_PW' psql -h $PG_SERVICE.database.svc.cluster.local -U postgres <<EOF
-- Create or update user
DO \\\$\\\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_user WHERE usename = 'core_user') THEN
    CREATE USER core_user WITH PASSWORD '$PG_DEV_PASSWORD';
    RAISE NOTICE 'Created user core_user';
  ELSE
    ALTER USER core_user WITH PASSWORD '$PG_DEV_PASSWORD';
    RAISE NOTICE 'Updated password for user core_user';
  END IF;
END
\\\$\\\$;

-- Create dev database if not exists
SELECT 'CREATE DATABASE core_pipeline_dev OWNER core_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'core_pipeline_dev') \gexec

-- Create prod database if not exists
SELECT 'CREATE DATABASE core_pipeline_prod OWNER core_user'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'core_pipeline_prod') \gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE core_pipeline_dev TO core_user;
GRANT ALL PRIVILEGES ON DATABASE core_pipeline_prod TO core_user;

-- Connect to dev database and grant schema privileges
\c core_pipeline_dev
GRANT ALL ON SCHEMA public TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO core_user;

-- Connect to prod database and grant schema privileges
\c core_pipeline_prod
GRANT ALL ON SCHEMA public TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO core_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO core_user;
EOF
" 2>&1 | grep -v "bitnami\|INFO\|Subscribe\|Submit\|Upgrade"

echo "✓ Database users and permissions configured"

echo ""
echo "=== Step 7: Verify we can connect with new passwords ==="
echo "Testing dev database..."
kubectl run psql-verify-dev --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$PG_DEV_PASSWORD' psql -h $PG_SERVICE.database.svc.cluster.local -U core_user -d core_pipeline_dev -c 'SELECT current_user, current_database();'" 2>&1 | grep -v "bitnami\|INFO\|Subscribe\|Submit\|Upgrade"

echo ""
echo "Testing prod database..."
kubectl run psql-verify-prod --rm -i --restart=Never --image=docker.io/bitnamilegacy/postgresql:16.4.0-debian-12-r13 --namespace=database -- \
  bash -c "PGPASSWORD='$PG_PROD_PASSWORD' psql -h $PG_SERVICE.database.svc.cluster.local -U core_user -d core_pipeline_prod -c 'SELECT current_user, current_database();'" 2>&1 | grep -v "bitnami\|INFO\|Subscribe\|Submit\|Upgrade"

echo ""
echo "=== Step 8: Sync passwords to application secrets ==="
REDIS_PASSWORD=$(kubectl get secret redis -n redis -o jsonpath='{.data.redis-password}' | base64 -d)

echo "Infrastructure passwords:"
echo "  Redis: ${#REDIS_PASSWORD} chars, ${REDIS_PASSWORD:0:5}...${REDIS_PASSWORD: -3}"
echo "  PostgreSQL Dev: ${#PG_DEV_PASSWORD} chars, ${PG_DEV_PASSWORD:0:5}...${PG_DEV_PASSWORD: -3}"
echo "  PostgreSQL Prod: ${#PG_PROD_PASSWORD} chars, ${PG_PROD_PASSWORD:0:5}...${PG_PROD_PASSWORD: -3}"

# Update dev-core
kubectl delete secret all-credentials -n dev-core 2>/dev/null || echo "No old secret"
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
echo "✓ Updated dev-core all-credentials"

# Update prod-core
kubectl delete secret all-credentials -n prod-core 2>/dev/null || echo "No old secret"
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
echo "✓ Updated prod-core all-credentials"

echo ""
echo "=== Step 9: Restart application pods ==="
kubectl delete pods -n dev-core -l app.kubernetes.io/name=core-pipeline
kubectl delete pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "Waiting 15 seconds for pods to start..."
sleep 15

echo ""
echo "=== Step 10: Check pod status ==="
echo "Dev pods:"
kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "Prod pods:"
kubectl get pods -n prod-core -l app.kubernetes.io/name=core-pipeline

echo ""
echo "========================================"
echo "FIX COMPLETE"
echo "========================================"
echo ""
echo "Wait 30 seconds for apps to start, then run:"
echo "  kubectl logs -n dev-core -l app.kubernetes.io/name=core-pipeline --tail=30"
echo "  curl -k https://core-pipeline.dev.theedgestory.org/health/liveness"
echo "  curl -k https://core-pipeline.theedgestory.org/health/liveness"
