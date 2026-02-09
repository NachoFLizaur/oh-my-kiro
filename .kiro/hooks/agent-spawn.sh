#!/bin/bash
# Oh-My-Kiro: agentSpawn hook
# Injects project context when an agent starts
# STDOUT is added to the agent's context

# Read hook event from STDIN (JSON)
EVENT=$(cat)

echo "## Project Context (auto-injected)"
echo ""

# Git status
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  BRANCH=$(git branch --show-current 2>/dev/null)
  STATUS=$(git status --porcelain 2>/dev/null | head -20)
  echo "### Git Status"
  echo "- Branch: \`${BRANCH}\`"
  if [ -n "$STATUS" ]; then
    echo "- Modified files:"
    echo '```'
    echo "$STATUS"
    echo '```'
  else
    echo "- Working tree clean"
  fi
  echo ""
fi

# Active plans
if [ -d ".kiro/plans" ]; then
  PLANS=$(find .kiro/plans -name "*.md" -not -name ".draft-*" -not -name ".gitkeep" 2>/dev/null)
  DRAFTS=$(find .kiro/plans -name ".draft-*.md" 2>/dev/null)
  
  echo "### Active Plans"
  if [ -n "$PLANS" ]; then
    echo "$PLANS" | while read -r plan; do
      NAME=$(basename "$plan" .md)
      STATUS_LINE=$(grep -o 'Status: [A-Z_]*' "$plan" 2>/dev/null | tail -1)
      echo "- \`${NAME}\`: ${STATUS_LINE:-Status unknown}"
    done
  else
    echo "- No plans found"
  fi
  
  if [ -n "$DRAFTS" ]; then
    echo "- Drafts in progress:"
    echo "$DRAFTS" | while read -r draft; do
      echo "  - \`$(basename "$draft")\`"
    done
  fi
  echo ""
fi

# Active notepads
if [ -d ".kiro/notepads" ]; then
  NOTEPADS=$(find .kiro/notepads -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
  if [ -n "$NOTEPADS" ]; then
    echo "### Active Notepads"
    echo "$NOTEPADS" | while read -r np; do
      FILES=$(find "$np" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
      echo "- \`$(basename "$np")\`: ${FILES} files"
    done
    echo ""
  fi
fi

# Project type detection
echo "### Project Info"
if [ -f "package.json" ]; then
  echo "- Type: Node.js project"
elif [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  echo "- Type: Python project"
elif [ -f "Cargo.toml" ]; then
  echo "- Type: Rust project"
elif [ -f "go.mod" ]; then
  echo "- Type: Go project"
else
  echo "- Type: Unknown (no standard project file detected)"
fi

exit 0
