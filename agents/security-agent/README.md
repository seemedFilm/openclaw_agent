# Security-Agent - Security & Compliance Agent

Automatisiertes Security-Scanning und Vulnerability-Management mit Claude Sonnet 4.6.

## 📋 Übersicht

Der **Security-Agent** ist ein Sicherheitsexperte, der proaktiv Schwachstellen identifiziert und Compliance sicherstellt.

**Hauptaufgaben:**
- ✅ Dependency-Scanning (npm, Snyk, Trivy)
- ✅ Secrets-Detection (Git-History-Scan)
- ✅ SAST-Analyse (SQL-Injection, XSS, etc.)
- ✅ Config-Audit (Lynis, Trivy)
- ✅ Compliance-Checks (OWASP Top 10, CWE Top 25)

**Status:** ✅ Production-Ready (Phase 2)  
**Model:** Claude Sonnet 4.6 via LiteLLM/Bedrock

---

## 🎯 Capabilities

| Capability | Tools | Severity |
|------------|-------|----------|
| **Dependency Scanning** | npm-audit, Snyk, Trivy | CRITICAL |
| **Secrets Detection** | gitleaks, pattern matching | CRITICAL |
| **SAST Analysis** | Custom analysis | HIGH |
| **Config Audit** | Lynis, Trivy | MEDIUM |
| **Compliance** | OWASP, CWE | MEDIUM |

---

## 🚀 Usage

### Full Security Scan

```bash
ssh root@192.168.1.11
openclaw tui
# Select: security-agent
```

**Message:**
```
Run a full security scan of the current project:
- Scan dependencies for vulnerabilities
- Check for secrets in code and git history
- Run SAST analysis
- Report findings by severity
```

**Expected Output:**
```markdown
# Security Scan Report

**Overall Risk:** 🟡 MEDIUM

**Vulnerabilities:**
- 🔴 CRITICAL: 0
- 🟠 HIGH: 2
- 🟡 MEDIUM: 5
- 🔵 LOW: 3

**Details in:** security-report-20260602.md
```

---

## 📊 Security Report Format

Reports include:
1. **Executive Summary** - Overall risk, counts
2. **Critical Issues** - Immediate action required
3. **High Priority** - Fix within 1 week
4. **Medium Priority** - Fix within 1 month
5. **Dependency Vulnerabilities** - CVE details
6. **Secrets Detected** - Location and remediation
7. **Compliance Status** - OWASP Top 10
8. **Recommendations** - Prioritized action items

---

## 🔐 Severity Levels

- **🔴 CRITICAL (9.0-10.0):** Fix within 24h (SQL Injection, exposed secrets)
- **🟠 HIGH (7.0-8.9):** Fix within 1 week (XSS, auth bypass)
- **🟡 MEDIUM (4.0-6.9):** Fix within 1 month (Path traversal)
- **🔵 LOW (0.1-3.9):** Fix when convenient (Missing headers)

---

## 📚 Documentation

- **System Prompts:** [prompts.md](prompts.md)
- **Configuration:** [config.yaml](config.yaml)
- **Quick Reference:** [../../docs/QUICK-REFERENCE.md](../../docs/QUICK-REFERENCE.md)

---

**Version:** 1.0.0  
**Status:** ✅ Production-Ready  
**Letzte Aktualisierung:** 2026-06-02
