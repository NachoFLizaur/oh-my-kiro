# Oh-My-Kiro — Conventions

## File Naming
| Element | Convention | Example |
|---------|------------|---------|
| Agent configs | lowercase `.json` | `phantom.json`, `ghost-explorer.json` |
| Prompt files | match agent name `.md` | `phantom.md`, `ghost-explorer.md` |
| Plan files | kebab-case `.md` | `add-user-auth.md`, `refactor-api.md` |
| Steering files | kebab-case `.md` | `product.md`, `plan-format.md` |
| Hook scripts | kebab-case `.sh` | `agent-spawn.sh`, `stop-check.sh` |
| Skill directories | kebab-case | `git-operations/`, `code-review/` |

## Agent Naming
- Main agents: lowercase (`phantom`, `wraith`, `revenant`)
- Subagents: `ghost-` prefix (`ghost-explorer`, `ghost-analyst`, `ghost-validator`, `ghost-oracle`, `ghost-implementer`)
- The `ghost-` prefix prevents collision with user's own agents

## Directory Structure
```
.kiro/
├── agents/       # Agent JSON configs (*.json)
├── prompts/      # Agent prompt files (*.md)
├── steering/     # Shared context files (*.md)
├── plans/        # Generated plan files (*.md, runtime)
├── notepads/     # Cross-subagent memory (runtime)
├── skills/       # On-demand skill files (*/SKILL.md)
├── hooks/        # Lifecycle hook scripts (*.sh)
└── scripts/      # Validation and utility scripts (*.sh)
```

## Plan Files
- Location: `.kiro/plans/{kebab-case-name}.md`
- Draft prefix: `.draft-{name}.md` (hidden, deleted after finalization)
- **Note**: Drafts use a dot-prefix and are hidden by default. Use `ls -a .kiro/plans/` to see them.
- Status lifecycle: DRAFT → READY → IN_PROGRESS → COMPLETE

## Notepad System

The notepad system provides cross-subagent memory for plan execution. Since subagents have isolated contexts and can't see each other's work, notepads provide a shared filesystem location for exchanging findings, decisions, and intermediate results.

### Location
`.kiro/notepads/{plan-name}/` — one directory per active plan.

### File Naming
| File | Written By | Purpose |
|------|-----------|---------|
| `exploration.md` | ghost-explorer | Codebase exploration findings |
| `research.md` | ghost-researcher | Research results and recommendations |
| `pre-analysis.md` | ghost-analyst | Pre-plan analysis and preparation |
| `review.md` | ghost-analyst / ghost-reviewer | Plan or code review notes |
| `validator-review.md` | ghost-validator | Plan validation results |
| `oracle-advice.md` | ghost-oracle | Strategic advisory consultations |
| `decisions.md` | phantom / wraith | Key decisions made during execution |
| `progress.md` | wraith | Execution progress and blockers |

### Rules
- Subagents **APPEND** to notepad files, never overwrite
- Main agents (Phantom/Wraith) create the notepad directory before spawning subagents
- Notepad files use markdown format
- Each entry should be labeled with the task context (e.g., `### Exploration: auth module`)
- Notepad directories are cleaned up when plan status is COMPLETE

### Example
```
.kiro/notepads/add-user-auth/
├── exploration.md    # Explorer's findings about current auth code
├── research.md       # Researcher's findings about auth approaches
├── pre-analysis.md   # Analyst's pre-plan analysis
├── review.md         # Analyst's review of the plan
├── validator-review.md   # Validator's plan validation results
├── oracle-advice.md  # Oracle's strategic advisory
├── decisions.md      # Phantom's key decisions
└── progress.md       # Wraith's execution progress
```

## Configuration Rules
- **NEVER** include `model` field in agent configs — users set their own
- **ALWAYS** use `file://../prompts/{name}.md` for prompt references (relative to agent config dir)
- **ALWAYS** use `file://.kiro/steering/omk/**/*.md` for resources (relative to project root)
- **ALWAYS** use `trustedAgents` for subagent autonomy

## Manifest File
- Location: `.kiro/.omk-manifest.json`
- Generated automatically on install/update
- Tracks installed file versions and hashes
- Should be added to `.gitignore`
