#!/bin/bash
# Fix core-pipeline-dev nginx webhook and ImagePullBackOff issues

set -e

GITHUB_TOKEN="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"

echo "=========================================="
echo "PART 1: Fix nginx ingress admission webhook"
echo "=========================================="

# Check if ingress-nginx namespace exists
if ! kubectl get namespace ingress-nginx 2>/dev/null; then
  echo "❌ ingress-nginx namespace not found. Installing ingress-nginx..."

  kubectl create namespace ingress-nginx

  # Install nginx ingress controller using kubectl apply
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

  echo "✓ Nginx ingress controller installed"
  echo "Waiting 30 seconds for controller to start..."
  sleep 30
else
  echo "✓ ingress-nginx namespace exists"

  # Check if admission webhook service exists
  if ! kubectl get service ingress-nginx-controller-admission -n ingress-nginx 2>/dev/null; then
    echo "⚠️ Admission webhook service missing. Reinstalling ingress-nginx..."

    # Delete old resources
    kubectl delete all --all -n ingress-nginx 2>/dev/null || true

    # Reinstall
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml

    echo "✓ Nginx ingress controller reinstalled"
    echo "Waiting 30 seconds for controller to start..."
    sleep 30
  else
    echo "✓ Admission webhook service exists"
  fi
fi

# Verify ingress-nginx is running
echo "Checking ingress-nginx pods..."
kubectl get pods -n ingress-nginx

echo ""
echo "=========================================="
echo "PART 2: Fix ghcr-secret in dev-core"
echo "=========================================="

# Delete old secret
kubectl delete secret ghcr-secret -n dev-core 2>/dev/null && echo "Old secret deleted" || echo "No old secret found"

# Create fresh secret
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password="$GITHUB_TOKEN" \
  -n dev-core

echo "✓ ghcr-secret created in dev-core"

# Verify secret
echo "Verifying secret contents..."
kubectl get secret ghcr-secret -n dev-core -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d | jq '.auths."ghcr.io".auth' | base64 -d

echo ""
echo "=========================================="
echo "PART 3: Ensure deployment uses imagePullSecrets"
echo "=========================================="

# Check if deployment has imagePullSecrets
if kubectl get deployment core-pipeline-dev -n dev-core -o yaml | grep -q "imagePullSecrets"; then
  echo "✓ Deployment already has imagePullSecrets"
else
  echo "⚠️ Adding imagePullSecrets to deployment..."
  kubectl patch deployment core-pipeline-dev -n dev-core -p '{"spec":{"template":{"spec":{"imagePullSecrets":[{"name":"ghcr-secret"}]}}}}'
  echo "✓ imagePullSecrets added"
fi

echo ""
echo "=========================================="
echo "PART 4: Delete failing pods to force recreation"
echo "=========================================="

echo "Deleting all dev-core pods to force fresh start..."
kubectl delete pods -n dev-core --all --grace-period=30

echo "Waiting 20 seconds for pods to recreate..."
sleep 20

echo ""
echo "=========================================="
echo "PART 5: Delete and recreate ingress"
echo "=========================================="

echo "Deleting dev ingress to force recreation with working webhook..."
kubectl delete ingress -n dev-core --all 2>/dev/null || echo "No ingress to delete"

echo "Forcing ArgoCD sync to recreate ingress..."
kubectl patch application core-pipeline-dev -n argocd --type merge -p '{"operation":{"sync":{"prune":false}}}'

echo "Waiting 15 seconds for sync..."
sleep 15

echo ""
echo "=========================================="
echo "PART 6: Check final status"
echo "=========================================="

echo "Dev-core pods:"
kubectl get pods -n dev-core

echo ""
echo "Dev-core ingress:"
kubectl get ingress -n dev-core

echo ""
echo "ArgoCD app status:"
kubectl get application core-pipeline-dev -n argocd

echo ""
echo "=========================================="
echo "Fix complete!"
echo "=========================================="
echo ""
echo "If pods are still failing:"
echo "1. Check pod logs:"
echo "   kubectl logs -n dev-core <pod-name>"
echo ""
echo "2. Verify secret is used by pods:"
echo "   kubectl get pod <pod-name> -n dev-core -o yaml | grep -A5 imagePullSecrets"
echo ""
echo "3. Test ingress endpoint:"
echo "   curl -k https://core-pipeline.dev.theedgestory.org/health"
