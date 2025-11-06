# Quick Access Guide

## Authentik SSO

### Recovery Link (Valid for 10 minutes)
```
http://auth.local.test/recovery/use-token/BpraRDUXkNSV9hjgKx2pPNRk8kgoJNO7mjlZhufn3Kt3COiqC9ri42pHG94j/
```

### Generate New Recovery Key
```bash
kubectl exec -it -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1) -- ak create_recovery_key 10 akadmin
```

The command will output a recovery URL like:
```
/recovery/use-token/***********/
```

Full URL: `http://auth.local.test/recovery/use-token/***********/`

## Setup Admin Password

Once logged in via recovery key:

1. Go to **Admin Interface** (top right menu)
2. Click on **Directory** → **Users**
3. Find user `akadmin`
4. Click **Edit**
5. Set a new password
6. Save

Now you can login normally with:
- Username: `akadmin`
- Password: (your new password)

## Infrastructure Access

```bash
# PostgreSQL
kubectl exec -it -n infrastructure $(kubectl get pod -n infrastructure -l app.kubernetes.io/name=postgresql-postgresql -o name | head -1) -- psql -U postgres

# Redis
kubectl exec -it -n infrastructure $(kubectl get pod -n infrastructure -l app.kubernetes.io/name=redis-master -o name | head -1) -- redis-cli -a local-redis-password-changeme

# Check all pods
kubectl get pods -A
```

## Services

- **LoadBalancer IP**: `kubectl get svc -n ingress-nginx ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}'`
- **Authentik**: http://auth.local.test
- **Ingress Controller**: Running in `ingress-nginx` namespace

## Databases Created

- `core_dev` - User: `core_dev_user`
- `core_prod` - User: `core_prod_user`
- `authentik` - User: `authentik_user`
- `dcmaidbot` - User: `dcmaidbot_user`

All passwords are in `environments/local/*-values.yaml` files.
