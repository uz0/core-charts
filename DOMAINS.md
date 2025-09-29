# Core Pipeline Domains

## Production
- URL: `https://core-pipeline.theedgestory.org`
- Namespace: `prod-core`
- Ingress host: `core-pipeline.theedgestory.org`
- TLS secret: `core-pipeline-tls`

## Development
- URL: `https://core-pipeline.dev.theedgestory.org`
- Namespace: `dev-core`
- Ingress host: `core-pipeline.dev.theedgestory.org`
- TLS secret: `core-pipeline-dev-tls`

## ArgoCD UI Links
- Dev: http://46.62.223.198:30113/applications/argocd/core-pipeline-dev
- Prod: http://46.62.223.198:30113/applications/argocd/core-pipeline-prod

## CI/CD Environment URLs (to update in core-pipeline repo)
```yaml
deploy-dev:
  environment:
    name: development
    url: https://core-pipeline.dev.theedgestory.org

deploy-prod:
  environment:
    name: production
    url: https://core-pipeline.theedgestory.org
```