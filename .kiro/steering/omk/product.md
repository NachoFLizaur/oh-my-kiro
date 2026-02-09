# Oh-My-Kiro — Product Overview

## What Is Oh-My-Kiro?
Oh-My-Kiro is an open-source multi-agent orchestration system for Kiro CLI. It provides two specialized agents that work together through structured plan files:

- **Prometheus** (The Planner): Researches codebases, interviews users to understand requirements, and generates detailed execution plans
- **Sisyphus** (The Executor): Reads plans from disk and autonomously executes them by delegating to specialized subagents

## Core Principle
The **plan file on disk** (`.kiro/plans/{name}.md`) is the sole handoff artifact between Prometheus and Sisyphus. They never share context directly. This enables:
- Separate sessions for planning and execution
- Human review of plans before execution
- Plan reuse and version control
- Clear separation of concerns

## Architecture
```
User → Prometheus (planning session)
         ↓ writes plan to disk
    .kiro/plans/{name}.md
         ↓ reads plan from disk
User → Sisyphus (execution session)
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
