#!/bin/bash
# Run this on the server to deploy with swagger support

echo "======================================"
echo "Deploying Core Pipeline with Swagger"
echo "======================================"

# Delete existing deployments
kubectl delete deployment core-pipeline -n dev-core --ignore-not-found
kubectl delete deployment core-pipeline -n prod-core --ignore-not-found

# Apply updated manifests
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Wait for rollout
echo "Waiting for deployments..."
kubectl rollout status deployment/core-pipeline -n dev-core --timeout=120s
kubectl rollout status deployment/core-pipeline -n prod-core --timeout=120s

# Check status
echo ""
echo "=== Development Environment ==="
kubectl get pods,svc,ingress -n dev-core

echo ""
echo "=== Production Environment ==="
kubectl get pods,svc,ingress -n prod-core

echo ""
echo "======================================"
echo "Testing Endpoints"
echo "======================================"

# Test internal endpoints
echo "Testing dev service..."
kubectl run test-dev --image=curlimages/curl --rm -it --restart=Never -n dev-core -- curl -s http://core-pipeline:80/ | head -5

echo "Testing prod service..."
kubectl run test-prod --image=curlimages/curl --rm -it --restart=Never -n prod-core -- curl -s http://core-pipeline:80/ | head -5

echo ""
echo "======================================"
echo "Access URLs:"
echo "======================================"
echo "Dev Swagger:  https://core-pipeline.dev.theedgestory.org/swagger"
echo "Prod Swagger: https://core-pipeline.theedgestory.org/swagger"
echo ""
echo "Note: The petstore3 swagger is temporary. Real core-pipeline needs to be built."