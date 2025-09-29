#!/bin/bash

# This script sets up ArgoCD authentication for private GitHub repository
# Run this on the server after creating a GitHub Personal Access Token

echo "============================================"
echo "Setting up ArgoCD Authentication"
echo "============================================"
echo ""
echo "First, create a GitHub Personal Access Token:"
echo "1. Go to: https://github.com/settings/tokens/new"
echo "2. Give it a name: 'ArgoCD-CoreCharts'"
echo "3. Select scope: 'repo' (Full control of private repositories)"
echo "4. Click 'Generate token'"
echo "5. Copy the token"
echo ""
read -p "Enter your GitHub username: " GITHUB_USER
read -sp "Enter your GitHub token: " GITHUB_TOKEN
echo ""

# Create the repository secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: repo-core-charts-private
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/uz0/core-charts
  username: ${GITHUB_USER}
  password: ${GITHUB_TOKEN}
EOF

echo "✓ Repository credentials added to ArgoCD"

# Restart ArgoCD to pick up new credentials
echo "Restarting ArgoCD components..."
kubectl rollout restart deployment/argocd-repo-server -n argocd
kubectl rollout restart deployment/argocd-application-controller -n argocd

# Wait for restart
echo "Waiting for ArgoCD to restart..."
sleep 10
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server -n argocd --timeout=120s

echo "✓ ArgoCD restarted"

# Delete and recreate applications
echo "Recreating ArgoCD applications..."
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

# Force sync
echo "Forcing sync..."
sleep 5
kubectl patch application core-pipeline-dev -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
kubectl patch application core-pipeline-prod -n argocd \
  --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

echo ""
echo "============================================"
echo "Checking Status"
echo "============================================"
kubectl get applications -n argocd | grep core-pipeline
echo ""
echo "To check sync status:"
echo "kubectl describe application core-pipeline-dev -n argocd | grep -A5 Status:"