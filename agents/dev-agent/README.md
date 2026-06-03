# Dev-Agent - Development Agent

Automatisierte Code-Entwicklung mit Claude Sonnet 4.6 via AWS Bedrock.

## 📋 Übersicht

Der **Dev-Agent** ist ein senior software engineer agent, der Teil des OpenClaw Multi-Agent-Systems ist. Er ist spezialisiert auf:

- ✅ Code-Entwicklung (Features, APIs, UI-Komponenten)
- ✅ Debugging und Fehleranalyse
- ✅ Code-Refactoring und Optimierung
- ✅ Git-Operations und Workflow-Automation
- ✅ Test-Driven Development
- ✅ Dokumentation

**Status:** ✅ Production-Ready (Phase 2)

**Model:** Claude Sonnet 4.6 via LiteLLM/Bedrock (`eu.anthropic.claude-sonnet-4-6`)

---

## 🎯 Capabilities

### Core Development

| Capability | Beschreibung | Priorität |
|------------|--------------|-----------|
| **Code Generation** | Neue Features von Spec implementieren | Hoch |
| **Bug Fixing** | Fehler analysieren und beheben | Hoch |
| **Refactoring** | Code-Qualität verbessern | Hoch |
| **Debugging** | Root-Cause-Analyse mit Tools | Hoch |
| **Testing** | Unit/Integration/E2E-Tests | Mittel |
| **Documentation** | Code-Dokumentation | Niedrig |

### Unterstützte Sprachen

```
JavaScript/TypeScript  → Node.js, React, Vue, Angular
Python                → Django, Flask, FastAPI
Go                   → Gin, Echo, standard library
Rust                 → Actix, Rocket, Tokio
SQL                  → PostgreSQL, MySQL, SQLite
```

### Git Operations

```bash
# Branch Management
✅ Create, switch, merge, rebase branches
✅ Conflict resolution
✅ Interactive rebase

# Commit Workflow
✅ Conventional commit messages
✅ Atomic commits
✅ Commit message templates

# Pull Requests
✅ PR creation with descriptions
✅ Auto-assign reviewers
✅ Link to issues
```

---

## 🏗️ Architektur

```
┌──────────────────────────────────────────────────────────┐
│                       User Request                        │
└─────────────────────┬────────────────────────────────────┘
                      │
                      ▼
┌──────────────────────────────────────────────────────────┐
│                      Dev-Agent                            │
│  ┌────────────────────────────────────────────────────┐  │
│  │            Claude Sonnet 4.6 (LiteLLM)             │  │
│  │         eu.anthropic.claude-sonnet-4-6             │  │
│  └────────────────────────────────────────────────────┘  │
│                          │                                │
│         ┌────────────────┼────────────────┐              │
│         │                │                │              │
│         ▼                ▼                ▼              │
│  ┌──────────┐   ┌──────────────┐  ┌─────────────┐      │
│  │   Git    │   │ Language     │  │  Testing    │      │
│  │ Operations│   │  Servers     │  │  Tools      │      │
│  └──────────┘   └──────────────┘  └─────────────┘      │
│         │                │                │              │
└─────────┼────────────────┼────────────────┼──────────────┘
          │                │                │
          ▼                ▼                ▼
┌──────────────────────────────────────────────────────────┐
│                   File System / Git                       │
│  src/  tests/  docs/  .git/  node_modules/  ...          │
└──────────────────────────────────────────────────────────┘
          │
          ├──────────────┐─────────────┐
          ▼              ▼             ▼
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│Review-Agent │  │Security-Agent│  │ Ops-Agent   │
│             │  │             │  │             │
│ Code Review │  │ Vuln-Scan   │  │ Deployment  │
└─────────────┘  └─────────────┘  └─────────────┘
```

### Workflow

```
1. User Request
   │
2. Dev-Agent analyzes request
   │
3. Code Implementation
   │   ├─ Read existing code
   │   ├─ Generate new code
   │   ├─ Run tests
   │   └─ Validate changes
   │
4. Git Operations
   │   ├─ Stage changes
   │   ├─ Commit with message
   │   └─ Push to remote
   │
5. Notify Other Agents
   │   ├─ Review-Agent → Code Review
   │   ├─ Security-Agent → Security Scan
   │   └─ Ops-Agent → Deployment (if ready)
   │
6. Return Result to User
```

---

## ⚙️ Konfiguration

### Config-Datei

**Speicherort:** `agents/dev-agent/config.yaml`

**Struktur:**
```yaml
agent:
  name: "dev-agent"
  model: "claude-sonnet-4-6"
  
provider:
  type: "litellm"
  base_url: "http://localhost:4000"
  api_key: "bedrock"

skills:
  - name: "code-generation"
    enabled: true
  - name: "git-operations"
    enabled: true
    config:
      commit_message_format: "conventional-commits"

memory:
  persistent: true
  scope: "project"

triggers:
  - event: "file_changed"
    action: "analyze_changes"
```

### Environment Variables

```bash
# LiteLLM Proxy
ANTHROPIC_BASE_URL="http://localhost:4000"
ANTHROPIC_API_KEY="bedrock"

# AWS Bedrock
AWS_ACCESS_KEY_ID="AKIA..."
AWS_SECRET_ACCESS_KEY="..."
AWS_REGION_NAME="eu-central-1"

# GitHub (optional, für PR-Operationen)
GITHUB_TOKEN="ghp_..."

# Logging
LOG_LEVEL="INFO"
LOG_FILE="/opt/openclaw/logs/dev-agent.log"
```

### Skills aktivieren/deaktivieren

```yaml
# In config.yaml
skills:
  - name: "code-generation"
    enabled: true  # ✅ Aktiviert
    
  - name: "documentation"
    enabled: false  # ❌ Deaktiviert
```

---

## 🚀 Deployment

### Voraussetzungen

- ✅ LXC Container mit Ubuntu 24.04 LTS
- ✅ OpenClaw CLI installiert (`/usr/local/bin/openclaw`)
- ✅ LiteLLM Proxy läuft auf Port 8000
- ✅ Git, Node.js, Python installiert
- ✅ Systemd Service Template vorhanden

### Installation

#### 1. Agents auf Container kopieren

```bash
# Auf lokalem Rechner
cd /path/to/openclaw
scp -r agents/dev-agent root@192.168.1.11:/opt/openclaw/agents/
```

#### 2. Agent registrieren

```bash
# Auf Container (SSH)
ssh root@192.168.1.11

cd /opt/openclaw/agents
openclaw agent register dev-agent --config dev-agent/config.yaml
```

**Expected Output:**
```
✅ Agent "dev-agent" successfully registered
   Model: claude-sonnet-4-6
   Skills: 7 enabled
   Status: Ready
```

#### 3. Systemd Service aktivieren

```bash
# Enable & start service
systemctl enable openclaw-agent@dev
systemctl start openclaw-agent@dev

# Check status
systemctl status openclaw-agent@dev
```

**Expected Output:**
```
● openclaw-agent@dev.service - OpenClaw Agent: dev
     Loaded: loaded (/etc/systemd/system/openclaw-agent@.service)
     Active: active (running) since ...
```

#### 4. Verifikation

```bash
# List all agents
openclaw agent list

# Test dev-agent
openclaw chat --agent dev-agent --message "Hello, can you help me with code?"

# Check logs
tail -f /opt/openclaw/logs/dev-agent.log
```

### Automatisches Deployment

Mit dem Deployment-Script:

```bash
cd proxmox
bash deploy-agents.sh
```

Das Script:
1. ✅ Kopiert alle Agents per SCP
2. ✅ Registriert alle Agents
3. ✅ Aktiviert Systemd Services
4. ✅ Führt Verifikation durch
5. ✅ Gibt Status-Report aus

---

## 💻 Verwendung

### Interaktive Session

```bash
# Starte Agent
openclaw agent start dev-agent

# Interaktive Chat-Session
openclaw chat --agent dev-agent
```

**Beispiel-Session:**
```
You: Implement a REST API endpoint for user registration

Dev-Agent: I'll implement a POST /auth/register endpoint with the following:
1. Email & password validation
2. Password hashing with bcrypt
3. User creation in database
4. Return user object (without password)

Let me create the files:
[... code implementation ...]

Done! Created:
- src/auth/auth.controller.ts
- src/auth/user.model.ts
- src/auth/auth.test.ts

Commit message:
[dev-agent] feat: add user registration endpoint
...
```

### Task-basierte Nutzung

```bash
# Direkter Task ohne Interactive Mode
openclaw agent run dev-agent --task "Fix bug #123: Login fails with 500 error"
```

**Task wird ausgeführt:**
1. Agent analysiert Issue #123
2. Identifiziert Root Cause
3. Implementiert Fix
4. Erstellt Tests
5. Committed Changes
6. Notifiziert Review-Agent

### CLI Commands

```bash
# Agent-Status
openclaw agent status dev-agent

# Agent-Logs
openclaw agent logs dev-agent --follow

# Agent stoppen
openclaw agent stop dev-agent

# Agent neu laden (nach Config-Änderung)
openclaw agent reload dev-agent

# Agent-Metriken
openclaw agent metrics dev-agent
```

---

## 📖 Beispiele

### Beispiel 1: Feature implementieren

**Task:**
```bash
openclaw agent run dev-agent --task "
Implement JWT authentication:
- POST /auth/register endpoint
- POST /auth/login endpoint (returns JWT)
- JWT middleware for protected routes
- Unit tests with >90% coverage
"
```

**Ergebnis:**
```
✅ Feature implementation complete

Files created:
- src/auth/auth.controller.ts      (120 lines)
- src/auth/auth.middleware.ts      (45 lines)
- src/auth/user.model.ts           (35 lines)
- src/auth/auth.test.ts            (180 lines)

Tests:
- 15 tests passed
- Coverage: 94%

Commit:
[dev-agent] feat: implement JWT authentication
SHA: abc123def456

Next steps:
- Review-Agent notified for code review
- Security-Agent will scan for vulnerabilities
```

### Beispiel 2: Bug fixen

**Task:**
```bash
openclaw agent run dev-agent --task "
Fix bug #456: Users can't login with passwords containing special characters

Steps:
1. Reproduce the issue
2. Identify root cause
3. Implement fix
4. Add test case to prevent regression
"
```

**Ablauf:**

**1. Reproduktion:**
```bash
Dev-Agent: Reproducing issue...
Testing with password: "P@ssw0rd#123$"
Result: 500 Internal Server Error ✗
```

**2. Root Cause:**
```bash
Dev-Agent: Root cause identified:
- Location: src/auth/auth.controller.ts:42
- Issue: bcrypt.compare() fails with special chars
- Reason: Password not properly URL-decoded
```

**3. Fix:**
```typescript
// Before
const { password } = req.body;

// After
const { password } = req.body;
const decodedPassword = decodeURIComponent(password);
```

**4. Test:**
```typescript
it('should handle special characters in password', async () => {
  const password = 'P@ssw0rd#123$';
  const response = await login(email, password);
  expect(response.status).toBe(200);
});
```

**Commit:**
```
[dev-agent] fix: handle special characters in passwords

Fixed 500 error when logging in with passwords containing
special characters (@, #, $, etc.)

Root cause: Password not URL-decoded before bcrypt.compare()

Changes:
- Added URL decoding step
- Added test case for special characters
- Updated password validation regex

Fixes: #456

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

### Beispiel 3: Refactoring

**Task:**
```bash
openclaw agent run dev-agent --task "
Refactor authentication code:
- Extract business logic to service layer
- Implement dependency injection
- Update tests to use mocks
- Maintain 100% backwards compatibility
"
```

**Änderungen:**

**1. Service Layer:**
```typescript
// NEW: src/auth/auth.service.ts
export class AuthService {
  constructor(
    private userRepo: UserRepository,
    private jwtService: JWTService
  ) {}
  
  async register(email: string, password: string): Promise<User> {
    // Business logic here
  }
}
```

**2. Controller Update:**
```typescript
// UPDATED: src/auth/auth.controller.ts
export class AuthController {
  constructor(private authService: AuthService) {}
  
  register = async (req, res) => {
    const user = await this.authService.register(req.body.email, req.body.password);
    return res.json(user);
  };
}
```

**3. Tests:**
```typescript
// UPDATED: src/auth/auth.test.ts
describe('AuthService', () => {
  let service: AuthService;
  let mockUserRepo: jest.Mocked<UserRepository>;
  
  beforeEach(() => {
    mockUserRepo = createMock<UserRepository>();
    service = new AuthService(mockUserRepo, mockJwtService);
  });
  
  // Tests mit Mocks
});
```

**Commit:**
```
[dev-agent] refactor: implement service layer for auth

Refactored authentication to use service layer pattern:
- Created AuthService for business logic
- Injected dependencies (UserRepository, JWTService)
- Updated tests to use mocks
- 100% backwards compatible (API unchanged)

Benefits:
- Better testability
- Clear separation of concerns
- Easier to maintain

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

---

## 🔄 Integration mit anderen Agents

### Review-Agent

**Wann wird notifiziert:**
- Nach Commit
- Vor PR-Erstellung
- Bei Code-Änderungen in kritischen Dateien

**Datenaustausch:**
```yaml
event: code_committed
data:
  commit_sha: "abc123def"
  files_changed:
    - "src/auth/auth.controller.ts"
    - "src/auth/auth.test.ts"
  test_coverage: 94
  description: "Implemented JWT authentication"
```

**Review-Agent-Antwort:**
```yaml
status: "approved"  # oder "changes_requested"
comments:
  - file: "src/auth/auth.controller.ts"
    line: 42
    message: "Consider adding rate limiting"
suggestions:
  - "Add input validation for email format"
  - "Increase JWT expiration to 7 days"
```

### Security-Agent

**Wann wird notifiziert:**
- Nach Dependency-Änderungen (`package.json`, `requirements.txt`)
- Bei Auth/Authz-Änderungen
- Vor Production-Deployment

**Datenaustausch:**
```yaml
event: dependency_added
data:
  package: "jsonwebtoken"
  version: "9.0.0"
  type: "dependency"
```

**Security-Agent-Antwort:**
```yaml
scan_result:
  vulnerabilities: []
  status: "PASSED"
  recommendations:
    - "Consider upgrading to latest patch version"
```

### Ops-Agent

**Wann wird notifiziert:**
- Bei Deployment-Ready-Status
- Nach Datenbank-Migrations
- Bei Infrastructure-Änderungen

**Datenaustausch:**
```yaml
event: deployment_ready
data:
  branch: "feature/jwt-auth"
  environment: "staging"
  migrations:
    - "001_create_users_table.sql"
  env_vars_required:
    - "JWT_SECRET"
    - "DATABASE_URL"
```

---

## 🐛 Troubleshooting

### Agent startet nicht

**Problem:**
```bash
systemctl status openclaw-agent@dev
● openclaw-agent@dev.service - failed
```

**Lösung:**

```bash
# 1. Check Logs
journalctl -u openclaw-agent@dev -n 50 --no-pager

# 2. Häufige Ursachen:
# - LiteLLM Proxy nicht erreichbar
curl http://localhost:4000/health

# - Config-Datei ungültig
openclaw agent validate dev-agent

# - OpenClaw CLI fehlt
which openclaw

# 3. Neu starten
systemctl restart openclaw-agent@dev
```

### LiteLLM Proxy nicht erreichbar

**Problem:**
```
Error: Connection refused to http://localhost:4000
```

**Lösung:**

```bash
# 1. Check LiteLLM Service
systemctl status litellm-proxy

# 2. Neu starten falls nötig
systemctl restart litellm-proxy

# 3. Test API
curl -X POST http://localhost:4000/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "claude-sonnet-4-6", "messages": [{"role": "user", "content": "test"}]}'
```

### Git-Operations schlagen fehl

**Problem:**
```
Error: Permission denied (publickey)
```

**Lösung:**

```bash
# 1. SSH-Key prüfen
ssh -T git@github.com

# 2. GitHub Token setzen (falls HTTPS)
git config --global credential.helper store
echo "https://<TOKEN>@github.com" > ~/.git-credentials

# 3. Alternativ: SSH-Key hinzufügen
ssh-keygen -t ed25519 -C "dev-agent@openclaw"
cat ~/.ssh/id_ed25519.pub
# → Key zu GitHub hinzufügen
```

### Code-Generation schlägt fehl

**Problem:**
```
Error: Unable to generate code - model returned empty response
```

**Mögliche Ursachen:**

1. **Rate Limit erreicht:**
   ```bash
   # Warte 60 Sekunden und versuche erneut
   sleep 60
   openclaw agent run dev-agent --task "..."
   ```

2. **Token Limit überschritten:**
   ```yaml
   # In config.yaml reduzieren:
   provider:
     max_tokens: 2048  # Statt 4096
   ```

3. **Model nicht verfügbar:**
   ```bash
   # Test Bedrock Zugriff
   aws bedrock list-foundation-models --region eu-central-1
   ```

### Tests schlagen fehl

**Problem:**
```
Error: 12 tests failed
```

**Lösung:**

```bash
# 1. Tests manuell ausführen
npm test  # oder pytest, go test, cargo test

# 2. Logs prüfen
cat /opt/openclaw/logs/dev-agent.log | grep ERROR

# 3. Abhängigkeiten installieren
npm install  # falls package.json geändert wurde

# 4. Test-Umgebung bereinigen
rm -rf node_modules
npm install
npm test
```

### Agent reagiert nicht

**Problem:**
Agent hängt, keine Response

**Lösung:**

```bash
# 1. Check Status
openclaw agent status dev-agent

# 2. Kill und Restart
openclaw agent kill dev-agent
systemctl restart openclaw-agent@dev

# 3. Logs prüfen
tail -f /opt/openclaw/logs/dev-agent.log

# 4. Falls alles fehlschlägt: Reset
openclaw agent reset dev-agent
# ⚠️ Löscht Memory und Session-State!
```

---

## 📊 Monitoring

### Metriken

```bash
# Agent-Metriken anzeigen
openclaw agent metrics dev-agent
```

**Verfügbare Metriken:**

| Metrik | Beschreibung |
|--------|--------------|
| `requests_total` | Anzahl der Requests |
| `requests_success` | Erfolgreiche Requests |
| `requests_failed` | Fehlgeschlagene Requests |
| `response_time_avg` | Durchschnittliche Response-Zeit |
| `token_usage` | Token-Verbrauch (Input/Output) |
| `code_generated_lines` | Generierte Code-Zeilen |
| `commits_created` | Anzahl Commits |

### Logs

```bash
# Live-Logs
tail -f /opt/openclaw/logs/dev-agent.log

# Logs durchsuchen
grep "ERROR" /opt/openclaw/logs/dev-agent.log

# Logs nach Zeit
journalctl -u openclaw-agent@dev --since "1 hour ago"
```

**Log-Format (JSON):**
```json
{
  "timestamp": "2026-06-02T14:30:00Z",
  "level": "INFO",
  "agent": "dev-agent",
  "message": "Code generation completed",
  "context": {
    "task": "implement-jwt-auth",
    "files_changed": 4,
    "lines_added": 234,
    "duration_ms": 1523
  }
}
```

### Prometheus Integration

```bash
# Metrics Endpoint
curl http://localhost:9090/metrics | grep openclaw_dev_agent
```

**Beispiel-Metriken:**
```
# HELP openclaw_dev_agent_requests_total Total requests to dev-agent
# TYPE openclaw_dev_agent_requests_total counter
openclaw_dev_agent_requests_total 1234

# HELP openclaw_dev_agent_response_time_seconds Response time
# TYPE openclaw_dev_agent_response_time_seconds histogram
openclaw_dev_agent_response_time_seconds_bucket{le="1.0"} 980
openclaw_dev_agent_response_time_seconds_bucket{le="5.0"} 1200
```

---

## 🔐 Sicherheit

### Credentials

**❌ NIEMALS:**
- Credentials in Code committen
- API-Keys in Logs ausgeben
- Secrets in Git-History

**✅ IMMER:**
- Environment Variables nutzen
- `.env` in `.gitignore`
- Secrets in sicheren Vaults

### File System Permissions

```bash
# Config-Dateien schützen
chmod 600 /opt/openclaw/agents/dev-agent/config.yaml

# Logs schützen
chmod 640 /opt/openclaw/logs/dev-agent.log
chown root:openclaw /opt/openclaw/logs/dev-agent.log
```

### Git Operations

**Einschränkungen:**
```yaml
# In config.yaml
permissions:
  commands:
    forbidden:
      - "git push --force origin main"  # Force-Push auf main verboten
      - "git reset --hard"              # Destructive resets
```

---

## 📚 Weiterführende Dokumentation

- **System Prompts:** [prompts.md](prompts.md) - Detaillierte Agent-Anweisungen
- **Konfiguration:** [config.yaml](config.yaml) - Vollständige Config-Referenz
- **Skills:** [skills/README.md](skills/README.md) - Dev-spezifische Skills
- **Agent-Übersicht:** [../README.md](../README.md) - Alle Agents
- **Quick Reference:** [../../docs/QUICK-REFERENCE.md](../../docs/QUICK-REFERENCE.md) - Schnellreferenz
- **Getting Started:** [../../docs/GETTING-STARTED.md](../../docs/GETTING-STARTED.md) - Kompletter Guide

---

**Version:** 1.0.0  
**Status:** ✅ Production-Ready  
**Letzte Aktualisierung:** 2026-06-02
