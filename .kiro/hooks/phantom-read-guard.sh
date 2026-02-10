#!/bin/bash
# Phantom Read Guard Hook
# Fires on fs_read — reminds Phantom to delegate codebase exploration
# Reads tool input from stdin, checks file path

input=$(cat)

# Try to extract filePath from JSON input
filepath=$(echo "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    # Handle both possible field names
    print(data.get('filePath', data.get('path', data.get('file', ''))))
except:
    print('')
" 2>/dev/null)

# If we couldn't parse, allow silently
if [ -z "$filepath" ]; then
  exit 0
fi

# Allow reads inside .kiro/ silently (steering, notepads, plans)
if [[ "$filepath" == .kiro/* ]] || [[ "$filepath" == */.kiro/* ]]; then
  exit 0
fi

# Project file read detected — inject warning
cat << 'EOF'
⚠️ PHANTOM READ GUARD: You are reading a project file directly. You are Phantom the PLANNER — delegate codebase exploration to ghost-explorer instead.

ALLOWED reads: .kiro/steering/*, .kiro/notepads/*, .kiro/plans/*
For everything else: spawn ghost-explorer with a 6-section delegation prompt.

If you are in Phase 0 (Orientation) reading steering files, this is fine. Otherwise, DELEGATE.
EOF
exit 0