#!/usr/bin/expect -f

set timeout 30
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

expect "# "
send "kubectl describe pod -n dev-core\r"

expect "# "
send "kubectl get svc -n dev-core\r"

expect "# "
send "kubectl get ingress -n dev-core\r"

expect "# "
send "kubectl logs -n dev-core core-pipeline-7ccd774bb5-b8h8d --tail=20\r"

expect "# "
send "exit\r"
expect eof