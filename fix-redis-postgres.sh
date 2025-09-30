#!/bin/bash
# Fix Redis and PostgreSQL connection refused errors

set -e

echo "=========================================="
echo "PART 1: Diagnose Redis issues"
echo "=========================================="

echo "Checking Redis namespace..."
kubectl get namespace redis 2>/dev/null || echo "⚠️ Redis namespace missing"

echo ""
echo "Checking Redis pods..."
kubectl get pods -n redis 2>/dev/null || echo "⚠️ No Redis pods found"

echo ""
echo "Checking Redis services..."
kubectl get svc -n redis 2>/dev/null || echo "⚠️ No Redis services found"

echo ""
echo "Checking Redis service endpoints..."
kubectl get endpoints redis-master -n redis 2>/dev/null || echo "⚠️ redis-master service has no endpoints"

echo ""
echo "Checking Redis ArgoCD application..."
kubectl get application redis -n argocd 2>/dev/null || echo "⚠️ Redis ArgoCD app not found"

echo ""
echo "=========================================="
echo "PART 2: Diagnose PostgreSQL issues"
echo "=========================================="

echo "Checking database namespace..."
kubectl get namespace database 2>/dev/null || echo "⚠️ Database namespace missing"

echo ""
echo "Checking PostgreSQL pods..."
kubectl get pods -n database 2>/dev/null || echo "⚠️ No PostgreSQL pods found"

echo ""
echo "Checking PostgreSQL services..."
kubectl get svc -n database 2>/dev/null || echo "⚠️ No PostgreSQL services found"

echo ""
echo "Checking PostgreSQL service endpoints..."
kubectl get endpoints postgresql -n database 2>/dev/null || echo "⚠️ postgresql service has no endpoints"

echo ""
echo "Checking PostgreSQL ArgoCD application..."
kubectl get application postgresql -n argocd 2>/dev/null || echo "⚠️ PostgreSQL ArgoCD app not found"

echo ""
echo "=========================================="
echo "PART 3: Fix Redis"
echo "=========================================="

if kubectl get application redis -n argocd 2>/dev/null; then
  echo "Redis ArgoCD app exists, syncing..."
  kubectl patch application redis -n argocd --type merge -p '{"operation":{"sync":{"prune":false}}}'

  echo "Waiting 20 seconds for sync..."
  sleep 20
else
  echo "Redis ArgoCD app missing, creating from file..."

  cd ~/core-charts
  git pull origin main

  if [ -f argocd-apps/redis.yaml ]; then
    kubectl apply -f argocd-apps/redis.yaml
    echo "✓ Redis app created"

    echo "Waiting 20 seconds for deployment..."
    sleep 20
  else
    echo "❌ argocd-apps/redis.yaml not found"
  fi
fi

echo ""
echo "Checking Redis pods after fix..."
kubectl get pods -n redis 2>/dev/null || echo "⚠️ Still no Redis pods"

echo ""
echo "=========================================="
echo "PART 4: Fix PostgreSQL"
echo "=========================================="

if kubectl get application postgresql -n argocd 2>/dev/null; then
  echo "PostgreSQL ArgoCD app exists, syncing..."
  kubectl patch application postgresql -n argocd --type merge -p '{"operation":{"sync":{"prune":false}}}'

  echo "Waiting 20 seconds for sync..."
  sleep 20
else
  echo "PostgreSQL ArgoCD app missing, creating from file..."

  cd ~/core-charts

  if [ -f argocd-apps/postgresql.yaml ]; then
    kubectl apply -f argocd-apps/postgresql.yaml
    echo "✓ PostgreSQL app created"

    echo "Waiting 20 seconds for deployment..."
    sleep 20
  else
    echo "❌ argocd-apps/postgresql.yaml not found"
  fi
fi

echo ""
echo "Checking PostgreSQL pods after fix..."
kubectl get pods -n database 2>/dev/null || echo "⚠️ Still no PostgreSQL pods"

echo ""
echo "=========================================="
echo "PART 5: Test connectivity from dev-core pod"
echo "=========================================="

DEV_POD=$(kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$DEV_POD" ]; then
  echo "Testing from pod: $DEV_POD"

  echo ""
  echo "Testing Redis connectivity..."
  kubectl exec -n dev-core $DEV_POD -- timeout 5 nc -zv redis-master.redis.svc.cluster.local 6379 2>&1 || echo "⚠️ Redis not reachable"

  echo ""
  echo "Testing PostgreSQL connectivity..."
  kubectl exec -n dev-core $DEV_POD -- timeout 5 nc -zv postgresql.database.svc.cluster.local 5432 2>&1 || echo "⚠️ PostgreSQL not reachable"

  echo ""
  echo "Checking DNS resolution..."
  kubectl exec -n dev-core $DEV_POD -- nslookup redis-master.redis.svc.cluster.local 2>&1 || echo "⚠️ DNS issue"
else
  echo "⚠️ No dev-core pod found to test from"
fi

echo ""
echo "=========================================="
echo "PART 6: Final status"
echo "=========================================="

echo "Redis status:"
kubectl get pods -n redis -o wide 2>/dev/null || echo "No Redis pods"

echo ""
echo "PostgreSQL status:"
kubectl get pods -n database -o wide 2>/dev/null || echo "No PostgreSQL pods"

echo ""
echo "Redis service endpoints:"
kubectl get endpoints redis-master -n redis 2>/dev/null || echo "No endpoints"

echo ""
echo "PostgreSQL service endpoints:"
kubectl get endpoints postgresql -n database 2>/dev/null || echo "No endpoints"

echo ""
echo "ArgoCD applications:"
kubectl get applications -n argocd | grep -E "redis|postgresql"

echo ""
echo "=========================================="
echo "Diagnosis complete!"
echo "=========================================="
echo ""
echo "If Redis/PostgreSQL pods are not running:"
echo "1. Check ArgoCD app status: kubectl get application redis -n argocd -o yaml"
echo "2. Check pod logs: kubectl logs -n redis <pod-name>"
echo "3. Check events: kubectl get events -n redis --sort-by='.lastTimestamp'"
echo ""
echo "If pods are running but not reachable:"
echo "1. Check service: kubectl describe svc redis-master -n redis"
echo "2. Check network policies: kubectl get networkpolicy -n redis"
echo "3. Restart dev-core pods: kubectl delete pods -n dev-core --all"
