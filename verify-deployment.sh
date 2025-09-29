#!/bin/bash

echo "=== Deployment Verification Script ==="
echo ""

# Check development environment
echo "Checking Development Environment:"
echo "---------------------------------"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://core-pipeline.dev.theedgestory.org/
curl -s -o /dev/null -w "Swagger UI Status: %{http_code}\n" https://core-pipeline.dev.theedgestory.org/swagger
echo ""

# Check production environment
echo "Checking Production Environment:"
echo "---------------------------------"
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" https://core-pipeline.theedgestory.org/
curl -s -o /dev/null -w "Swagger UI Status: %{http_code}\n" https://core-pipeline.theedgestory.org/swagger
echo ""

# If you're on the server, also check Kubernetes resources
if command -v kubectl &> /dev/null; then
    echo "Kubernetes Resources Status:"
    echo "----------------------------"
    
    echo "Development namespace (dev-core):"
    kubectl get pods -n dev-core
    kubectl get svc -n dev-core
    kubectl get ingress -n dev-core
    echo ""
    
    echo "Production namespace (prod-core):"
    kubectl get pods -n prod-core
    kubectl get svc -n prod-core
    kubectl get ingress -n prod-core
    echo ""
    
    echo "ArgoCD Applications:"
    kubectl get applications -n argocd | grep core-pipeline
fi