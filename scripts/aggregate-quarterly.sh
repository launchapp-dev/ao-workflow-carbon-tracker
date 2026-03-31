#!/usr/bin/env bash
# aggregate-quarterly.sh — Roll up 3 months of emissions into quarterly totals
# Input:  data/emissions/inventory.json
# Output: data/quarterly-summary.json

set -euo pipefail

INVENTORY="data/emissions/inventory.json"
OUTPUT="data/quarterly-summary.json"

if [ ! -f "$INVENTORY" ]; then
  echo "ERROR: Emissions inventory not found: $INVENTORY" >&2
  exit 1
fi

echo "Aggregating quarterly data from: $INVENTORY"

python3 - "$INVENTORY" "$OUTPUT" << 'PYEOF'
import json
import sys
from datetime import datetime, date

with open(sys.argv[1]) as f:
    inventory = json.load(f)

if not inventory:
    print("ERROR: Empty inventory")
    sys.exit(1)

# Sort by period
inventory.sort(key=lambda r: r.get('period', ''))

# Get the latest 3 periods for the quarter
latest_3 = inventory[-3:]
periods = [r['period'] for r in latest_3]

# Determine quarter label from the last period
last_period = periods[-1]  # e.g., "2026-03"
year, month = map(int, last_period.split('-'))
quarter = (month - 1) // 3 + 1
quarter_label = f"{year}-Q{quarter}"

# Aggregate scope totals
scope_1_total = sum(r.get('scope_1', {}).get('total_tco2e', 0) for r in latest_3)
scope_2_total = sum(r.get('scope_2', {}).get('total_tco2e', 0) for r in latest_3)
scope_3_total = sum(r.get('scope_3', {}).get('total_tco2e', 0) for r in latest_3)
grand_total = scope_1_total + scope_2_total + scope_3_total

# Check for prior year same quarter (12 months back)
prior_q_periods = []
for p in periods:
    yr, mo = map(int, p.split('-'))
    prior_q_periods.append(f"{yr-1}-{mo:02d}")

prior_q = [r for r in inventory if r.get('period') in prior_q_periods]
prior_scope_1 = sum(r.get('scope_1', {}).get('total_tco2e', 0) for r in prior_q)
prior_scope_2 = sum(r.get('scope_2', {}).get('total_tco2e', 0) for r in prior_q)
prior_scope_3 = sum(r.get('scope_3', {}).get('total_tco2e', 0) for r in prior_q)
prior_total = prior_scope_1 + prior_scope_2 + prior_scope_3

def pct_change(current, prior):
    if prior == 0:
        return None
    return round((current - prior) / prior * 100, 1)

output = {
    'quarter': quarter_label,
    'periods_included': periods,
    'generated_at': datetime.utcnow().isoformat() + 'Z',
    'emissions': {
        'scope_1_tco2e': round(scope_1_total, 2),
        'scope_2_tco2e': round(scope_2_total, 2),
        'scope_3_tco2e': round(scope_3_total, 2),
        'total_tco2e': round(grand_total, 2)
    },
    'year_over_year': {
        'prior_quarter_label': f"{year-1}-Q{quarter}",
        'prior_scope_1_tco2e': round(prior_scope_1, 2),
        'prior_scope_2_tco2e': round(prior_scope_2, 2),
        'prior_scope_3_tco2e': round(prior_scope_3, 2),
        'prior_total_tco2e': round(prior_total, 2),
        'scope_1_pct_change': pct_change(scope_1_total, prior_scope_1),
        'scope_2_pct_change': pct_change(scope_2_total, prior_scope_2),
        'scope_3_pct_change': pct_change(scope_3_total, prior_scope_3),
        'total_pct_change': pct_change(grand_total, prior_total)
    }
}

with open(sys.argv[2], 'w') as f:
    json.dump(output, f, indent=2)

print(f"Quarter: {quarter_label}")
print(f"Periods: {', '.join(periods)}")
print(f"Scope 1: {scope_1_total:.1f} tCO2e")
print(f"Scope 2: {scope_2_total:.1f} tCO2e")
print(f"Scope 3: {scope_3_total:.1f} tCO2e")
print(f"Total:   {grand_total:.1f} tCO2e")
if prior_total > 0:
    change = pct_change(grand_total, prior_total)
    direction = "decrease" if change < 0 else "increase"
    print(f"YoY: {abs(change):.1f}% {direction} vs {year-1}-Q{quarter}")
print(f"\nOutput: {sys.argv[2]}")
PYEOF
