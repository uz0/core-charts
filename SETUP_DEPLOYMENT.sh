#!/bin/bash

# Complete setup script for core-pipeline deployment
set -e

echo "=========================================="
echo "Core Pipeline Deployment Setup"
echo "=========================================="
echo ""

# Check if required environment variables are set
if [ -z "$GITHUB_TOKEN" ]; then
  echo "ERROR: GITHUB_TOKEN environment variable is not set"
  echo "Please create a GitHub token with 'repo' and 'packages:write' scopes"
  echo "Export it: export GITHUB_TOKEN=your_token_here"
  exit 1
fi

if [ -z "$GITHUB_USER" ]; then
  GITHUB_USER="uz0"
  echo "Using default GitHub user: $GITHUB_USER"
fi

echo "Step 1: Creating image pull secrets for Kubernetes"
echo "=================================================="

# Create image pull secret for dev environment
kubectl create namespace dev-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=noreply@github.com \
  -n dev-core \
  --dry-run=client -o yaml | kubectl apply -f -

# Create image pull secret for prod environment
kubectl create namespace prod-core --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=$GITHUB_USER \
  --docker-password=$GITHUB_TOKEN \
  --docker-email=noreply@github.com \
  -n prod-core \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Image pull secrets created"
echo ""

echo "Step 2: Adding repository credentials to ArgoCD"
echo "================================================"

# Create ArgoCD repository secret
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-core-charts
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/uz0/core-charts
  username: $GITHUB_USER
  password: $GITHUB_TOKEN
EOF

echo "✅ ArgoCD repository credentials added"
echo ""

echo "Step 3: Applying Kubernetes manifests"
echo "======================================"

# Apply the manifests
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

echo "✅ Kubernetes manifests applied"
echo ""

echo "Step 4: Creating ArgoCD applications"
echo "===================================="

# Apply ArgoCD applications
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

echo "✅ ArgoCD applications created"
echo ""

echo "Step 5: Restarting ArgoCD components"
echo "===================================="

kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd

echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=120s

echo "✅ ArgoCD restarted"
echo ""

echo "Step 6: Initial sync of applications"
echo "===================================="

# Force initial sync
kubectl patch application core-pipeline-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

kubectl patch application core-pipeline-prod -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

echo "✅ Applications synced"
echo ""

echo "=========================================="
echo "Deployment Setup Complete!"
echo "=========================================="
echo ""
echo "Verification Commands:"
echo "----------------------"
echo "kubectl get applications -n argocd"
echo "kubectl get pods -n dev-core"
echo "kubectl get pods -n prod-core"
echo ""
echo "ArgoCD UI:"
echo "----------"
echo "Dev:  http://46.62.223.198:30113/applications/argocd/core-pipeline-dev"
echo "Prod: http://46.62.223.198:30113/applications/argocd/core-pipeline-prod"
echo ""
echo "Application URLs:"
echo "-----------------"
echo "Dev:  https://core-pipeline.dev.theedgestory.org"
echo "Prod: https://core-pipeline.prod.theedgestory.org"
echo ""
echo "Next Steps:"
echo "-----------"
echo "1. Push code to 'develop' branch → deploys to dev"
echo "2. Push code to 'main' branch → deploys to production"
echo "3. Create a release tag (v1.0.0) → deploys specific version"
echo ""
echo "CI/CD Files to Copy to core-pipeline repo:"
echo "------------------------------------------"
echo "- core-pipeline-ci-cd/.github/workflows/deploy.yaml"
echo "- core-pipeline-ci-cd/Dockerfile"