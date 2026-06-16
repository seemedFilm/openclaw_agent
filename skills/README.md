# OpenClaw Custom Skills

Übersicht über Custom Skills für das OpenClaw Multi-Agent-System.

## 📋 Übersicht

Custom Skills erweitern die Fähigkeiten der OpenClaw-Agents mit spezialisierten Funktionalitäten. Skills sind wiederverwendbare Module, die von mehreren Agents genutzt werden können.

**Status:** Phase 3 (In Arbeit - 2/3 Skills fertig)

---

## 🎯 Verfügbare Skills

### 1. Traefik-Manager

**Status:** 📅 Geplant (Phase 3)

**Purpose:** Remote-Management von Traefik-Konfigurationen via SSH.

**Capabilities:**
- Route-Management (Add/Update/Delete)
- Middleware-Konfiguration (CORS, Rate-Limiting, Auth)
- SSL-Zertifikat-Management
- Health-Monitoring
- Load-Balancer-Konfiguration

**Verwendung:**
```yaml
# In Agent-Config
skills:
  - name: "traefik-manager"
    enabled: true
    config:
      remote_host: "192.168.1.23"
      ssh_user: "root"
      config_path: "/docker/volume/traefik/config"
```

**Operations:**

```bash
# Route hinzufügen
traefik-manager add-route \
  --domain api.example.com \
  --backend http://192.168.1.50:8080 \
  --ssl letsencrypt

# Middleware hinzufügen
traefik-manager add-middleware \
  --name rate-limit-api \
  --type rate-limit \
  --config "average: 100, burst: 200"

# SSL-Zertifikat erneuern
traefik-manager renew-cert \
  --domain api.example.com
```

**Dokumentation:** [traefik-manager/README.md](traefik-manager/README.md)

---

### 2. Cert-Manager

**Status:** ✅ Implementiert (Phase 3)

**Purpose:** Automatisches SSL-Zertifikat-Management mit Web-Interface und OpenClaw-Integration.

**Capabilities:**
- **Web-Interface:** Dashboard für Zertifikatsverwaltung (Port 5000)
- **REST API:** FastAPI-Backend für Web-UI und OpenClaw
- **Dual Certificate Sources:** step-ca (192.168.1.3) + Let's Encrypt (Traefik)
- **Auto-Renewal:** Monitoring und automatische Erneuerung 30 Tage vor Ablauf
- **Audit-Logging:** Vollständige Operations-History

**Verwendung:**

**Web-UI:**
```bash
# Traefik-Route einrichten
/opt/openclaw/skills/traefik-service-manager/traefik-service-manager.sh add \
  --hostname certs.internal \
  --backend http://192.168.1.11:5000

# Öffne: https://certs.internal
```

**REST API:**
```bash
# Zertifikat erstellen
curl -X POST http://localhost:5001/api/certs \
  -H "Content-Type: application/json" \
  -d '{"hostname":"myapp.internal","type":"step-ca","auto_renew":true}'

# Zertifikate auflisten
curl http://localhost:5001/api/certs

# Zertifikat erneuern
curl -X POST http://localhost:5001/api/certs/myapp.internal/renew
```

**OpenClaw Integration:**
```python
# Im ops-agent
import requests
response = requests.post('http://localhost:5001/api/certs', json={
    'hostname': 'myapp.internal',
    'type': 'step-ca',
    'auto_renew': True
})
```

**Dokumentation:** [cert-manager/README.md](cert-manager/README.md)

---

## 🛠️ Skill-Entwicklung (Phase 3)

### Skill-Struktur

Jeder Custom Skill folgt dieser Verzeichnisstruktur:

```
skills/
└── my-skill/
    ├── README.md              # Dokumentation
    ├── config.schema.yaml     # Config-Schema (JSON Schema)
    ├── skill.ts               # Hauptimplementation
    ├── operations/            # Skill-Operationen
    │   ├── operation-1.ts
    │   └── operation-2.ts
    ├── utils/                 # Utility-Functions
    │   └── helpers.ts
    ├── tests/                 # Tests
    │   └── skill.test.ts
    └── examples/              # Verwendungsbeispiele
        └── example.md
```

### Skill-API

```typescript
// skill.ts
import { Skill, SkillContext, SkillResult } from '@openclaw/sdk';

export class MySkill extends Skill {
  name = 'my-skill';
  version = '1.0.0';
  description = 'Description of what this skill does';

  async execute(
    operation: string,
    params: Record<string, any>,
    context: SkillContext
  ): Promise<SkillResult> {
    switch (operation) {
      case 'operation-1':
        return this.operation1(params, context);
      case 'operation-2':
        return this.operation2(params, context);
      default:
        throw new Error(`Unknown operation: ${operation}`);
    }
  }

  private async operation1(
    params: any,
    context: SkillContext
  ): Promise<SkillResult> {
    // Implementation
    return {
      success: true,
      data: { ... },
      message: 'Operation completed successfully'
    };
  }
}
```

### Config-Schema

```yaml
# config.schema.yaml
$schema: "http://json-schema.org/draft-07/schema#"
title: "MySkill Configuration"
type: object
properties:
  enabled:
    type: boolean
    default: true
  config:
    type: object
    properties:
      remote_host:
        type: string
        description: "Remote host IP or hostname"
      ssh_user:
        type: string
        default: "root"
      timeout:
        type: number
        default: 30000
    required:
      - remote_host
```

### Skill-Registrierung

```bash
# Skill registrieren
openclaw skill register my-skill --path ./skills/my-skill

# Skill aktivieren für Agent
openclaw agent add-skill ops-agent my-skill

# Skill testen
openclaw skill test my-skill --operation operation-1 --params '{...}'
```

---

## 🔄 Integration mit Agents

### In Agent-Config

```yaml
# agents/ops-agent/config.yaml
skills:
  - name: "traefik-manager"
    enabled: true
    priority: "high"
    config:
      remote_host: "192.168.1.23"
      ssh_user: "root"

  - name: "cert-manager"
    enabled: true
    priority: "high"
    config:
      provider: "letsencrypt"
      email: "ops@example.com"
```

### Von Agent aufrufen

```typescript
// Im Agent-Code
const result = await this.executeSkill('traefik-manager', 'add-route', {
  domain: 'api.example.com',
  backend: 'http://192.168.1.50:8080',
  ssl: true
});

if (result.success) {
  console.log('Route added successfully');
}
```

---

## 📚 Best Practices

### Skill-Design

✅ **Single Responsibility:** Ein Skill = Eine Domäne (z.B. nur Traefik)
✅ **Idempotenz:** Mehrfaches Ausführen = Gleiches Ergebnis
✅ **Error Handling:** Klare Error-Messages mit Kontext
✅ **Logging:** Ausführliche Logs für Debugging
✅ **Testing:** Unit + Integration Tests
✅ **Documentation:** README mit Beispielen

### Config-Management

```yaml
# Secrets in Environment Variables
skills:
  - name: "my-skill"
    config:
      api_key: "${MY_SKILL_API_KEY}"  # ← Environment Variable
      secret: "${MY_SKILL_SECRET}"
```

### Error Handling

```typescript
try {
  const result = await skill.execute('operation', params);
  return result;
} catch (error) {
  logger.error('Skill execution failed', {
    skill: 'my-skill',
    operation: 'operation',
    error: error.message,
    params
  });
  throw new SkillExecutionError(error.message, { cause: error });
}
```

---

## 🔐 Sicherheit

### SSH-Keys

**Setup für Remote-Skills:**

```bash
# SSH-Key generieren
ssh-keygen -t ed25519 -C "openclaw-skills" -f ~/.ssh/openclaw_skills

# Public Key auf Remote-Host
ssh-copy-id -i ~/.ssh/openclaw_skills.pub root@192.168.1.23

# In Agent-Config
skills:
  - name: "traefik-manager"
    config:
      ssh_key_path: "/root/.ssh/openclaw_skills"
```

### Credentials

**❌ NIEMALS:**
- Credentials in Config-Dateien
- API-Keys in Git committen
- Secrets in Logs ausgeben

**✅ IMMER:**
- Environment Variables
- Secret Management (Vault, AWS Secrets Manager)
- Verschlüsselte Configs

---

## 📖 Weitere Dokumentation

- **Traefik-Manager:** [traefik-manager/README.md](traefik-manager/README.md)
- **Cert-Manager:** [cert-manager/README.md](cert-manager/README.md)
- **Agent-Übersicht:** [../agents/README.md](../agents/README.md)
- **Quick Reference:** [../docs/QUICK-REFERENCE.md](../docs/QUICK-REFERENCE.md)

---

## 🗺️ Roadmap

### Phase 3 (In Arbeit - 2/3 fertig)
- [x] **Traefik-Manager Skill** ✅
  - [x] Route-Management
  - [x] Middleware-Configuration
  - [x] Health-Monitoring
  - [x] step-ca & Let's Encrypt Integration

- [x] **Cert-Manager Skill** ✅
  - [x] Web-Interface (Dashboard)
  - [x] REST API (FastAPI)
  - [x] step-ca Integration
  - [x] Let's Encrypt Integration
  - [x] Auto-Renewal Scheduler
  - [x] Audit-Logging

- [ ] **Monitoring & Alerting Skill** 🚧
  - [ ] Prometheus Integration
  - [ ] Alert-Manager
  - [ ] Grafana Dashboards

### Phase 4 (Zukünftig)
- [ ] **Deployment-Automation Skill**
  - [ ] Blue-Green Deployments
  - [ ] Rollback Automation
  - [ ] Health Checks

- [ ] **Monitoring Skill**
  - [ ] Prometheus Integration
  - [ ] Grafana Dashboard Creation
  - [ ] Alert Management

---

**Version:** 1.0.0  
**Status:** Phase 3 Planung  
**Letzte Aktualisierung:** 2026-06-02
