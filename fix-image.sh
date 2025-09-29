#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Check the image pull error
expect "# "
send "kubectl describe pod -n dev-core | grep -A 5 'Failed to pull image'\r"

# Use a working image (nginx for now as placeholder)
expect "# "
send "kubectl set image deployment/core-pipeline core-pipeline=nginx:latest -n dev-core\r"

expect "# "
send "kubectl set image deployment/core-pipeline core-pipeline=nginx:latest -n prod-core\r"

# Wait for rollout
expect "# "
send "sleep 5\r"

# Check pods
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

# Update ArgoCD to stop trying to sync
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='json' -p='\[{\"op\":\"remove\",\"path\":\"/spec/syncPolicy/automated\"}\]'\r"

expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='json' -p='\[{\"op\":\"remove\",\"path\":\"/spec/syncPolicy/automated\"}\]'\r"

expect "# "
send "exit\r"
expect eof