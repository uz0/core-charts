# Production Server Setup Guide

**Server:** 46.62.223.198
**Domain:** theedgestory.org
**Tunnel:** Cloudflare Tunnel (no Let's Encrypt)

## 🔑 Step 1: Set Up SSH Access

### Option A: Add SSH Key (Recommended)

1. **Access your server via cloud provider console/VNC**

2. **Add your SSH public key to the server:**
```bash
# Create SSH directory
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add your public key to authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEmydtfH6D5svozK3UGYMC4G/VbKXg7GniAY2K3OCQNR vasilisa.versus@tripleten.com" >> ~/.ssh/authorized_keys

# Set correct permissions
chmod 600 ~/.ssh/authorized_keys
```

3. **Test SSH connection from your local machine:**
```bash
ssh root@46.62.223.198
```

### Option B: Enable Password Authentication

If you can't use SSH keys, temporarily enable password authentication:

```bash
# On server, edit SSH config
nano /etc/ssh/sshd_config

# Change these lines:
PasswordAuthentication yes
PermitRootLogin yes

# Restart SSH
systemctl restart sshd
```

## 🚀 Step 2: Deploy Infrastructure

Once you have SSH access, run these commands from your local machine:

```bash
# 1. Copy deployment scripts to server
scp deploy-production.sh root@46.62.223.198:/root/
scp generate-secrets.sh root@46.62.223.198:/root/
scp cloudflare-tunnel.yaml root@46.62.223.198:/root/

# 2. SSH into the server
ssh root@46.62.223.198

# 3. On the server, generate secure secrets
cd /root
./generate-secrets.sh

# 4. Edit the generated secrets file (optional)
nano environments/production/secrets/values.yaml

# 5. Run the deployment
./deploy-production.sh
```

## 🌐 Step 3: Configure Cloudflare Tunnel

### In Cloudflare Dashboard:

1. **Go to Zero Trust > Networks > Tunnels**
2. **Create a new tunnel**
3. **Choose "Cloudflared"**
4. **Copy the tunnel token**
5. **On your server, run:**
```bash
export CLOUDFLARE_TUNNEL_TOKEN="your-token-here"
cloudflared service install $CLOUDFLARE_TUNNEL_TOKEN
systemctl enable cloudflared
systemctl start cloudflared
```

### Add Ingress Rules:

Use the `cloudflare-tunnel.yaml` file as a reference to configure these hostnames in Cloudflare:

- `auth.theedgestory.org` → Authentik SSO
- `core-pipeline.theedgestory.org` → Core Pipeline (Production)
- `core-pipeline.dev.theedgestory.org` → Core Pipeline (Development)
- `grafana.theedgestory.org` → Grafana Monitoring

## 🔧 Step 4: Post-Deployment Configuration

### 1. Configure Authentik SSO

```bash
# Get Authentik URL
kubectl get ingress -n authentik

# Create recovery key
kubectl exec -it -n authentik $(kubectl get pod -n authentik -l app.kubernetes.io/name=authentik-server -o name | head -1) -- \
  ak create_recovery_key 10 akadmin

# Access Authentik at: https://auth.theedgestory.org
# Default admin: akadmin
```

### 2. Add Google OAuth (Optional)

Edit `environments/production/secrets/values.yaml`:
```yaml
authentik:
  google:
    clientId: "your-google-client-id"
    clientSecret: "your-google-client-secret"
```

### 3. Verify Services

```bash
# Check all pods
kubectl get pods -A

# Check services
kubectl get svc -A

# Check application logs
kubectl logs -n core-pipeline-prod -l app.kubernetes.io/name=core-pipeline
kubectl logs -n dcmaidbot -l app.kubernetes.io/name=dcmaidbot
```

## 📊 Step 5: Access Your Applications

After deployment, your applications will be available at:

- **Authentik SSO**: https://auth.theedgestory.org
- **Core Pipeline (Prod)**: https://core-pipeline.theedgestory.org
- **Core Pipeline (Dev)**: https://core-pipeline.dev.theedgestory.org
- **Grafana**: https://grafana.theedgestory.org
- **DCMaidBot**: Running as Telegram bot

## 🔄 Step 6: Updates and Maintenance

### Update Applications

```bash
# Edit values file
nano environments/production/core-pipeline-prod-values.yaml

# Apply changes
cd /opt/core-charts
helmfile -e production apply
```

### Restart Services

```bash
# Restart specific application
kubectl rollout restart deployment/core-pipeline -n core-pipeline-prod

# Check rollout status
kubectl rollout status deployment/core-pipeline -n core-pipeline-prod
```

### Backup Databases

```bash
# Backup PostgreSQL
kubectl exec -n infrastructure postgresql-0 -- pg_dumpall -U postgres > backup.sql

# Copy backup locally
scp root@46.62.223.198:/root/backup.sql ./backup-$(date +%Y%m%d).sql
```

## 🚨 Troubleshooting

### Pods Not Starting

```bash
# Describe pod for errors
kubectl describe pod -n <namespace> <pod-name>

# View logs
kubectl logs -n <namespace> <pod-name> -f
```

### Cloudflare Tunnel Issues

```bash
# Check cloudflared status
systemctl status cloudflared

# View logs
journalctl -u cloudflared -f
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
kubectl exec -it -n infrastructure postgresql-0 -- psql -U postgres

# Check Redis
kubectl exec -it -n infrastructure redis-master-0 -- redis-cli
```

## 📝 Important Notes

1. **Store your passwords securely** - The generate-secrets.sh script outputs all passwords
2. **No SSL certificates needed** - Cloudflare tunnel handles TLS termination
3. **All traffic goes through Cloudflare** - No direct server exposure
4. **Monitor resource usage** - Check Grafana for system metrics
5. **Regular backups** - Set up automated database backups

## 🎯 Success Criteria

✅ All pods running and healthy
✅ Applications accessible via Cloudflare tunnel
✅ Authentik SSO working
✅ Databases initialized
✅ Monitoring active
✅ No hardcoded secrets in git

## 📞 Support

If you encounter issues:

1. Check logs: `kubectl logs -n <namespace> <pod-name>`
2. Check pod status: `kubectl get pods -A`
3. Check ingress: `kubectl get ingress -A`
4. Review this guide
5. Check the official documentation links in docs/README.md