# ArgoCD Auto-Sync Setup Guide

This repository includes a GitHub Actions workflow that automatically syncs ArgoCD applications to your Kubernetes cluster when changes are merged to the main branch.

## Required GitHub Secrets

You need to configure the following secrets in your GitHub repository settings (Settings → Secrets and variables → Actions):

### 1. KUBE_CONFIG_DATA (Required)
Your base64-encoded kubeconfig file:

```bash
# Get your kubeconfig and encode it:
cat ~/.kube/config | base64 -w 0 > kubeconfig-base64.txt
```

Copy the contents of `kubeconfig-base64.txt` and add it as the `KUBE_CONFIG_DATA` secret.

### 2. ARGOCD_SERVER (Optional)
ArgoCD server address (e.g., `argocd.example.com:443`)

### 3. ARGOCD_AUTH_TOKEN (Optional)
ArgoCD authentication token for CLI access:

```bash
# Generate token from ArgoCD:
argocd account generate-token --account <service-account-name>
```

## How It Works

1. **Triggers on**: Push to `main` branch when ArgoCD files change
2. **Automatically applies**: All ArgoCD application manifests to your cluster
3. **Verifies**: Applications are created and checks their sync status
4. **Optional**: Triggers immediate sync using ArgoCD CLI (if tokens configured)

## Manual Sync

If you prefer to sync manually on your server instead of using GitHub Actions:

```bash
# Apply all ArgoCD applications
kubectl apply -f argocd/applications.yaml

# Or apply individual apps
kubectl apply -f argocd-apps/core-pipeline-dev.yaml
kubectl apply -f argocd-apps/core-pipeline-prod.yaml
```

## Disabling Auto-Sync

To disable the GitHub Actions workflow, either:
1. Delete `.github/workflows/sync-argocd.yml`
2. Or comment out the workflow triggers

## Security Notes

- Keep your `KUBE_CONFIG_DATA` secret secure
- Use a service account with minimal required permissions
- Consider using OIDC authentication for production environments