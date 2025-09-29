#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Add repository to ArgoCD with no authentication (assuming it's public)
expect "# "
send "kubectl delete secret -n argocd repo-uz0-core-charts --ignore-not-found\r"

expect "# "
send "cat <<EOF | kubectl apply -f -\r"
send "apiVersion: v1\r"
send "kind: Secret\r"
send "metadata:\r"
send "  name: repo-uz0-core-charts\r"
send "  namespace: argocd\r"
send "  labels:\r"
send "    argocd.argoproj.io/secret-type: repository\r"
send "stringData:\r"
send "  type: git\r"
send "  url: https://github.com/uz0/core-charts\r"
send "  insecure: \"true\"\r"
send "EOF\r"

# Restart repo server to pick up new config
expect "# "
send "kubectl rollout restart deployment/argocd-repo-server -n argocd\r"

expect "# "
send "sleep 10\r"

# Try to sync again
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'\r"

expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type merge -p '{\"metadata\":{\"annotations\":{\"argocd.argoproj.io/refresh\":\"hard\"}}}'\r"

expect "# "
send "sleep 5\r"

# Check status
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.status.sync.status}'\r"

expect "# "
send "echo ''\r"

expect "# "
send "exit\r"
expect eof