# Modern Kubernetes Infrastructure

**Production-ready, cloud-native infrastructure using modern declarative tooling**

🎯 **Philosophy**: No bash scripts, only declarative configurations
🛠️ **Tools**: Helmfile + Helm 3 + Kustomize
🚀 **GitOps Ready**: Works with ArgoCD or FluxCD
☁️ **Cloud Agnostic**: Deploy anywhere (MicroK8s, AWS, GKE, Hetzner, etc.)

---

## 🏗️ Architecture

### Infrastructure Stack

- **Orchestration**: Kubernetes (K8s, K3s, MicroK8s compatible)
- **Deployment**: Helmfile for declarative multi-chart management
- **Database**: PostgreSQL (shared, multi-tenant)
- **Cache**: Redis (shared)
- **Messaging**: Kafka (via Strimzi operator)
- **Storage**: MinIO (S3-compatible)
- **Monitoring**: Prometheus + Grafana + Loki
- **Auth**: Authentik SSO (Google OAuth)
- **Ingress**: NGINX Ingress Controller
- **Certificates**: cert-manager (Let's Encrypt)

### Applications

1. **core-pipeline** - NestJS API (prod + dev environments)
2. **dcmaidbot** - Telegram bot with AI capabilities

---

## 🚀 Quick Start

### Prerequisites

Install required tools:

```bash
# Helm 3
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Helmfile
# On Linux:
wget https://github.com/helmfile/helmfile/releases/download/v0.169.0/helmfile_0.169.0_linux_amd64.tar.gz
tar -xzf helmfile_*.tar.gz
sudo mv helmfile /usr/local/bin/

# On macOS:
brew install helmfile

# On Windows:
# Download from: https://github.com/helmfile/helmfile/releases

# kubectl (if not already installed)
# Follow: https://kubernetes.io/docs/tasks/tools/
```

Verify installation:

```bash
make check-tools
```

### Local Development (MicroK8s)

**1. Setup MicroK8s cluster:**

```bash
# Install MicroK8s (Ubuntu/Debian)
sudo snap install microk8s --classic

# Add your user to microk8s group
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Setup cluster with required addons
make local-setup
```

**2. Configure secrets:**

```bash
# Generate secrets template
make secrets-template

# Edit secrets (use strong passwords!)
nano environments/local/secrets/values.yaml
```

Example `environments/local/secrets/values.yaml`:

```yaml
postgresql:
  password: "MySecurePostgresPassword123!"
  databases:
    - name: core_dev
      password: "CoreDevPassword123!"
    - name: core_prod
      password: "CoreProdPassword123!"
    - name: authentik
      password: "AuthentikPassword123!"
    - name: dcmaidbot
      password: "DcmaidbotPassword123!"

redis:
  password: "MySecureRedisPassword123!"

monitoring:
  grafana:
    adminPassword: "GrafanaAdmin123!"
```

**3. Deploy:**

```bash
# Full installation
make install

# Or step by step:
make deps-update   # Update Helm dependencies
make local-deploy  # Deploy all services
```

**4. Access services:**

```bash
# Get LoadBalancer IP (from MetalLB)
kubectl get svc -n ingress-nginx

# Add to /etc/hosts:
192.168.100.10  auth.local.test
192.168.100.10  api.local.test
192.168.100.10  api-dev.local.test
192.168.100.10  grafana.local.test
```

Open in browser:
- Authentik SSO: http://auth.local.test
- Core Pipeline (prod): http://api.local.test
- Core Pipeline (dev): http://api-dev.local.test

---

## 📦 Production Deployment

### Cloud Provider Setup

**1. Prepare your Kubernetes cluster:**

Choose your provider:

<details>
<summary><b>Hetzner Cloud</b></summary>

```bash
# Install hcloud CLI
brew install hcloud  # macOS
# or: snap install hcloud  # Linux

# Create cluster
hcloud context create my-project
hcloud server create --type cx21 --image ubuntu-22.04 --name k8s-master

# Install K3s
ssh root@<server-ip>
curl -sfL https://get.k3s.io | sh -

# Get kubeconfig
scp root@<server-ip>:/etc/rancher/k3s/k3s.yaml ~/.kube/config
# Edit ~/.kube/config and replace 127.0.0.1 with server IP
```

</details>

<details>
<summary><b>AWS EKS</b></summary>

```bash
# Install eksctl
brew install eksctl  # macOS

# Create cluster
eksctl create cluster \
  --name my-cluster \
  --region us-east-1 \
  --nodes 3 \
  --node-type t3.medium

# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name my-cluster
```

</details>

<details>
<summary><b>Google GKE</b></summary>

```bash
# Install gcloud
# Follow: https://cloud.google.com/sdk/docs/install

# Create cluster
gcloud container clusters create my-cluster \
  --zone us-central1-a \
  --num-nodes 3 \
  --machine-type n1-standard-2

# Configure kubectl
gcloud container clusters get-credentials my-cluster --zone us-central1-a
```

</details>

**2. Configure production secrets:**

```bash
# Copy secrets template
cp environments/production/values.yaml environments/production/secrets/values.yaml

# Edit with production credentials
nano environments/production/secrets/values.yaml
```

**IMPORTANT**: Use external secrets management in production:
- [Sealed Secrets](https://sealed-secrets.netlify.app/)
- [External Secrets Operator](https://external-secrets.io/)
- Cloud provider secrets (AWS Secrets Manager, GCP Secret Manager, etc.)

**3. Update domain configuration:**

Edit `environments/production/values.yaml`:

```yaml
# Change theedgestory.org to your domain
applications:
  corePipeline:
    prod:
      domain: api.yourdomain.com
    dev:
      domain: api-dev.yourdomain.com

authentik:
  domain: auth.yourdomain.com
```

**4. Deploy to production:**

```bash
# Preview changes
make prod-diff

# Deploy
make prod-deploy

# Or with approval:
helmfile -e production apply
```

---

## 🔧 Daily Operations

### Deployment Commands

```bash
# Local development
make local-deploy          # Full deployment
make local-apply           # Apply changes with diff
make local-status          # Check status
make diff                  # Show what will change

# Production
make prod-diff             # Preview changes
make prod-apply            # Apply changes
make prod-status           # Check status

# Utilities
make validate              # Validate Helm charts
make template              # Render templates
make logs NS=namespace POD=podname    # View logs
make shell NS=namespace POD=podname   # Get shell
```

### Update Application Version

No bash scripts needed! Just update the values file:

```bash
# Edit environment-specific values
nano environments/production/core-pipeline-prod-values.yaml

# Add/update:
image:
  tag: "v1.2.3"

# Deploy
make prod-apply
```

### Database Operations

Connect to PostgreSQL:

```bash
# Get pod name
kubectl get pods -n infrastructure

# Connect to PostgreSQL
kubectl exec -it -n infrastructure postgresql-0 -- psql -U postgres

# Or use make command
make shell NS=infrastructure POD=postgresql-0
```

### View Monitoring

```bash
# Port-forward Grafana (if no ingress)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Open: http://localhost:3000
# Default user: admin
# Password: from secrets/values.yaml
```

---

## 📁 Repository Structure

```
core-charts/
├── helmfile.yaml                    # Main deployment configuration
├── Makefile                         # Modern deployment commands
├── environments/
│   ├── local/
│   │   ├── values.yaml              # Local environment config
│   │   └── secrets/values.yaml      # Local secrets (gitignored)
│   └── production/
│       ├── values.yaml              # Production environment config
│       └── secrets/values.yaml      # Production secrets (gitignored)
├── charts/
│   ├── postgresql-init/             # Database initialization (replaces init.sql)
│   ├── authentik/                   # SSO provider
│   ├── core-pipeline/               # NestJS API
│   ├── dcmaidbot/                   # Telegram bot
│   └── infrastructure/              # Shared services (PostgreSQL, Redis, etc.)
├── argocd-apps/                     # GitOps Application definitions (optional)
└── docs/                            # Documentation
```

---

## 🔐 Secrets Management

### Local Development

Secrets are stored in gitignored files:

```bash
environments/local/secrets/values.yaml      # Local secrets
environments/production/secrets/values.yaml # Production secrets (NEVER COMMIT!)
```

### Production (Recommended)

Use **External Secrets Operator**:

1. Install operator:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

2. Configure secret store (example for AWS):

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
```

3. Create ExternalSecret:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: postgresql-credentials
spec:
  secretStoreRef:
    name: aws-secrets-manager
  target:
    name: postgresql-secret
  data:
    - secretKey: password
      remoteRef:
        key: prod/postgresql/password
```

---

## 🎯 GitOps with ArgoCD

Enable GitOps for production:

```yaml
# environments/production/values.yaml
argocd:
  enabled: true
```

Deploy:

```bash
make prod-deploy
```

ArgoCD will monitor the Git repository and automatically sync changes.

---

## 🆘 Troubleshooting

### Check Overall Status

```bash
make status
```

### View Pod Logs

```bash
# List pods
kubectl get pods -A

# View logs
make logs NS=authentik POD=authentik-server-xxx
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n infrastructure

# Check if PostgreSQL is ready
kubectl exec -n infrastructure postgresql-0 -- pg_isready

# View PostgreSQL logs
kubectl logs -n infrastructure postgresql-0
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress resources
kubectl get ingress -A

# Check LoadBalancer IP (MetalLB)
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

## 📚 Learn More

- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

---

## 🚀 Migration from Old Setup

If you're migrating from the bash script setup:

**What's changed:**
- ✅ **Replaced**: All bash scripts → Helmfile + Makefile
- ✅ **Extracted**: `init.sql` from values → Kubernetes Job
- ✅ **Removed**: Hardcoded IPs → Service discovery
- ✅ **Added**: Environment-specific configurations
- ✅ **Improved**: Secrets management (gitignored files)

**How to migrate:**

1. Backup existing data:
```bash
# Backup PostgreSQL
kubectl exec -n infrastructure postgresql-0 -- pg_dumpall -U postgres > backup.sql

# Backup Redis (if needed)
kubectl exec -n infrastructure redis-master-0 -- redis-cli --rdb dump.rdb
```

2. Deploy new setup:
```bash
make install
```

3. Restore data if needed:
```bash
kubectl exec -i -n infrastructure postgresql-0 -- psql -U postgres < backup.sql
```

---

**Ready to deploy? Start with:** `make install`
