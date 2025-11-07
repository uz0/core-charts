#!/bin/bash
# Production Deployment Script for core-charts
# This script sets up and deploys the entire infrastructure on production server

set -e

echo "🚀 Starting Production Deployment for core-charts"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root"
   exit 1
fi

# Update system
print_status "Updating system packages..."
apt-get update && apt-get upgrade -y

# Install required dependencies
print_status "Installing dependencies..."

# Install basic tools
apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gpg \
    git \
    htop \
    unzip

# Install Docker
print_status "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
    usermod -aG docker root
    rm get-docker.sh
else
    print_warning "Docker already installed"
fi

# Install Kubernetes (k3s for production)
print_status "Installing k3s Kubernetes..."
if ! command -v kubectl &> /dev/null; then
    curl -sfL https://get.k3s.io | sh -s - --disable traefik --write-kubeconfig-mode 644
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
else
    print_warning "k3s already installed"
fi

# Wait for k3s to be ready
print_status "Waiting for Kubernetes to be ready..."
sleep 30
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install Helm 3
print_status "Installing Helm 3..."
if ! command -v helm &> /dev/null; then
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    print_warning "Helm already installed"
fi

# Install Helmfile
print_status "Installing Helmfile..."
if ! command -v helmfile &> /dev/null; then
    HELMFILE_VERSION="v0.169.0"
    wget https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/helmfile_${HELMFILE_VERSION}_linux_amd64.tar.gz
    tar -xzf helmfile_*.tar.gz
    mv helmfile /usr/local/bin/
    rm helmfile_*.tar.gz
else
    print_warning "Helmfile already installed"
fi

# Verify installations
print_status "Verifying installations..."
docker --version
kubectl version --client
helm version
helmfile version

# Clone or update repository
REPO_DIR="/opt/core-charts"
if [ -d "$REPO_DIR" ]; then
    print_status "Updating existing repository..."
    cd $REPO_DIR
    git pull origin main
else
    print_status "Cloning repository..."
    git clone https://github.com/your-org/core-charts.git $REPO_DIR
    cd $REPO_DIR
fi

# Create namespace for ingress
print_status "Creating namespaces..."
kubectl create namespace ingress-nginx --dry-run=client -o yaml | kubectl apply -f -

# Install Cloudflared (for Cloudflare tunnel)
print_status "Installing Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb
    rm cloudflared-linux-amd64.deb
else
    print_warning "Cloudflared already installed"
fi

# Setup Cloudflare tunnel (if credentials provided)
if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    print_status "Setting up Cloudflare tunnel..."
    cloudflared service install $CLOUDFLARE_TUNNEL_TOKEN
    systemctl enable cloudflared
    systemctl start cloudflared
else
    print_warning "Cloudflare tunnel token not provided. Please set CLOUDFLARE_TUNNEL_TOKEN environment variable"
fi

# Create secrets template
print_status "Setting up production secrets..."
SECRETS_FILE="$REPO_DIR/environments/production/secrets/values.yaml"
if [ ! -f "$SECRETS_FILE" ] || [ ! -s "$SECRETS_FILE" ]; then
    cat > "$SECRETS_FILE" << 'EOF'
# Production Secrets - DO NOT COMMIT
# Generate strong passwords for production!

postgresql:
  password: "CHANGE_ME_POSTGRES_PASSWORD"
  databases:
    - name: core_dev
      password: "CHANGE_ME_CORE_DEV_PASSWORD"
    - name: core_prod
      password: "CHANGE_ME_CORE_PROD_PASSWORD"
    - name: authentik
      password: "CHANGE_ME_AUTHENTIK_PASSWORD"
    - name: dcmaidbot
      password: "CHANGE_ME_DCMAIDBOT_PASSWORD"

redis:
  password: "CHANGE_ME_REDIS_PASSWORD"

monitoring:
  grafana:
    adminPassword: "CHANGE_ME_GRAFANA_PASSWORD"

authentik:
  secretKey: "CHANGE_ME_AUTHENTIK_SECRET_KEY"
  postgresql:
    password: "CHANGE_ME_AUTHENTIK_PASSWORD"
EOF
    print_warning "Please edit $SECRETS_FILE with actual production passwords"
fi

# Create production-specific values for Cloudflare tunnel
print_status "Configuring production values for Cloudflare tunnel..."
PROD_VALUES_FILE="$REPO_DIR/environments/production/values.yaml"
# Backup original
cp "$PROD_VALUES_FILE" "${PROD_VALUES_FILE}.backup"

# Update ingress configuration for Cloudflare tunnel
cat > "$REPO_DIR/environments/production/ingress-values.yaml" << 'EOF'
# Ingress NGINX configuration for production with Cloudflare tunnel

controller:
  service:
    type: ClusterIP  # Use ClusterIP with Cloudflare tunnel
    annotations:
      cloudflare.tunnel: "true"

  replicaCount: 2

  metrics:
    enabled: true
    serviceMonitor:
      enabled: true

  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

  config:
    use-forwarded-headers: "true"
    compute-full-forwarded-for: "true"
    proxy-body-size: "100m"
    proxy-buffer-size: "16k"
    server-tokens: "false"

# Disable cert-manager as we use Cloudflare tunnel
EOF

# Update production values to disable cert-manager
sed -i 's/certManager:\n  enabled: true/certManager:\n  enabled: false/' "$PROD_VALUES_FILE"

# Deploy infrastructure
print_status "Deploying infrastructure with Helmfile..."
cd $REPO_DIR

# Update Helm dependencies
print_status "Updating Helm dependencies..."
helmfile deps update

# Deploy infrastructure layer by layer
print_status "Deploying infrastructure layer 0 (cert-manager, ingress)..."
helmfile -e production -l layer=infrastructure sync

print_status "Deploying infrastructure layer 1 (databases)..."
helmfile -e production -l layer=infrastructure -l component=database sync

print_status "Deploying infrastructure layer 2 (monitoring)..."
helmfile -e production -l layer=monitoring sync

print_status "Deploying authentication layer..."
helmfile -e production -l layer=authentication sync

# Wait for databases to be ready
print_status "Waiting for databases to be ready..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=postgresql -n infrastructure --timeout=300s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=redis -n infrastructure --timeout=300s

# Deploy applications
print_status "Deploying applications..."
helmfile -e production -l layer=application sync

# Deploy GitOps (optional)
print_status "Deploying GitOps (ArgoCD)..."
helmfile -e production -l layer=gitops sync

# Verify deployment
print_status "Verifying deployment..."
echo ""
echo "=== Pod Status ==="
kubectl get pods -A

echo ""
echo "=== Services ==="
kubectl get services -A

echo ""
echo "=== Ingress ==="
kubectl get ingress -A

echo ""
echo "=== Getting LoadBalancer IP (if using LoadBalancer) ==="
kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "Using ClusterIP with Cloudflare tunnel"

# Setup port-forwards for local access (temporary)
print_status "Setting up port-forwards for local access..."
cat > /tmp/port-forwards.sh << 'EOF'
#!/bin/bash
# Port-forward script for local access
echo "Setting up port forwards..."

# Authentik
kubectl port-forward -n authentik svc/authentik-server 9000:80 &
echo "Authentik available at: http://localhost:9000"

# Core Pipeline Prod
kubectl port-forward -n core-pipeline-prod svc/core-pipeline 9001:3000 &
echo "Core Pipeline Prod available at: http://localhost:9001"

# Core Pipeline Dev
kubectl port-forward -n core-pipeline-dev svc/core-pipeline 9002:3000 &
echo "Core Pipeline Dev available at: http://localhost:9002"

# Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 9003:80 &
echo "Grafana available at: http://localhost:9003"

echo ""
echo "Port forwards are running in background."
echo "Press Ctrl+C to stop all port forwards."
EOF

chmod +x /tmp/port-forwards.sh

# Get URLs
echo ""
echo "=================================================="
echo "🎉 Deployment Complete!"
echo "=================================================="
echo ""
echo "Services deployed:"
echo "  - Authentik SSO: http://auth.theedgestory.org (via Cloudflare tunnel)"
echo "  - Core Pipeline (prod): http://core-pipeline.theedgestory.org"
echo "  - Core Pipeline (dev): http://core-pipeline.dev.theedgestory.org"
echo "  - Grafana: http://grafana.theedgestory.org"
echo ""
echo "For local access (via port-forward):"
echo "  Run: /tmp/port-forwards.sh"
echo ""
echo "Next steps:"
echo "1. Edit secrets: nano $SECRETS_FILE"
echo "2. Apply updated secrets: helmfile -e production apply"
echo "3. Configure Cloudflare tunnel in Cloudflare dashboard"
echo "4. Setup monitoring and alerts"
echo ""
echo "To check logs:"
echo "  kubectl logs -n <namespace> <pod-name>"
echo ""
echo "To get shell:"
echo "  kubectl exec -it -n <namespace> <pod-name> -- bash"
echo ""