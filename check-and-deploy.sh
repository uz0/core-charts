#!/usr/bin/expect -f

set timeout 120
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect {
    "Enter passphrase for key*" {
        send "\r"
        expect "password:"
        send "123454\r"
    }
    "password:" {
        send "123454\r"
    }
}

# Check current status
expect "# "
send "echo '=== Checking current deployments ==='\r"

expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

expect "# "
send "kubectl get ingress -n dev-core\r"

expect "# "
send "kubectl get ingress -n prod-core\r"

# Apply manifests
expect "# "
send "echo '=== Applying manifests ==='\r"

expect "# "
send "kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml\r"

expect "# "
send "kubectl apply -f https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml\r"

# Wait for pods
expect "# "
send "sleep 5\r"

# Check pods again
expect "# "
send "echo '=== Checking pods after deployment ==='\r"

expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

# Check services
expect "# "
send "kubectl get svc -n dev-core\r"

expect "# "
send "kubectl get svc -n prod-core\r"

# Test connectivity
expect "# "
send "kubectl run test-curl --image=curlimages/curl --rm -it --restart=Never -n dev-core -- curl -s http://core-pipeline:80/\r"

expect "# "
send "exit\r"
expect eof