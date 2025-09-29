#!/usr/bin/expect -f

set timeout 120
spawn ssh -i ~/.ssh/uz0 root@46.62.223.198

expect "password:"
send "123454\r"

# Download and apply dev manifests
expect "# "
send "curl -sL https://raw.githubusercontent.com/uz0/core-charts/main/manifests/dev-core-pipeline.yaml | kubectl apply -f -\r"

expect "# "
send "sleep 5\r"

# Download and apply prod manifests
expect "# "
send "curl -sL https://raw.githubusercontent.com/uz0/core-charts/main/manifests/prod-core-pipeline.yaml | kubectl apply -f -\r"

expect "# "
send "sleep 5\r"

# Check deployments
expect "# "
send "kubectl get all -n dev-core\r"

expect "# "
send "kubectl get all -n prod-core\r"

# Update ArgoCD applications to track the manifests directory
expect "# "
send "kubectl delete application core-pipeline-dev core-pipeline-prod -n argocd --ignore-not-found\r"

# Create new ArgoCD application for dev
expect "# "
send "cat <<'EOF' | kubectl apply -f -\r"
send "apiVersion: argoproj.io/v1alpha1\r"
send "kind: Application\r"
send "metadata:\r"
send "  name: core-pipeline-dev\r"
send "  namespace: argocd\r"
send "spec:\r"
send "  project: default\r"
send "  source:\r"
send "    repoURL: https://github.com/uz0/core-charts\r"
send "    targetRevision: main\r"
send "    path: manifests\r"
send "    directory:\r"
send "      include: dev-core-pipeline.yaml\r"
send "  destination:\r"
send "    server: https://kubernetes.default.svc\r"
send "    namespace: dev-core\r"
send "  syncPolicy:\r"
send "    automated:\r"
send "      prune: true\r"
send "      selfHeal: true\r"
send "    syncOptions:\r"
send "    - CreateNamespace=true\r"
send "EOF\r"

# Create new ArgoCD application for prod
expect "# "
send "cat <<'EOF' | kubectl apply -f -\r"
send "apiVersion: argoproj.io/v1alpha1\r"
send "kind: Application\r"
send "metadata:\r"
send "  name: core-pipeline-prod\r"
send "  namespace: argocd\r"
send "spec:\r"
send "  project: default\r"
send "  source:\r"
send "    repoURL: https://github.com/uz0/core-charts\r"
send "    targetRevision: main\r"
send "    path: manifests\r"
send "    directory:\r"
send "      include: prod-core-pipeline.yaml\r"
send "  destination:\r"
send "    server: https://kubernetes.default.svc\r"
send "    namespace: prod-core\r"
send "  syncPolicy:\r"
send "    automated:\r"
send "      prune: true\r"
send "      selfHeal: true\r"
send "    syncOptions:\r"
send "    - CreateNamespace=true\r"
send "EOF\r"

expect "# "
send "kubectl get applications -n argocd | grep core-pipeline\r"

expect "# "
send "exit\r"
expect eof