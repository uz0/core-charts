#!/bin/bash

echo "=== Core Pipeline Deployment Script ==="
echo "This script will deploy core-pipeline to both dev and prod environments"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check command result
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
    else
        echo -e "${RED}✗ $1${NC}"
        exit 1
    fi
}

echo -e "${YELLOW}Step 1: Cleaning up existing deployments...${NC}"
kubectl delete namespace dev-core --ignore-not-found=true
kubectl delete namespace prod-core --ignore-not-found=true
check_result "Cleanup completed"

echo ""
echo -e "${YELLOW}Step 2: Deploying to dev environment...${NC}"
kubectl apply -f manifests/dev-core-pipeline.yaml
check_result "Dev deployment applied"

echo ""
echo -e "${YELLOW}Step 3: Deploying to production environment...${NC}"
kubectl apply -f manifests/prod-core-pipeline.yaml
check_result "Production deployment applied"

echo ""
echo -e "${YELLOW}Step 4: Waiting for deployments to be ready...${NC}"
echo "Waiting for dev deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/core-pipeline -n dev-core
check_result "Dev deployment ready"

echo "Waiting for production deployment..."
kubectl wait --for=condition=available --timeout=120s deployment/core-pipeline -n prod-core
check_result "Production deployment ready"

echo ""
echo -e "${YELLOW}Step 5: Verifying ingress setup...${NC}"
kubectl get ingress -n dev-core core-pipeline
kubectl get ingress -n prod-core core-pipeline

echo ""
echo -e "${YELLOW}Step 6: Testing endpoints...${NC}"
echo "Development environment:"
kubectl get ingress -n dev-core core-pipeline -o jsonpath='{.spec.rules[0].host}'
echo ""
echo "Production environment:"
kubectl get ingress -n prod-core core-pipeline -o jsonpath='{.spec.rules[0].host}'
echo ""

echo ""
echo -e "${GREEN}=== Deployment Complete ===${NC}"
echo ""
echo "Applications should be available at:"
echo "  Dev:  https://core-pipeline.dev.theedgestory.org/swagger"
echo "  Prod: https://core-pipeline.theedgestory.org/swagger"
echo ""
echo "Note: It may take a few minutes for DNS and certificates to propagate."