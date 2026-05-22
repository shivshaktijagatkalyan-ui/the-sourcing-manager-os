# Security Policy

## Overview

This document outlines security best practices for the Sourcing Manager OS project, including container security, secrets management, and vulnerability scanning.

---

## Secrets Management

### Local Development (.env)

1. **Create .env file from template:**
   ```bash
   cp .env.example .env
   ```

2. **Fill in your development secrets:**
   ```bash
   # .env (gitignored)
   SUPABASE_URL=http://127.0.0.1:54321
   SUPABASE_ANON_KEY=your-key-here
   PHONE_ENCRYPTION_KEY=your-key-here
   ```

3. **Never commit .env to git:**
   ```bash
   # Already in .gitignore
   .env
   .env.local
   .env.*.local
   ```

### Production Secrets

**DO NOT store secrets in:**
- ❌ Environment variables in docker-compose.yml
- ❌ Docker images (Dockerfile ENV)
- ❌ Git repositories
- ❌ Docker layer cache

**Instead use:**
- ✅ HashiCorp Vault
- ✅ AWS Secrets Manager
- ✅ Azure Key Vault
- ✅ Google Secret Manager
- ✅ Docker Secrets (Swarm)

**Example: Using HashiCorp Vault**
```bash
# Start Vault
vault server -dev

# Set secret
vault kv put secret/sourcing-manager \
  SUPABASE_ANON_KEY="your-key" \
  PHONE_ENCRYPTION_KEY="your-key"

# Retrieve secret (in container startup script)
vault kv get -field=SUPABASE_ANON_KEY secret/sourcing-manager
```

**Example: Using AWS Secrets Manager**
```bash
# Store secret
aws secretsmanager create-secret \
  --name sourcing-manager/prod \
  --secret-string '{"SUPABASE_ANON_KEY":"...", "PHONE_ENCRYPTION_KEY":"..."}'

# Retrieve secret
aws secretsmanager get-secret-value --secret-id sourcing-manager/prod
```

---

## Container Security

### Resource Limits

All services have resource limits to prevent denial-of-service:

| Service | CPU Limit | Memory Limit | CPU Reservation | Memory Reservation |
|---------|-----------|--------------|------------------|-------------------|
| Proxy | 0.5 | 256M | 0.25 | 128M |
| Web Dashboard | 1.0 | 512M | 0.5 | 256M |
| Flutter App | 0.5 | 256M | 0.25 | 128M |

Production settings (docker-compose.prod.yml):

| Service | CPU Limit | Memory Limit | CPU Reservation | Memory Reservation |
|---------|-----------|--------------|------------------|-------------------|
| Proxy | 1.0 | 512M | 0.5 | 256M |
| Web Dashboard | 2.0 | 1G | 1.0 | 512M |
| Flutter App | 1.0 | 512M | 0.5 | 256M |

### Capabilities Dropping

All services drop unnecessary Linux capabilities:

```yaml
cap_drop:
  - ALL           # Drop all capabilities

cap_add:
  - NET_BIND_SERVICE  # Only add what's needed
```

**Capabilities Reference:**
- `NET_BIND_SERVICE` – Bind to ports < 1024
- `NET_RAW` – Raw socket access (dropped for Flutter)
- `SYS_ADMIN` – System administration (dangerous, always drop)
- `SYS_PTRACE` – Process tracing (dangerous, always drop)

### Read-Only Filesystems

Root filesystem is read-only; only /tmp and runtime directories are writable:

```yaml
read_only: true
tmpfs:
  - /tmp:rw
  - /var/run:rw
  - /var/cache:rw
```

Benefits:
- ✅ Prevents unauthorized filesystem modifications
- ✅ Makes rootkit/malware installation impossible
- ✅ Immutable application code

### Non-Root Users

All services run as non-root:
- **Proxy**: `nginx` user (UID 101)
- **Web Dashboard**: `node` user (UID 1000)
- **Flutter App**: `nginx` user (UID 101)

Verification:
```bash
docker exec sourcing-manager-web id
# uid=1000(node) gid=1000(node) groups=1000(node)
```

### no-new-privileges

All services use `no-new-privileges`:
```yaml
security_opt:
  - no-new-privileges:true
```

Prevents privilege escalation through setuid/setgid binaries.

---

## Vulnerability Scanning

### Docker Scout (Built-in)

Automatically scans images on push to check for known CVEs:

```bash
# Manual scan
docker scout cves ghcr.io/yourrepo/sourcing-manager:latest

# Output example
CVES  COUNT
critical  2
high      5
medium   12
low       8
```

### GitHub Actions Integration

CI/CD automatically:
1. Builds images
2. Scans with Docker Scout
3. Scans with Trivy filesystem
4. Comments on PRs with vulnerability summary
5. Uploads SARIF reports to GitHub Security tab

**Workflow:** `.github/workflows/docker-build.yml`

**Trigger:** On push to main/develop, PRs, or manual trigger

**Scan Results:**
- Dashboard: GitHub → Security → Code scanning alerts
- PR Comments: Vulnerability summary on each PR
- SARIF Reports: Machine-readable format for CI/CD integration

### Trivy Scanner

Comprehensive vulnerability scanner:

```bash
# Scan image
trivy image ghcr.io/yourrepo/sourcing-manager:latest

# Scan filesystem
trivy fs ./

# Fail on high/critical
trivy image --severity HIGH,CRITICAL ghcr.io/yourrepo/sourcing-manager:latest
```

---

## Image Security

### Docker Hardened Images (DHI)

Base images are hardened with:
- ✅ Minimal attack surface
- ✅ Pre-scanned for CVEs
- ✅ Non-root users included
- ✅ Read-only filesystem support
- ✅ Signed and verified

Current images:
- `docker/dhi-node:24-alpine3.21` – Web Dashboard
- `docker/dhi-nginx:1-alpine3.21` – Proxy & Flutter App

### Image Signing

Future: Sign images with Notary/Cosign:
```bash
# Sign image
cosign sign --key cosign.key ghcr.io/yourrepo/sourcing-manager:latest

# Verify signature
cosign verify --key cosign.pub ghcr.io/yourrepo/sourcing-manager:latest
```

---

## Network Security

### Isolated Network

Services communicate on private bridge network (172.22.0.0/16):
- Internal communication via service DNS names
- No exposure to host network
- Prevents unintended traffic

### TLS/SSL Configuration

Future: Add SSL certificates:
```bash
# Generate self-signed cert (development)
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes

# Place in ./ssl/
mkdir -p ssl
cp key.pem ssl/
cp cert.pem ssl/
```

---

## Incident Response

### Container Compromise Detection

If container is compromised:
1. **Immediately stop:** `docker stop <container>`
2. **Preserve logs:** `docker logs <container> > logs.txt`
3. **Inspect volume:** `docker run -it -v <volume>:/data alpine sh`
4. **Check capabilities:** `docker inspect <container> | jq '.CapAdd'`
5. **Review iptables:** `docker exec <container> iptables -L`

### Rollback Procedure

```bash
# Rollback to previous image
docker pull ghcr.io/repo/sourcing-manager:previous-tag
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --no-build

# Or use image digest (immutable)
docker compose pull --digest
```

---

## Regular Security Audits

**Weekly:**
- [ ] Review vulnerability scan results
- [ ] Check for new base image updates

**Monthly:**
- [ ] Rotate secrets (PHONE_ENCRYPTION_KEY, API keys)
- [ ] Review access logs
- [ ] Update base images

**Quarterly:**
- [ ] Security audit of Dockerfile changes
- [ ] Penetration testing
- [ ] Update security policy

---

## References

- [OWASP Container Security Top 10](https://owasp.org/www-project-container-security/)
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [NIST Container Security Guidelines](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
