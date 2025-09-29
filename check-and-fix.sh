#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Check the actual error in detail
expect "# "
send "kubectl describe application core-pipeline-dev -n argocd | grep -A 10 'Status:'\r"

# Check if the repository URL is correct
expect "# "
send "kubectl get application core-pipeline-dev -n argocd -o jsonpath='{.spec.source.repoURL}'\r"

expect "# "
send "echo ''\r"

# Check git access to the repository
expect "# "
send "git ls-remote https://github.com/uz0/core-charts\r"

expect "# "
send "exit\r"
expect eof