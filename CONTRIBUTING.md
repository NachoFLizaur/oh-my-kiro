# Contributing to Oh-My-Kiro

Welcome, and thanks for your interest in Oh-My-Kiro! This is a multi-agent orchestration system for [Kiro](https://kiro.dev) — it separates planning from execution using structured plan files and specialized agents.

Oh-My-Kiro is **not a traditional code project**. There's no build system, no package manager, no test framework. The "source code" is agent prompts, JSON configs, shell hooks, and skill files. Contributions are mainly about writing better prompts, adding new skills, and improving agent behavior.

If you haven't already, read the [README](README.md) for an overview of how the system works.

---

## How to Contribute

There are several ways to help:

- **Report agent behavior issues** — If an agent does something unexpected (wrong delegation, ignoring constraints, identity confusion), open an issue describing the conversation and what went wrong.
- **Improve existing prompts** — Tighten constraints, fix edge cases, improve clarity. This is the highest-impact contribution.
- **Add new skills** — Domain-specific knowledge files that agents load on demand.
- **Add or improve hooks** — Shell scripts that enforce safety constraints at runtime.
- **Improve documentation** — Steering files, README, this guide.
- **Propose new subagents** — If you see a gap in the agent roster, open an issue to discuss it first.

Open an [issue](https://github.com/NachoFLizaur/oh-my-kiro/issues) for bug reports and feature proposals. Submit a [pull request](https://github.com/NachoFLizaur/oh-my-kiro/pulls) for concrete changes. Use [discussions](https://github.com/NachoFLizaur/oh-my-kiro/discussions) for open-ended questions and ideas.

---

## Development Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/NachoFLizaur/oh-my-kiro.git
   cd oh-my-kiro
   ```

2. **Install Kiro CLI**

   Follow the instructions at [kiro.dev](https://kiro.dev) to install `kiro-cli` and make it available in your PATH.

3. **Run the installer**

   ```bash
   ./install.sh
   ```

   This copies the `.kiro/` directory into your working directory. Use `--global` to install to `~/.kiro/` instead.

4. **Open your project in Kiro**

   The agents are now available. Press `ctrl+p` for Phantom (planner), `ctrl+a` for Revenant (plan executor), or `ctrl+e` for Wraith (direct executor).

---

## Project Structure

```
.kiro/
├── agents/           # Agent JSON configs (permissions, tools, hooks)
├── prompts/          # Agent prompt files — the main contribution target
├── steering/omk/     # Shared context files (product, conventions, architecture)
├── hooks/            # Lifecycle hook scripts (safety enforcement)
├── skills/           # On-demand skill files (domain knowledge)
├── scripts/          # Validation and utility scripts
├── plans/            # Generated plan files (runtime, gitignored)
└── notepads/         # Cross-subagent memory (runtime, gitignored)
```

**Key files to know:**

| File | What it does |
|------|-------------|
| `.kiro/agents/*.json` | Defines each agent's tools, permissions, allowed paths, subagent access, hooks, and keyboard shortcut |
| `.kiro/prompts/*.md` | The actual prompt that shapes agent behavior — identity, workflow, constraints, delegation format |
| `.kiro/steering/omk/product.md` | Project description that all agents read for context |
| `.kiro/steering/omk/conventions.md` | Naming conventions, directory structure, configuration rules |
| `.kiro/steering/omk/plan-format.md` | Template and rules for plan files |
| `.kiro/steering/omk/architecture.md` | System architecture, agent roles, delegation flows |
| `.kiro/hooks/*.sh` | Shell scripts that run at agent lifecycle events (spawn, pre-tool-use) |
| `.kiro/skills/*/SKILL.md` | Domain knowledge loaded on demand when relevant to a task |

---

## Prompt Writing Guidelines

This is the most important section. Prompts are the core of Oh-My-Kiro — they define how agents think, what they can do, and how they interact. Writing good prompts is the primary contribution type.

### Structure every prompt with clear identity

Start with an identity section that tells the agent exactly what it is and isn't:

```markdown
## Identity

You are **AgentName**, the [role] agent for Oh-My-Kiro.

### What You ARE
- A [specific capability]
- A [specific capability]

### What You ARE NOT
- NOT a [thing it should never do]
- NOT a [thing it should never do]
```

This pattern prevents identity confusion, especially when agents are swapped mid-session.

### Use explicit constraints

Define positive and negative constraints clearly. Use MUST DO / MUST NOT DO sections:

```markdown
### MUST DO
- Always delegate codebase exploration to ghost-explorer
- Always verify subagent work independently
- Always write findings to the notepad directory

### MUST NOT DO
- Never write code directly
- Never skip the interview phase
- Never trust subagent self-reports without verification
```

### Never reference specific model names

Prompts must work with any model the user configures. Never mention specific model names, versions, or providers. Write model-agnostic instructions.

### Use the 6-section delegation format

When an agent delegates to a subagent, use this structured format:

```
TASK: {what to do}
EXPECTED OUTCOME: {deliverables}
REQUIRED TOOLS: {tools needed}
MUST DO: {positive constraints}
MUST NOT DO: {negative constraints}
CONTEXT: {background + inherited wisdom}
```

This ensures subagents receive complete, unambiguous instructions every time.

### Keep prompts focused

A prompt should cover one agent's role completely but concisely. If you find yourself writing extensive domain knowledge (review checklists, coding patterns, framework guides), that content belongs in a **skill file** instead. Skills are loaded on demand, keeping the base prompt lean.

**Rule of thumb:** If a section is longer than 50 lines and only applies to certain tasks, extract it into a skill.

### Test with multiple scenarios

Before submitting a prompt change, test it by:

1. Starting a fresh conversation with the agent
2. Trying the happy path (normal usage)
3. Trying edge cases (ambiguous requests, conflicting instructions)
4. Verifying delegation works correctly (right subagent, right format)
5. Checking that constraints are respected (the agent refuses things it should refuse)

---

## Adding New Skills

Skills are on-demand knowledge files that agents load when relevant. They live in `.kiro/skills/`.

### Steps

1. Create a directory under `.kiro/skills/` using kebab-case:

   ```
   .kiro/skills/my-new-skill/
   ```

2. Add a `SKILL.md` file with YAML frontmatter:

   ```markdown
   ---
   name: my-new-skill
   description: Brief description of when this skill should be loaded. Be specific about trigger conditions.
   ---

   # My New Skill

   Content goes here. Use clear headings, tables, and code examples.
   Agents will read this file in full when they determine it's relevant.
   ```

3. The `name` and `description` fields in the frontmatter are required. The description helps agents decide when to load the skill — make it specific.

4. Skills are automatically available to agents that have `skill://.kiro/skills/**/SKILL.md` in their `resources` config.

### Existing skills for reference

| Skill | Directory | Purpose |
|-------|-----------|---------|
| Git Operations | `git-operations/` | Branching, commits, merge workflows |
| Code Review | `code-review/` | Review checklists, security patterns, language-specific checks |
| Frontend UX | `frontend-ux/` | UI/UX patterns, accessibility, responsive design |

---

## Adding New Hooks

Hooks are shell scripts that run at agent lifecycle events. They enforce safety constraints at runtime.

### Steps

1. Create a script in `.kiro/hooks/` using kebab-case:

   ```bash
   #!/usr/bin/env bash
   set -euo pipefail

   # Description of what this hook does
   # Trigger: when this hook fires (e.g., preToolUse, agentSpawn)

   # Your logic here
   ```

2. Make it executable:

   ```bash
   chmod +x .kiro/hooks/my-hook.sh
   ```

3. Wire it into the relevant agent config (`.kiro/agents/*.json`) under the `hooks` key:

   ```json
   {
     "hooks": {
       "preToolUse": [
         {
           "command": "sh .kiro/hooks/my-hook.sh",
           "timeout_ms": 5000
         }
       ]
     }
   }
   ```

### Available hook points

| Hook | When it fires |
|------|--------------|
| `agentSpawn` | When an agent starts a session |
| `preToolUse` | Before a tool is invoked (can block the action) |
| `userPromptSubmit` | When the user sends a message |

### Guidelines

- Always use `set -euo pipefail` at the top
- Quote all variables (`"$variable"`, not `$variable`)
- Keep hooks fast — they run on every relevant event
- Use `echo` to inject context or warnings into the agent's input
- Exit with non-zero to block an action (for `preToolUse` hooks)

---

## Testing Changes

There is no automated test suite. "Testing" means running Kiro CLI with the agents and verifying they behave correctly through real conversations.

### How to test

1. **Start Kiro CLI** and invoke the agent you modified (e.g., `ctrl+p` for Phantom)
2. **Try the normal workflow** — does the agent behave as expected for typical requests?
3. **Try edge cases** — ambiguous requests, requests that should be refused, requests that require delegation
4. **Verify delegation** — when the agent delegates to a subagent, does it use the correct format? Does it pick the right subagent?
5. **Check constraints** — does the agent respect its MUST NOT DO rules? Does it stay within its allowed paths?
6. **Test identity persistence** — after several turns, does the agent still identify correctly? (Identity confusion is a real failure mode)

### What to look for

- Agent stays in its defined role (planner doesn't write code, explorer doesn't modify files)
- Delegation uses the 6-section format with complete context
- Hooks fire correctly and block disallowed actions
- Skills load when relevant and provide useful context
- Plan files follow the format defined in `plan-format.md`

---

## Pull Request Process

1. **Fork** the repository and create a branch from `main`
2. **Make your changes** — keep each PR focused on one logical change
3. **Test with Kiro CLI** — verify the agent behavior is correct (see [Testing Changes](#testing-changes))
4. **Write a clear PR description** that explains:
   - What you changed and why
   - How you tested it (what scenarios you tried)
   - Any trade-offs or decisions you made
5. **One PR per logical change** — don't bundle unrelated prompt fixes with a new skill

### PR title conventions

- `fix(phantom): prevent code generation during planning phase`
- `feat(skills): add database-migrations skill`
- `improve(revenant): clarify delegation format for reviewer subagent`
- `docs(steering): update architecture.md with new subagent`

### What makes a good PR

- **Focused**: Changes one thing well
- **Tested**: Describes specific scenarios that were verified
- **Explained**: The "why" is clear, not just the "what"
- **Consistent**: Follows existing naming conventions (see `.kiro/steering/omk/conventions.md`)

---

## Code of Conduct

Be respectful, constructive, and welcoming. This is an open-source project and contributions from everyone are valued.

- **Be kind** — assume good intent, especially in text-based communication
- **Be constructive** — if something is wrong, suggest how to fix it
- **Be patient** — not everyone has the same background or experience
- **Be specific** — "this prompt could be clearer" is less helpful than "this constraint on line 42 could be misread as X; consider rephrasing to Y"

We don't tolerate harassment, personal attacks, or exclusionary behavior of any kind.

---

## License

By contributing to Oh-My-Kiro, you agree that your contributions will be licensed under the [MIT License](LICENSE).
