#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Get application manifest details
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o yaml | head -50\r"

expect "# "
send "exit\r"
expect eof