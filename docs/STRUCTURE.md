# Repository Structure

Complete overview of the clean, modern structure.

## 📁 Directory Layout

```
core-charts/
├── .git/                        # Git repository
├── .gitignore                   # Secrets protection
│
├── README.md                    # Brief overview (root)
├── CLAUDE.md                    # AI assistant instructions
│
├── docs/                        # 📚 All documentation here
│   ├── README.md                # Complete guide
│   ├── ACCESS.md                # Access credentials
│   └── STRUCTURE.md             # This file
│
├── environments/                # 🌍 Environment configs
│   ├── local/                   # Local/MicroK8s
│   │   ├── values.yaml          # Global settings
│   │   ├── authentik-values.yaml
│   │   ├── postgresql-values.yaml
│   │   ├── postgresql-init-values.yaml
│   │   ├── redis-values.yaml
│   │   ├── ingress-values.yaml
│   │   └── (more services...)
│   │
│   └── production/              # Production
│       └── (same structure)
│
├── charts/                      # 📦 Helm charts
│   ├── postgresql-init/         # DB initialization
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   └── templates/
│   │       ├── configmap.yaml
│   │       ├── job.yaml
│   │       └── _helpers.tpl
│   │
│   ├── core-pipeline/           # Application chart
│   │   ├── Chart.yaml
│   │   ├── values.yaml
│   │   ├── values.prod.yaml
│   │   ├── values.dev.yaml
│   │   └── templates/
│   │
│   ├── dcmaidbot/               # Bot chart
│   │   └── (similar structure)
│   │
│   └── infrastructure/          # Legacy (not used)
│
└── helmfile.yaml                # Declarative deployment
```

## 📝 File Descriptions

### Root Files

- **README.md** - Brief overview, quick start
- **CLAUDE.md** - Instructions for AI assistants
- **.gitignore** - Protects secrets from Git

### Documentation (docs/)

- **README.md** - Complete deployment guide
- **ACCESS.md** - Access credentials, recovery keys
- **STRUCTURE.md** - This file (repo structure)

### Environment Configs (environments/)

**Purpose**: Environment-specific values for all services

**Structure**:
- `local/` - MicroK8s, development, testing
- `production/` - Production deployment

**Files per environment**:
- `values.yaml` - Global settings (storage class, etc.)
- `authentik-values.yaml` - Authentik SSO configuration
- `postgresql-values.yaml` - PostgreSQL settings
- `postgresql-init-values.yaml` - Database initialization
- `redis-values.yaml` - Redis cache settings
- `ingress-values.yaml` - Ingress controller settings

### Charts (charts/)

**postgresql-init/**:
- Custom chart for database initialization
- Creates databases and users via Kubernetes Job
- Replaces old init.sql in values approach

**core-pipeline/**:
- Application Helm chart
- Supports dev/prod variants
- Includes deployment, service, ingress

**dcmaidbot/**:
- Telegram bot chart
- Configurable via environment values

**infrastructure/** (Legacy):
- Old approach, not used in new setup
- Kept for reference only

### Helmfile

**helmfile.yaml**:
- Declarative multi-chart deployment
- Defines all services and dependencies
- Environment-aware (local/production)
- Optional (can use Helm directly)

## 🎯 Design Principles

### Separation of Concerns

1. **Charts** (`charts/`) - Reusable templates
2. **Configs** (`environments/`) - Environment-specific values
3. **Docs** (`docs/`) - All documentation
4. **Root** - Only overview files

### Environment Isolation

- Local and production completely separated
- Different domains, passwords, resources
- Easy to add more environments (staging, etc.)

### No Scripts

- Pure declarative configuration
- Helm charts and values files only
- No bash scripts, no Makefiles
- GitOps-ready

### Secrets Management

- Secrets never committed to Git
- `.gitignore` protects `environments/*/secrets/`
- Production uses external-secrets or sealed-secrets
- Local uses plain values (acceptable for dev)

## 🔍 File Naming Conventions

### Helm Charts
- `Chart.yaml` - Chart metadata
- `values.yaml` - Default values
- `values.prod.yaml` - Production overrides
- `values.dev.yaml` - Development overrides

### Environment Values
- `<service>.values.yaml` - Service-specific config
- Pattern: Service name + `.values.yaml`
- Example: `authentik-values.yaml`, `redis-values.yaml`

### Documentation
- `README.md` - Main docs
- `UPPERCASE.md` - Special docs (ACCESS, STRUCTURE)
- Keep docs in `docs/` directory

## ✅ What's Clean

- ❌ No bash scripts
- ❌ No hardcoded IPs
- ❌ No secrets in Git
- ❌ No init.sql in values
- ❌ No custom wrappers
- ❌ No mixed configs
- ✅ Pure declarative
- ✅ Environment separation
- ✅ Service discovery
- ✅ Modern patterns
- ✅ Well documented

## 🚀 Adding New Service

1. **Create chart** (if custom):
   ```bash
   helm create charts/myservice
   ```

2. **Add environment values**:
   ```bash
   touch environments/local/myservice.values.yaml
   touch environments/production/myservice.values.yaml
   ```

3. **Configure in helmfile**:
   Add release in `helmfile.yaml`

4. **Deploy**:
   ```bash
   helm upgrade --install myservice ./charts/myservice \
     --namespace myservice \
     --values environments/local/myservice.values.yaml
   ```

## 📚 Related Docs

- [Main Guide](README.md) - Complete documentation
- [Access Guide](ACCESS.md) - Credentials and access
- [CLAUDE.md](../CLAUDE.md) - AI instructions

---

**Clean, modern, maintainable structure** ✨
