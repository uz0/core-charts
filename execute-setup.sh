#!/bin/bash
# Clean deployment script - run this ON THE SERVER
# NO CREDENTIALS STORED HERE

echo "======================================"
echo "Core Pipeline Deployment"
echo "======================================"

# Apply the Kubernetes manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Remove broken ArgoCD applications
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Create new ArgoCD applications
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/argocd/applications.yaml

# Check status
echo ""
echo "=== Development Environment ==="
kubectl get all -n dev-core

echo ""
echo "=== Production Environment ==="
kubectl get all -n prod-core

echo ""
echo "=== ArgoCD Applications ==="
kubectl get applications -n argocd | grep core-pipeline

echo ""
echo "Done! Check ArgoCD UI for sync status."