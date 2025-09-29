#!/usr/bin/expect -f

set timeout 30
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

expect "# "
send "kubectl get applications -n argocd\r"

expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o yaml\r"

expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

expect "# "
send "exit\r"
expect eof