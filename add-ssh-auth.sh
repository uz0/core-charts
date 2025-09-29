#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Generate SSH key for ArgoCD
expect "# "
send "ssh-keygen -t ed25519 -f /tmp/argocd-repo-key -N '' -C 'argocd@k8s'\r"

expect "# "
send "cat /tmp/argocd-repo-key\r"

expect "# "
send "echo ''\r"

expect "# "
send "echo 'Add this public key to GitHub repository as Deploy Key:'\r"

expect "# "
send "cat /tmp/argocd-repo-key.pub\r"

expect "# "
send "echo ''\r"

# Create secret with SSH key
expect "# "
send "kubectl create secret generic repo-core-charts-ssh --from-file=sshPrivateKey=/tmp/argocd-repo-key -n argocd --dry-run=client -o yaml | kubectl apply -f -\r"

# Patch the secret with labels
expect "# "
send "kubectl patch secret repo-core-charts-ssh -n argocd -p '{\"metadata\":{\"labels\":{\"argocd.argoproj.io/secret-type\":\"repo-creds\"}},\"stringData\":{\"type\":\"git\",\"url\":\"git@github.com:uz0\"}}'\r"

# Update applications to use SSH URL
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/repoURL\",\"value\":\"git@github.com:uz0/core-charts.git\"}\]'\r"

expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/repoURL\",\"value\":\"git@github.com:uz0/core-charts.git\"}\]'\r"

# Restart ArgoCD
expect "# "
send "kubectl rollout restart deployment/argocd-repo-server -n argocd\r"

expect "# "
send "sleep 10\r"

# Check status
expect "# "
send "kubectl get applications -n argocd | grep core-pipeline\r"

expect "# "
send "exit\r"
expect eof