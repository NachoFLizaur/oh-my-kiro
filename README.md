<div align="center">

# Oh-My-Kiro

**Multi-agent orchestration for [Kiro](https://kiro.dev).**

Structured planning. Delegated execution. Defense-in-depth guardrails.

[![npm](https://img.shields.io/npm/v/oh-my-kiro)](https://www.npmjs.com/package/oh-my-kiro)
[![Bun](https://img.shields.io/badge/Bun-compatible-pink.svg)](https://bun.sh)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## Table of Contents

- [What is Oh-My-Kiro?](#what-is-oh-my-kiro)
- [Architecture Overview](#architecture-overview)
  - [Main Agents](#main-agents)
  - [Subagents](#subagents)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
  - [Planning with Phantom](#planning-with-phantom)
  - [Executing Plans with Revenant](#executing-plans-with-revenant)
  - [Direct Tasks with Wraith](#direct-tasks-with-wraith)
- [Plan File Format](#plan-file-format)
- [Delegation Format](#delegation-format)
- [Configuration](#configuration)
  - [Agent Configs](#agent-configs)
  - [Steering Files](#steering-files)
  - [Skills](#skills)
  - [MCP Servers](#mcp-servers)
  - [Hooks](#hooks)
- [Customization](#customization)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## What is Oh-My-Kiro?

Oh-My-Kiro is an open-source multi-agent orchestration system for [Kiro](https://kiro.dev). It provides a structured, multi-agent workflow that separates **planning** from **execution**, with 7 specialized subagents for different tasks.

**Key ideas:**

- **Planning and execution are separate concerns.** One agent plans, another executes. The plan file on disk is the only handoff artifact.
- **Main agents never write code.** They delegate everything to specialized subagents.
- **Multiple layers of safety.** JSON config permissions, shell hooks for runtime enforcement, and identity reinforcement at every turn.
- **Cross-agent memory.** A shared filesystem (`.kiro/notepads/`) lets subagents coordinate without sharing context windows.
- **Web research on demand.** Ghost-researcher can search the web and fetch page content via MCP tools, with automatic complexity routing between quick lookups and deep research.
- **Trust but verify.** The executor independently verifies every subagent's work — never trusts self-reports.

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                             USER                                 │
│                                                                  │
│      ctrl+p                ctrl+a                ctrl+e          │
│         │                     │                     │            │
│         ▼                     ▼                     ▼            │
│   ┌──────────┐          ┌──────────┐          ┌──────────┐       │
│   │ Phantom  │          │ Revenant │          │  Wraith  │       │
│   │(Planner) │          │(Executor)│          │ (Direct) │       │
│   └────┬─────┘          └────┬─────┘          └────┬─────┘       │
│        │                     │                     │             │
│        │ writes              │ reads               │             │
│        ▼                     ▼                     │             │
│   ┌─────────────────────────────┐                  │             │
│   │  .kiro/plans/{name}.md      │                  │             │
│   └─────────────────────────────┘                  │             │
│                                                    ▼             │
│  Planning subagents              Execution subagents             │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ ghost-analyst   │◀─Phantom   │ghost-implementer│◀─Revenant    │
│  │ (pre-analysis)  │            │  (writes code)  │  /Wraith     │
│  └─────────────────┘            └─────────────────┘              │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ ghost-validator │◀─Phantom   │ ghost-reviewer  │◀─Revenant    │
│  │ (plan review)   │ (optional) │ (code review)   │  /Wraith     │
│  └─────────────────┘            └─────────────────┘              │
│  ┌─────────────────┐            ┌─────────────────┐              │
│  │ ghost-explorer  │◀─all       │  ghost-oracle   │◀─Revenant    │
│  │ (exploration)   │  agents    │   (advisory)    │  /Wraith     │
│  └─────────────────┘            └─────────────────┘              │
│  ┌─────────────────┐                                             │
│  │ghost-researcher │◀─Phantom                                    │
│  │ (web research)  │                                             │
│  └─────────────────┘                                             │
└──────────────────────────────────────────────────────────────────┘
```

**3 main agents** orchestrate work. **7 subagents** do the actual work. The plan file on disk is the sole handoff between planning and execution.

### Main Agents

| Agent | Shortcut | Role |
|-------|----------|------|
| **Phantom** | `ctrl+p` | Plans work through interviews and research, generates plan files |
| **Revenant** | `ctrl+a` | Reads and executes plan files autonomously |
| **Wraith** | `ctrl+e` | Handles direct tasks without formal planning |

### Subagents

Subagents are specialized agents that main agents delegate to. Users never invoke subagents directly.

| Subagent | Role | Delegated by |
|----------|------|-------------|
| **ghost-explorer** | Codebase exploration and analysis | Phantom, Revenant, Wraith |
| **ghost-analyst** | Pre-plan analysis (mandatory before planning) | Phantom |
| **ghost-validator** | Post-plan validation (optional, defaults to APPROVE) | Phantom |
| **ghost-oracle** | Strategic advisory and debugging escalation | Revenant, Wraith |
| **ghost-researcher** | Technical research with web search (MCP-powered) | Phantom |
| **ghost-reviewer** | Code review and quality checks | Revenant, Wraith |
| **ghost-implementer** | Task implementation (writes code) | Revenant, Wraith |

### Plan Lifecycle

```
DRAFT  →  READY  →  IN_PROGRESS  →  COMPLETE
  │         │            │              │
  │         │            │              └── All tasks verified
  │         │            └── Revenant/Wraith executing
  │         └── User reviewed and approved
  └── Phantom drafting
```

---

## Quick Start

**1. Install**

```bash
npx oh-my-kiro@latest
```

**Already have Oh-My-Kiro?** Update to the latest version:

```bash
npx oh-my-kiro@latest --update
```

> Always use `@latest` — `npx` caches packages, so without it you may get a stale version.

**2. Open your project in Kiro**

**3. Start planning with Phantom (`ctrl+p`)**

---

## Installation

### Prerequisites

- [Kiro](https://kiro.dev) installed and available in your PATH

### Recommended: npx (no clone needed)

```bash
npx oh-my-kiro@latest
```

This copies the `.kiro/` directory into your current working directory. Agents are available only in that project.

**Global install** (all projects):

```bash
npx oh-my-kiro@latest --global
```

Installs to `~/.kiro/`, making agents available in every project you open with Kiro.

**Overwrite existing files** (skip prompts):

```bash
npx oh-my-kiro@latest --force
```

### Alternative: Clone + install script

```bash
git clone https://github.com/NachoFLizaur/oh-my-kiro.git
cd oh-my-kiro
./install.sh            # local install
./install.sh --global   # global install
```

### Options

| Flag | Description |
|------|-------------|
| `--global` | Install to `~/.kiro/` instead of `./.kiro/` |
| `--force` | Overwrite existing files without prompting |
| `--update` | Smart update — installs new files, updates changed files, skips user-modified files |
| `--dry-run` | Preview what `--update` would do without making changes |
| `--uninstall` | Remove Oh-My-Kiro files (only ours — never the whole `.kiro/`) |
| `--help` | Show usage information |

### Updating

When a new version is released, use `--update` for a safe, non-destructive upgrade:

```bash
npx oh-my-kiro@latest --update
```

The updater uses a manifest (`.kiro/.omk-manifest.json`) to track file hashes and make smart decisions:

- **New files** from the update are installed automatically
- **Changed files** you haven't modified are replaced (with `.bak` backup)
- **Files you've customized** (e.g., edited steering files) are skipped — your changes are preserved
- **Removed files** from upstream are deleted (with `.bak` backup)

Preview changes before applying:

```bash
npx oh-my-kiro@latest --update --dry-run
```

### Uninstall

```bash
# Local
npx oh-my-kiro@latest --uninstall

# Global
npx oh-my-kiro@latest --uninstall --global
```

The `--uninstall` flag removes only Oh-My-Kiro files tracked in the manifest — it never deletes the entire `.kiro/` directory, preserving any custom agents or files you've added.

---

## Usage

### Planning with Phantom

**Shortcut:** `ctrl+p`

Phantom is the planner. It interviews you to understand requirements, delegates research to subagents, and produces a structured plan file. It **never** writes code.

**Workflow:**

1. Press `ctrl+p` to start Phantom
2. Describe what you want to build
3. Phantom delegates to `ghost-analyst` for **mandatory pre-analysis** (identifies hidden intentions, ambiguities, and risks)
4. Phantom asks clarifying questions informed by ghost-analyst's analysis
5. It delegates exploration to `ghost-explorer` and research to `ghost-researcher`
6. It drafts a plan and optionally sends it to `ghost-validator` for a **High Accuracy Review** (you choose)
7. The final plan is written to `.kiro/plans/{plan-name}.md`
8. You review the plan and approve it

**Example — Planning a feature:**

```
You:  I need to add user authentication to my Express API.

Phantom:  Before I create a plan, I have some questions:
  1. What auth method — JWT, session-based, or OAuth?
  2. Which endpoints need protection?
  3. Do you need role-based access control?
  4. Is there an existing User model, or do we start from scratch?

You:  JWT with refresh tokens. Protect all /api/* routes except
      /api/auth/login and /api/auth/register. No roles for now.
      We have a User model in src/models/user.ts.

Phantom:  Got it. Let me analyze and explore the codebase.
  [Delegates to ghost-analyst for pre-analysis of the request]
  [Delegates to ghost-explorer to map the existing routes and models]
  [Delegates to ghost-researcher to web-search current best practices for JWT refresh]
  [Writes .kiro/plans/add-jwt-auth.md]
  [Offers optional High Accuracy Review via ghost-validator]

Phantom:  Plan is ready at .kiro/plans/add-jwt-auth.md — 6 tasks,
             estimated ~2 hours. Please review and let me know if
             anything needs changes.
```

> After reviewing the plan, switch to Revenant (`ctrl+a`) to execute it. See [the complete plan file example](#a-complete-plan-file) below.

### Executing Plans with Revenant

**Shortcut:** `ctrl+a`

Revenant reads existing plan files and executes them task by task. It delegates all implementation to subagents and independently verifies their work. When stuck or facing architectural decisions, it can consult `ghost-oracle` for strategic advice.

**Workflow:**

1. Press `ctrl+a` to start Revenant
2. Revenant lists available plans from `.kiro/plans/`
3. Tell it which plan to execute (or it picks the most recent)
4. Revenant delegates each task to `ghost-implementer` (implementation) or `ghost-explorer` (analysis)
5. After each task, Revenant independently verifies the work — it never trusts subagent self-reports
6. Revenant sends completed work to `ghost-reviewer` for quality checks
7. Plan status is updated as tasks complete

**Example — Executing the auth plan:**

```
You:  Execute the JWT auth plan.

Revenant:  Found .kiro/plans/add-jwt-auth.md (status: READY).
        6 tasks. Starting execution.

Revenant:  Task 1/6 — Create auth middleware.
  [Delegates to ghost-implementer with full task context]
  [ghost-implementer creates src/middleware/auth.ts]
  [Revenant independently reads the file and runs the tests]
  ✓ Task 1 verified. Moving to Task 2.

Revenant:  Task 4/6 — Add refresh token endpoint.
  [Delegates to ghost-implementer]
  [ghost-implementer creates the endpoint]
  [Revenant runs verification: curl + test suite]
  ✗ Verification failed — refresh token not persisted.
  [Re-delegates with correction context]
  ✓ Task 4 verified on second attempt.

Revenant:  All 6 tasks complete. Sending to ghost-reviewer for
        final quality check.
  [ghost-reviewer approves]
  Plan status → COMPLETE.
```

> **Key point:** Revenant never trusts subagent self-reports. It reads the actual files and runs the verification commands from the plan.

> **Tip:** After finishing a plan with Phantom, run `/clear` before switching to Revenant to free up context.

### Direct Tasks with Wraith

**Shortcut:** `ctrl+e`

Wraith handles direct tasks that don't need a full plan. Quick fixes, explorations, one-off tasks.

**Workflow:**

1. Press `ctrl+e` to start Wraith
2. Describe your task directly
3. For significant work, Wraith delegates to subagents
4. For simple questions or small tasks, it may handle them directly

**Good for:**

- Bug fixes: *"Fix the null pointer in auth.ts line 42"*
- Exploration: *"How does the payment flow work?"*
- Quick changes: *"Add a loading spinner to the dashboard"*
- One-off tasks: *"Run the test suite and fix any failures"*

**Example — Quick fix:**

```
You:  The login error message says "Authetication failed" — fix the typo.

Wraith:  On it.
  [Delegates to ghost-implementer: fix typo in login error message]
  [ghost-implementer finds the string in src/auth/login.ts, fixes it]
  [Wraith verifies the change]
  Done — "Authetication" → "Authentication" in src/auth/login.ts:47.
```

> No plan file, no interview. For small, well-defined tasks, Wraith is the fastest path.

**Not good for** (use Phantom + Revenant instead):

- Multi-file features
- Architectural changes
- Anything that benefits from upfront planning

---

## Configuration

### Agent Configs

Agent JSON configs live in `.kiro/agents/`. Each config defines:

- **tools** — Which tools the agent can use
- **allowedPaths** — File system restrictions (e.g., Phantom can only write to `plans/` and `notepads/`)
- **subagent access** — Which subagents each agent can delegate to
- **hooks** — Lifecycle hooks for runtime enforcement
- **keyboardShortcut** — The shortcut to invoke the agent

```
.kiro/agents/
├── phantom.json       # ctrl+p — The Planner
├── revenant.json            # ctrl+a — The Plan Executor
├── wraith.json         # ctrl+e — The Direct Executor
├── ghost-explorer.json     # Codebase exploration
├── ghost-analyst.json        # Pre-plan analysis
├── ghost-validator.json        # Post-plan validation
├── ghost-oracle.json       # Strategic advisory
├── ghost-researcher.json   # Technical research
├── ghost-reviewer.json     # Code review
└── ghost-implementer.json  # Task implementation
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
| Web Search | `web-search/SKILL.md` | Quick factual lookups, documentation finding |
| Deep Research | `deep-research/SKILL.md` | Comprehensive multi-source research, comparisons |

Skills are loaded automatically when an agent determines they're relevant to the current task.

### MCP Servers

Oh-My-Kiro uses [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) servers to extend agent capabilities. MCP configuration lives in `.kiro/settings/mcp.json`.

**Included MCP servers:**

| Server | Package | Purpose |
|--------|---------|---------|
| `web-research` | `web-research-mcp` | Web search and page fetching via DuckDuckGo |

The `web-research` MCP server is used by `ghost-researcher` for web-based technical research. It provides two tools:
- `multi_search` — Search DuckDuckGo with multiple queries in parallel
- `fetch_pages` — Fetch and extract content from multiple URLs

**First-time setup**: The MCP server is installed automatically via `npx` on first use. No API keys required — it uses DuckDuckGo for search.

**Customization**: To add your own MCP servers, edit `.kiro/settings/mcp.json`:

```json
{
  "mcpServers": {
    "web-research": {
      "command": "npx",
      "args": ["-y", "web-research-mcp"]
    },
    "your-server": {
      "command": "npx",
      "args": ["-y", "your-mcp-package"]
    }
  }
}
```

Any agent with `includeMcpJson: true` in its config (the default) will have access to workspace-level MCP servers.

### Hooks

Shell hooks in `.kiro/hooks/` enforce safety constraints at runtime:

| Hook | Trigger | Purpose |
|------|---------|---------|
| `agent-spawn.sh` | Agent starts | Injects git status + plan context |
| `pre-tool-use.sh` | Before any tool | Blocks plan file deletion and `.kiro/` destruction |
| `phantom-read-guard.sh` | Phantom reads a file | Warns when reading project files (should delegate to `ghost-explorer`) |
| `phantom-write-guard.sh` | Phantom writes a file | Blocks writes outside `.kiro/plans/` and `.kiro/notepads/` |

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

---

## Delegation Format

All main agents delegate to subagents using a **6-section format**:

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
├── phantom.md         # Planner behavior
├── revenant.md              # Plan executor behavior
├── wraith.md           # Direct executor behavior
├── ghost-explorer.md       # Explorer behavior
├── ghost-analyst.md          # Pre-plan analyst behavior
├── ghost-validator.md          # Post-plan validator behavior
├── ghost-oracle.md         # Strategic advisor behavior
├── ghost-researcher.md     # Researcher behavior
├── ghost-reviewer.md       # Code reviewer behavior
└── ghost-implementer.md    # Implementer behavior
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

### Phantom writing code instead of planning

- Check that `phantom-write-guard.sh` is executable: `chmod +x .kiro/hooks/phantom-write-guard.sh`
- Verify the hook is referenced in `phantom.json` under `hooks.preToolUse`
- Phantom should only write to `.kiro/plans/` and `.kiro/notepads/`

### Plan not found by Revenant

- Plans must be in `.kiro/plans/` with a `.md` extension
- Check the plan status — Revenant looks for plans in `READY` or `IN_PROGRESS` state
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
