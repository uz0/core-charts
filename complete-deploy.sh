#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Fix the service port
expect "# "
send "kubectl delete svc core-pipeline -n dev-core\r"

expect "# "
send "kubectl expose deployment core-pipeline --port=3000 --target-port=3000 -n dev-core\r"

# Create prod deployment with single command
expect "# "
send "kubectl create deployment core-pipeline --image=ghcr.io/uz0/core-pipeline:latest --replicas=2 -n prod-core --dry-run=client -o yaml | kubectl apply -f -\r"

expect "# "
send "kubectl expose deployment core-pipeline --port=3000 --target-port=3000 -n prod-core\r"

# Check pods
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

# Check services
expect "# "
send "kubectl get svc -n dev-core\r"

expect "# "
send "kubectl get svc -n prod-core\r"

# Test the application
expect "# "
send "kubectl port-forward -n dev-core svc/core-pipeline 3000:3000 &\r"

expect "# "
send "sleep 2\r"

expect "# "
send "curl -s http://localhost:3000/health | head -5\r"

expect "# "
send "pkill -f 'port-forward'\r"

expect "# "
send "exit\r"
expect eof