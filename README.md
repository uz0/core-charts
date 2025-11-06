# Core Charts - Modern Kubernetes Infrastructure

Production-ready Kubernetes infrastructure with modern tooling.

## 🚀 Quick Start

See [docs/README.md](docs/README.md) for complete documentation.

### Deploy

```bash
export KUBECONFIG="path/to/kubeconfig"

# Add repos
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add authentik https://charts.goauthentik.io
helm repo update

# Deploy infrastructure
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --values environments/local/ingress-values.yaml --wait

helm upgrade --install postgresql bitnami/postgresql \
  --namespace infrastructure --create-namespace \
  --values environments/local/postgresql-values.yaml --wait

helm upgrade --install redis bitnami/redis \
  --namespace infrastructure \
  --values environments/local/redis-values.yaml --wait

helm upgrade --install postgresql-init ./charts/postgresql-init \
  --namespace infrastructure \
  --values environments/local/postgresql-init-values.yaml --wait

helm upgrade --install authentik authentik/authentik \
  --namespace authentik --create-namespace \
  --values environments/local/authentik-values.yaml --wait
```

Or use Helmfile:
```bash
helmfile.exe -e local sync
```

## 📁 Structure

```
core-charts/
├── environments/          # Environment configs
│   ├── local/
│   └── production/
├── charts/               # Helm charts
│   ├── postgresql-init/
│   ├── core-pipeline/
│   └── dcmaidbot/
├── docs/                 # Documentation
│   ├── README.md        # Complete guide
│   ├── HELMFILE.md      # Helmfile guide
│   ├── ACCESS.md        # Access info
│   └── STRUCTURE.md     # Repository structure
├── helmfile.yaml        # Declarative deployment
├── CLAUDE.md            # AI instructions
└── README.md            # This file
```

## 📚 Documentation

- **[Complete Guide](docs/README.md)** - Full documentation
- **[Helmfile Guide](docs/HELMFILE.md)** - How to use Helmfile
- **[Access Guide](docs/ACCESS.md)** - Credentials and access
- **[Repository Structure](docs/STRUCTURE.md)** - Directory layout
- **[CLAUDE.md](CLAUDE.md)** - AI assistant instructions

## ✅ Status

**Deployed on MicroK8s**:
- ✅ Ingress-NGINX
- ✅ PostgreSQL (4 databases)
- ✅ Redis
- ✅ Authentik SSO

## 🔧 Operations

```bash
# Check status
kubectl get pods -A

# Access Authentik
kubectl exec -it -n authentik \
  $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1) -- \
  ak create_recovery_key 10 akadmin
```

See [docs/](docs/) for detailed information.
