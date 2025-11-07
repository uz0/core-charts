#!/bin/bash
# Generate secure secrets for production deployment

set -e

SECRETS_FILE="environments/production/secrets/values.yaml"

# Function to generate random password
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Generate random secret key
generate_secret() {
    openssl rand -hex 32
}

echo "🔐 Generating production secrets..."
echo "=================================="

# Check if file exists and is not empty
if [ -f "$SECRETS_FILE" ] && [ -s "$SECRETS_FILE" ]; then
    echo "⚠️  Secrets file already exists. Creating backup..."
    cp "$SECRETS_FILE" "${SECRETS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
fi

# Generate secrets
POSTGRES_PASSWORD=$(generate_password)
CORE_DEV_PASSWORD=$(generate_password)
CORE_PROD_PASSWORD=$(generate_password)
AUTHENTIK_PASSWORD=$(generate_password)
DCMAIDBOT_PASSWORD=$(generate_password)
REDIS_PASSWORD=$(generate_password)
GRAFANA_PASSWORD=$(generate_password)
AUTHENTIK_SECRET=$(generate_secret)

# Create secrets file
cat > "$SECRETS_FILE" << EOF
# Production Secrets - GENERATED: $(date)
# IMPORTANT: Store these passwords securely!
# Do not commit to version control!

postgresql:
  password: "${POSTGRES_PASSWORD}"
  databases:
    - name: core_dev
      password: "${CORE_DEV_PASSWORD}"
    - name: core_prod
      password: "${CORE_PROD_PASSWORD}"
    - name: authentik
      password: "${AUTHENTIK_PASSWORD}"
    - name: dcmaidbot
      password: "${DCMAIDBOT_PASSWORD}"

redis:
  password: "${REDIS_PASSWORD}"

monitoring:
  grafana:
    adminPassword: "${GRAFANA_PASSWORD}"

authentik:
  secretKey: "${AUTHENTIK_SECRET}"
  postgresql:
    password: "${AUTHENTIK_PASSWORD}"
  # Add your Google OAuth credentials
  # google:
  #   clientId: "your-google-client-id"
  #   clientSecret: "your-google-client-secret"

# Additional application secrets can be added here
EOF

echo "✅ Secrets generated successfully!"
echo ""
echo "📝 IMPORTANT - Save these credentials securely:"
echo "==============================================="
echo ""
echo "PostgreSQL Admin Password: ${POSTGRES_PASSWORD}"
echo "Core Dev DB Password: ${CORE_DEV_PASSWORD}"
echo "Core Prod DB Password: ${CORE_PROD_PASSWORD}"
echo "Authentik DB Password: ${AUTHENTIK_PASSWORD}"
echo "DCMaidbot DB Password: ${DCMAIDBOT_PASSWORD}"
echo "Redis Password: ${REDIS_PASSWORD}"
echo "Grafana Admin Password: ${GRAFANA_PASSWORD}"
echo "Authentik Secret Key: ${AUTHENTIK_SECRET}"
echo ""
echo "⚠️  STORE THESE IN A PASSWORD MANAGER!"
echo ""
echo "Next steps:"
echo "1. Copy this file to the production server"
echo "2. Run: chmod 600 ${SECRETS_FILE}"
echo "3. Add Google OAuth credentials if needed"
echo "4. Run deployment: ./deploy-production.sh"
echo ""