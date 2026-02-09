#!/bin/bash
# Oh-My-Kiro: preToolUse hook
# Validates tool operations for safety
# Exit 0 = allow, Exit 2 = block (STDERR to LLM)

EVENT=$(cat)

# Parse JSON safely using python3, with grep fallback
if command -v python3 >/dev/null 2>&1; then
  TOOL=$(echo "$EVENT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null)
else
  TOOL=$(echo "$EVENT" | grep -o '"tool_name":"[^"]*"' | sed 's/"tool_name":"//;s/"$//' 2>/dev/null)
fi

# If we can't parse, allow (fail-open)
[ -z "$TOOL" ] && exit 0

# Check for plan file deletion or .kiro destruction via shell
if [ "$TOOL" = "execute_bash" ] || [ "$TOOL" = "shell" ]; then
  if command -v python3 >/dev/null 2>&1; then
    INPUT=$(echo "$EVENT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('command',''))" 2>/dev/null)
  else
    INPUT=$(echo "$EVENT" | grep -o '"command":"[^"]*"' | sed 's/"command":"//;s/"$//' 2>/dev/null)
  fi
  
  # Block deletion of plan files
  if echo "$INPUT" | grep -qE 'rm\s+.*\.kiro/plans/[^.]+\.md'; then
    echo "BLOCKED: Cannot delete plan files. Plans should be archived, not deleted." >&2
    exit 2
  fi
  
  # Block force operations on .kiro
  if echo "$INPUT" | grep -qE 'rm\s+-rf\s+\.kiro'; then
    echo "BLOCKED: Cannot force-delete .kiro directory." >&2
    exit 2
  fi
fi

# Allow everything else
exit 0
