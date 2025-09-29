#!/bin/bash

# This script should be run on the server

# Apply dev manifests
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml

# Apply prod manifests
kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml

# Delete old ArgoCD applications
kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found

# Create new ArgoCD application for dev
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-pipeline-dev
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/uz0/core-charts
    targetRevision: main
    path: manifests
    directory:
      include: dev-core-pipeline.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: dev-core
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Create new ArgoCD application for prod
kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: core-pipeline-prod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/uz0/core-charts
    targetRevision: main
    path: manifests
    directory:
      include: prod-core-pipeline.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: prod-core
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF

# Check status
echo "Checking deployments..."
kubectl get all -n dev-core
kubectl get all -n prod-core
kubectl get applications -n argocd | grep core-pipeline