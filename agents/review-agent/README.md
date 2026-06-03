# Review-Agent

Code-Review-Spezialist für Quality Assurance, Security und Best Practices.

## 🎯 Überblick

Der **Review-Agent** ist ein spezialisierter Agent für umfassende Code-Reviews, Security-Audits und Quality-Checks. Er analysiert Code aus mehreren Perspektiven und gibt strukturiertes, actionable Feedback.

## 🛠️ Capabilities

### 1. Code Reviews
- **Syntax & Style:** Code-Konventionen, Naming, Formatting
- **Complexity Analysis:** Cyclomatic Complexity, Nested Depth
- **Code Smells:** Duplicates, Long Methods, God Classes
- **SOLID Principles:** Violations und Verbesserungsvorschläge

### 2. Security Audits
- **OWASP Top 10:** SQL Injection, XSS, CSRF, etc.
- **Input Validation:** Fehlende oder unzureichende Validierung
- **Authentication/Authorization:** Schwachstellen in Auth-Logic
- **Sensitive Data:** Hardcoded Secrets, Credentials Exposure
- **Dependency Vulnerabilities:** Bekannte CVEs

### 3. Best Practices
- **Error Handling:** Try/Catch, Error-Propagation
- **Logging:** Structured Logging, Log-Levels
- **Testing:** Test-Coverage, Test-Qualität
- **Documentation:** Comments, JSDoc/PyDoc
- **Performance:** O-Notation, Bottlenecks

### 4. Pull Request Analysis
- **Commit Quality:** Message-Format, Atomic Commits
- **Breaking Changes:** API-Changes, Migration-Needs
- **Test Coverage:** New Code Coverage
- **Merge Conflicts:** Potentielle Konflikte

## 🔧 Configuration

### Model
- **Claude Sonnet 4.6** via AWS Bedrock (eu-central-1)
- Max Tokens: 8192
- Context Window: 128k tokens

### Workspace
- `/opt/openclaw/workspaces/review-agent`

### Bootstrap
- **System Instructions:** `~/.openclaw/agents/review-agent/agent/.claude.md`
- **Prompts:** `~/.openclaw/agents/review-agent/agent/prompts.md`

## 📖 Usage

### Basic Review

```bash
openclaw agent --agent review-agent --message "Reviewe /path/to/file.ts"
```

### Comprehensive Review

```bash
openclaw agent --agent review-agent --message "Reviewe /path/to/file.ts aus folgenden Perspektiven:
- Security (OWASP Top 10)
- Code-Qualität (Complexity, DRY, SOLID)
- Performance (O-Notation, Bottlenecks)
- Best Practices (Error-Handling, Logging)

Strukturiertes Feedback mit Prioritäten (Critical/High/Medium/Low)."
```

### Pull Request Review

```bash
openclaw agent --agent review-agent --message "Reviewe PR #123 in /path/to/repo:
- Commit-Quality
- Breaking Changes
- Test-Coverage
- Merge-Konflikte
- Security-Implikationen"
```

### Security-Focused Review

```bash
openclaw agent --agent review-agent --message "Security-Audit für /path/to/project:
- OWASP Top 10 Checks
- Input-Validation
- Auth/Authz
- Sensitive Data Exposure
- Dependency-Vulnerabilities

Report mit Severity-Ratings."
```

## 🎯 Review Format

Der Review-Agent strukturiert seine Antworten standardmäßig wie folgt:

### ✅ Positive Findings
- Was funktioniert gut
- Best Practices die eingehalten werden
- Gute Design-Entscheidungen

### 🔴 Critical Issues
- Security-Vulnerabilities
- Breaking Changes
- Major Bugs

### 🟡 Medium Issues
- Code-Quality-Problems
- Performance-Concerns
- Refactoring-Opportunities

### 🟢 Minor Issues / Nitpicks
- Style-Violations
- Documentation-Gaps
- Minor Improvements

### 💡 Recommendations
- Konkrete Verbesserungsvorschläge
- Alternative Implementierungen
- Tool/Library-Empfehlungen

## 🧪 Example: Successful Review

**Input:**
```bash
openclaw agent --agent review-agent --message "Reviewe /opt/openclaw/workspaces/dev-agent/src/checkPasswordStrength.ts"
```

**Output (Auszug):**
```markdown
## 🔍 Code Review: checkPasswordStrength.ts

### ✅ Positive Findings
- Klare Interface-Definition
- O(1) Lookup für Common-Passwords
- Gute Kommentierung

### 🔴 Security Issues (5)
1. **Zu kleine Common-Password-Liste** (23 Einträge)
   Fix: HaveIBeenPwned Top 100k nutzen
   
2. **Keine Max-Länge** → DoS-Risiko
   Fix: Max 256 Zeichen limitieren

### 🟡 Code-Quality Issues (4)
1. **Magic Numbers** ohne Konstanten
   Fix: const SCORE_THRESHOLDS = {...}
   
2. **Score-Logik inkonsistent** bei len < 8
   Fix: Early return bei zu kurz

### Top 3 Fixes:
1. len < 8 → early return
2. Max-Länge einführen
3. Sequential-Regex verbessern
```

**18/18 Tests bestanden nach Review-Feedback-Umsetzung.**

## 🔧 Skills

Der Review-Agent kann folgende Skills nutzen:

### 1. Static Analysis
- Linting (ESLint, Pylint)
- Type-Checking (TypeScript, MyPy)
- Complexity-Metrics

### 2. Security Scanning
- Dependency-Audit (npm audit, pip-audit)
- Secret-Detection (git-secrets)
- SAST-Tools (Semgrep, Bandit)

### 3. Test Analysis
- Coverage-Reports (Jest, Pytest)
- Test-Quality-Metriken
- Mutation-Testing

## 📊 Review Metrics

**Durchschnittliche Review-Zeiten:**
- Single File (< 200 LOC): 5-10s
- Medium File (200-500 LOC): 10-20s
- Large File (> 500 LOC): 20-40s
- Full Project: 1-3 min

**Review-Qualität:**
- Security Issues Detection: ~95%
- Code-Quality Issues: ~85%
- False Positives: < 5%

## 🛠️ Integration

### Mit Dev-Agent
```bash
# Workflow: Develop → Review → Fix
1. Dev-Agent erstellt Code
2. Review-Agent reviewed
3. Dev-Agent implementiert Fixes
```

### Mit Security-Agent
```bash
# Workflow: Review → Deep Security Scan
1. Review-Agent findet Security-Issues
2. Security-Agent führt tieferen Scan durch
```

### Mit CI/CD
```bash
# Pre-Commit Hook
git commit → Review-Agent → Approve/Reject

# Pull Request Hook
PR opened → Review-Agent → Comment with Findings
```

## 📝 Best Practices

### DO:
✅ Konkrete File-Paths angeben  
✅ Review-Perspektiven spezifizieren  
✅ Prioritäten erwarten  
✅ Strukturiertes Feedback verlangen  

### DON'T:
❌ Vage Anfragen ("Reviewe mal den Code")  
❌ Ohne File-Path  
❌ Ohne Kriterien  
❌ Zu große Projekte auf einmal (> 10k LOC)  

## 🔗 Related

- **Dev-Agent:** Code-Entwicklung
- **Security-Agent:** Tiefere Security-Scans
- **Ops-Agent:** Deployment-Reviews

## 📚 Resources

- [Code-Review Best Practices](https://google.github.io/eng-practices/review/)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Clean Code Principles](https://clean-code-developer.de/)

---

**Version:** 1.0.0  
**Last Update:** 2026-06-03
