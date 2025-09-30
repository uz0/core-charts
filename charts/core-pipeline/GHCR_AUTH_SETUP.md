# GitHub Container Registry Authentication Setup

## Problem
The core-pipeline deployment is failing with `ImagePullBackOff` error when trying to pull images from GitHub Container Registry (ghcr.io).

## Solution
Configure image pull secrets for authenticating with GHCR.

## Steps to Configure

### 1. Create a GitHub Personal Access Token (PAT)
1. Go to GitHub Settings → Developer settings → Personal access tokens
2. Generate a new token with `read:packages` scope
3. Save the token securely

### 2. Deploy with Authentication

#### Option A: Using Helm values during deployment
```bash
helm upgrade --install core-pipeline ./charts/core-pipeline \
  -f values.yaml \
  -f values-dev.yaml \
  -f dev.tag.yaml \
  --set ghcrCredentials.password="YOUR_GITHUB_PAT_TOKEN" \
  -n dev-core
```

#### Option B: Create the secret manually
```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password=YOUR_GITHUB_PAT_TOKEN \
  -n dev-core
```

#### Option C: Using Sealed Secrets (Recommended for GitOps)
```bash
# Create the secret locally
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=uz0 \
  --docker-password=YOUR_GITHUB_PAT_TOKEN \
  -n dev-core \
  --dry-run=client -o yaml > ghcr-secret.yaml

# Seal the secret
kubeseal --format yaml < ghcr-secret.yaml > ghcr-sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f ghcr-sealed-secret.yaml
```

### 3. Verify the Deployment
```bash
# Check if the secret is created
kubectl get secret ghcr-secret -n dev-core

# Check pod status
kubectl get pods -n dev-core -l app.kubernetes.io/name=core-pipeline

# Check deployment events
kubectl describe deployment core-pipeline-dev -n dev-core
```

## Configuration Changes Made

1. **values-dev.yaml**: Added `imagePullSecrets` configuration
2. **templates/imagepullsecret.yaml**: Added template for creating GHCR secret
3. **values-dev.yaml**: Added `ghcrCredentials` section for configuring credentials

## Important Notes
- Never commit PAT tokens to version control
- For production, use Sealed Secrets or external secret management solutions
- The PAT token needs at least `read:packages` scope to pull images from GHCR
- If the repository is public, authentication might not be required