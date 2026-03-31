#!/usr/bin/env bash
# analyze-hotspots.sh — Identify top emission sources by scope and category
# Input:  data/emissions/inventory.json
# Output: data/reductions/hotspots.json

set -euo pipefail

INVENTORY="data/emissions/inventory.json"
OUTPUT="data/reductions/hotspots.json"

if [ ! -f "$INVENTORY" ]; then
  echo "ERROR: Emissions inventory not found: $INVENTORY" >&2
  exit 1
fi

mkdir -p data/reductions

echo "Analyzing emission hotspots from: $INVENTORY"

python3 - "$INVENTORY" "$OUTPUT" << 'PYEOF'
import json
import sys
from collections import defaultdict
from statistics import mean, stdev

with open(sys.argv[1]) as f:
    inventory = json.load(f)

# inventory is a list of period records
# Each record has: period, scope_1, scope_2, scope_3 with breakdowns

source_history = defaultdict(list)  # (scope, category) -> [monthly tco2e values]

for period_record in inventory:
    for scope_key in ['scope_1', 'scope_2', 'scope_3']:
        scope_data = period_record.get(scope_key, {})
        scope_num = int(scope_key.split('_')[1])
        breakdown = scope_data.get('breakdown', [])
        if not breakdown:
            # scope_2 may not have breakdown, use total
            total = scope_data.get('total_tco2e', 0)
            if total > 0:
                source_history[(scope_num, scope_key)].append(total)
        for item in breakdown:
            category = item.get('category', 'unknown')
            tco2e = float(item.get('tco2e', 0))
            source_history[(scope_num, category)].append(tco2e)

# Calculate stats per source
hotspots = []
for (scope, category), values in source_history.items():
    if not values:
        continue
    avg = mean(values) if values else 0
    trend = 'stable'
    if len(values) >= 4:
        recent_avg = mean(values[-3:])
        early_avg = mean(values[:-3])
        if recent_avg > early_avg * 1.05:
            trend = 'worsening'
        elif recent_avg < early_avg * 0.95:
            trend = 'improving'

    hotspots.append({
        'scope': scope,
        'category': category,
        'avg_monthly_tco2e': round(avg, 2),
        'last_period_tco2e': round(values[-1], 2) if values else 0,
        'trend': trend,
        'data_points': len(values),
        'total_tco2e_ytd': round(sum(values[-12:]), 2)
    })

# Sort by average monthly emissions descending
hotspots.sort(key=lambda x: x['avg_monthly_tco2e'], reverse=True)

# Calculate cumulative % for Pareto analysis
total_avg = sum(h['avg_monthly_tco2e'] for h in hotspots)
cumulative = 0
for h in hotspots:
    cumulative += h['avg_monthly_tco2e']
    h['cumulative_pct'] = round(cumulative / total_avg * 100, 1) if total_avg > 0 else 0
    h['pareto_class'] = 'A' if h['cumulative_pct'] <= 80 else ('B' if h['cumulative_pct'] <= 95 else 'C')

output = {
    'generated_at': __import__('datetime').datetime.utcnow().isoformat() + 'Z',
    'total_sources_analyzed': len(hotspots),
    'total_avg_monthly_tco2e': round(total_avg, 2),
    'hotspots': hotspots
}

with open(sys.argv[2], 'w') as f:
    json.dump(output, f, indent=2)

print(f"Identified {len(hotspots)} emission sources")
print(f"Total avg monthly: {total_avg:.1f} tCO2e")
print("\nTop 5 hotspots:")
for h in hotspots[:5]:
    print(f"  Scope {h['scope']} {h['category']}: {h['avg_monthly_tco2e']:.1f} tCO2e/mo ({h['trend']})")
print(f"\nOutput: {sys.argv[2]}")
PYEOF
