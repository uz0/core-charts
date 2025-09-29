#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Re-enable auto-sync for dev
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='merge' -p '{\"spec\":{\"syncPolicy\":{\"automated\":{\"prune\":true,\"selfHeal\":true}}}}'\r"

# Re-enable auto-sync for prod
expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='merge' -p '{\"spec\":{\"syncPolicy\":{\"automated\":{\"prune\":true,\"selfHeal\":true}}}}'\r"

# Force refresh
expect "# "
send "kubectl annotate application core-pipeline-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite\r"

expect "# "
send "kubectl annotate application core-pipeline-prod -n argocd argocd.argoproj.io/refresh=hard --overwrite\r"

# Wait a moment
expect "# "
send "sleep 10\r"

# Check applications status
expect "# "
send "kubectl get applications -n argocd | grep core-pipeline\r"

# Check pods
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

# Check ingress
expect "# "
send "kubectl get ingress -n dev-core\r"

expect "# "
send "kubectl get ingress -n prod-core\r"

# Test the service
expect "# "
send "curl -I http://core-pipeline.dev.theedgestory.org 2>/dev/null | head -1\r"

expect "# "
send "exit\r"
expect eof