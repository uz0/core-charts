# Helmfile Guide

Complete guide to using Helmfile for managing Kubernetes deployments in this repository.

## Table of Contents

- [What is Helmfile?](#what-is-helmfile)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Environment Management](#environment-management)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)
- [Best Practices](#best-practices)

---

## What is Helmfile?

**Helmfile** is a declarative spec for deploying Helm charts. It allows you to:

- **Declare** multiple Helm releases in a single YAML file
- **Version control** your entire deployment configuration
- **Manage environments** (local, staging, production) with different values
- **Control dependencies** between releases
- **Deploy everything** with a single command

**Why we use it:**
- ✅ No bash scripts needed
- ✅ Declarative infrastructure as code
- ✅ Environment-specific configurations
- ✅ Dependency management between services
- ✅ GitOps ready

---

## Installation

### Windows (Git Bash / MSYS2)

```bash
# Download latest version
cd /tmp
curl -L "https://github.com/helmfile/helmfile/releases/download/v1.1.8/helmfile_1.1.8_windows_amd64.tar.gz" -o helmfile.tar.gz
tar -xzf helmfile.tar.gz

# Install to local bin
mkdir -p ~/.local/bin
mv helmfile.exe ~/.local/bin/
chmod +x ~/.local/bin/helmfile.exe

# Verify installation
helmfile.exe version
```

### Linux

```bash
# Download latest version
wget https://github.com/helmfile/helmfile/releases/download/v1.1.8/helmfile_1.1.8_linux_amd64.tar.gz
tar -xzf helmfile_1.1.8_linux_amd64.tar.gz

# Install
sudo mv helmfile /usr/local/bin/
chmod +x /usr/local/bin/helmfile

# Verify
helmfile version
```

### macOS

```bash
# Using Homebrew
brew install helmfile

# Or download binary
curl -L "https://github.com/helmfile/helmfile/releases/download/v1.1.8/helmfile_1.1.8_darwin_amd64.tar.gz" -o helmfile.tar.gz
tar -xzf helmfile.tar.gz
sudo mv helmfile /usr/local/bin/
```

---

## Configuration

### helmfile.yaml Structure

Our `helmfile.yaml` is organized into layers:

```yaml
repositories:           # Helm chart repositories
environments:           # Environment definitions (local/production)
helmDefaults:          # Default settings for all releases
releases:              # List of Helm releases to manage
  # Layer 0: Core Platform (ingress, cert-manager)
  # Layer 1: Databases & Storage (PostgreSQL, Redis)
  # Layer 2: Observability (Prometheus, Grafana, Loki)
  # Layer 3: Authentication (Authentik)
  # Application Layer: Your applications
```

### Key Sections Explained

#### 1. Repositories

```yaml
repositories:
  - name: bitnami
    url: https://charts.bitnami.com/bitnami
  - name: authentik
    url: https://charts.goauthentik.io
```

**Purpose:** Define Helm chart repositories to pull charts from.

#### 2. Environments

```yaml
environments:
  local:
    values:
      - environments/local/values.yaml
  production:
    values:
      - environments/production/values.yaml
```

**Purpose:** Define different deployment environments with their own configurations.

#### 3. Helm Defaults

```yaml
helmDefaults:
  createNamespace: true    # Auto-create namespaces
  wait: true              # Wait for resources to be ready
  timeout: 600            # 10 minute timeout
  atomic: true            # Rollback on failure
```

**Purpose:** Set common defaults for all Helm operations.

#### 4. Releases

```yaml
releases:
  - name: postgresql
    namespace: infrastructure
    chart: bitnami/postgresql
    version: 16.2.7
    condition: postgresql.enabled
    values:
      - environments/{{ .Environment.Name }}/postgresql-values.yaml
    labels:
      layer: infrastructure
      component: database
```

**Components:**
- **name:** Release name in Kubernetes
- **namespace:** Kubernetes namespace
- **chart:** Chart reference (repo/chart or ./local/path)
- **version:** Chart version (for remote charts)
- **condition:** Enable/disable via environment values
- **needs:** Dependencies (deploy after these)
- **values:** Values files to use
- **labels:** Organize releases

---

## Usage

### Basic Commands

#### List All Releases

```bash
helmfile.exe -e local list
```

Shows all releases, their status, and whether they're enabled.

**Output example:**
```
NAME            NAMESPACE       ENABLED  INSTALLED
ingress-nginx   ingress-nginx   true     true
postgresql      infrastructure  true     true
authentik       authentik       true     true
```

#### Deploy Everything

```bash
# Sync all enabled releases
helmfile.exe -e local sync

# Apply with confirmation (shows diff)
helmfile.exe -e local apply

# Skip dependency updates
helmfile.exe -e local sync --skip-deps
```

**`sync` vs `apply`:**
- **sync:** Deploy immediately, no confirmation
- **apply:** Show changes first, ask for confirmation

#### Deploy Specific Release

```bash
# Deploy only PostgreSQL
helmfile.exe -e local -l name=postgresql sync

# Deploy only infrastructure layer
helmfile.exe -e local -l layer=infrastructure sync

# Deploy by namespace
helmfile.exe -e local -l namespace=authentik sync
```

#### Check Status

```bash
# Status of all releases
helmfile.exe -e local status

# Test releases (runs Helm tests)
helmfile.exe -e local test
```

#### Delete Releases

```bash
# Delete all releases
helmfile.exe -e local destroy

# Delete specific release
helmfile.exe -e local -l name=postgresql destroy

# Delete with confirmation
helmfile.exe -e local delete
```

---

## Environment Management

### Local Environment

**File:** `environments/local/values.yaml`

```yaml
# Toggles for services
postgresql:
  enabled: true

authentik:
  enabled: true

monitoring:
  enabled: false  # Disabled to save resources

# Global settings
storageClass: "microk8s-hostpath"
```

**Service-specific values:**
- `environments/local/postgresql-values.yaml`
- `environments/local/redis-values.yaml`
- `environments/local/authentik-values.yaml`
- etc.

### Production Environment

**File:** `environments/production/values.yaml`

```yaml
# Production toggles
postgresql:
  enabled: true

monitoring:
  enabled: true  # Enable full monitoring

# Production settings
storageClass: "ssd-storage"
certManager:
  enabled: true
  issuer: letsencrypt-prod
```

> **Note:** Create the PostgreSQL admin secret ahead of time as described in [docs/postgresql-secret.md](docs/postgresql-secret.md).

### Switching Environments

```bash
# Deploy to local
helmfile.exe -e local sync

# Deploy to production
helmfile.exe -e production sync

# List what would change in production
helmfile.exe -e production apply
```

---

## Common Tasks

### 1. Initial Deployment

```bash
# Set your kubeconfig
export KUBECONFIG="/path/to/kubeconfig"

# Navigate to repository
cd /path/to/core-charts

# Deploy everything to local environment
helmfile.exe -e local sync
```

### 2. Update a Service Configuration

```bash
# Edit the values file
nano environments/local/authentik-values.yaml

# Apply changes
helmfile.exe -e local -l name=authentik apply

# Or use sync for immediate deployment
helmfile.exe -e local -l name=authentik sync
```

### 3. Add a New Service

1. **Add repository** (if needed) to `helmfile.yaml`:
   ```yaml
   repositories:
     - name: my-repo
       url: https://charts.example.com
   ```

2. **Add release** to `helmfile.yaml`:
   ```yaml
   releases:
     - name: my-service
       namespace: my-namespace
       chart: my-repo/my-chart
       version: 1.0.0
       condition: myService.enabled
       values:
         - environments/{{ .Environment.Name }}/my-service-values.yaml
   ```

3. **Create values files:**
   ```bash
   # Create environment-specific values
   touch environments/local/my-service-values.yaml
   touch environments/production/my-service-values.yaml
   ```

4. **Enable in environment:**
   ```yaml
   # environments/local/values.yaml
   myService:
     enabled: true
   ```

5. **Deploy:**
   ```bash
   helmfile.exe -e local sync
   ```

### 4. Upgrade a Chart Version

```bash
# Edit helmfile.yaml, change version number
# For example: version: 16.2.7 → version: 16.3.0

# Apply the upgrade
helmfile.exe -e local -l name=postgresql apply
```

### 5. Rollback a Release

```bash
# List release history
helm history postgresql -n infrastructure

# Rollback using helm directly
helm rollback postgresql 1 -n infrastructure

# Or redeploy with helmfile
helmfile.exe -e local -l name=postgresql sync
```

### 6. Enable/Disable a Service

```bash
# Edit environment values
nano environments/local/values.yaml

# Change enabled flag
monitoring:
  enabled: false  # was true

# Apply changes (will destroy disabled releases)
helmfile.exe -e local sync
```

---

## Troubleshooting

### Helmfile Not Found

**Error:** `bash: helmfile: command not found`

**Solution:**
```bash
# Windows: Use .exe extension
helmfile.exe -e local list

# Linux/Mac: Check installation
which helmfile
echo $PATH

# Add to PATH if needed
export PATH="$HOME/.local/bin:$PATH"
```

### Chart Not Found

**Error:** `chart "bitnami/postgresql" not found`

**Solution:**
```bash
# Update Helm repositories
helm repo update

# Or let helmfile do it
helmfile.exe -e local sync
```

### Release Already Exists

**Error:** `release already exists`

**Solution:**
```bash
# Helmfile should handle this automatically
# If it doesn't, use --skip-deps
helmfile.exe -e local sync --skip-deps

# Or delete and recreate
helmfile.exe -e local -l name=my-release destroy
helmfile.exe -e local -l name=my-release sync
```

### Values File Not Found

**Error:** `values file matching "..." does not exist`

**Solution:**
```bash
# Check if values file exists
ls environments/local/

# Create missing values file
touch environments/local/missing-values.yaml

# Verify helmfile configuration
helmfile.exe -e local list
```

### Dependency Issues

**Error:** `needs ingress-nginx, but ingress-nginx is not installed`

**Solution:**
```bash
# Deploy dependencies first
helmfile.exe -e local -l name=ingress-nginx sync

# Then deploy dependent service
helmfile.exe -e local -l name=my-service sync

# Or remove 'needs' from helmfile.yaml temporarily
```

### Timeout Errors

**Error:** `context deadline exceeded`

**Solution:**
```bash
# Increase timeout in helmfile.yaml
helmDefaults:
  timeout: 1200  # 20 minutes

# Or check pod status
kubectl get pods -A

# Check specific pod logs
kubectl logs -n namespace pod-name
```

---

## Best Practices

### 1. Use Labels for Organization

```yaml
releases:
  - name: postgresql
    labels:
      layer: infrastructure
      component: database
      criticality: high
```

**Deploy by label:**
```bash
helmfile.exe -e local -l layer=infrastructure sync
```

### 2. Manage Dependencies

```yaml
releases:
  - name: authentik
    needs:
      - infrastructure/postgresql  # namespace/release
      - infrastructure/redis
```

**Benefits:**
- Ensures correct deployment order
- Prevents dependency errors

### 3. Use Conditions for Toggles

```yaml
# In helmfile.yaml
condition: monitoring.enabled

# In environments/local/values.yaml
monitoring:
  enabled: false  # Disable in local

# In environments/production/values.yaml
monitoring:
  enabled: true   # Enable in production
```

### 4. Version Everything

```yaml
releases:
  - name: postgresql
    chart: bitnami/postgresql
    version: 16.2.7  # Pin specific version
```

**Benefits:**
- Reproducible deployments
- Controlled upgrades

### 5. Separate Values by Environment

```
environments/
├── local/
│   ├── values.yaml              # Global toggles
│   ├── postgresql-values.yaml   # Service-specific
│   └── authentik-values.yaml
└── production/
    ├── values.yaml
    ├── postgresql-values.yaml
    └── authentik-values.yaml
```

### 6. Use .gitignore for Secrets

```bash
# In .gitignore
environments/*/secrets/
environments/*/*.secrets.yaml
*.secret.yaml
```

**Store secrets securely:**
- Use external-secrets operator
- Use sealed-secrets
- Use cloud provider secret managers

### 7. Test Before Production

```bash
# Always test in local first
helmfile.exe -e local sync

# Verify everything works
kubectl get pods -A

# Then deploy to production
helmfile.exe -e production apply
```

---

## Advanced Usage

### Selective Sync

```bash
# Deploy only specific layers
helmfile.exe -e local -l layer=infrastructure sync
helmfile.exe -e local -l layer=application sync

# Deploy by component
helmfile.exe -e local -l component=database sync

# Multiple filters
helmfile.exe -e local -l layer=infrastructure,component=cache sync
```

### Template Functions

Helmfile supports Go template functions:

```yaml
values:
  - environments/{{ .Environment.Name }}/values.yaml
  - environments/{{ .Environment.Name }}/{{ .Release.Name }}-values.yaml
```

**Available variables:**
- `{{ .Environment.Name }}` - Environment name (local/production)
- `{{ .Release.Name }}` - Release name
- `{{ .Release.Namespace }}` - Namespace

### Hooks

Execute commands before/after deployment:

```yaml
releases:
  - name: postgresql
    hooks:
      - events: ["presync"]
        command: "echo"
        args: ["Deploying PostgreSQL..."]
      - events: ["postsync"]
        command: "kubectl"
        args: ["get", "pods", "-n", "infrastructure"]
```

---

## Quick Reference

### Common Commands

| Command | Description |
|---------|-------------|
| `helmfile.exe -e local list` | List all releases |
| `helmfile.exe -e local sync` | Deploy all enabled releases |
| `helmfile.exe -e local apply` | Deploy with confirmation |
| `helmfile.exe -e local destroy` | Delete all releases |
| `helmfile.exe -e local status` | Show release status |
| `helmfile.exe -e local test` | Run Helm tests |
| `helmfile.exe -e local -l name=X sync` | Deploy specific release |
| `helmfile.exe -e local -l layer=Y sync` | Deploy by label |

### File Locations

| File | Purpose |
|------|---------|
| `helmfile.yaml` | Main configuration |
| `environments/local/values.yaml` | Local environment toggles |
| `environments/local/*-values.yaml` | Service-specific values |
| `charts/*/` | Local Helm charts |

### Environment Variables

```bash
# Set kubeconfig
export KUBECONFIG="/path/to/kubeconfig"

# Set environment inline
HELMFILE_ENVIRONMENT=local helmfile sync
```

---

## Getting Help

```bash
# Show helmfile help
helmfile.exe --help

# Show command-specific help
helmfile.exe sync --help

# Show version
helmfile.exe version
```

**Resources:**
- [Helmfile Documentation](https://helmfile.readthedocs.io/)
- [Helmfile GitHub](https://github.com/helmfile/helmfile)
- [Helm Documentation](https://helm.sh/docs/)

---

## Summary

Helmfile provides a **declarative**, **version-controlled** way to manage multiple Helm releases across different environments. Key benefits:

✅ **No bash scripts** - Pure declarative YAML
✅ **Environment separation** - Different configs for local/prod
✅ **Dependency management** - Control deployment order
✅ **GitOps ready** - Everything in version control
✅ **Single command deployment** - Deploy everything with one command

Start with: `helmfile.exe -e local sync`
