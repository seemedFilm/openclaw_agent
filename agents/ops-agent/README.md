# Ops-Agent - Operations & Infrastructure Agent

Automatisiertes Infrastructure-Management und Traefik-Konfiguration mit Claude Sonnet 4.6.

## 📋 Übersicht

Der **Ops-Agent** ist ein DevOps-Experte für Infrastructure-Management, Deployments und Monitoring.

**Hauptaufgaben:**
- ✅ Traefik-Management (Remote SSH zu 192.168.1.23)
- ✅ SSL-Zertifikat-Erneuerung (Let's Encrypt)
- ✅ Deployment-Automation (Blue-Green, Canary)
- ✅ Monitoring & Alerting
- ✅ Ansible-Playbook-Execution

**Status:** ✅ Production-Ready (Phase 2)  
**Model:** Claude Sonnet 4.6 via LiteLLM/Bedrock

---

## 🎯 Capabilities

| Capability | Description | Priority |
|------------|-------------|----------|
| **Traefik Management** | Remote config via SSH | HIGH |
| **SSL Certificates** | Let's Encrypt auto-renewal | HIGH |
| **Deployments** | Blue-Green, Rolling | HIGH |
| **Monitoring** | Health checks, alerts | MEDIUM |
| **Ansible** | Infrastructure automation | MEDIUM |

---

## 🚀 Usage

### Add Traefik Route

```bash
ssh root@192.168.1.11
openclaw tui
# Select: ops-agent
```

**Message:**
```
Add Traefik route:
- Domain: api.example.com
- Backend: http://192.168.1.50:8080
- SSL: Let's Encrypt
- Middlewares: Rate-Limiting (100 req/s), CORS, Security-Headers
- Health-Check: /health endpoint
```

**Expected Output:**
```markdown
✅ Route added successfully

**Domain:** api.example.com  
**Backend:** http://192.168.1.50:8080  
**SSL:** ✓ Let's Encrypt  
**Health Check:** /health

**Access:** https://api.example.com
```

### Deploy Application

**Message:**
```
Deploy myapp:v2.0.0 to production:
- Strategy: Blue-Green
- Current: http://192.168.1.50:8080
- New: http://192.168.1.51:8080
- Rollback on failure: true
```

---

## 🔧 Traefik Configuration

**Remote Host:** 192.168.1.23  
**Config Path:** `/docker/volume/traefik/config`  
**Container:** `traefik`  
**Access:** SSH as root

All Traefik operations are executed remotely via SSH.

---

## 📊 Deployment Strategies

### Blue-Green
- Zero downtime
- Instant rollback
- Full version switch

### Rolling Update
- Gradual rollout
- Reduced risk
- Slower deployment

### Canary
- Test with subset of users
- Progressive rollout
- Safe experimentation

---

## 📚 Documentation

- **System Prompts:** [prompts.md](prompts.md)
- **Configuration:** [config.yaml](config.yaml)
- **Quick Reference:** [../../docs/QUICK-REFERENCE.md](../../docs/QUICK-REFERENCE.md)

---

**Version:** 1.0.0  
**Status:** ✅ Production-Ready  
**Letzte Aktualisierung:** 2026-06-02
