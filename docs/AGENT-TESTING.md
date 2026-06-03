# 🧪 Agent Testing Guide

Dokumentation der erfolgreichen Agent-Tests und Testing-Best-Practices.

---

## Erfolgreicher End-to-End Test

### Test-Scenario: Password-Checker Development

**Datum:** 2026-06-03  
**Agents getestet:** Dev-Agent, Review-Agent  
**Status:** ✅ Erfolgreich

---

## Test 1: Dev-Agent - Code Development

### Aufgabe
Erstelle eine TypeScript-Funktion `checkPasswordStrength`, die:
- Passwort-Stärke analysiert (Score 0-100)
- Strength-Levels zurückgibt (weak/medium/strong)
- Detailliertes Feedback gibt
- Jest-Tests inkludiert

### Command
```bash
cd /opt/openclaw/workspaces/dev-agent
openclaw agent --agent dev-agent --message "Erstelle eine TypeScript-Funktion \"checkPasswordStrength\", die ein Passwort analysiert und einen Score von 0-100 zurückgibt.

Requirements:
- Länge (min 8 Zeichen)
- Großbuchstaben, Kleinbuchstaben, Zahlen, Sonderzeichen
- Keine häufigen Passwörter (z.B. \"password123\")
- Return: { score: number, strength: \"weak\" | \"medium\" | \"strong\", feedback: string[] }

Erstelle außerdem Jest-Tests dafür.

Speichere die Files in meinem Workspace."
```

### Ergebnis

**Erstellte Files:**
```
src/checkPasswordStrength.ts  - Hauptimplementierung
tests/checkPasswordStrength.test.ts  - Jest-Tests
package.json  - Projekt-Config
tsconfig.json  - TypeScript-Config
jest.config.js  - Jest-Config
```

**Code-Qualität:**
- ✅ Saubere TypeScript-Typen
- ✅ Common-Password-Detection (23 Einträge)
- ✅ Scoring-System mit Penalties
- ✅ Pattern-Detection (Wiederholungen, Sequenzen)
- ✅ Structured Feedback

**Test-Coverage:**
```bash
npm test

PASS tests/checkPasswordStrength.test.ts
  checkPasswordStrength
    return shape
      ✓ returns score, strength and feedback for any input (3 ms)
      ✓ score is always between 0 and 100 (1 ms)
    empty / very short passwords
      ✓ returns score 0 and weak for empty string
      ✓ is weak for a single character (1 ms)
      ✓ flags passwords shorter than 8 characters
    common passwords
      ✓ penalises 'password123'
      ✓ penalises 'qwerty' (common, case-insensitive) (1 ms)
      ✓ penalises '123456'
    character class feedback
      ✓ requests uppercase when missing
      ✓ requests lowercase when missing (1 ms)
      ✓ requests numbers when missing
      ✓ requests special characters when missing (1 ms)
    pattern penalties
      ✓ penalises repeated characters (aaa)
      ✓ penalises sequential patterns (123)
    strength tiers
      ✓ weak: simple short password (1 ms)
      ✓ medium: decent but not great
      ✓ strong: long complex password (1 ms)
    positive feedback
      ✓ gives a compliment when no issues found

Test Suites: 1 passed, 1 total
Tests:       18 passed, 18 total
Snapshots:   0 total
Time:        1.251 s
```

**Bewertung:** ✅ Production-Ready Code

---

## Test 2: Review-Agent - Code Review

### Aufgabe
Reviewe den von Dev-Agent erstellten Password-Checker aus Security- und Code-Quality-Perspektive.

### Command
```bash
openclaw agent --agent review-agent --message "Reviewe bitte die Datei /opt/openclaw/workspaces/dev-agent/src/checkPasswordStrength.ts aus Security- und Code-Quality-Perspektive.

Prüfe:
- Security-Aspekte
- Code-Qualität
- Best Practices
- Potentielle Bugs
- Performance"
```

### Ergebnis

**Review-Kategorien:**

#### ✅ Positive Findings
- Klare Interface-Definition
- O(1) Lookup für Common-Passwords via Set
- Score-Clamping mit Math.max/min
- Gut strukturierte Kommentare

#### 🔴 Security-Probleme (5 gefunden)
1. **Kleine Common-Password-Liste** (nur 23 Einträge)
   - Empfehlung: HaveIBeenPwned Top 100k Liste nutzen
   
2. **Score-Manipulation möglich**
   - Kurze Passwörter können trotzdem "medium" erreichen
   
3. **Keine Max-Länge** → DoS-Risiko bei bcrypt
   - Empfehlung: Max 256 Zeichen
   
4. **Keine Keyboard-Walk-Erkennung**
   - "qwertyuiop", "asdfghjkl" nicht erkannt
   
5. **Timing-Leak bei toLowerCase()** (minor)

#### 🟡 Code-Qualität Issues (4 gefunden)
1. **Score-Logik inkonsistent** bei len < 8
   - 4-Zeichen-Passwort kann "medium" werden
   
2. **Magic Numbers** ohne Konstanten
   - Wartbarkeit leidet
   
3. **Kein Input-Type-Guard**
   - Was bei null/undefined?
   
4. **Variety-Bonus zu niedrig** (+5 für alle 4 Klassen)

#### 🟠 Bugs (2 gefunden)
1. **Sequential-Regex unvollständig**
   - Erkennt nicht: efg, ghi, xyz, rückwärts
   
2. **Feedback-Message misleading**
   - "Great job!" auch bei Score 70 (gerade so strong)

**Top 3 Prioritäten:**
1. 🔴 len < 8 → früh returnen mit "weak"
2. 🔴 Max-Länge einführen (DoS-Schutz)
3. 🟡 Sequential-Regex durch generische Funktion ersetzen

**Bewertung:** ✅ Professional-Grade Review

---

## Agent Testing Best Practices

### 1. Dev-Agent Testing

**Good Tasks:**
- Feature-Implementierung mit klaren Requirements
- Test-Coverage erwarten
- Production-Quality verlangen
- Konkrete Input/Output-Specs geben

**Example Command:**
```bash
openclaw agent --agent dev-agent --message "Erstelle [Feature] mit:
- Requirements: [Liste]
- Tests: [Framework]
- TypeScript/Python
- Error-Handling
- Dokumentation"
```

**Bad Tasks:**
- Vage Anforderungen ("Erstelle etwas Cooles")
- Keine Test-Erwartung
- Fehlende Specs

### 2. Review-Agent Testing

**Good Tasks:**
- Konkreter File-Path angeben
- Mehrere Perspektiven (Security, Quality, Performance)
- Strukturiertes Feedback erwarten

**Example Command:**
```bash
openclaw agent --agent review-agent --message "Reviewe /path/to/file.ts:
- Security-Aspekte
- Code-Qualität
- Best Practices
- Potentielle Bugs
- Performance
Strukturiertes Feedback mit Prioritäten."
```

**Bad Tasks:**
- "Reviewe mal den Code" (zu vage)
- Kein File-Path
- Keine Kriterien

### 3. Security-Agent Testing

**Good Tasks:**
- Dependency-Audit
- Vulnerability-Scan
- Compliance-Check
- Security-Best-Practices-Review

**Example Command:**
```bash
openclaw agent --agent security-agent --message "Prüfe /path/to/project auf:
- CVEs in Dependencies
- OWASP Top 10
- Hardcoded Secrets
- Insecure Patterns
Erstelle Security-Report."
```

### 4. Ops-Agent Testing

**Good Tasks:**
- Traefik-Route erstellen
- Deployment-Config
- Service-Health-Check
- Infrastructure-Automation

**Example Command:**
```bash
openclaw agent --agent ops-agent --message "Erstelle Traefik-Route für:
- Domain: service.example.com
- Backend: localhost:3000
- HTTPS via Let's Encrypt
- Rate-Limiting: 100/min
Deploye auf 192.168.1.4."
```

---

## Test-Workflow Recommendations

### Workflow 1: Feature Development
```
1. Dev-Agent: Implementierung erstellen
2. Review-Agent: Code reviewen
3. Dev-Agent: Fixes umsetzen
4. Security-Agent: Security-Audit
5. Ops-Agent: Deployment vorbereiten
```

### Workflow 2: Bug Fix
```
1. Dev-Agent: Bug analysieren und fixen
2. Review-Agent: Fix reviewen
3. Dev-Agent: Tests erweitern
```

### Workflow 3: Security Audit
```
1. Security-Agent: Vulnerability-Scan
2. Dev-Agent: Fixes implementieren
3. Review-Agent: Fixes reviewen
4. Security-Agent: Re-Scan
```

---

## Testing Commands

### Quick Tests
```bash
# Dev-Agent
openclaw agent --agent dev-agent --message "Erstelle Hello-World in TypeScript"

# Review-Agent
openclaw agent --agent review-agent --message "Reviewe ~/.openclaw/agents/dev-agent/agent/.claude.md"

# Security-Agent
openclaw agent --agent security-agent --message "Prüfe /opt/openclaw/workspaces/dev-agent auf Secrets"

# Ops-Agent
openclaw agent --agent ops-agent --message "Zeige System-Status von 192.168.1.11"
```

### Complex Tests
```bash
# End-to-End Feature Development
openclaw agent --agent dev-agent --message "Erstelle REST API mit Express + TypeScript:
- GET /api/users
- POST /api/users
- JWT-Auth
- Input-Validation
- Tests mit Supertest
Speichere in workspace."

# Comprehensive Review
openclaw agent --agent review-agent --message "Full Review von /opt/openclaw/workspaces/dev-agent/src:
- Security (OWASP Top 10)
- Code-Quality (Complexity, DRY, SOLID)
- Performance (O-Notation, Bottlenecks)
- Best-Practices (Error-Handling, Logging)
Strukturierter Report mit Prioritäten."
```

---

## Verification Checklist

Nach jedem Test:

- [ ] Agent antwortet innerhalb 30s
- [ ] Response ist strukturiert und vollständig
- [ ] Code (falls erstellt) ist syntaktisch korrekt
- [ ] Tests (falls erstellt) sind ausführbar
- [ ] Review (falls durchgeführt) ist detailliert
- [ ] Keine Model-Errors in Logs

**Debug bei Problemen:**
```bash
# Gateway Status
openclaw status

# Model Connection
openclaw health

# Logs
journalctl -u openclaw-gateway -n 50 --no-pager | grep error
```

---

## Performance Benchmarks

**Durchschnittliche Response-Zeiten:**
- Simple Query: 1-3s
- Code-Generation: 5-15s
- Comprehensive Review: 10-30s
- Large Project Analysis: 30-60s

**Token-Usage:**
- Simple Query: ~100-500 tokens
- Code-Generation: ~1k-3k tokens
- Review: ~2k-5k tokens

---

**Version:** 1.0.0  
**Last Update:** 2026-06-03
