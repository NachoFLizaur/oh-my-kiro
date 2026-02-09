---
name: code-review
description: Code review checklists, quality patterns, and security checks. Load when reviewing code, checking quality, running code audits, or evaluating implementations.
---

# Code Review Skill

Structured patterns for reviewing code across languages and frameworks. Use these checklists and patterns to produce thorough, actionable reviews.

---

## Code Review Checklist

Run through each category for every review. Skip a category only if it genuinely doesn't apply.

### Functionality

- [ ] Code does what the requirements/ticket/plan says it should
- [ ] Edge cases are handled (empty inputs, nulls, boundary values, overflow)
- [ ] Error paths return meaningful errors, not silent failures
- [ ] State transitions are correct (no impossible states, no stale data)
- [ ] Side effects are intentional and documented (DB writes, API calls, file I/O)
- [ ] Backward compatibility is preserved (or breaking changes are flagged)

### Readability

- [ ] Names reveal intent — `getUserById` not `getData`, `isExpired` not `check`
- [ ] Functions do one thing and are short enough to read without scrolling
- [ ] Control flow is linear where possible (early returns over deep nesting)
- [ ] Comments explain *why*, not *what* — the code explains what
- [ ] No dead code, commented-out blocks, or TODO items without tracking
- [ ] Consistent formatting with the rest of the codebase

### Security

- [ ] User input is validated and sanitized before use
- [ ] No secrets, tokens, or credentials in source code
- [ ] SQL queries use parameterized statements (no string concatenation)
- [ ] Authentication and authorization checks are present on protected paths
- [ ] Sensitive data is not logged or exposed in error messages
- [ ] Dependencies are from trusted sources and pinned to specific versions

### Performance

- [ ] No unnecessary database queries inside loops (N+1 problem)
- [ ] Large collections are paginated or streamed, not loaded entirely into memory
- [ ] Expensive operations are cached where appropriate
- [ ] Async operations don't block the main thread
- [ ] No memory leaks (unclosed connections, unremoved event listeners, growing caches)
- [ ] Algorithms are appropriate for the data size (no O(n^2) on large datasets)

### Testing

- [ ] New behavior has corresponding tests
- [ ] Tests cover both happy path and error cases
- [ ] Tests are deterministic (no flaky timing, no external dependencies)
- [ ] Test names describe the scenario, not the implementation
- [ ] Mocks/stubs are minimal — prefer real implementations where practical

---

## Common Code Smells

Patterns that indicate deeper problems. When you spot these, flag them with specific fix suggestions.

### Structural Smells

| Smell | What It Looks Like | Fix |
|-------|-------------------|-----|
| **God Object** | One class/module handles auth, logging, DB, and email | Split into focused modules with single responsibilities |
| **Feature Envy** | Function constantly accesses another object's data | Move the function to the object it's reaching into |
| **Shotgun Surgery** | One change requires edits in 10+ files | Extract the shared concern into a single module |
| **Primitive Obsession** | Passing `(string, string, number, boolean)` everywhere | Create a domain type: `UserFilter { name, email, age, active }` |
| **Long Parameter List** | Function takes 5+ parameters | Group into an options/config object |

### Logic Smells

| Smell | What It Looks Like | Fix |
|-------|-------------------|-----|
| **Nested Conditionals** | 4+ levels of if/else nesting | Use early returns, guard clauses, or extract helper functions |
| **Boolean Blindness** | `process(true, false, true)` | Use named constants, enums, or an options object |
| **Magic Numbers** | `if (status === 3)` or `timeout: 86400000` | Extract to named constants: `STATUS_COMPLETE`, `ONE_DAY_MS` |
| **Copy-Paste Code** | Two blocks that are 90% identical | Extract shared logic into a parameterized function |
| **Speculative Generality** | Abstract factory for a class with one implementation | Remove the abstraction until a second use case exists |

### Naming Smells

| Smell | Example | Better |
|-------|---------|--------|
| **Vague names** | `data`, `info`, `result`, `temp` | `userProfile`, `validationErrors`, `parsedConfig` |
| **Misleading names** | `isReady` returns a string | Rename to match return type: `getReadyStatus` |
| **Inconsistent conventions** | `getUser`, `fetchAccount`, `loadProfile` | Pick one verb per operation and use it everywhere |
| **Abbreviated names** | `usrMgr`, `cfgSvc`, `btnHndlr` | `userManager`, `configService`, `buttonHandler` |

---

## Security Review Patterns

Check these patterns explicitly. Security issues are always CRITICAL severity.

### Injection Attacks

**SQL Injection** — Look for string concatenation in queries:
```
# BAD — injectable
query = f"SELECT * FROM users WHERE id = '{user_id}'"

# GOOD — parameterized
query = "SELECT * FROM users WHERE id = $1"
cursor.execute(query, [user_id])
```

**Command Injection** — Look for user input in shell commands:
```
# BAD — injectable
os.system(f"convert {filename} output.png")

# GOOD — use subprocess with argument list
subprocess.run(["convert", filename, "output.png"], check=True)
```

**XSS (Cross-Site Scripting)** — Look for unescaped user content in HTML:
```
// BAD — XSS vector
element.innerHTML = userComment

// GOOD — use text content or sanitize
element.textContent = userComment
```

### Authentication & Authorization

- **Missing auth checks**: Every endpoint that serves user-specific data must verify identity
- **Broken access control**: Verify users can only access their own resources (IDOR)
- **Token handling**: Tokens must be stored securely (httpOnly cookies, not localStorage for sensitive tokens)
- **Session management**: Sessions must expire, and logout must invalidate server-side state

### Data Exposure

- **Overfetching**: API returns full user object (including password hash) when only name is needed — use explicit field selection
- **Error details**: Stack traces or internal paths leaked to clients — return generic errors externally, log details internally
- **Logging sensitive data**: Passwords, tokens, PII in log output — redact before logging
- **Hardcoded secrets**: API keys, database passwords in source — use environment variables or secret managers

### Dependency Risks

- **Unpinned versions**: `"lodash": "^4.0.0"` can silently upgrade to a compromised version — pin exact versions for production
- **Abandoned packages**: Check last publish date and open issues — consider alternatives if unmaintained
- **Excessive permissions**: A package that needs filesystem access for a string utility — audit transitive dependencies

---

## Performance Review Patterns

Flag these when found. Use WARNING severity unless the impact is measurable and significant.

### Database

**N+1 Queries** — The most common performance bug:
```
# BAD — 1 query for users + N queries for orders
users = db.query("SELECT * FROM users")
for user in users:
    orders = db.query(f"SELECT * FROM orders WHERE user_id = {user.id}")

# GOOD — 1 query with join or batch load
users_with_orders = db.query("""
    SELECT u.*, o.* FROM users u
    LEFT JOIN orders o ON o.user_id = u.id
""")
```

**Missing indexes**: Queries filtering or sorting on unindexed columns — check query plans for full table scans.

**Unbounded queries**: `SELECT * FROM logs` with no LIMIT — always paginate or set reasonable limits.

### Memory

**Unbounded caches**: Cache that grows forever without eviction — use LRU or TTL-based caching.

**Large object retention**: Holding references to large objects (DOM nodes, buffers) after they're no longer needed — set to null or use WeakRef.

**String concatenation in loops**: Building large strings with `+=` in a loop — use a builder/buffer pattern or array join.

### Frontend-Specific

**Unnecessary re-renders**: Component re-renders when unrelated state changes — use memoization (`React.memo`, `useMemo`, `computed`).

**Bundle size**: Importing entire libraries for one function — use tree-shakeable imports: `import { debounce } from 'lodash-es/debounce'`.

**Layout thrashing**: Reading layout properties (offsetHeight) then writing styles in a loop — batch reads and writes separately.

**Unoptimized images**: Large images served without compression or responsive sizing — use appropriate formats (WebP/AVIF) and `srcset`.

---

## Review Comment Best Practices

Write comments that help the author improve, not comments that demonstrate your knowledge.

### Comment Structure

Every review comment should have three parts:

1. **What**: Point to the specific code (file, line, snippet)
2. **Why**: Explain the concern — what could go wrong, what principle is violated
3. **How**: Suggest a concrete fix or alternative

```markdown
# BAD — vague, unhelpful
"This doesn't look right."

# BAD — prescriptive without explanation
"Change this to use a Map."

# GOOD — specific, reasoned, actionable
"`user-service.ts:42` — This linear search through `allUsers` runs on every
request. With 10k+ users this becomes a bottleneck.
Consider indexing by ID with a Map for O(1) lookups:
`const usersById = new Map(allUsers.map(u => [u.id, u]))`"
```

### Severity Levels

Use consistent severity to help authors prioritize:

| Level | Meaning | Author Action |
|-------|---------|---------------|
| **CRITICAL** | Bug, security hole, data loss risk, broken functionality | Must fix before merge |
| **WARNING** | Performance issue, missing edge case, fragile pattern | Should fix, discuss if disagreed |
| **INFO** | Style preference, minor improvement, learning opportunity | Optional, author decides |

### Tone Guidelines

- **Ask questions** when unsure: "Could this throw if `user` is null?" not "This will crash"
- **Explain the tradeoff** when suggesting changes: "This adds complexity but prevents X"
- **Acknowledge good work**: "Nice use of discriminated unions here" — positive feedback reinforces good patterns
- **Avoid "you"**: "This function could be simplified" not "You wrote this wrong"
- **One concern per comment**: Don't bundle unrelated issues into a single comment

---

## Language-Specific Patterns

### TypeScript

| Pattern | Flag | Prefer |
|---------|------|--------|
| `any` type | WARNING — defeats type safety | Specific types, `unknown` with type guards, or generics |
| Non-null assertion `!` | WARNING — hides potential nulls | Optional chaining `?.` with explicit null handling |
| `enum` (numeric) | INFO — can cause runtime surprises | String enums or `as const` union types |
| Implicit return types | INFO — on public APIs | Explicit return type annotations on exported functions |
| `== null` comparisons | INFO — if codebase uses strict | `=== null \|\| === undefined` or `?? ` operator |
| Barrel files re-exporting everything | WARNING — hurts tree-shaking | Direct imports from source modules |
| `Object.assign` for immutability | INFO | Spread syntax `{ ...obj, key: value }` |

**TypeScript-specific checks**:
- Ensure `strict` mode is enabled in `tsconfig.json`
- Check for proper error typing in catch blocks (`unknown`, not `any`)
- Verify discriminated unions are exhaustively handled (switch with `never` default)
- Look for `as` type assertions that bypass the type system — prefer type guards

### Python

| Pattern | Flag | Prefer |
|---------|------|--------|
| Mutable default arguments | CRITICAL — shared between calls | `def f(items=None): items = items or []` |
| Bare `except:` | WARNING — catches KeyboardInterrupt | `except Exception:` or specific exceptions |
| `type()` for type checking | INFO | `isinstance()` which handles inheritance |
| String formatting with `%` or `.format()` | INFO | f-strings for readability |
| Global mutable state | WARNING — hard to test and reason about | Dependency injection or function parameters |
| Missing `__init__.py` | INFO — if package imports fail | Add `__init__.py` to package directories |

**Python-specific checks**:
- Verify type hints are present on public functions
- Check for proper context manager usage (`with` for files, connections, locks)
- Look for circular imports (often a sign of tangled architecture)
- Ensure `requirements.txt` or `pyproject.toml` pins dependency versions

### Rust

| Pattern | Flag | Prefer |
|---------|------|--------|
| `.unwrap()` in library code | WARNING — panics on failure | `?` operator or explicit error handling |
| `.clone()` without reason | INFO — may indicate ownership issues | Borrow where possible, document why clone is needed |
| `unsafe` blocks | CRITICAL — requires justification | Safe alternatives; if unavoidable, document the safety invariant |
| Large `match` with `_ => ()` | WARNING — silently ignores new variants | Handle all variants explicitly, or use `#[non_exhaustive]` |
| `String` where `&str` suffices | INFO — unnecessary allocation | `&str` for read-only string parameters |

**Rust-specific checks**:
- Verify error types implement `std::error::Error` and `Display`
- Check for proper lifetime annotations (not just `'static` everywhere)
- Look for `Arc<Mutex<>>` patterns that might indicate design issues
- Ensure `clippy` warnings are addressed

### Shell Scripts

| Pattern | Flag | Prefer |
|---------|------|--------|
| Unquoted variables | CRITICAL — word splitting, glob expansion | `"$variable"` always quoted |
| Missing `set -euo pipefail` | WARNING — errors silently ignored | Add at top of every script |
| `eval` with user input | CRITICAL — command injection | Avoid `eval`; use arrays for dynamic commands |
| Parsing `ls` output | WARNING — breaks on special characters | Use `find` or glob patterns |
| `[ ]` test syntax | INFO | `[[ ]]` for bash (safer, more features) |

**Shell-specific checks**:
- Verify scripts have proper shebang lines (`#!/usr/bin/env bash`)
- Check for proper exit codes on error paths
- Look for missing cleanup on script exit (use `trap` for temp files)
- Ensure `shellcheck` passes without warnings
