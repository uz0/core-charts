#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Check if repository secret exists
expect "# "
send "kubectl get secret -n argocd | grep repo\r"

# Create repository credentials for ArgoCD (assuming the repo is public now)
expect "# "
send "kubectl create secret generic repo-uz0-core-charts -n argocd --from-literal=type=git --from-literal=url=https://github.com/uz0/core-charts --dry-run=client -o yaml | kubectl apply -f -\r"

# Annotate the applications to use the repository
expect "# "
send "kubectl annotate application core-pipeline-dev -n argocd argocd.argoproj.io/refresh=hard --overwrite\r"

expect "# "
send "kubectl annotate application core-pipeline-prod -n argocd argocd.argoproj.io/refresh=hard --overwrite\r"

# Force reconciliation
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}' --type merge\r"

# Check application status details
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.status.conditions\[0\].message}'\r"

expect "# "
send "echo ''\r"

# Check pods again
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl describe pod -n dev-core | grep Image:\r"

expect "# "
send "exit\r"
expect eof