# Oh-My-Kiro

**Multi-agent orchestration for [Kiro](https://kiro.dev).**

Structured planning. Delegated execution. Defense-in-depth guardrails.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Table of Contents

- [What is Oh-My-Kiro?](#what-is-oh-my-kiro)
- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
  - [Planning with Prometheus](#planning-with-prometheus)
  - [Executing Plans with Atlas](#executing-plans-with-atlas)
  - [Direct Tasks with Sisyphus](#direct-tasks-with-sisyphus)
- [Configuration](#configuration)
  - [Agent Configs](#agent-configs)
  - [Steering Files](#steering-files)
  - [Skills](#skills)
  - [Hooks](#hooks)
- [Plan File Format](#plan-file-format)
  - [A Complete Plan File](#a-complete-plan-file)
- [Subagents](#subagents)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## What is Oh-My-Kiro?

Oh-My-Kiro is an open-source multi-agent orchestration system for [Kiro](https://kiro.dev). It provides a structured, multi-agent workflow that separates **planning** from **execution**, with specialized subagents for different tasks.

**Key ideas:**

- **Planning and execution are separate concerns.** One agent plans, another executes. The plan file on disk is the only handoff artifact.
- **Main agents never write code.** They delegate everything to specialized subagents.
- **Multiple layers of safety.** JSON config permissions, shell hooks for runtime enforcement, and identity reinforcement at every turn.
- **Cross-agent memory.** A shared filesystem (`.kiro/notepads/`) lets subagents coordinate without sharing context windows.
- **Trust but verify.** The executor independently verifies every subagent's work — never trusts self-reports.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER                                    │
│                                                                 │
│   ctrl+p              ctrl+a              ctrl+e                │
│     │                   │                   │                   │
│     ▼                   ▼                   ▼                   │
│ ┌───────────┐     ┌───────────┐     ┌───────────────┐          │
│ │ Prometheus │     │   Atlas   │     │   Sisyphus    │          │
│ │ (Planner)  │     │(Plan Exec)│     │(Direct Exec)  │          │
│ └─────┬─────┘     └─────┬─────┘     └───────┬───────┘          │
│       │                 │                     │                  │
│       │  writes         │  reads              │                  │
│       ▼                 ▼                     │                  │
│   ┌─────────────────────────┐                │                  │
│   │  .kiro/plans/{name}.md  │                │                  │
│   └─────────────────────────┘                │                  │
│                                              │                  │
│  ┌───────────────────────────────────────────┘                  │
│  │  Delegates to subagents                                      │
│  │                                                              │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  ├─▶│ omk-explorer │  │ omk-reviewer │  │omk-researcher│       │
│  │  └──────────────┘  └──────────────┘  └──────────────┘       │
│  │  ┌──────────────┐  ┌──────────────┐                         │
│  └─▶│omk-sisyphus-jr│  │  omk-metis  │                         │
│     │ (writes code) │  │(plan review)│                         │
│     └──────────────┘  └──────────────┘                         │
└─────────────────────────────────────────────────────────────────┘
```

**3 main agents** orchestrate work. **5 subagents** do the actual work. The plan file on disk is the sole handoff between planning and execution.

### Plan Lifecycle

```
DRAFT  →  READY  →  IN_PROGRESS  →  COMPLETE
  │         │            │              │
  │         │            │              └── All tasks verified
  │         │            └── Atlas/Sisyphus executing
  │         └── User reviewed and approved
  └── Prometheus drafting
```

---

## Quick Start

**1. Clone and install**

```bash
git clone https://github.com/nflizaur/oh-my-kiro.git
cd oh-my-kiro
./install.sh
```

**2. Open your project in Kiro**

Oh-My-Kiro agents are now available in your project.

**3. Start planning**

Press `ctrl+p` to open **Prometheus** and describe what you want to build. When the plan is ready, press `ctrl+a` to switch to **Atlas** and execute it.

---

## Installation

### Prerequisites

- [Kiro CLI](https://kiro.dev) installed and available in your PATH

### Local Install (single project)

```bash
git clone https://github.com/nflizaur/oh-my-kiro.git
cd oh-my-kiro
./install.sh
```

This copies the `.kiro/` directory into your current working directory. Agents are available only in that project.

### Global Install (all projects)

```bash
./install.sh --global
```

This installs to `~/.kiro/`, making agents available in every project you open with Kiro.

### Options

| Flag | Description |
|------|-------------|
| `--global` | Install to `~/.kiro/` instead of `./.kiro/` |
| `--force` | Overwrite existing files without prompting |
| `--help` | Show usage information |

### Uninstall

```bash
# Local
rm -rf .kiro/

# Global
rm -rf ~/.kiro/
```

---

## Usage

### Planning with Prometheus

**Shortcut:** `ctrl+p`

Prometheus is the planner. It interviews you to understand requirements, delegates research to subagents, and produces a structured plan file. It **never** writes code.

**Workflow:**

1. Press `ctrl+p` to start Prometheus
2. Describe what you want to build
3. Prometheus asks clarifying questions (interview process)
4. It delegates exploration to `omk-explorer` and research to `omk-researcher`
5. It drafts a plan and sends it to `omk-metis` for review
6. The final plan is written to `.kiro/plans/{plan-name}.md`
7. You review the plan and approve it

**Example — Planning a feature:**

```
You:  I need to add user authentication to my Express API.

Prometheus:  Before I create a plan, I have some questions:
  1. What auth method — JWT, session-based, or OAuth?
  2. Which endpoints need protection?
  3. Do you need role-based access control?
  4. Is there an existing User model, or do we start from scratch?

You:  JWT with refresh tokens. Protect all /api/* routes except
      /api/auth/login and /api/auth/register. No roles for now.
      We have a User model in src/models/user.ts.

Prometheus:  Got it. Let me explore the codebase and draft a plan.
  [Delegates to omk-explorer to map the existing routes and models]
  [Delegates to omk-researcher to check best practices for JWT refresh]
  [Writes .kiro/plans/add-jwt-auth.md]
  [Sends plan to omk-metis for review]

Prometheus:  Plan is ready at .kiro/plans/add-jwt-auth.md — 6 tasks,
             estimated ~2 hours. Please review and let me know if
             anything needs changes.
```

> After reviewing the plan, switch to Atlas (`ctrl+a`) to execute it. See [the complete plan file example](#a-complete-plan-file) below.

### Executing Plans with Atlas

**Shortcut:** `ctrl+a`

Atlas reads existing plan files and executes them task by task. It delegates all implementation to subagents and independently verifies their work.

**Workflow:**

1. Press `ctrl+a` to start Atlas
2. Atlas lists available plans from `.kiro/plans/`
3. Tell it which plan to execute (or it picks the most recent)
4. Atlas delegates each task to `omk-sisyphus-jr` (implementation) or `omk-explorer` (analysis)
5. After each task, Atlas independently verifies the work — it never trusts subagent self-reports
6. Atlas sends completed work to `omk-reviewer` for quality checks
7. Plan status is updated as tasks complete

**Example — Executing the auth plan:**

```
You:  Execute the JWT auth plan.

Atlas:  Found .kiro/plans/add-jwt-auth.md (status: READY).
        6 tasks. Starting execution.

Atlas:  Task 1/6 — Create auth middleware.
  [Delegates to omk-sisyphus-jr with full task context]
  [omk-sisyphus-jr creates src/middleware/auth.ts]
  [Atlas independently reads the file and runs the tests]
  ✓ Task 1 verified. Moving to Task 2.

Atlas:  Task 4/6 — Add refresh token endpoint.
  [Delegates to omk-sisyphus-jr]
  [omk-sisyphus-jr creates the endpoint]
  [Atlas runs verification: curl + test suite]
  ✗ Verification failed — refresh token not persisted.
  [Re-delegates with correction context]
  ✓ Task 4 verified on second attempt.

Atlas:  All 6 tasks complete. Sending to omk-reviewer for
        final quality check.
  [omk-reviewer approves]
  Plan status → COMPLETE.
```

> **Key point:** Atlas never trusts subagent self-reports. It reads the actual files and runs the verification commands from the plan.

> **Tip:** After finishing a plan with Prometheus, run `/clear` before switching to Atlas to free up context.

### Direct Tasks with Sisyphus

**Shortcut:** `ctrl+e`

Sisyphus handles direct tasks that don't need a full plan. Quick fixes, explorations, one-off tasks.

**Workflow:**

1. Press `ctrl+e` to start Sisyphus
2. Describe your task directly
3. For significant work, Sisyphus delegates to subagents
4. For simple questions or small tasks, it may handle them directly

**Good for:**

- Bug fixes: *"Fix the null pointer in auth.ts line 42"*
- Exploration: *"How does the payment flow work?"*
- Quick changes: *"Add a loading spinner to the dashboard"*
- One-off tasks: *"Run the test suite and fix any failures"*

**Example — Quick fix:**

```
You:  The login error message says "Authetication failed" — fix the typo.

Sisyphus:  On it.
  [Delegates to omk-sisyphus-jr: fix typo in login error message]
  [omk-sisyphus-jr finds the string in src/auth/login.ts, fixes it]
  [Sisyphus verifies the change]
  Done — "Authetication" → "Authentication" in src/auth/login.ts:47.
```

> No plan file, no interview. For small, well-defined tasks, Sisyphus is the fastest path.

**Not good for** (use Prometheus + Atlas instead):

- Multi-file features
- Architectural changes
- Anything that benefits from upfront planning

---

## Configuration

### Agent Configs

Agent JSON configs live in `.kiro/agents/`. Each config defines:

- **tools** — Which tools the agent can use
- **allowedPaths** — File system restrictions (e.g., Prometheus can only write to `plans/` and `notepads/`)
- **subagent access** — Which subagents each agent can delegate to
- **hooks** — Lifecycle hooks for runtime enforcement
- **keyboardShortcut** — The shortcut to invoke the agent

```
.kiro/agents/
├── prometheus.json       # ctrl+p — The Planner
├── atlas.json            # ctrl+a — The Plan Executor
├── sisyphus.json         # ctrl+e — The Direct Executor
├── omk-explorer.json     # Codebase exploration
├── omk-metis.json        # Plan review
├── omk-researcher.json   # Technical research
├── omk-reviewer.json     # Code review
└── omk-sisyphus-jr.json  # Task implementation
```

### Steering Files

Steering files in `.kiro/steering/omk/` provide shared context that all agents can read. This is where you describe your project so agents understand what they're working with.

| File | Purpose |
|------|---------|
| `product.md` | What the project is, who it's for, core principles |
| `conventions.md` | Coding standards, naming conventions, patterns to follow |
| `plan-format.md` | Template and rules for plan files |
| `architecture.md` | System architecture, directory structure, key decisions |

**To customize for your project:** Edit these files to describe your codebase, conventions, and architecture. The more context you provide, the better the agents perform.

### Skills

Skills are on-demand knowledge files that agents load when relevant. They live in `.kiro/skills/`.

| Skill | File | When loaded |
|-------|------|-------------|
| Git Operations | `git-operations/SKILL.md` | Branching, commits, merge workflows |
| Code Review | `code-review/SKILL.md` | Review checklists, security patterns |
| Frontend UX | `frontend-ux/SKILL.md` | UI/UX, accessibility, responsive design |

Skills are loaded automatically when an agent determines they're relevant to the current task.

### Hooks

Shell hooks in `.kiro/hooks/` enforce safety constraints at runtime:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `agent-spawn.sh` | Agent starts | Injects git status + plan context |
| `pre-tool-use.sh` | Before any tool | Blocks plan file deletion and `.kiro/` destruction |
| `prometheus-read-guard.sh` | Prometheus reads a file | Warns when reading project files (should delegate to `omk-explorer`) |
| `prometheus-write-guard.sh` | Prometheus writes a file | Blocks writes outside `.kiro/plans/` and `.kiro/notepads/` |

---

## Plan File Format

Plans follow a structured template defined in `.kiro/steering/omk/plan-format.md`. Key sections:

```markdown
# {Plan Name}

## TL;DR
One-paragraph summary.

## Context
Why this work is needed.

## Work Objectives
1. Concrete objective 1
2. Concrete objective 2

## Scope
### In Scope
- What IS included

### Out of Scope
- What is NOT included

## Execution Strategy
How the work should be approached.

### Files to Create / Modify
| File | Purpose |
|------|---------|

## Tasks
### Task 1: {Name}
- [ ] Subtask A
- [ ] Subtask B

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

Plans are stored in `.kiro/plans/` and are **gitignored** — they are runtime artifacts, not committed to your repository.

### A Complete Plan File

Here's what a real plan looks like after Prometheus finishes the interview and exploration:

````markdown
# Add JWT Authentication

## TL;DR
Add JWT-based authentication with refresh tokens to the Express API.
Protect all /api/* routes except login and register. Use the existing
User model and add token storage to Redis.

## Context
The API currently has no authentication. All endpoints are public.
We need to secure them before the beta launch. The team chose JWT
with refresh tokens over session-based auth for stateless scaling.

## Work Objectives
1. Auth middleware that validates JWT on protected routes
2. Login endpoint that returns access + refresh token pair
3. Register endpoint with password hashing
4. Refresh endpoint that rotates tokens
5. Token blacklist in Redis for logout support

## Scope
### In Scope
- JWT access tokens (15 min expiry)
- Refresh tokens (7 day expiry) stored in Redis
- Password hashing with bcrypt
- /api/auth/login, /api/auth/register, /api/auth/refresh, /api/auth/logout

### Out of Scope
- Role-based access control (future plan)
- OAuth / social login
- Email verification

## Execution Strategy
Build bottom-up: utilities first, then middleware, then endpoints.
Each task is independently testable.

### Files to Create
| File | Purpose |
|------|---------|
| `src/middleware/auth.ts` | JWT validation middleware |
| `src/auth/tokens.ts` | Token generation and verification |
| `src/routes/auth.ts` | Auth route handlers |
| `tests/auth.test.ts` | Integration tests |

### Files to Modify
| File | Changes |
|------|---------|
| `src/models/user.ts` | Add password hash field |
| `src/app.ts` | Mount auth routes, apply middleware |
| `src/config.ts` | Add JWT_SECRET, REDIS_URL |

## Tasks

- [ ] **Task 1**: Create token utility module
  - Files: `src/auth/tokens.ts`
  - Details: generateAccessToken(), generateRefreshToken(),
    verifyToken(). Use jsonwebtoken library.
  - Verify: `npm test -- --grep "token"`

- [ ] **Task 2**: Add password field to User model
  - Files: `src/models/user.ts`
  - Details: Add passwordHash field, pre-save hook for hashing
  - Verify: `npm test -- --grep "User model"`

- [ ] **Task 3**: Create auth middleware
  - Files: `src/middleware/auth.ts`
  - Details: Extract Bearer token from Authorization header,
    verify with tokens.ts, attach user to req
  - Verify: `npm test -- --grep "auth middleware"`

- [ ] **Task 4**: Create auth route handlers
  - Files: `src/routes/auth.ts`
  - Details: POST /login, POST /register, POST /refresh, POST /logout
  - Verify: `npm test -- --grep "auth routes"`

- [ ] **Task 5**: Mount routes and apply middleware
  - Files: `src/app.ts`, `src/config.ts`
  - Details: Apply auth middleware to /api/* except /api/auth/*
  - Verify: `npm test`

- [ ] **Task 6**: Write integration tests
  - Files: `tests/auth.test.ts`
  - Details: Full flow — register, login, access protected route,
    refresh token, logout, verify blacklist
  - Verify: `npm test -- --grep "auth integration"`

## Verification Strategy
### Automated Checks
```bash
npm test
npm run lint
curl -s localhost:3000/api/users | grep -q "401"
```

### Manual Checks
- [ ] Login returns access + refresh tokens
- [ ] Protected route rejects expired tokens
- [ ] Refresh endpoint rotates tokens
- [ ] Logout blacklists the refresh token

## Acceptance Criteria
- [ ] All /api/* routes return 401 without valid token
- [ ] Login returns JWT access token + refresh token
- [ ] Refresh endpoint issues new token pair
- [ ] Logout invalidates refresh token
- [ ] All tests pass
- [ ] No lint errors

## References
- jsonwebtoken docs: https://github.com/auth0/node-jsonwebtoken
- Existing User model: src/models/user.ts

## Notes
- Chose bcrypt over argon2 for broader compatibility
- Redis is already in the stack for caching — reuse for token blacklist
- Access token expiry (15 min) is intentionally short for security

---
*Plan generated by Prometheus | 2026-02-09*
*Status: READY*
````

---

## Subagents

Subagents are specialized agents that main agents delegate to. Users never invoke subagents directly.

| Subagent | Role | Delegated by |
|----------|------|-------------|
| **omk-explorer** | Codebase exploration and analysis — reads files, traces dependencies, maps architecture | Prometheus, Atlas, Sisyphus |
| **omk-metis** | Plan review and approval — validates plan quality, completeness, and feasibility | Prometheus |
| **omk-researcher** | Technical research and documentation lookup — investigates libraries, APIs, best practices | Prometheus |
| **omk-reviewer** | Code review and quality checks — reviews implementation for correctness, style, security | Atlas, Sisyphus |
| **omk-sisyphus-jr** | Task implementation — the subagent that actually writes code, creates files, runs commands | Atlas, Sisyphus |

All delegation uses a **6-section format**:

```
TASK: {what to do}
EXPECTED OUTCOME: {deliverables}
REQUIRED TOOLS: {tools needed}
MUST DO: {positive constraints}
MUST NOT DO: {negative constraints}
CONTEXT: {background + inherited wisdom}
```

---

## Customization

### Modify Agent Prompts

Agent prompts live in `.kiro/prompts/` as markdown files. Edit them to change agent behavior:

```
.kiro/prompts/
├── prometheus.md         # Planner behavior
├── atlas.md              # Plan executor behavior
├── sisyphus.md           # Direct executor behavior
├── omk-explorer.md       # Explorer behavior
├── omk-metis.md          # Plan reviewer behavior
├── omk-researcher.md     # Researcher behavior
├── omk-reviewer.md       # Code reviewer behavior
└── omk-sisyphus-jr.md    # Implementer behavior
```

### Add Steering Files

Add your own project context to `.kiro/steering/omk/`:

1. Edit `product.md` with your project description
2. Edit `conventions.md` with your coding standards
3. Edit `architecture.md` with your system design
4. All agents automatically pick up changes

### Add Skills

Create new skill files to give agents domain knowledge:

1. Create a directory under `.kiro/skills/` (e.g., `.kiro/skills/my-domain/`)
2. Add a `SKILL.md` file with the knowledge
3. Agents will load it when relevant to the task

### Add Hooks

Add custom shell hooks in `.kiro/hooks/` and reference them in agent JSON configs under the `hooks` key. Available hook points:

- `agentSpawn` — Runs when an agent starts
- `preToolUse` — Runs before a tool is invoked (can block the action)
- `userPromptSubmit` — Runs when the user sends a message

---

## Troubleshooting

### Agent not loading

- Verify `.kiro/agents/{name}.json` exists and is valid JSON
- Check that the prompt file referenced in the config exists
- For local installs, make sure you're in the project directory where `.kiro/` was installed

### Prometheus writing code instead of planning

- Check that `prometheus-write-guard.sh` is executable: `chmod +x .kiro/hooks/prometheus-write-guard.sh`
- Verify the hook is referenced in `prometheus.json` under `hooks.preToolUse`
- Prometheus should only write to `.kiro/plans/` and `.kiro/notepads/`

### Plan not found by Atlas

- Plans must be in `.kiro/plans/` with a `.md` extension
- Check the plan status — Atlas looks for plans in `READY` or `IN_PROGRESS` state
- Run `ls .kiro/plans/*.md` to see available plans

### Subagent not responding

- Verify the subagent JSON config exists in `.kiro/agents/`
- Check that the parent agent's config lists the subagent in `toolsSettings.subagent.availableAgents`
- Ensure the subagent's prompt file exists in `.kiro/prompts/`

### Permission errors

- Hooks must be executable: `chmod +x .kiro/hooks/*.sh`
- On global install, check `~/.kiro/` permissions
- If `pre-tool-use.sh` blocks an action, it's working as intended — check if the action is allowed

### Cross-agent memory not working

- Notepads directory must exist: `mkdir -p .kiro/notepads/`
- Notepads are **gitignored** runtime artifacts — they won't appear in version control
- Each plan gets its own notepad directory: `.kiro/notepads/{plan-name}/`

---

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

---

## License

[MIT](LICENSE) © Nacho F. Lizaur
