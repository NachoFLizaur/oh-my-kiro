# Oh-My-Kiro — Product Overview

## What Is Oh-My-Kiro?
Oh-My-Kiro is an open-source multi-agent orchestration system for Kiro CLI. It provides three main agents and seven specialized subagents that work together through structured plan files:

- **Prometheus** (The Planner): Researches codebases, interviews users, and generates detailed execution plans with mandatory pre-analysis and optional high-accuracy validation
- **Atlas** (The Plan Executor): Reads plans from disk and autonomously executes them by delegating to specialized subagents, with strategic advisory support
- **Sisyphus** (The Direct Executor): Handles immediate user requests by delegating to specialized subagents

## Core Principle
The **plan file on disk** (`.kiro/plans/{name}.md`) is the sole handoff artifact between Prometheus and Atlas. They never share context directly. This enables:
- Separate sessions for planning and execution
- Human review of plans before execution
- Plan reuse and version control
- Clear separation of concerns

## Architecture
```
User → Prometheus (planning session)
         ├── omk-metis (pre-analysis)
         ├── omk-explorer + omk-researcher
         └── omk-momus (optional validation)
         ↓ writes plan to disk
    .kiro/plans/{name}.md
         ↓ reads plan from disk
User → Atlas (plan execution session)
         ├── omk-sisyphus-jr (implementation)
         ├── omk-reviewer (code review)
         └── omk-oracle (strategic advice)

User → Sisyphus (direct task session)
         └── Any subagent as needed + omk-oracle
```

## Target Users
- Developers who want structured, repeatable workflows
- Teams that want to separate planning from execution
- Users who want AI-assisted planning with human oversight
- Anyone who wants autonomous code execution with guardrails

## Quality Standards
- Production-quality: comprehensive prompts, proper error handling
- Open-source ready: MIT license, clear documentation
- Extensible: skills, hooks, and subagents can be customized
- No vendor lock-in: no model specified in configs, works with any Kiro-supported model
