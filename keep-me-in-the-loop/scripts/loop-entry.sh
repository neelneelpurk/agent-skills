#!/usr/bin/env bash
# Create a new .loop/ check-in entry, scaffold its sections, update the index,
# and print the path of the file that was created.
#
# Usage: loop-entry.sh [trigger] [project-root]
#   trigger      one of: timer | decision | big-change | test-added | test-pass | manual
#                (any label is accepted; defaults to "manual")
#   project-root directory that should contain .loop/ (defaults to the current directory)
#
# The script owns timestamp + filename generation so entries always sort
# chronologically and never collide. It writes only a scaffold — the caller
# fills in the content.

set -euo pipefail

trigger="${1:-manual}"
root="${2:-$(pwd)}"

loop_dir="$root/.loop"
mkdir -p "$loop_dir"

# Sortable, filesystem-safe timestamp for the filename; ISO-8601 for the body.
stamp="$(date +%Y-%m-%d_%H-%M-%S)"
iso="$(date +%Y-%m-%dT%H:%M:%S%z)"

entry="$loop_dir/$stamp.md"

# Two check-ins in the same second still get distinct files.
if [ -e "$entry" ]; then
  suffix=1
  while [ -e "$loop_dir/${stamp}-$suffix.md" ]; do
    suffix=$((suffix + 1))
  done
  entry="$loop_dir/${stamp}-$suffix.md"
fi

cat > "$entry" <<EOF
---
timestamp: $iso
trigger: $trigger
---

# Check-in — $stamp

**Trigger:** $trigger

## Where I've reached
<!-- Current phase and overall progress. One or two lines. -->

## What's done since last check-in
<!-- Concrete, verifiable items completed since the previous entry. -->
-

## Critical decisions
<!-- For each decision: what was decided, why, alternatives considered, tradeoffs.
     Write "None since last check-in." if there were none. -->
-

## Test status
<!-- TDD state: tests added (red), tests now passing (green), tests failing, coverage. -->
-

## Next steps
<!-- What happens next, so the user can redirect before it does. -->
-
EOF

# Rebuild a newest-first index from the directory each run. Regenerating (rather than
# inserting a line) keeps the index correct even if entries are added or removed by hand.
index="$loop_dir/INDEX.md"
tmp="$(mktemp)"
printf '# Loop check-ins\n\nNewest first.\n\n' > "$tmp"
# List entries newest-first by filename (timestamps sort lexically), skipping the index itself.
for f in $(ls -1 "$loop_dir"/*.md 2>/dev/null | grep -v '/INDEX.md$' | sort -r); do
  name="$(basename "$f")"
  # Pull the trigger from the entry's YAML frontmatter; fall back to "?" if absent.
  t="$(sed -n 's/^trigger:[[:space:]]*//p' "$f" | head -1)"
  [ -n "$t" ] || t="?"
  printf -- '- [%s](%s) — `%s`\n' "${name%.md}" "$name" "$t" >> "$tmp"
done
mv "$tmp" "$index"

echo "$entry"
