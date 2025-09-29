#!/usr/bin/expect -f

set timeout 60
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Delete the existing nginx deployment
expect "# "
send "kubectl delete deployment core-pipeline -n dev-core\r"

# Create proper deployment for core-pipeline
expect "# "
send "cat > /tmp/core-pipeline-deploy.yaml << 'EOF'\r"
send "apiVersion: apps/v1\r"
send "kind: Deployment\r"
send "metadata:\r"
send "  name: core-pipeline\r"
send "  namespace: dev-core\r"
send "spec:\r"
send "  replicas: 1\r"
send "  selector:\r"
send "    matchLabels:\r"
send "      app: core-pipeline\r"
send "  template:\r"
send "    metadata:\r"
send "      labels:\r"
send "        app: core-pipeline\r"
send "    spec:\r"
send "      containers:\r"
send "      - name: core-pipeline\r"
send "        image: ghcr.io/uz0/core-pipeline:latest\r"
send "        ports:\r"
send "        - containerPort: 3000\r"
send "        env:\r"
send "        - name: NODE_ENV\r"
send "          value: development\r"
send "        - name: PORT\r"
send "          value: \"3000\"\r"
send "EOF\r"

expect "# "
send "kubectl apply -f /tmp/core-pipeline-deploy.yaml\r"

# Update service to use port 3000
expect "# "
send "kubectl patch svc core-pipeline -n dev-core -p '{\"spec\":{\"ports\":\[{\"port\":3000,\"targetPort\":3000,\"protocol\":\"TCP\"}\]}}'\r"

# Create prod deployment
expect "# "
send "kubectl create namespace prod-core --dry-run=client -o yaml | kubectl apply -f -\r"

expect "# "
send "cat > /tmp/core-pipeline-prod.yaml << 'EOF'\r"
send "apiVersion: apps/v1\r"
send "kind: Deployment\r"
send "metadata:\r"
send "  name: core-pipeline\r"
send "  namespace: prod-core\r"
send "spec:\r"
send "  replicas: 2\r"
send "  selector:\r"
send "    matchLabels:\r"
send "      app: core-pipeline\r"
send "  template:\r"
send "    metadata:\r"
send "      labels:\r"
send "        app: core-pipeline\r"
send "    spec:\r"
send "      containers:\r"
send "      - name: core-pipeline\r"
send "        image: ghcr.io/uz0/core-pipeline:latest\r"
send "        ports:\r"
send "        - containerPort: 3000\r"
send "        env:\r"
send "        - name: NODE_ENV\r"
send "          value: production\r"
send "        - name: PORT\r"
send "          value: \"3000\"\r"
send "---\r"
send "apiVersion: v1\r"
send "kind: Service\r"
send "metadata:\r"
send "  name: core-pipeline\r"
send "  namespace: prod-core\r"
send "spec:\r"
send "  selector:\r"
send "    app: core-pipeline\r"
send "  ports:\r"
send "  - port: 3000\r"
send "    targetPort: 3000\r"
send "EOF\r"

expect "# "
send "kubectl apply -f /tmp/core-pipeline-prod.yaml\r"

# Check status
expect "# "
send "kubectl get pods -n dev-core\r"

expect "# "
send "kubectl get pods -n prod-core\r"

expect "# "
send "exit\r"
expect eof