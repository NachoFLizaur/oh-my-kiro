#!/bin/bash
# Prometheus Write Guard Hook
# Fires on fs_write — blocks writes outside .kiro/plans/ and .kiro/notepads/
# This is defense-in-depth on top of write.allowedPaths

input=$(cat)

filepath=$(echo "$input" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('filePath', data.get('path', data.get('file', ''))))
except:
    print('')
" 2>/dev/null)

if [ -z "$filepath" ]; then
  exit 0
fi

# Allow writes to .kiro/plans/ and .kiro/notepads/
if [[ "$filepath" == .kiro/plans/* ]] || [[ "$filepath" == */.kiro/plans/* ]]; then
  exit 0
fi
if [[ "$filepath" == .kiro/notepads/* ]] || [[ "$filepath" == */.kiro/notepads/* ]]; then
  exit 0
fi

# Block all other writes
cat << 'EOF'
🚫 PROMETHEUS WRITE BLOCKED: You are Prometheus the PLANNER. You can ONLY write to:
  - .kiro/plans/**  (plan drafts and final plans)
  - .kiro/notepads/** (notepad entries)

You CANNOT write project files. Create a PLAN instead — Atlas will execute it.
Your job: create a plan at .kiro/plans/.draft-{name}.md
Atlas's job: delegate implementation to omk-sisyphus-jr
EOF
exit 1
