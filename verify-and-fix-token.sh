#!/bin/bash
set -e

echo "=== GitHub Token Diagnostic and Fix Script ==="
echo ""

# The token from your output
CURRENT_TOKEN="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"

echo "Testing current token: ${CURRENT_TOKEN:0:10}..."
RESPONSE=$(curl -s -H "Authorization: Bearer $CURRENT_TOKEN" https://api.github.com/user)

if echo "$RESPONSE" | grep -q "message"; then
    echo "❌ Token is INVALID or lacks permissions"
    echo "Response: $RESPONSE"
    echo ""
    echo "ACTION REQUIRED:"
    echo "1. Go to: https://github.com/settings/tokens?type=beta"
    echo "2. Click 'Generate new token' → 'Fine-grained token'"
    echo "3. Name: 'core-charts-ghcr-access'"
    echo "4. Resource owner: uz0"
    echo "5. Repository access: 'All repositories' (or select core-pipeline)"
    echo "6. Permissions → Repository → Contents: Read-only"
    echo "7. Permissions → Repository → Packages: Read"
    echo "8. Click 'Generate token'"
    echo "9. CRITICAL: After generating, click 'Configure SSO' → 'Authorize' next to uz0"
    echo ""
    echo "Then run this command on the server:"
    echo "export GITHUB_TOKEN='your-new-token-here'"
    echo "./verify-and-fix-token.sh"
else
    USER=$(echo "$RESPONSE" | grep -o '"login":"[^"]*"' | cut -d'"' -f4)
    echo "✅ Token is valid for user: $USER"
    echo ""

    # Test package access
    echo "Testing GHCR package access..."
    PKG_RESPONSE=$(curl -s -H "Authorization: Bearer $CURRENT_TOKEN" https://ghcr.io/v2/uz0/core-pipeline/tags/list)

    if echo "$PKG_RESPONSE" | grep -q "DENIED"; then
        echo "❌ Token cannot access uz0/core-pipeline package"
        echo "Response: $PKG_RESPONSE"
        echo ""
        echo "This means SSO is NOT authorized for uz0 organization."
        echo ""
        echo "ACTION REQUIRED:"
        echo "1. Go to: https://github.com/settings/tokens"
        echo "2. Find your token: ${CURRENT_TOKEN:0:20}..."
        echo "3. Click 'Configure SSO' next to it"
        echo "4. Click 'Authorize' next to 'uz0' organization"
        echo "5. Confirm authorization"
        echo ""
        echo "Then re-run this script to verify."
    else
        echo "✅ Token can access uz0/core-pipeline package!"
        echo "Available tags:"
        echo "$PKG_RESPONSE" | jq -r '.tags[]' 2>/dev/null || echo "$PKG_RESPONSE"
        echo ""
        echo "Updating Kubernetes secrets..."

        AUTH=$(echo -n "uz0:$CURRENT_TOKEN" | base64 -w 0)

        for NAMESPACE in dev-core prod-core; do
            cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-secret
  namespace: $NAMESPACE
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "{\"auths\":{\"ghcr.io\":{\"username\":\"uz0\",\"password\":\"$CURRENT_TOKEN\",\"auth\":\"$AUTH\"}}}" | base64 -w 0)
EOF
            echo "✅ Updated ghcr-secret in $NAMESPACE"
        done

        echo ""
        echo "Restarting pods..."
        kubectl delete pods -n dev-core -l app.kubernetes.io/name=core-pipeline
        kubectl delete pods -n prod-core -l app.kubernetes.io/name=core-pipeline

        echo ""
        echo "✅ All done! Check pod status in ~30s:"
        echo "kubectl get pods -n dev-core"
        echo "kubectl get pods -n prod-core"
    fi
fi
