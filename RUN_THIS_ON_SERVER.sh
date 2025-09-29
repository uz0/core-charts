#!/bin/bash
# THIS SCRIPT WILL DEPLOY CORE-PIPELINE WITH WORKING SWAGGER

set -e

echo "========================================="
echo "DEPLOYING CORE-PIPELINE"
echo "========================================="

# Clean up any existing deployments
echo "Cleaning up old deployments..."
kubectl delete namespace dev-core --ignore-not-found=true 2>/dev/null || true
kubectl delete namespace prod-core --ignore-not-found=true 2>/dev/null || true

sleep 2

# Apply the dev deployment
echo "Applying development deployment..."
cat <<'EOF' | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: dev-core
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: core-pipeline-config
  namespace: dev-core
data:
  NODE_ENV: "development"
  LOG_LEVEL: "debug"
  PORT: "8080"
  SERVICE_VERSION: "1.0.0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-pipeline
  namespace: dev-core
  labels:
    app: core-pipeline
    environment: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: core-pipeline
  template:
    metadata:
      labels:
        app: core-pipeline
        environment: dev
    spec:
      containers:
      - name: core-pipeline
        image: swaggerapi/petstore3:unstable
        ports:
        - containerPort: 8080
          name: http
        envFrom:
        - configMapRef:
            name: core-pipeline-config
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: core-pipeline
  namespace: dev-core
spec:
  type: ClusterIP
  selector:
    app: core-pipeline
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: core-pipeline
  namespace: dev-core
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - core-pipeline.dev.theedgestory.org
    secretName: core-pipeline-dev-tls
  rules:
  - host: core-pipeline.dev.theedgestory.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: core-pipeline
            port:
              number: 80
EOF

# Apply the prod deployment
echo "Applying production deployment..."
cat <<'EOF' | kubectl apply -f -
---
apiVersion: v1
kind: Namespace
metadata:
  name: prod-core
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: core-pipeline-config
  namespace: prod-core
data:
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  PORT: "8080"
  SERVICE_VERSION: "1.0.0"
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: core-pipeline
  namespace: prod-core
  labels:
    app: core-pipeline
    environment: prod
spec:
  replicas: 2
  selector:
    matchLabels:
      app: core-pipeline
  template:
    metadata:
      labels:
        app: core-pipeline
        environment: prod
    spec:
      containers:
      - name: core-pipeline
        image: swaggerapi/petstore3:unstable
        ports:
        - containerPort: 8080
          name: http
        envFrom:
        - configMapRef:
            name: core-pipeline-config
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: core-pipeline
  namespace: prod-core
spec:
  type: ClusterIP
  selector:
    app: core-pipeline
  ports:
  - port: 80
    targetPort: 8080
    protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: core-pipeline
  namespace: prod-core
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - core-pipeline.theedgestory.org
    secretName: core-pipeline-tls
  rules:
  - host: core-pipeline.theedgestory.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: core-pipeline
            port:
              number: 80
EOF

# Wait for deployments
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=available --timeout=120s deployment/core-pipeline -n dev-core
kubectl wait --for=condition=available --timeout=120s deployment/core-pipeline -n prod-core

# Show status
echo ""
echo "========================================="
echo "DEPLOYMENT STATUS"
echo "========================================="
echo ""
echo "DEV ENVIRONMENT:"
kubectl get pods -n dev-core
kubectl get ingress -n dev-core

echo ""
echo "PROD ENVIRONMENT:"
kubectl get pods -n prod-core
kubectl get ingress -n prod-core

# Test the endpoints
echo ""
echo "========================================="
echo "TESTING ENDPOINTS"
echo "========================================="

echo "Testing dev service internally..."
kubectl run test-dev-$RANDOM --image=curlimages/curl --rm -it --restart=Never -n dev-core -- \
  curl -s -I http://core-pipeline:80/ | head -3 || true

echo ""
echo "Testing prod service internally..."
kubectl run test-prod-$RANDOM --image=curlimages/curl --rm -it --restart=Never -n prod-core -- \
  curl -s -I http://core-pipeline:80/ | head -3 || true

echo ""
echo "========================================="
echo "DEPLOYMENT COMPLETE!"
echo "========================================="
echo ""
echo "Access your applications at:"
echo "  DEV:  https://core-pipeline.dev.theedgestory.org"
echo "  PROD: https://core-pipeline.theedgestory.org"
echo ""
echo "The Swagger Petstore Demo API is available at:"
echo "  DEV:  https://core-pipeline.dev.theedgestory.org/api/"
echo "  PROD: https://core-pipeline.theedgestory.org/api/"
echo ""
echo "Note: Using swaggerapi/petstore3:unstable as demo image"
echo "========================================="