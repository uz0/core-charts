#!/bin/bash
# Comprehensive fix for all remaining ArgoCD issues

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "PART 1: Fix ghcr-secret in both namespaces"
echo "=========================================="

for namespace in dev-core prod-core; do
  echo "Fixing ghcr-secret in $namespace..."
  kubectl delete secret ghcr-secret -n $namespace 2>/dev/null && echo "  Old secret deleted" || echo "  No old secret found"

  kubectl create secret docker-registry ghcr-secret \
    --docker-server=ghcr.io \
    --docker-username=uz0 \
    --docker-password="$GITHUB_TOKEN" \
    -n $namespace

  echo "  ✓ ghcr-secret created in $namespace"
done

echo ""
echo "=========================================="
echo "PART 2: Fix Redis StatefulSet"
echo "=========================================="
echo "Deleting redis ArgoCD application to allow fresh deployment..."
kubectl delete application redis -n argocd --wait=false 2>/dev/null || echo "Redis app already deleted"

echo "Waiting 10 seconds for cleanup..."
sleep 10

echo "Deleting Redis StatefulSets (preserving PVCs)..."
kubectl delete statefulset redis-master -n redis --cascade=orphan 2>/dev/null || echo "redis-master not found"
kubectl delete statefulset redis-replicas -n redis --cascade=orphan 2>/dev/null || echo "redis-replicas not found"

echo "Deleting Redis pods to force recreation..."
kubectl delete pods -n redis --all --grace-period=30 2>/dev/null || echo "No redis pods to delete"

echo ""
echo "=========================================="
echo "PART 3: Fix PostgreSQL StatefulSet"
echo "=========================================="
echo "Deleting postgresql ArgoCD application to allow fresh deployment..."
kubectl delete application postgresql -n argocd --wait=false 2>/dev/null || echo "PostgreSQL app already deleted"

echo "Waiting 10 seconds for cleanup..."
sleep 10

echo "Deleting PostgreSQL StatefulSet (preserving PVCs)..."
kubectl delete statefulset postgresql -n database --cascade=orphan 2>/dev/null || echo "postgresql not found"

echo "Deleting PostgreSQL pods to force recreation..."
kubectl delete pods -n database --all --grace-period=30 2>/dev/null || echo "No database pods to delete"

echo ""
echo "=========================================="
echo "PART 4: Fix Kafka - Delete existing deployment"
echo "=========================================="
echo "Deleting kafka ArgoCD application to allow fresh KRaft deployment..."
kubectl delete application kafka -n argocd --wait=false 2>/dev/null || echo "Kafka app already deleted"

echo "Waiting 10 seconds for cleanup..."
sleep 10

echo "Deleting Kafka resources..."
kubectl delete statefulset -n kafka --all --cascade=orphan 2>/dev/null || echo "No kafka StatefulSets"
kubectl delete pods -n kafka --all --grace-period=30 2>/dev/null || echo "No kafka pods"

# Clean up old Zookeeper resources if they exist
kubectl delete statefulset -n kafka -l app.kubernetes.io/component=zookeeper --cascade=orphan 2>/dev/null || echo "No zookeeper StatefulSets"

echo ""
echo "=========================================="
echo "PART 5: Delete infrastructure app permanently"
echo "=========================================="
if kubectl get application infrastructure -n argocd 2>/dev/null; then
  echo "Removing infrastructure app finalizer..."
  kubectl patch application infrastructure -n argocd -p '{"metadata":{"finalizers":null}}' --type merge
  kubectl delete application infrastructure -n argocd --force --grace-period=0 2>/dev/null || echo "Already deleted"
else
  echo "Infrastructure app not found (good)"
fi

echo ""
echo "=========================================="
echo "PART 6: Fix nginx ingress admission webhook"
echo "=========================================="
echo "Checking if nginx admission webhook service exists..."
if ! kubectl get service ingress-nginx-controller-admission -n ingress-nginx 2>/dev/null; then
  echo "⚠️  Nginx admission webhook service missing"
  echo "Checking if ingress-nginx is installed..."

  if kubectl get namespace ingress-nginx 2>/dev/null; then
    echo "Restarting ingress-nginx controller to fix webhook..."
    kubectl rollout restart deployment -n ingress-nginx 2>/dev/null || echo "No deployments to restart"
  else
    echo "⚠️  ingress-nginx namespace not found. You may need to install nginx ingress controller."
  fi
else
  echo "✓ Nginx admission webhook service exists"
fi

echo ""
echo "=========================================="
echo "PART 7: Recreate ArgoCD applications"
echo "=========================================="
echo "Applying ArgoCD applications from Git repo..."

# Wait for git changes to be pulled
cd ~/core-charts
echo "Pulling latest changes from Git..."
git pull origin main

# Apply all ArgoCD apps
echo "Applying ArgoCD applications..."
kubectl apply -f argocd-apps/postgresql.yaml
kubectl apply -f argocd-apps/redis.yaml
kubectl apply -f argocd-apps/kafka.yaml

echo ""
echo "=========================================="
echo "PART 8: Force sync core-pipeline apps"
echo "=========================================="
echo "Syncing core-pipeline-dev..."
kubectl patch application core-pipeline-dev -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'

echo "Syncing core-pipeline-prod..."
kubectl patch application core-pipeline-prod -n argocd --type merge -p '{"operation":{"sync":{"prune":true}}}'

echo ""
echo "=========================================="
echo "PART 9: Wait for deployments (60 seconds)"
echo "=========================================="
echo "Waiting for applications to deploy..."
sleep 60

echo ""
echo "=========================================="
echo "PART 10: Check final status"
echo "=========================================="
echo ""
echo "ArgoCD Applications:"
kubectl get applications -n argocd

echo ""
echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "Prod-core pods:"
kubectl get pods -n prod-core

echo ""
echo "Database pods:"
kubectl get pods -n database 2>/dev/null || echo "No database namespace"

echo ""
echo "Redis pods:"
kubectl get pods -n redis 2>/dev/null || echo "No redis namespace"

echo ""
echo "Kafka pods:"
kubectl get pods -n kafka 2>/dev/null || echo "No kafka namespace"

echo ""
echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "Next steps to verify:"
echo "1. Check if any apps are still OutOfSync:"
echo "   kubectl get applications -n argocd"
echo ""
echo "2. Check pod logs if any are still failing:"
echo "   kubectl logs -n dev-core <pod-name>"
echo "   kubectl logs -n prod-core <pod-name>"
echo ""
echo "3. Test health endpoints:"
echo "   curl -k https://core-pipeline.dev.theedgestory.org/health"
echo "   curl -k https://core-pipeline.theedgestory.org/health"
