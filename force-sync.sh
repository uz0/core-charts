#!/usr/bin/expect -f

set timeout 120
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Get ArgoCD admin password
expect "# "
send "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d\r"

expect "# "
send "echo ''\r"

# Port forward ArgoCD server
expect "# "
send "kubectl port-forward svc/argocd-server -n argocd 8080:443 &\r"

expect "# "
send "sleep 3\r"

# Login to ArgoCD
expect "# "
send "argocd login localhost:8080 --username admin --password \$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d) --insecure\r"

# Refresh and sync dev
expect "# "
send "argocd app get core-pipeline-dev --refresh\r"

expect "# "
send "argocd app sync core-pipeline-dev --prune\r"

# Refresh and sync prod
expect "# "
send "argocd app get core-pipeline-prod --refresh\r"

expect "# "
send "argocd app sync core-pipeline-prod --prune\r"

# Kill port forward
expect "# "
send "pkill -f 'port-forward svc/argocd-server'\r"

# Check final status
expect "# "
send "kubectl get applications -n argocd\r"

expect "# "
send "exit\r"
expect eof