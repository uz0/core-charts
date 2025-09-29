#!/bin/bash
# Run this script on the server to deploy core-pipeline

echo "======================================"
echo "Deploying Core Pipeline to Dev and Prod"
echo "======================================"

# Clean up old ArgoCD applications
echo "Removing broken ArgoCD applications..."
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Deploy to dev-core
echo "Deploying to dev-core..."
kubectl apply -f - <<'EOF'
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
  PORT: "80"
  SERVICE_VERSION: "1.0.0"
  KAFKA_BROKERS: "kafka.kafka.svc.cluster.local:9092"
  POSTGRES_HOST: "postgresql.database.svc.cluster.local"
  POSTGRES_PORT: "5432"
  POSTGRES_DB: "core_pipeline_dev"
  POSTGRES_USER: "core_user"
  REDIS_HOST: "redis-master.redis.svc.cluster.local"
  REDIS_PORT: "6379"
---
apiVersion: v1
kind: Secret
metadata:
  name: core-pipeline-secrets
  namespace: dev-core
type: Opaque
stringData:
  POSTGRES_PASSWORD: "core_password_dev"
  REDIS_PASSWORD: ""
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
        image: nginx:latest
        ports:
        - containerPort: 80
          name: http
        envFrom:
        - configMapRef:
            name: core-pipeline-config
        - secretRef:
            name: core-pipeline-secrets
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: core-pipeline
  namespace: dev-core
  labels:
    app: core-pipeline
spec:
  type: ClusterIP
  selector:
    app: core-pipeline
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
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

# Deploy to prod-core
echo "Deploying to prod-core..."
kubectl apply -f - <<'EOF'
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
  PORT: "80"
  SERVICE_VERSION: "1.0.0"
  KAFKA_BROKERS: "kafka.kafka.svc.cluster.local:9092"
  POSTGRES_HOST: "postgresql.database.svc.cluster.local"
  POSTGRES_PORT: "5432"
  POSTGRES_DB: "core_pipeline"
  POSTGRES_USER: "core_user"
  REDIS_HOST: "redis-master.redis.svc.cluster.local"
  REDIS_PORT: "6379"
---
apiVersion: v1
kind: Secret
metadata:
  name: core-pipeline-secrets
  namespace: prod-core
type: Opaque
stringData:
  POSTGRES_PASSWORD: "core_password_prod"
  REDIS_PASSWORD: ""
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
        image: nginx:latest
        ports:
        - containerPort: 80
          name: http
        envFrom:
        - configMapRef:
            name: core-pipeline-config
        - secretRef:
            name: core-pipeline-secrets
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: core-pipeline
  namespace: prod-core
  labels:
    app: core-pipeline
spec:
  type: ClusterIP
  selector:
    app: core-pipeline
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: core-pipeline
  namespace: prod-core
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - core-pipeline.prod.theedgestory.org
    secretName: core-pipeline-prod-tls
  rules:
  - host: core-pipeline.prod.theedgestory.org
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: core-pipeline
            port:
              number: 80
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: core-pipeline
  namespace: prod-core
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: core-pipeline
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: core-pipeline
  namespace: prod-core
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: core-pipeline
EOF

echo "======================================"
echo "Deployment Complete!"
echo "======================================"
echo ""
echo "Checking dev-core resources:"
kubectl get all -n dev-core
echo ""
echo "Checking prod-core resources:"
kubectl get all -n prod-core
echo ""
echo "Resources deployed:"
echo "- Dev: 1 replica, ConfigMap, Secret, Service, Ingress"
echo "- Prod: 2 replicas, ConfigMap, Secret, Service, Ingress, HPA, PDB"
echo ""
echo "Access URLs:"
echo "- Dev: https://core-pipeline.dev.theedgestory.org"
echo "- Prod: https://core-pipeline.prod.theedgestory.org"