#!/usr/bin/env bash
# aggregate-activities.sh — Aggregate validated source data by scope and category
# Input:  data/sources/current.json
# Output: stdout (summary aggregation for calculator agent context)

set -euo pipefail

CURRENT="data/sources/current.json"

if [ ! -f "$CURRENT" ]; then
  echo "ERROR: Validated source data not found: $CURRENT" >&2
  exit 1
fi

echo "=== Activity Data Aggregation ==="
echo "Source: $CURRENT"
echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

python3 - "$CURRENT" << 'PYEOF'
import json
import sys
from collections import defaultdict

with open(sys.argv[1]) as f:
    records = json.load(f)

# Aggregate by scope -> category -> unit
agg = defaultdict(lambda: defaultdict(lambda: defaultdict(float)))
counts = defaultdict(lambda: defaultdict(int))

for r in records:
    scope = str(r.get('scope', '?'))
    category = r.get('category', 'unknown')
    unit = r.get('unit', 'unknown')
    try:
        value = float(r.get('activity_value', 0))
    except (ValueError, TypeError):
        continue
    agg[scope][category][unit] += value
    counts[scope][category] += 1

# Print summary
for scope in sorted(agg.keys()):
    print(f"SCOPE {scope}:")
    for category in sorted(agg[scope].keys()):
        for unit, total in agg[scope][category].items():
            n = counts[scope][category]
            print(f"  {category}: {total:,.2f} {unit} ({n} records)")
    print()

# Print totals by scope
print("RECORD COUNTS:")
total = sum(counts[s][c] for s in counts for c in counts[s])
print(f"  Total records: {total}")
for scope in sorted(counts.keys()):
    scope_total = sum(counts[scope][c] for c in counts[scope])
    print(f"  Scope {scope}: {scope_total} records")

PYEOF
