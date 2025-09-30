# core-pipeline

![Version: 1.0.1](https://img.shields.io/badge/Version-1.0.1-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 1.0.0](https://img.shields.io/badge/AppVersion-1.0.0-informational?style=flat-square)

Production-ready Helm chart for NestJS core-pipeline application

**Homepage:** <https://github.com/uz0/core-pipeline>

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| uz0 | <admin@example.com> |  |

## Source Code

* <https://github.com/uz0/core-pipeline>

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `10` |  |
| autoscaling.minReplicas | int | `2` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| autoscaling.targetMemoryUtilizationPercentage | int | `80` |  |
| configMap.data | object | `{}` |  |
| configMap.enabled | bool | `true` |  |
| env.API_PREFIX | string | `""` |  |
| env.KAFKA_BROKER | string | `"kafka.kafka.svc.cluster.local:9092"` |  |
| env.KAFKA_BROKERS | string | `"kafka.kafka.svc.cluster.local:9092"` |  |
| env.KAFKA_CLIENT_ID | string | `"core-pipeline"` |  |
| env.KAFKA_CONSUMER_GROUP | string | `"core-pipeline-group"` |  |
| env.KAFKA_GROUP_ID | string | `"core-pipeline-group"` |  |
| env.LOG_LEVEL | string | `"info"` |  |
| env.LOG_PRETTY | string | `"false"` |  |
| env.METRICS_ENABLED | string | `"true"` |  |
| env.METRICS_PREFIX | string | `"core_pipeline"` |  |
| env.NODE_ENV | string | `"production"` |  |
| env.OTEL_EXPORTER_OTLP_ENDPOINT | string | `"http://tempo.monitoring:4318"` |  |
| env.OTEL_SERVICE_NAME | string | `"core-pipeline"` |  |
| env.PORT | string | `"3000"` |  |
| env.POSTGRES_DB | string | `"core_pipeline"` |  |
| env.POSTGRES_HOST | string | `"postgresql.database.svc.cluster.local"` |  |
| env.POSTGRES_PORT | string | `"5432"` |  |
| env.POSTGRES_USER | string | `"core_user"` |  |
| env.REDIS_HOST | string | `"redis-master.redis.svc.cluster.local"` |  |
| env.REDIS_PORT | string | `"6379"` |  |
| env.SERVICE_VERSION | string | `"1.0.0"` |  |
| env.SWAGGER_ENABLED | string | `"true"` |  |
| env.SWAGGER_PATH | string | `"swagger"` |  |
| env.TRACING_ENABLED | string | `"true"` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"ghcr.io/uz0/core-pipeline"` |  |
| image.tag | string | `"latest"` |  |
| imagePullSecrets | list | `[]` |  |
| ingress.annotations."cert-manager.io/cluster-issuer" | string | `"letsencrypt-prod"` |  |
| ingress.annotations."nginx.ingress.kubernetes.io/force-ssl-redirect" | string | `"true"` |  |
| ingress.annotations."nginx.ingress.kubernetes.io/ssl-protocols" | string | `"TLSv1.2 TLSv1.3"` |  |
| ingress.className | string | `"nginx"` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"core-pipeline.example.com"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe.failureThreshold | int | `3` |  |
| livenessProbe.httpGet.path | string | `"/"` |  |
| livenessProbe.httpGet.port | string | `"http"` |  |
| livenessProbe.initialDelaySeconds | int | `30` |  |
| livenessProbe.periodSeconds | int | `10` |  |
| livenessProbe.timeoutSeconds | int | `5` |  |
| networkPolicy.enabled | bool | `false` |  |
| networkPolicy.policyTypes[0] | string | `"Ingress"` |  |
| networkPolicy.policyTypes[1] | string | `"Egress"` |  |
| nodeSelector | object | `{}` |  |
| persistence.accessMode | string | `"ReadWriteOnce"` |  |
| persistence.enabled | bool | `false` |  |
| persistence.mountPath | string | `"/data"` |  |
| persistence.size | string | `"8Gi"` |  |
| persistence.storageClass | string | `""` |  |
| podAnnotations."prometheus.io/path" | string | `"/metrics"` |  |
| podAnnotations."prometheus.io/port" | string | `"3000"` |  |
| podAnnotations."prometheus.io/scrape" | string | `"true"` |  |
| podDisruptionBudget.enabled | bool | `false` |  |
| podDisruptionBudget.minAvailable | int | `1` |  |
| podSecurityContext.fsGroup | int | `1000` |  |
| podSecurityContext.runAsNonRoot | bool | `true` |  |
| podSecurityContext.runAsUser | int | `1000` |  |
| readinessProbe.failureThreshold | int | `3` |  |
| readinessProbe.httpGet.path | string | `"/"` |  |
| readinessProbe.httpGet.port | string | `"http"` |  |
| readinessProbe.initialDelaySeconds | int | `10` |  |
| readinessProbe.periodSeconds | int | `5` |  |
| readinessProbe.timeoutSeconds | int | `3` |  |
| replicaCount | int | `2` |  |
| resources.limits.cpu | string | `"500m"` |  |
| resources.limits.memory | string | `"512Mi"` |  |
| resources.requests.cpu | string | `"250m"` |  |
| resources.requests.memory | string | `"256Mi"` |  |
| secrets.POSTGRES_PASSWORD | string | `"core_password"` |  |
| secrets.REDIS_PASSWORD | string | `""` |  |
| securityContext.allowPrivilegeEscalation | bool | `false` |  |
| securityContext.capabilities.drop[0] | string | `"ALL"` |  |
| securityContext.readOnlyRootFilesystem | bool | `true` |  |
| securityContext.runAsNonRoot | bool | `true` |  |
| securityContext.runAsUser | int | `1000` |  |
| service.port | int | `80` |  |
| service.targetPort | int | `8080` |  |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` |  |
| serviceAccount.create | bool | `true` |  |
| serviceAccount.name | string | `""` |  |
| serviceMonitor.enabled | bool | `false` |  |
| serviceMonitor.interval | string | `"30s"` |  |
| serviceMonitor.scrapeTimeout | string | `"10s"` |  |
| startupProbe.failureThreshold | int | `30` |  |
| startupProbe.httpGet.path | string | `"/"` |  |
| startupProbe.httpGet.port | string | `"http"` |  |
| startupProbe.initialDelaySeconds | int | `0` |  |
| startupProbe.periodSeconds | int | `10` |  |
| startupProbe.successThreshold | int | `1` |  |
| startupProbe.timeoutSeconds | int | `3` |  |
| tolerations | list | `[]` |  |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)
