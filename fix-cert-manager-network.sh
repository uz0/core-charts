#!/bin/bash
set -e

echo "========================================"
echo "FIX CERT-MANAGER NETWORK ACCESS"
echo "========================================"

echo ""
echo "=== 1. Patch cert-manager to use host network mode ==="
kubectl patch deployment cert-manager -n cert-manager --type=merge -p '{"spec":{"template":{"spec":{"hostNetwork":true}}}}'

echo ""
echo "=== 2. Wait for cert-manager to restart ==="
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=120s

echo ""
echo "=== 3. Test if cert-manager can reach Let's Encrypt ==="
sleep 5
kubectl logs -n cert-manager -l app=cert-manager --tail=20

echo ""
echo "=== 4. Delete old self-signed TLS secrets ==="
kubectl delete secret -n dev-core core-pipeline-dev-tls --ignore-not-found
kubectl delete secret -n prod-core core-pipeline-prod-tls --ignore-not-found
kubectl delete secret -n argocd argocd-tls --ignore-not-found

echo ""
echo "=== 5. Re-add cert-manager annotations to trigger certificate issuance ==="
kubectl annotate ingress -n dev-core core-pipeline-dev cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite
kubectl annotate ingress -n prod-core core-pipeline-prod cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite
kubectl annotate ingress -n argocd argocd-server-ingress cert-manager.io/cluster-issuer=letsencrypt-prod --overwrite

echo ""
echo "=== 6. Check certificate status ==="
echo "Waiting 10 seconds for certificates to be requested..."
sleep 10
kubectl get certificate -A | grep -E "core-pipeline|argocd"

echo ""
echo "=== 7. Monitor cert-manager logs for any issues ==="
kubectl logs -n cert-manager -l app=cert-manager --tail=30

echo ""
echo "Fix complete! Monitor certificates with: kubectl get certificate -A"
