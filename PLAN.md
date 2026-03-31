# Carbon Footprint Tracker — Workflow Plan

## Overview

An automated carbon emissions tracking and reduction pipeline for organizations subject to climate disclosure requirements (SEC climate rules, EU CSRD, GHG Protocol). The system ingests emissions data across Scope 1 (direct), Scope 2 (purchased energy), and Scope 3 (value chain), calculates carbon footprints using GHG Protocol methodologies, benchmarks against reduction targets, identifies reduction opportunities, and produces quarterly sustainability reports.

## Agents

| Agent | Model | Role |
|---|---|---|
| **data-collector** | claude-haiku-4-5 | Ingests and validates emissions source data (utility bills, fuel records, travel logs, supply chain data) |
| **calculator** | claude-sonnet-4-6 | Calculates Scope 1/2/3 emissions using GHG Protocol emission factors and methodologies |
| **benchmarker** | claude-sonnet-4-6 | Compares calculated emissions against SBTi targets, historical baselines, and industry benchmarks |
| **opportunity-finder** | claude-opus-4-6 | Identifies and prioritizes emission reduction opportunities with ROI analysis |
| **reporter** | claude-sonnet-4-6 | Generates quarterly sustainability reports, annual disclosures, and progress dashboards |

## MCP Servers

- `filesystem` — read/write all data, config, and report files
- `sequential-thinking` — complex multi-scope calculations and reduction strategy reasoning

## Phase Pipeline

### Workflow 1: `ingest-emissions-data` (Monthly — 1st of each month)
Collects and validates raw emissions source data.

| Phase | Mode | Agent/Command | What It Does |
|---|---|---|---|
| `parse-source-files` | command | `bash scripts/parse-sources.sh` | Normalizes raw CSV/JSON source files (utility bills, fuel logs, travel records) into standard format |
| `validate-and-store` | agent | data-collector | Validates data quality, flags gaps/anomalies, stores structured records to `data/sources/current.json` |

### Workflow 2: `calculate-footprint` (Monthly — after ingestion)
Calculates emissions across all three scopes.

| Phase | Mode | Agent/Command | What It Does |
|---|---|---|---|
| `aggregate-activity-data` | command | `bash scripts/aggregate-activities.sh` | Aggregates activity data by scope and category using jq/awk |
| `calculate-emissions` | agent | calculator | Applies GHG Protocol emission factors to activity data, calculates Scope 1/2/3 totals, writes `data/emissions/current-period.json` |
| `benchmark-against-targets` | agent | benchmarker | Compares emissions against SBTi targets, prior periods, and industry benchmarks; issues status verdict |
| `generate-monthly-summary` | agent | reporter | Produces monthly emissions summary report |

**Decision routing on `benchmark-against-targets`:**
- `on-track` → `generate-monthly-summary` (standard report)
- `behind-target` → `generate-monthly-summary` (includes variance analysis and recommended actions)
- `critical-overshoot` → `generate-monthly-summary` (triggers immediate alert report with escalation)

### Workflow 3: `reduction-planning` (Quarterly)
Identifies and prioritizes reduction opportunities.

| Phase | Mode | Agent/Command | What It Does |
|---|---|---|---|
| `analyze-hotspots` | command | `bash scripts/analyze-hotspots.sh` | Identifies top emission sources by scope/category using python3 |
| `find-opportunities` | agent | opportunity-finder | Analyzes hotspots, researches reduction levers, estimates abatement cost curves |
| `evaluate-feasibility` | agent | benchmarker | Evaluates proposed reductions against targets, calculates impact on trajectory |
| `compile-reduction-plan` | agent | reporter | Produces quarterly reduction plan with prioritized actions |

**Decision routing on `evaluate-feasibility`:**
- `sufficient` → `compile-reduction-plan` (reduction plan meets target trajectory)
- `insufficient` → `find-opportunities` (rework — need more/bigger reductions)
- `max_rework_attempts`: 3

### Workflow 4: `quarterly-report` (Quarterly — end of Q1/Q2/Q3/Q4)
Produces comprehensive sustainability reports for stakeholders.

| Phase | Mode | Agent/Command | What It Does |
|---|---|---|---|
| `aggregate-quarterly-data` | command | `bash scripts/aggregate-quarterly.sh` | Rolls up 3 months of emissions data into quarterly totals |
| `compile-disclosure` | agent | calculator | Compiles Scope 1/2/3 inventory with methodology notes, data quality scores, exclusions |
| `assess-progress` | agent | benchmarker | Assesses progress against annual targets, SBTi pathway, and prior year |
| `generate-quarterly-report` | agent | reporter | Produces quarterly sustainability report for board/stakeholders |

## Directory Structure

```
examples/carbon-tracker/
├── .ao/workflows/
│   ├── agents.yaml
│   ├── phases.yaml
│   ├── workflows.yaml
│   ├── mcp-servers.yaml
│   └── schedules.yaml
├── config/
│   ├── organization.yaml        # Org name, reporting boundaries, base year, industry sector
│   ├── emission-factors.yaml    # GHG Protocol emission factors by source type
│   ├── targets.yaml             # SBTi targets, interim milestones, annual budgets
│   └── categories.yaml          # Emission source categories mapped to Scope 1/2/3
├── data/
│   ├── sources/
│   │   ├── raw/                 # Incoming source files (utility bills, fuel logs, travel)
│   │   ├── current.json         # Validated current-period source data
│   │   └── anomalies.json       # Flagged/rejected records
│   ├── emissions/
│   │   ├── current-period.json  # Calculated emissions for current period
│   │   ├── inventory.json       # Running annual emissions inventory
│   │   └── history/             # Historical period snapshots
│   ├── benchmarks/
│   │   ├── target-status.json   # Current status vs targets
│   │   └── industry-benchmarks.json  # Sector benchmark data
│   ├── reductions/
│   │   ├── hotspots.json        # Top emission sources analysis
│   │   ├── opportunities.json   # Identified reduction opportunities
│   │   └── active-plan.json     # Current reduction action plan
│   └── quarterly-summary.json   # Latest quarterly compiled data
├── reports/
│   ├── monthly/                 # Monthly emissions summaries
│   ├── quarterly/               # Quarterly sustainability reports
│   └── annual/                  # Annual disclosure documents
├── scripts/
│   ├── parse-sources.sh         # Normalize raw source files
│   ├── aggregate-activities.sh  # Aggregate activity data by scope
│   ├── analyze-hotspots.sh      # Identify top emission sources
│   └── aggregate-quarterly.sh   # Roll up quarterly data
├── CLAUDE.md                    # Agent context and domain reference
└── README.md                    # Project overview and usage
```

## Config File Designs

### organization.yaml
```yaml
name: "Greenfield Manufacturing Corp"
industry_sector: "Manufacturing"
reporting_boundary: "Operational Control"
base_year: 2023
base_year_emissions_tco2e: 45000
fiscal_year_start: "01-01"
facilities:
  - id: HQ-001
    name: "Corporate Headquarters"
    type: office
    location: "San Francisco, CA"
    employees: 500
  - id: MFG-001
    name: "Primary Manufacturing Plant"
    type: manufacturing
    location: "Portland, OR"
    employees: 1200
  - id: WH-001
    name: "Distribution Center"
    type: warehouse
    location: "Denver, CO"
    employees: 150
reporting_contact:
  name: "Jordan Chen"
  title: "Director of Sustainability"
  email: "jchen@greenfield.example.com"
```

### emission-factors.yaml
```yaml
# GHG Protocol emission factors (tCO2e per unit)
scope_1:
  natural_gas:
    factor: 0.05311   # tCO2e per MMBtu
    unit: MMBtu
  diesel:
    factor: 0.01021   # tCO2e per gallon
    unit: gallon
  gasoline:
    factor: 0.00887   # tCO2e per gallon
    unit: gallon
  propane:
    factor: 0.00574   # tCO2e per gallon
    unit: gallon
  refrigerants:
    R410A:
      factor: 2.088    # tCO2e per kg (GWP)
      unit: kg
scope_2:
  electricity:
    # Location-based factors by eGRID subregion
    WECC_CAMX: 0.000225  # tCO2e per kWh (California)
    WECC_NWPP: 0.000286  # tCO2e per kWh (Pacific Northwest)
    RMPA: 0.000571       # tCO2e per kWh (Rocky Mountain)
    unit: kWh
  steam:
    factor: 0.06686   # tCO2e per MMBtu
    unit: MMBtu
scope_3:
  business_travel_air:
    short_haul: 0.000257  # tCO2e per passenger-mile (<300 mi)
    medium_haul: 0.000195 # tCO2e per passenger-mile (300-2300 mi)
    long_haul: 0.000152   # tCO2e per passenger-mile (>2300 mi)
    unit: passenger-mile
  employee_commuting:
    car_alone: 0.000404   # tCO2e per mile
    carpool: 0.000202     # tCO2e per mile
    public_transit: 0.000089  # tCO2e per mile
    unit: mile
  purchased_goods:
    steel: 1.89           # tCO2e per metric ton
    aluminum: 8.14        # tCO2e per metric ton
    plastics: 3.12        # tCO2e per metric ton
    unit: metric_ton
```

### targets.yaml
```yaml
framework: "Science Based Targets initiative (SBTi)"
pathway: "1.5°C aligned"
base_year: 2023
base_year_emissions:
  scope_1: 12500    # tCO2e
  scope_2: 18000    # tCO2e
  scope_3: 14500    # tCO2e
  total: 45000      # tCO2e
near_term_target:
  year: 2030
  scope_1_2_reduction: 42    # % reduction from base year
  scope_3_reduction: 25      # % reduction from base year
annual_budgets:
  2024:
    scope_1: 11625
    scope_2: 16740
    scope_3: 13963
    total: 42328
  2025:
    scope_1: 10750
    scope_2: 15480
    scope_3: 13425
    total: 39655
  2026:
    scope_1: 9875
    scope_2: 14220
    scope_3: 12888
    total: 36983
```

## Decision Contracts

### emissions-status (benchmark-against-targets phase)
```yaml
required_fields:
  - verdict       # on-track | behind-target | critical-overshoot
  - scope_1_status
  - scope_2_status
  - scope_3_status
  - variance_pct  # % over/under annual budget
```

**Verdict definitions:**
- `on-track`: Total emissions ≤ annual budget trajectory (prorated to current month). All scopes within 10% of budget.
- `behind-target`: Total emissions 1–20% above budget trajectory, or any single scope >15% above its budget.
- `critical-overshoot`: Total emissions >20% above budget trajectory, or annual target mathematically unreachable given remaining months.

### reduction-priority (evaluate-feasibility phase)
```yaml
required_fields:
  - verdict       # sufficient | insufficient
  - gap_tco2e     # remaining gap to close (tCO2e)
  - coverage_pct  # % of gap addressed by proposed reductions
```

## Sample Data

The example ships with 6 months of realistic sample data (Jan–Jun 2026) for Greenfield Manufacturing:
- Monthly utility bills (electricity, natural gas) per facility
- Quarterly fuel purchase records (diesel for fleet, gasoline for company vehicles)
- Monthly travel expense reports aggregated to passenger-miles
- Quarterly purchased goods summaries (raw materials for manufacturing)

## Key Domain Concepts for CLAUDE.md

- **Scope 1**: Direct emissions from owned/controlled sources (on-site fuel combustion, company vehicles, refrigerant leaks)
- **Scope 2**: Indirect emissions from purchased energy (electricity, steam, heating/cooling)
- **Scope 3**: All other indirect emissions in value chain (business travel, employee commuting, purchased goods, waste)
- **GHG Protocol**: The global standard for measuring and managing greenhouse gas emissions (WRI/WBCSD)
- **SBTi**: Science Based Targets initiative — validates that corporate emission reduction targets align with Paris Agreement goals
- **tCO2e**: Tonnes of CO2 equivalent — standard unit normalizing all GHGs by their global warming potential
- **Location-based vs Market-based (Scope 2)**: Location-based uses grid average emission factors; market-based uses factors from energy contracts/RECs
- **eGRID**: EPA's Emissions & Generation Resource Integrated Database — provides emission factors by electricity grid subregion
- **Base Year**: The reference year against which reduction targets are measured. Must be recalculated if organizational boundaries change.
- **Carbon Budget**: Annual emissions allocation derived from reduction targets, prorated from base year to target year on a linear pathway
