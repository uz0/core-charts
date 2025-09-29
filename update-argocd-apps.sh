#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Update dev application to use main branch and correct path
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/targetRevision\",\"value\":\"main\"},{\"op\":\"replace\",\"path\":\"/spec/source/path\",\"value\":\"charts/core-pipeline\"},{\"op\":\"replace\",\"path\":\"/spec/project\",\"value\":\"default\"}]'\r"

# Update prod application similarly
expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/targetRevision\",\"value\":\"main\"},{\"op\":\"replace\",\"path\":\"/spec/source/path\",\"value\":\"charts/core-pipeline\"},{\"op\":\"replace\",\"path\":\"/spec/project\",\"value\":\"default\"}]'\r"

# Delete the current pod to force refresh
expect "# "
send "kubectl delete pod -n dev-core core-pipeline-7ccd774bb5-b8h8d\r"

# Manually trigger sync using kubectl
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type merge -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"revision\":\"main\",\"prune\":true,\"syncStrategy\":{\"hook\":{}}}}}'\r"

expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type merge -p '{\"operation\":{\"initiatedBy\":{\"username\":\"admin\"},\"sync\":{\"revision\":\"main\",\"prune\":true,\"syncStrategy\":{\"hook\":{}}}}}'\r"

# Check status
expect "# "
send "kubectl get applications -n argocd\r"

expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "exit\r"
expect eof