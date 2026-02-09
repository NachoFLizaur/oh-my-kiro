---
name: git-operations
description: Git workflow patterns, branching strategies, and commit conventions. Load when working with git operations, branch management, commit messages, merge strategies, or version control workflows.
---

# Git Operations Skill

Practical git patterns and commands for agent-driven development workflows.

## Branching Strategies

### Feature Branches (Recommended Default)

```bash
# Create feature branch from main
git checkout main && git pull origin main
git checkout -b feat/short-description

# Keep branch up to date with main
git fetch origin main
git rebase origin/main

# Push feature branch
git push -u origin feat/short-description
```

**Branch naming conventions:**

| Prefix | Purpose | Example |
|--------|---------|---------|
| `feat/` | New feature | `feat/user-auth` |
| `fix/` | Bug fix | `fix/login-redirect` |
| `chore/` | Maintenance, deps, config | `chore/update-deps` |
| `docs/` | Documentation only | `docs/api-reference` |
| `refactor/` | Code restructuring | `refactor/auth-module` |
| `test/` | Test additions or fixes | `test/auth-coverage` |

### Trunk-Based Development

For fast-moving projects with CI/CD:

```bash
# Work directly on main with short-lived branches
git checkout -b feat/small-change
# ... make changes, commit ...
git checkout main && git pull
git merge --no-ff feat/small-change
git push origin main
git branch -d feat/small-change
```

**Rules:**
- Branches live < 1 day
- All commits pass CI before merge
- Use feature flags for incomplete work

### GitFlow (Complex Release Cycles)

```bash
# Release branch
git checkout develop
git checkout -b release/1.2.0

# Hotfix from production
git checkout main
git checkout -b hotfix/critical-bug
# ... fix ...
git checkout main && git merge hotfix/critical-bug
git checkout develop && git merge hotfix/critical-bug
git tag -a v1.2.1 -m "Hotfix: critical bug"
```

**Use GitFlow when:** multiple versions in production, formal release process, long-lived feature branches are unavoidable.

## Commit Message Conventions

### Conventional Commits Format

```
<type>(<scope>): <subject>

[optional body]

[optional footer(s)]
```

**Types:**

| Type | When to Use |
|------|-------------|
| `feat` | New feature for the user |
| `fix` | Bug fix for the user |
| `docs` | Documentation changes only |
| `style` | Formatting, missing semicolons (no logic change) |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or correcting tests |
| `chore` | Build process, dependencies, tooling |
| `perf` | Performance improvement |
| `ci` | CI/CD configuration changes |

**Examples:**

```bash
# Feature with scope
git commit -m "feat(auth): add JWT refresh token rotation"

# Bug fix
git commit -m "fix(api): handle null response from upstream service"

# Breaking change (footer)
git commit -m "feat(api)!: change authentication endpoint response format

BREAKING CHANGE: /auth/login now returns {token, refreshToken} instead of {accessToken}."

# Multi-line body
git commit -m "refactor(db): extract connection pooling into dedicated module

Move connection pool management from scattered inline code into
a centralized module. This reduces duplication and makes pool
configuration consistent across all database operations."
```

**Rules:**
- Subject line: imperative mood, lowercase, no period, max 72 chars
- Body: wrap at 72 chars, explain *why* not *what*
- Footer: `BREAKING CHANGE:`, `Fixes #123`, `Refs #456`

## Common Git Operations

### Interactive Rebase (Cleaning History)

```bash
# Squash last 3 commits before PR
git rebase -i HEAD~3

# Rebase onto main (resolve conflicts per-commit)
git rebase origin/main

# Abort if rebase goes wrong
git rebase --abort

# Continue after resolving conflicts
git add . && git rebase --continue
```

### Cherry-Pick

```bash
# Apply a specific commit to current branch
git cherry-pick <commit-sha>

# Cherry-pick without committing (stage only)
git cherry-pick --no-commit <commit-sha>

# Cherry-pick a range of commits
git cherry-pick <start-sha>^..<end-sha>
```

### Stash

```bash
# Stash current changes with a message
git stash push -m "WIP: auth refactor"

# List stashes
git stash list

# Apply most recent stash (keep in stash list)
git stash apply

# Apply and remove from stash list
git stash pop

# Apply a specific stash
git stash apply stash@{2}

# Stash only unstaged changes
git stash push --keep-index -m "unstaged only"

# Stash including untracked files
git stash push --include-untracked -m "with untracked"
```

### Bisect (Finding Bug Introduction)

```bash
# Start bisect
git bisect start

# Mark current commit as bad
git bisect bad

# Mark a known good commit
git bisect good <commit-sha>

# Git checks out a middle commit — test it, then:
git bisect good   # if this commit is fine
git bisect bad    # if this commit has the bug

# Automated bisect with a test script
git bisect start HEAD <known-good-sha>
git bisect run npm test

# Done — reset to original state
git bisect reset
```

### Undoing Changes

```bash
# Unstage a file (keep changes in working directory)
git restore --staged <file>

# Discard working directory changes
git restore <file>

# Undo last commit (keep changes staged)
git reset --soft HEAD~1

# Undo last commit (keep changes unstaged)
git reset HEAD~1

# Create a new commit that undoes a previous commit
git revert <commit-sha>

# Revert a merge commit (specify parent to keep)
git revert -m 1 <merge-commit-sha>
```

### Viewing History

```bash
# Compact log with graph
git log --oneline --graph --all

# Log for a specific file
git log --follow -p -- <file>

# Find commits that changed a specific string
git log -S "function_name" --oneline

# Show what changed between two branches
git log main..feat/my-branch --oneline

# Blame with ignore whitespace
git blame -w <file>
```

## Merge Strategies

### Fast-Forward Merge

```bash
# Only merge if fast-forward is possible (linear history)
git merge --ff-only feat/my-branch
```

**Use when:** branch is up to date with main, want linear history.

### No-Fast-Forward Merge

```bash
# Always create a merge commit (preserves branch history)
git merge --no-ff feat/my-branch
```

**Use when:** you want to preserve that work happened on a branch.

### Squash Merge

```bash
# Squash all branch commits into one, then commit
git merge --squash feat/my-branch
git commit -m "feat(auth): add complete authentication system"
```

**Use when:** branch has messy history, want clean single commit on main.

### Rebase and Merge

```bash
# Rebase feature branch onto main first
git checkout feat/my-branch
git rebase origin/main
# Resolve any conflicts, then:
git checkout main
git merge --ff-only feat/my-branch
```

**Use when:** want linear history without merge commits.

### Conflict Resolution

```bash
# See which files have conflicts
git diff --name-only --diff-filter=U

# Accept ours (current branch) for a file
git checkout --ours <file>

# Accept theirs (incoming branch) for a file
git checkout --theirs <file>

# After resolving, mark as resolved
git add <file>

# Continue the merge
git merge --continue
```

**Conflict markers explained:**
```
<<<<<<< HEAD (current branch)
your changes
=======
their changes
>>>>>>> feat/other-branch (incoming branch)
```

## Git Hooks

### Common Hook Scripts

**pre-commit** — Run linting and formatting:
```bash
#!/usr/bin/env bash
set -euo pipefail

# Lint staged files only
STAGED=$(git diff --cached --name-only --diff-filter=ACM)

if echo "$STAGED" | grep -q '\.ts$'; then
  npx eslint --fix $(echo "$STAGED" | grep '\.ts$')
  git add $(echo "$STAGED" | grep '\.ts$')
fi

if echo "$STAGED" | grep -q '\.py$'; then
  ruff check --fix $(echo "$STAGED" | grep '\.py$')
  git add $(echo "$STAGED" | grep '\.py$')
fi
```

**commit-msg** — Enforce conventional commits:
```bash
#!/usr/bin/env bash
set -euo pipefail

COMMIT_MSG=$(cat "$1")
PATTERN='^(feat|fix|docs|style|refactor|test|chore|perf|ci)(\(.+\))?!?: .{1,72}'

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo "ERROR: Commit message does not follow Conventional Commits format."
  echo "Expected: <type>(<scope>): <subject>"
  echo "Got: $COMMIT_MSG"
  exit 1
fi
```

**pre-push** — Run tests before pushing:
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Running tests before push..."
npm test || {
  echo "Tests failed. Push aborted."
  exit 1
}
```

### Hook Installation

```bash
# Set custom hooks directory (project-level)
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/*
```

## .gitignore Patterns

### Universal Patterns

```gitignore
# OS files
.DS_Store
Thumbs.db
*.swp
*~

# Editor/IDE
.idea/
.vscode/
*.sublime-*

# Environment and secrets
.env
.env.*
!.env.example
*.pem
*.key
```

### Language-Specific Patterns

**Node.js / TypeScript:**
```gitignore
node_modules/
dist/
build/
*.tsbuildinfo
.npm
.yarn/cache
coverage/
```

**Python:**
```gitignore
__pycache__/
*.py[cod]
*.egg-info/
.venv/
venv/
dist/
.mypy_cache/
.ruff_cache/
.pytest_cache/
```

**Go:**
```gitignore
/vendor/
*.exe
*.test
*.out
```

**Rust:**
```gitignore
/target/
Cargo.lock  # for libraries only; commit for binaries
```

### Debugging .gitignore

```bash
# Check why a file is ignored
git check-ignore -v <file>

# List all ignored files
git ls-files --ignored --exclude-standard

# Force-add an ignored file (use sparingly)
git add -f <file>
```

## Tag and Release Workflows

### Semantic Versioning Tags

```bash
# Create annotated tag (preferred — includes metadata)
git tag -a v1.2.0 -m "Release 1.2.0: add user authentication"

# Push a specific tag
git push origin v1.2.0

# Push all tags
git push origin --tags

# List tags matching a pattern
git tag -l "v1.*"

# Delete a local tag
git tag -d v1.2.0

# Delete a remote tag
git push origin --delete v1.2.0
```

### Release Workflow

```bash
# 1. Ensure main is up to date
git checkout main && git pull origin main

# 2. Create release tag
git tag -a v1.2.0 -m "Release 1.2.0: summary of changes"

# 3. Push tag (triggers CI/CD release pipeline)
git push origin v1.2.0

# 4. Create GitHub release (if using GitHub)
gh release create v1.2.0 --title "v1.2.0" --notes "Release notes here"
```

### Versioning Strategy

| Change Type | Version Bump | Example |
|-------------|-------------|---------|
| Breaking API change | Major (`X.0.0`) | `1.0.0` -> `2.0.0` |
| New feature (backward-compatible) | Minor (`0.X.0`) | `1.0.0` -> `1.1.0` |
| Bug fix (backward-compatible) | Patch (`0.0.X`) | `1.0.0` -> `1.0.1` |
| Pre-release | Suffix | `1.1.0-beta.1` |

### Tagging a Past Commit

```bash
# Tag a specific commit (not HEAD)
git tag -a v1.1.0 <commit-sha> -m "Release 1.1.0"
git push origin v1.1.0
```
