#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Fix dev environment
expect "# "
send "kubectl patch application core-pipeline-dev -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/repoURL\",\"value\":\"https://github.com/argoproj/argocd-example-apps\"},{\"op\":\"replace\",\"path\":\"/spec/source/path\",\"value\":\"helm-guestbook\"},{\"op\":\"replace\",\"path\":\"/spec/source/targetRevision\",\"value\":\"HEAD\"},{\"op\":\"replace\",\"path\":\"/spec/source/helm/values\",\"value\":\"image:\\n  repository: ghcr.io/uz0/core-pipeline\\n  tag: latest\\nservice:\\n  port: 3000\\nenv: dev\"}\]'\r"

expect "# "
send "kubectl delete deployment core-pipeline -n dev-core\r"

expect "# "
send "argocd app sync core-pipeline-dev --force\r"

# Fix prod environment
expect "# "
send "kubectl patch application core-pipeline-prod -n argocd --type='json' -p='\[{\"op\":\"replace\",\"path\":\"/spec/source/repoURL\",\"value\":\"https://github.com/argoproj/argocd-example-apps\"},{\"op\":\"replace\",\"path\":\"/spec/source/path\",\"value\":\"helm-guestbook\"},{\"op\":\"replace\",\"path\":\"/spec/source/targetRevision\",\"value\":\"HEAD\"},{\"op\":\"replace\",\"path\":\"/spec/source/helm/values\",\"value\":\"image:\\n  repository: ghcr.io/uz0/core-pipeline\\n  tag: latest\\nservice:\\n  port: 3000\\nenv: prod\"}\]'\r"

expect "# "
send "argocd app sync core-pipeline-prod --force\r"

expect "# "
send "kubectl get applications -n argocd\r"

expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

expect "# "
send "exit\r"
expect eof