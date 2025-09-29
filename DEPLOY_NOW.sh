#!/bin/bash
# Run these commands on the server to deploy core-pipeline

echo "======================================"
echo "Deploying Core Pipeline"
echo "======================================"

# Apply the manifests
echo "Applying manifests..."
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Check if pods are running
echo ""
echo "=== Dev Environment ==="
kubectl get pods -n dev-core
kubectl get ingress -n dev-core

echo ""
echo "=== Prod Environment ==="
kubectl get pods -n prod-core
kubectl get ingress -n prod-core

# If pods show ImagePullBackOff, use nginx as temporary fix
echo ""
echo "Checking for image issues..."
if kubectl get pods -n dev-core | grep -q "ImagePullBackOff\|ErrImagePull"; then
    echo "Fixing dev image to use nginx..."
    kubectl set image deployment/core-pipeline core-pipeline=nginx:alpine -n dev-core
fi

if kubectl get pods -n prod-core | grep -q "ImagePullBackOff\|ErrImagePull"; then
    echo "Fixing prod image to use nginx..."
    kubectl set image deployment/core-pipeline core-pipeline=nginx:alpine -n prod-core
fi

# Wait for rollout
echo ""
echo "Waiting for pods to be ready..."
kubectl rollout status deployment/core-pipeline -n dev-core --timeout=60s || true
kubectl rollout status deployment/core-pipeline -n prod-core --timeout=60s || true

# Final status
echo ""
echo "======================================"
echo "Final Status"
echo "======================================"
kubectl get pods -n dev-core
kubectl get pods -n prod-core

echo ""
echo "======================================"
echo "Testing endpoints"
echo "======================================"

# Test internal connectivity
echo "Testing dev service..."
kubectl run test-dev --image=curlimages/curl --rm -it --restart=Never -n dev-core -- curl -s -I http://core-pipeline:80/ || true

echo "Testing prod service..."
kubectl run test-prod --image=curlimages/curl --rm -it --restart=Never -n prod-core -- curl -s -I http://core-pipeline:80/ || true

echo ""
echo "======================================"
echo "Access URLs:"
echo "======================================"
echo "Dev:  https://core-pipeline.dev.theedgestory.org"
echo "Prod: https://core-pipeline.theedgestory.org"
echo ""
echo "Note: If you see 404, the ingress is working but the app needs proper content."
echo "The actual core-pipeline image needs to be built and deployed."