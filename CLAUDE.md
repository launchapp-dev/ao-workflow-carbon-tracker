# Carbon Footprint Tracker — Agent Context

This repo tracks and reduces greenhouse gas emissions for **Greenfield Manufacturing Corp**,
a mid-size manufacturer with facilities in San Francisco (HQ), Portland (manufacturing), and
Denver (distribution). The company has committed to a Science Based Target (SBTi) 1.5°C-aligned
pathway: 42% reduction in Scope 1+2 and 25% reduction in Scope 3 by 2030 vs. 2023 baseline.

## Domain Knowledge

### The Three Scopes (GHG Protocol)

**Scope 1 — Direct emissions** (owned/controlled sources):
- Stationary combustion: natural gas boilers, propane heaters
- Mobile combustion: company-owned fleet vehicles (diesel trucks, gasoline cars)
- Fugitive emissions: refrigerant leaks from HVAC/cooling systems
- Our largest Scope 1 sources: natural gas at MFG-001, diesel fleet at MFG-001 and WH-001

**Scope 2 — Indirect energy emissions** (purchased electricity/steam):
- Location-based method: uses eGRID subregion average emission factors
- Market-based method: uses factors from energy contracts or RECs (not yet implemented)
- Our largest source: MFG-001 electricity (1.2M+ kWh/month, WECC_NWPP subregion)
- WH-001 in Denver (RMPA) has the highest emission factor (0.000571 tCO2e/kWh — coal-heavy grid)

**Scope 3 — Value chain emissions** (all other indirect):
- Category 1 (Purchased Goods): steel, aluminum, plastics for manufacturing — highest Scope 3 source
- Category 6 (Business Travel): primarily air travel from HQ
- Category 7 (Employee Commuting): estimated from HR data, updated quarterly
- Categories NOT tracked yet (future): upstream transport, use of sold products

### Key Units
- **tCO2e**: tonnes of CO2 equivalent — the standard unit for all GHGs normalized by GWP
- **MMBtu**: million British thermal units — unit for natural gas and steam
- **eGRID**: EPA grid subregion emission factor database (updated annually)
- **GWP**: Global Warming Potential — multiplier converting CH4, N2O, HFCs to CO2 equivalent

### SBTi and Carbon Budgets

The **Science Based Targets initiative** validates that corporate reduction targets align with
the Paris Agreement. Our validated commitment (SBTi-GFC-2024-0142) requires:
- Linear reduction from 45,000 tCO2e (2023) to 28,565 tCO2e (2030) for Scope 1+2+3
- Annual budgets in `config/targets.yaml` are prorated linearly from base year to 2030

**Carbon budget proration**: When assessing monthly/quarterly performance, the annual budget
must be prorated to the current period. For month M: budget = annual_budget × M/12.

### Benchmark Verdict Thresholds
- **on-track**: emissions ≤ prorated annual budget AND all scopes within 10% of budget
- **behind-target**: emissions 1–20% above prorated budget OR any scope >15% above budget
- **critical-overshoot**: emissions >20% above prorated budget OR annual target unreachable

## Data Directory Reference

| File | Purpose |
|---|---|
| `data/sources/raw/` | Drop zone for raw source files (CSV/JSON from utilities, fleet, travel, procurement) |
| `data/sources/current.json` | Validated, standardized source records for the current period |
| `data/sources/anomalies.json` | Quality flags and anomalies detected during validation |
| `data/emissions/current-period.json` | Latest GHG calculation output (Scope 1/2/3 breakdown) |
| `data/emissions/inventory.json` | Running history of monthly emission records |
| `data/emissions/history/` | Archived monthly snapshots |
| `data/benchmarks/target-status.json` | Latest benchmark assessment vs. SBTi targets |
| `data/benchmarks/industry-benchmarks.json` | Sector peer comparisons |
| `data/reductions/hotspots.json` | Pareto analysis of emission sources |
| `data/reductions/opportunities.json` | Ranked reduction opportunities with ROI |
| `data/reductions/active-plan.json` | Current quarter's reduction action plan |
| `data/quarterly-summary.json` | Aggregated quarterly totals (updated by scripts) |

## Config Reference

| File | Purpose |
|---|---|
| `config/organization.yaml` | Facilities, reporting boundary, contacts |
| `config/emission-factors.yaml` | GHG Protocol factors: Scope 1 (fuel types), Scope 2 (eGRID by subregion), Scope 3 |
| `config/targets.yaml` | SBTi pathway, annual budgets by scope, interim milestones |
| `config/categories.yaml` | Source category definitions with scope mapping |

## Scripts Reference

| Script | What It Does |
|---|---|
| `scripts/parse-sources.sh` | Normalizes raw CSV/JSON from `data/sources/raw/` using embedded python3 |
| `scripts/aggregate-activities.sh` | Aggregates validated source data by scope+category, prints to stdout |
| `scripts/analyze-hotspots.sh` | Runs Pareto analysis on emissions inventory → `data/reductions/hotspots.json` |
| `scripts/aggregate-quarterly.sh` | Rolls up 3 months into quarterly totals → `data/quarterly-summary.json` |

## Emission Factor Lookup Guide

When calculating emissions:
1. Find the source record's `category` field
2. Look up the matching section in `config/emission-factors.yaml`
3. For electricity: find the facility in `config/organization.yaml`, get `egrid_subregion`, then
   look up that subregion's factor under `scope_2.electricity`
4. Multiply `activity_value × factor = tco2e`

Example: MFG-001 electricity in January
- activity_value: 1,240,000 kWh
- facility eGRID: WECC_NWPP
- factor: 0.000286 tCO2e/kWh
- result: 1,240,000 × 0.000286 = 354.6 tCO2e

## Report Naming Convention

- Monthly summaries: `reports/monthly/YYYY-MM-summary.md`
- Quarterly reports: `reports/quarterly/YYYY-QN-report.md` (e.g., `2026-Q1-report.md`)
- Reduction plans: `reports/quarterly/YYYY-QN-reduction-plan.md`
- Anomaly alerts: `reports/monthly/anomaly-alert-YYYY-MM-DD.md`
- Annual disclosure: `reports/annual/latest-disclosure.md` (overwritten each quarter)

## Common Pitfalls

1. **Quarterly data vs. monthly data**: Purchased goods records often come in quarterly.
   Apportion quarterly values across 3 months (÷3) when building the monthly inventory.
2. **eGRID subregion matching**: Always use the facility's `egrid_subregion` from
   `config/organization.yaml` — don't guess from location names.
3. **Data quality score**: Weight by activity value — a low-quality record for 10 tCO2e
   matters less than a low-quality record for 500 tCO2e.
4. **Scope 3 completeness**: Not all Scope 3 categories are tracked. Never report a
   Scope 3 total without noting which categories are included and excluded.
