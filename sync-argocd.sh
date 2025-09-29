#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Check current applications
expect "# "
send "kubectl get applications -n argocd\r"

# Update core-pipeline-dev to use main branch
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='merge' -p '{\"spec\":{\"source\":{\"targetRevision\":\"main\"}}}'\r"

# Update core-pipeline-prod to use main branch
expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='merge' -p '{\"spec\":{\"source\":{\"targetRevision\":\"main\"}}}'\r"

# Try to sync dev
expect "# "
send "argocd app sync core-pipeline-dev\r"

# Try to sync prod
expect "# "
send "argocd app sync core-pipeline-prod\r"

# Check status
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.status.sync.status}'\r"

expect "# "
send "echo ''\r"

expect "# "
send "kubectl get application core-pipeline-prod -n argocd -o jsonpath='{.status.sync.status}'\r"

expect "# "
send "echo ''\r"

# Check pods
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

expect "# "
send "exit\r"
expect eof