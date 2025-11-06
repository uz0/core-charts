# PostgreSQL Admin Secret

The `postgresql-init` job and the Bitnami PostgreSQL chart expect an existing Kubernetes Secret that stores administrator credentials. The secret must be created before deploying the PostgreSQL release.

## Secret name and namespace

- **Name:** `postgresql-admin`
- **Namespace:** `infrastructure`

## Required keys

- `password` – the PostgreSQL administrator password (required)
- `username` – the administrator username (optional if you rely on the chart default of `postgres`)

## Example creation command

```bash
kubectl create secret generic postgresql-admin \
  --namespace infrastructure \
  --from-literal=password='your-strong-password' \
  --from-literal=username='postgres'
```

You can replace the `--from-literal` flags with `--from-file` if you prefer to source credentials from files.
