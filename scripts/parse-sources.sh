#!/usr/bin/env bash
# parse-sources.sh — Normalize raw source files into standard JSON format
# Input:  data/sources/raw/*.{csv,json}
# Output: data/sources/raw/parsed-*.json (one per source file)

set -euo pipefail

RAW_DIR="data/sources/raw"
PARSED_COUNT=0
ERROR_COUNT=0

if [ ! -d "$RAW_DIR" ]; then
  echo "ERROR: Raw data directory not found: $RAW_DIR" >&2
  exit 1
fi

echo "Scanning $RAW_DIR for source files..."

# Process CSV files
for csv_file in "$RAW_DIR"/*.csv; do
  [ -f "$csv_file" ] || continue
  base=$(basename "$csv_file" .csv)
  out_file="$RAW_DIR/parsed-${base}.json"

  echo "Parsing CSV: $csv_file"
  python3 - "$csv_file" "$out_file" << 'PYEOF'
import csv
import json
import sys
from datetime import datetime

input_file = sys.argv[1]
output_file = sys.argv[2]

records = []
with open(input_file, newline='') as f:
    reader = csv.DictReader(f)
    for row in reader:
        # Strip whitespace from all values
        record = {k.strip().lower().replace(' ', '_'): v.strip() for k, v in row.items()}
        record['_source_file'] = input_file
        record['_parsed_at'] = datetime.utcnow().isoformat() + 'Z'
        records.append(record)

with open(output_file, 'w') as f:
    json.dump(records, f, indent=2)

print(f"  Parsed {len(records)} records -> {output_file}")
PYEOF
  PARSED_COUNT=$((PARSED_COUNT + 1))
done

# Process JSON files (copy-through normalization)
for json_file in "$RAW_DIR"/*.json; do
  [ -f "$json_file" ] || continue
  # Skip already-parsed files
  [[ "$json_file" == *"parsed-"* ]] && continue
  base=$(basename "$json_file" .json)
  out_file="$RAW_DIR/parsed-${base}.json"

  echo "Normalizing JSON: $json_file"
  python3 - "$json_file" "$out_file" << 'PYEOF'
import json
import sys
from datetime import datetime

input_file = sys.argv[1]
output_file = sys.argv[2]

with open(input_file) as f:
    data = json.load(f)

# Wrap in array if object
if isinstance(data, dict):
    data = [data]

for record in data:
    record['_source_file'] = input_file
    record['_parsed_at'] = datetime.utcnow().isoformat() + 'Z'

with open(output_file, 'w') as f:
    json.dump(data, f, indent=2)

print(f"  Normalized {len(data)} records -> {output_file}")
PYEOF
  PARSED_COUNT=$((PARSED_COUNT + 1))
done

echo ""
echo "Parse complete: $PARSED_COUNT files processed, $ERROR_COUNT errors"
[ "$ERROR_COUNT" -gt 0 ] && exit 1 || exit 0
