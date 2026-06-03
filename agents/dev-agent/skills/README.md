# Dev-Agent Skills

Übersicht über die spezifischen Skills des Development Agents.

## 📋 Übersicht

Der Dev-Agent verfügt über 7 spezialisierte Skills für Software-Entwicklung:

| Skill | Status | Priorität | Beschreibung |
|-------|--------|-----------|--------------|
| **code-generation** | ✅ Enabled | Hoch | Code von Specs generieren |
| **code-refactoring** | ✅ Enabled | Hoch | Code-Qualität verbessern |
| **debugging** | ✅ Enabled | Hoch | Fehleranalyse und Fixes |
| **git-operations** | ✅ Enabled | Hoch | Git-Workflow-Automation |
| **file-management** | ✅ Enabled | Mittel | Datei-Operationen |
| **claude-code-integration** | ✅ Enabled | Hoch | Claude Code CLI Integration |
| **test-generation** | ✅ Enabled | Mittel | Test-Erstellung |
| **documentation** | ✅ Enabled | Niedrig | Code-Dokumentation |

---

## 🎯 Skill-Details

### 1. Code Generation

**Purpose:** Generiere neuen Code basierend auf Spezifikationen.

**Capabilities:**
- Feature-Implementierung von User Stories
- API-Endpoint-Erstellung
- UI-Komponenten
- Datenbank-Schema und Migrations
- Utility-Functions

**Beispiel:**

**Input:**
```
Implement a REST API endpoint for user profile updates:
- PATCH /users/:id/profile
- Fields: name, email, bio, avatar_url
- Validation: email format, name min 2 chars
- Authorization: User can only update own profile
```

**Output:**
```typescript
// src/users/users.controller.ts
@Patch(':id/profile')
@UseGuards(JwtAuthGuard)
async updateProfile(
  @Param('id') userId: string,
  @Body() updateDto: UpdateProfileDto,
  @Req() req: Request
) {
  // Authorization check
  if (req.user.id !== userId) {
    throw new ForbiddenException('Can only update own profile');
  }

  return this.usersService.updateProfile(userId, updateDto);
}

// src/users/dto/update-profile.dto.ts
export class UpdateProfileDto {
  @IsOptional()
  @IsString()
  @MinLength(2)
  name?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  bio?: string;

  @IsOptional()
  @IsUrl()
  avatar_url?: string;
}
```

### 2. Code Refactoring

**Purpose:** Verbessere Code-Qualität ohne Funktionalität zu ändern.

**Refactoring-Patterns:**
- Extract Method/Class
- Dependency Injection
- Strategy Pattern
- Repository Pattern
- Remove Code Duplication
- Simplify Complex Conditionals

**Beispiel:**

**Before (Code Smell):**
```typescript
function processOrder(order) {
  if (order.status === 'pending') {
    if (order.payment_method === 'credit_card') {
      // 50 lines of credit card processing
    } else if (order.payment_method === 'paypal') {
      // 50 lines of PayPal processing
    } else if (order.payment_method === 'bank_transfer') {
      // 50 lines of bank transfer processing
    }
  }
}
```

**After (Strategy Pattern):**
```typescript
interface PaymentProcessor {
  process(order: Order): Promise<PaymentResult>;
}

class CreditCardProcessor implements PaymentProcessor {
  async process(order: Order): Promise<PaymentResult> {
    // Credit card logic
  }
}

class PayPalProcessor implements PaymentProcessor {
  async process(order: Order): Promise<PaymentResult> {
    // PayPal logic
  }
}

class PaymentService {
  private processors: Map<string, PaymentProcessor>;

  constructor() {
    this.processors = new Map([
      ['credit_card', new CreditCardProcessor()],
      ['paypal', new PayPalProcessor()],
      ['bank_transfer', new BankTransferProcessor()]
    ]);
  }

  async processOrder(order: Order): Promise<PaymentResult> {
    const processor = this.processors.get(order.payment_method);
    if (!processor) {
      throw new Error(`Unknown payment method: ${order.payment_method}`);
    }
    return processor.process(order);
  }
}
```

### 3. Debugging

**Purpose:** Identifiziere und behebe Fehler systematisch.

**Debugging-Workflow:**
1. **Reproduce:** Fehler reproduzieren
2. **Isolate:** Root Cause identifizieren
3. **Fix:** Lösung implementieren
4. **Test:** Regression-Test hinzufügen
5. **Document:** Commit-Message mit Details

**Tools:**
- Stack-Trace-Analyse
- Debugger (Node Inspector, pdb, delve)
- Logging (console, winston, zap)
- Profiling (Chrome DevTools, py-spy)

**Beispiel:**

**Problem:**
```
TypeError: Cannot read property 'map' of undefined
    at renderList (components/List.tsx:42:15)
```

**Analysis:**
```typescript
// File: components/List.tsx, Line 42
const renderList = () => {
  return items.map(item => <ListItem key={item.id} {...item} />);
  // ^^^^^ items is undefined
};
```

**Root Cause:**
Parent component `Dashboard.tsx` doesn't pass `items` prop when API call fails.

**Fix:**
```typescript
// Option 1: Default value
const renderList = () => {
  return (items || []).map(item => <ListItem key={item.id} {...item} />);
};

// Option 2: Conditional rendering
const renderList = () => {
  if (!items) return <Loading />;
  return items.map(item => <ListItem key={item.id} {...item} />);
};

// Option 3: TypeScript strict null check
interface ListProps {
  items: Item[];  // Not nullable
}

// In parent component:
<List items={data?.items ?? []} />
```

**Prevention:**
```typescript
// Add test case
it('should handle undefined items gracefully', () => {
  render(<List items={undefined} />);
  expect(screen.getByText('Loading...')).toBeInTheDocument();
});
```

### 4. Git Operations

**Purpose:** Automatisiere Git-Workflows.

**Capabilities:**
- Branch Management
- Commit mit Conventional Commits
- Pull Request Creation
- Merge Conflict Resolution
- Cherry-Pick & Rebase

**Commit Message Template:**
```
[dev-agent] <type>: <short description>

<detailed description>

Technical details:
- Changed X to Y
- Refactored A for B

Testing:
- Added tests for Z
- Coverage: X%

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```

**Workflow-Beispiel:**

```bash
# 1. Feature Branch erstellen
git checkout -b feature/user-authentication

# 2. Code implementieren
# ... changes ...

# 3. Stage & Commit
git add src/auth/
git commit -m "[dev-agent] feat: implement JWT authentication

Added user authentication with JWT tokens:
- POST /auth/register endpoint
- POST /auth/login endpoint
- JWT middleware for protected routes

Technical details:
- JWT expires after 7 days
- Passwords hashed with bcrypt
- Refresh token rotation implemented

Testing:
- Unit tests for auth service
- Integration tests for endpoints
- Coverage: 94%

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"

# 4. Push
git push origin feature/user-authentication

# 5. Create PR
gh pr create \
  --title "feat: implement JWT authentication" \
  --body "Implements #123"
```

### 5. File Management

**Purpose:** Datei-Operationen automatisieren.

**Capabilities:**
- Create/Read/Update files
- Directory operations
- File search & replace
- Template generation
- Code scaffolding

**Beispiel - Scaffolding:**

```bash
# Generate CRUD files for "Product" entity
generate:
  entity: "Product"
  files:
    - src/products/products.controller.ts
    - src/products/products.service.ts
    - src/products/products.repository.ts
    - src/products/entities/product.entity.ts
    - src/products/dto/create-product.dto.ts
    - src/products/dto/update-product.dto.ts
    - src/products/products.controller.spec.ts
    - src/products/products.service.spec.ts
```

**Generated Structure:**
```
src/products/
├── products.controller.ts      # REST endpoints
├── products.service.ts         # Business logic
├── products.repository.ts      # Database access
├── entities/
│   └── product.entity.ts       # Entity definition
├── dto/
│   ├── create-product.dto.ts   # Creation DTO
│   └── update-product.dto.ts   # Update DTO
└── __tests__/
    ├── products.controller.spec.ts
    └── products.service.spec.ts
```

### 6. Claude Code Integration

**Purpose:** Integration mit Claude Code CLI.

**Features:**
- Session Management
- MCP Server Integration
- Tool Use
- IDE Integration
- Hooks

**Beispiel - Session starten:**

```bash
# Start Claude Code session
openclaw session start --project /opt/workspace/myproject

# Execute command in Claude Code
openclaw exec "Implement user authentication"

# Query Claude Code
openclaw query "Where is the authentication logic?"

# Stop session
openclaw session stop
```

**MCP Server Integration:**
```yaml
# In config.yaml
claude_code:
  mcp_servers:
    - name: "filesystem"
      enabled: true
    - name: "git"
      enabled: true
    - name: "github"
      enabled: true
      config:
        token: "${GITHUB_TOKEN}"
```

### 7. Test Generation

**Purpose:** Automatische Test-Erstellung.

**Test-Typen:**
- **Unit Tests:** Einzelne Funktionen/Klassen
- **Integration Tests:** Komponenten-Interaktion
- **E2E Tests:** Komplette User-Flows

**Coverage-Ziel:** >80%

**Beispiel:**

**Function to test:**
```typescript
export function calculateDiscount(price: number, coupon: string): number {
  if (price < 0) throw new Error('Price cannot be negative');
  if (coupon === 'SAVE10') return price * 0.9;
  if (coupon === 'SAVE20') return price * 0.8;
  return price;
}
```

**Generated Tests:**
```typescript
describe('calculateDiscount', () => {
  it('should apply 10% discount with SAVE10 coupon', () => {
    expect(calculateDiscount(100, 'SAVE10')).toBe(90);
  });

  it('should apply 20% discount with SAVE20 coupon', () => {
    expect(calculateDiscount(100, 'SAVE20')).toBe(80);
  });

  it('should return original price with invalid coupon', () => {
    expect(calculateDiscount(100, 'INVALID')).toBe(100);
  });

  it('should throw error for negative price', () => {
    expect(() => calculateDiscount(-10, 'SAVE10')).toThrow('Price cannot be negative');
  });

  it('should handle zero price', () => {
    expect(calculateDiscount(0, 'SAVE10')).toBe(0);
  });

  it('should handle empty coupon', () => {
    expect(calculateDiscount(100, '')).toBe(100);
  });
});

// Coverage: 100% (6/6 branches covered)
```

### 8. Documentation

**Purpose:** Code-Dokumentation automatisch generieren.

**Dokumentations-Typen:**
- Inline-Kommentare
- JSDoc/Docstrings
- README-Dateien
- API-Dokumentation (OpenAPI/Swagger)

**Beispiel - JSDoc:**

```typescript
/**
 * Authenticates a user with email and password.
 * 
 * @param email - User's email address
 * @param password - User's password (plain text)
 * @returns JWT token for authenticated user
 * @throws {UnauthorizedException} If credentials are invalid
 * @throws {TooManyRequestsException} If rate limit exceeded
 * 
 * @example
 * ```typescript
 * const token = await login('user@example.com', 'password123');
 * console.log(token); // "eyJhbGciOiJIUzI1NiIs..."
 * ```
 */
async function login(email: string, password: string): Promise<string> {
  // Implementation
}
```

**Beispiel - API-Dokumentation:**

```typescript
/**
 * @swagger
 * /auth/login:
 *   post:
 *     summary: Authenticate user
 *     tags: [Authentication]
 *     requestBody:
 *       required: true
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             properties:
 *               email:
 *                 type: string
 *                 format: email
 *               password:
 *                 type: string
 *                 format: password
 *     responses:
 *       200:
 *         description: Login successful
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 token:
 *                   type: string
 *       401:
 *         description: Invalid credentials
 */
```

---

## 🛠️ Skill-Konfiguration

### Skills aktivieren/deaktivieren

```yaml
# In agents/dev-agent/config.yaml
skills:
  - name: "code-generation"
    enabled: true  # ✅ Aktiv
    priority: "high"
    
  - name: "documentation"
    enabled: false  # ❌ Deaktiviert
    priority: "low"
```

### Skill-spezifische Config

```yaml
skills:
  - name: "git-operations"
    enabled: true
    config:
      commit_message_format: "conventional-commits"
      auto_commit: false
      auto_push: false
      allowed_branches:
        - "feature/*"
        - "fix/*"
        - "refactor/*"
      
  - name: "test-generation"
    enabled: true
    config:
      frameworks:
        - "jest"
        - "pytest"
      coverage_threshold: 80
      generate_mocks: true
```

---

## 📊 Skill-Performance

### Metriken

```bash
# Skill-spezifische Metriken
openclaw agent metrics dev-agent --skill code-generation
```

**Beispiel-Output:**
```
Skill: code-generation
- Total invocations: 1234
- Success rate: 98.5%
- Avg response time: 2.3s
- Lines of code generated: 45678
- Languages: TypeScript (60%), Python (25%), Go (15%)
```

---

## 🔍 Troubleshooting

### Skill schlägt fehl

**Problem:** Skill gibt Error zurück

**Lösung:**
```bash
# 1. Check Logs
grep "code-generation" /opt/openclaw/logs/dev-agent.log

# 2. Validate Config
openclaw agent validate dev-agent --skill code-generation

# 3. Test Skill isoliert
openclaw skill test dev-agent code-generation
```

---

## 📚 Weiterführende Links

- **Agent-Übersicht:** [../README.md](../README.md)
- **Konfiguration:** [../config.yaml](../config.yaml)
- **System-Prompts:** [../prompts.md](../prompts.md)

---

**Version:** 1.0.0  
**Letzte Aktualisierung:** 2026-06-02
