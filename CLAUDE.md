# CLAUDE.md

Instructions for Claude Code when working with this repository.

## 🚨 CRITICAL RULES

### File Management
- ✅ **ALLOWED**: Only `CLAUDE.md` and `README.md` in root
- ❌ **FORBIDDEN**: Any other documentation files in root (use docs/ if needed)
- ✅ **Charts**: Only in `charts/` directory
- ✅ **Config**: Only in `environments/` directory

### Production Standards
1. **No bash scripts** - Use Helm/Helmfile only
2. **No hardcoded secrets** - Use environment-specific values files
3. **Service discovery** - No hardcoded IPs, use Kubernetes DNS
4. **Modern tooling** - Helm 3, Helmfile, Kustomize
5. **GitOps ready** - Declarative configurations

## Current State

### ✅ Modern Kubernetes Infrastructure

**Deployment Method:**
- Pure Helm 3 deployments
- Environment-specific values (local/production)
- No bash scripts or custom tooling needed

**Infrastructure:**
- **MicroK8s**: Local development cluster
- **PostgreSQL**: Shared database (Bitnami chart)
- **Redis**: Shared cache (Bitnami chart)
- **Authentik**: SSO authentication (Official chart)
- **Ingress-NGINX**: Traffic routing
- **MetalLB**: LoadBalancer support

**Cluster Info:**
- **Server**: `kubectl config view -o jsonpath='{.clusters[0].cluster.server}'`
- **LoadBalancer IP**: `kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- **Storage Class**: microk8s-hostpath

## Key Information

### Access
- **Authentik**: [http://auth.local.test](http://auth.local.test)
- **Admin User**: `akadmin`
- **Access Method**: Recovery key (see ACCESS.md)

### Databases Created
All databases initialized via postgresql-init Job:
- `core_dev` - User: `core_dev_user`
- `core_prod` - User: `core_prod_user`
- `authentik` - User: `authentik_user`
- `dcmaidbot` - User: `dcmaidbot_user`

Passwords are in `environments/local/*.values.yaml`

### Repository Structure

```
core-charts/
├── environments/
│   ├── local/              # Local/MicroK8s configuration
│   │   ├── values.yaml
│   │   ├── authentik-values.yaml
│   │   ├── postgresql-values.yaml
│   │   ├── postgresql-init-values.yaml
│   │   ├── redis-values.yaml
│   │   └── ingress-values.yaml
│   └── production/         # Production configuration
│       └── [same structure]
├── charts/
│   ├── postgresql-init/    # DB initialization Job
│   ├── core-pipeline/      # Application chart
│   └── dcmaidbot/          # Bot application
├── helmfile.yaml           # Declarative multi-chart deployment
├── CLAUDE.md              # This file
├── README.md              # Brief overview
└── docs/                  # All documentation
    ├── README.md          # Complete guide
    ├── HELMFILE.md        # Helmfile usage guide
    ├── ACCESS.md          # Access credentials
    └── STRUCTURE.md       # Repository structure

**OLD REMOVED:**
- ❌ scripts/ - All bash scripts removed
- ❌ argocd-apps/ - Not needed for direct deployment
- ❌ config/ - Moved to environments/
- ❌ k8s/ - Raw manifests not needed
- ❌ Makefile - Use helmfile instead
```

## Common Tasks

See [docs/HELMFILE.md](docs/HELMFILE.md) for complete Helmfile guide.

### Deploy Everything (Local)
```bash
# Deploy all services (one command)
helmfile.exe -e local sync

# Or deploy only enabled services (interactive, shows changes)
helmfile.exe -e local apply

# List all releases and their status
helmfile.exe -e local list

# Deploy specific layer
helmfile.exe -e local -l layer=infrastructure sync
helmfile.exe -e local -l layer=application sync
```

### Check Status
```bash
# All pods
kubectl get pods -A

# Specific service
kubectl get pods -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1)
kubectl logs -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1)

# Ingress
kubectl get ingress -A
```

### Update a Service
```bash
# Edit values
nano environments/local/authentik-values.yaml

# Apply changes
helmfile.exe -e local apply

# Or update specific service only
helm upgrade authentik authentik/authentik \
  --namespace authentik \
  --values environments/local/authentik-values.yaml
```

### Access Authentik
```bash
# Generate recovery key
kubectl exec -it -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1) -- \
  ak create_recovery_key 10 akadmin

# Output will be: /recovery/use-token/***********/
# Full URL: http://auth.local.test/recovery/use-token/***********/
```

## Deployment Principles

### ✅ DO
- Use official Helm charts when available
- Store configuration in environment-specific values files
- Use Kubernetes DNS for service discovery
- Keep secrets in gitignored files or use external-secrets
- Document everything in Markdown

### ❌ DON'T
- Write bash scripts for deployment
- Hardcode IPs or passwords
- Put secrets in Git
- Create custom chart wrappers unnecessarily
- Mix production and local configs

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod -n <namespace> $(kubectl get pod -n <namespace> -l app.kubernetes.io/name=<pod-name> -o name | head -1)
```

### Database Connection Issues
```bash
# Test PostgreSQL
kubectl exec -it -n infrastructure $(kubectl get pod -n infrastructure -l app.kubernetes.io/name=postgresql-postgresql -o name | head -1) -- psql -U postgres

# Check init job logs
kubectl logs -n infrastructure $(kubectl get job -n infrastructure -l app.kubernetes.io/name=postgresql-init -o name | head -1)
```

### Authentik Login Issues
```bash
# Create recovery key
kubectl exec -it -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1) -- ak create_recovery_key 10 akadmin
```

## Migration Notes

**What Changed:**
- ✅ Removed 16 bash scripts → Pure Helm deployment
- ✅ Removed hardcoded IPs → Kubernetes DNS
- ✅ Removed init.sql from values → Proper Job chart
- ✅ Removed custom Authentik wrapper → Official chart
- ✅ Added environment separation → local/production

**Benefits:**
- Simpler deployment (just Helm commands)
- Better separation of concerns
- Production-ready from day one
- No custom tooling to maintain
- Easier to understand and debug

## Important Notes

- **No ArgoCD**: Direct Helm deployment (can add later if needed)
- **LoadBalancer**: MetalLB provides IPs on local cluster
- **Storage**: MicroK8s hostpath-storage (microk8s-hostpath) for local development
- **DNS**: Add hosts file entries for *.local.test domains

## Future Additions

When ready to add more features:

1. **ArgoCD**: GitOps automation
2. **External Secrets**: Better secrets management
3. **Monitoring**: Prometheus + Grafana
4. **Backups**: Velero for cluster backups
5. **CI/CD**: GitHub Actions for automated deployments

## Success Criteria

✅ All pods running and healthy
✅ Databases initialized with proper users
✅ Authentik accessible via browser
✅ No bash scripts in repository
✅ No hardcoded secrets or IPs
✅ Clean, modern Helm-based deployment
