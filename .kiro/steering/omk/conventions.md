# Oh-My-Kiro — Conventions

## File Naming
| Element | Convention | Example |
|---------|------------|---------|
| Agent configs | lowercase `.json` | `prometheus.json`, `omk-explorer.json` |
| Prompt files | match agent name `.md` | `prometheus.md`, `omk-explorer.md` |
| Plan files | kebab-case `.md` | `add-user-auth.md`, `refactor-api.md` |
| Steering files | kebab-case `.md` | `product.md`, `plan-format.md` |
| Hook scripts | kebab-case `.sh` | `agent-spawn.sh`, `stop-check.sh` |
| Skill directories | kebab-case | `git-operations/`, `code-review/` |

## Agent Naming
- Main agents: lowercase (`prometheus`, `sisyphus`)
- Subagents: `omk-` prefix (`omk-explorer`, `omk-metis`, `omk-implementer`)
- The `omk-` prefix prevents collision with user's own agents

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
- Location: `.kiro/notepads/{plan-name}/`
- One directory per active plan
- Subagents write findings here for cross-task memory
- Cleaned up when plan is marked COMPLETE

## Configuration Rules
- **NEVER** include `model` field in agent configs — users set their own
- **ALWAYS** use `file://../prompts/{name}.md` for prompt references (relative to agent config dir)
- **ALWAYS** use `file://.kiro/steering/omk/**/*.md` for resources (relative to project root)
- **ALWAYS** use `trustedAgents` for subagent autonomy
