#!/usr/bin/expect -f

set timeout 120
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Get detailed application status
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o yaml | grep -A 20 'status:'\r"

expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.status.conditions}' | jq\r"

# Check if ArgoCD can access the repository
expect "# "
send "kubectl logs -n argocd deployment/argocd-repo-server --tail=50 | grep -i 'uz0\\|error\\|fail'\r"

# Check application controller logs
expect "# "
send "kubectl logs -n argocd deployment/argocd-application-controller --tail=50 | grep -i 'core-pipeline\\|error'\r"

# Get the exact source configuration
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.spec.source}' | jq\r"

expect "# "
send "exit\r"
expect eof