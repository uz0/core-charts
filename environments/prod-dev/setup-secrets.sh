#!/bin/bash

set -e

echo "🔐 Setting up secrets for PROD-DEV environment..."

# Check if required environment variables are set
if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
    echo "❌ Error: CLOUDFLARE_API_TOKEN environment variable is required"
    exit 1
fi

if [ -z "$CLOUDFLARE_TUNNEL_ID" ]; then
    echo "❌ Error: CLOUDFLARE_TUNNEL_ID environment variable is required"
    exit 1
fi

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Error: BOT_TOKEN environment variable is required"
    exit 1
fi

if [ -z "$OPENAI_API_KEY" ]; then
    echo "❌ Error: OPENAI_API_KEY environment variable is required"
    exit 1
fi

if [ -z "$NUDGE_SECRET" ]; then
    echo "❌ Error: NUDGE_SECRET environment variable is required"
    exit 1
fi

if [ -z "$ADMIN_IDS" ]; then
    echo "❌ Error: ADMIN_IDS environment variable is required"
    exit 1
fi

# Check dependencies
if ! command -v kubectl &> /dev/null; then
    echo "❌ Error: kubectl is required but not installed"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is required but not installed"
    exit 1
fi

# Get Cloudflare Account ID from API
echo "🔍 Getting Cloudflare Account ID..."
CLOUDFLARE_ACCOUNT_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
    -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" | \
    jq -r '.result.id')

if [ "$CLOUDFLARE_ACCOUNT_ID" = "null" ]; then
    echo "❌ Error: Failed to get Cloudflare Account ID. Check your API token."
    exit 1
fi

echo "✅ Cloudflare Account ID: $CLOUDFLARE_ACCOUNT_ID"

# Create namespaces
echo "📦 Creating namespaces..."
kubectl create namespace infrastructure --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace dcmaidbot-prod-dev --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace cert-manager --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare API Token secret
echo "🔑 Creating Cloudflare API Token secret..."
kubectl create secret generic cloudflare-api-token-secret \
    --from-literal=api-token="$CLOUDFLARE_API_TOKEN" \
    --namespace=infrastructure \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Cloudflare Tunnel secret
echo "🌐 Creating Cloudflare Tunnel secret..."
TUNNEL_SECRET=$(echo -n '{"accountTag":"'$CLOUDFLARE_ACCOUNT_ID'","tunnelSecret":"'"$(openssl rand -hex 32)"'","tunnelID":"'$CLOUDFLARE_TUNNEL_ID'"}' | base64 | tr -d '\n')
kubectl create secret generic cloudflare-tunnel-secret \
    --from-literal=tunnel-credentials="$TUNNEL_SECRET" \
    --namespace=infrastructure \
    --dry-run=client -o yaml | kubectl apply -f -

# Create database credentials secret
echo "🗄️ Creating database credentials secret..."
kubectl create secret generic database-credentials \
    --from-literal=prod-dev-url="postgresql://core_proddev_user:StrongProdDevUserPassword123!@postgresql.infrastructure.svc.cluster.local:5432/core_proddev" \
    --namespace=dcmaidbot-prod-dev \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Redis credentials secret
echo "📦 Creating Redis credentials secret..."
kubectl create secret generic redis-credentials \
    --from-literal=prod-dev-url="redis://:RedisProdDevPass123!@redis-master.infrastructure.svc.cluster.local:6379/0" \
    --namespace=dcmaidbot-prod-dev \
    --dry-run=client -o yaml | kubectl apply -f -

# Create DcMaidBot secrets
echo "🤖 Creating DcMaidBot secrets..."
kubectl create secret generic dcmaidbot-secrets \
    --from-literal=database-url="postgresql://dcmaidbot_proddev_user:DcmaidbotProdDevPass123!@postgresql.infrastructure.svc.cluster.local:5432/dcmaidbot_proddev" \
    --from-literal=openai-api-key="$OPENAI_API_KEY" \
    --from-literal=bot-token="$BOT_TOKEN" \
    --from-literal=admin-ids="$ADMIN_IDS" \
    --from-literal=nudge-secret="$NUDGE_SECRET" \
    --namespace=dcmaidbot-prod-dev \
    --dry-run=client -o yaml | kubectl apply -f -

# Create MinIO credentials secret
echo "📦 Creating MinIO credentials secret..."
kubectl create secret generic minio-credentials \
    --from-literal=access-key="minioadmin" \
    --from-literal=secret-key="MinIOProdDevPass123!" \
    --namespace=dcmaidbot-prod-dev \
    --dry-run=client -o yaml | kubectl apply -f -

# Create MCP Server config
echo "🔧 Creating MCP Server config..."
kubectl create configmap mcp-k8s-config \
    --from-literal=KUBECONFIG="" \
    --namespace=infrastructure \
    --dry-run=client -o yaml | kubectl apply -f -

echo "✅ All secrets created successfully!"
echo ""
echo "🚀 You can now deploy the infrastructure with:"
echo "   helmfile -e prod-dev sync"
echo ""
echo "📊 To check the status:"
echo "   kubectl get pods -n infrastructure"
echo "   kubectl get pods -n dcmaidbot-prod-dev"
echo "   kubectl get pods -n monitoring"