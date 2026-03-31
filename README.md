# Carbon Footprint Tracker

Automated carbon emissions tracking and reduction pipeline — ingests Scope 1/2/3 data monthly, calculates GHG Protocol-compliant footprints, benchmarks against SBTi targets, identifies reduction opportunities ranked by cost-effectiveness, and produces quarterly sustainability reports for climate disclosure.

## Workflow Diagram

```
Monthly (2nd of month)                  Monthly (3rd of month)
┌─────────────────────┐                 ┌──────────────────────────────────────────────────┐
│  ingest-emissions-  │                 │  calculate-footprint                             │
│  data               │                 │                                                  │
│                     │                 │  aggregate-activity-data (bash/python3)          │
│  parse-source-files │────────────────▶│       ↓                                          │
│  (bash)             │                 │  calculate-emissions (calculator)                │
│       ↓             │                 │       ↓                                          │
│  validate-and-store │                 │  benchmark-against-targets (benchmarker)         │
│  (data-collector)   │                 │       │                                          │
└─────────────────────┘                 │  on-track ──┐                                   │
                                        │  behind ────┼──▶ generate-monthly-summary        │
                                        │  critical ──┘    (reporter)                      │
                                        └──────────────────────────────────────────────────┘

Weekly (Monday 7am)                     Quarterly (5th Jan/Apr/Jul/Oct)
┌─────────────────┐                     ┌─────────────────────────────────────────────────┐
│ anomaly-        │                     │  reduction-planning                             │
│ detection       │                     │                                                 │
│                 │                     │  analyze-hotspots (bash/python3)                │
│ detect-anomalies│                     │       ↓                                         │
│ (data-collector)│                     │  find-opportunities (opportunity-finder) ◀──┐   │
└─────────────────┘                     │       ↓                                     │   │
                                        │  evaluate-feasibility (benchmarker)         │   │
                                        │       │                                     │   │
                                        │  sufficient ──▶ compile-reduction-plan      │   │
                                        │  insufficient ──────────────────────────────┘   │
                                        │                (rework, max 3 attempts)          │
                                        └─────────────────────────────────────────────────┘

Quarterly (10th Jan/Apr/Jul/Oct)
┌──────────────────────────────────────────────────────────────┐
│  quarterly-report                                            │
│                                                              │
│  aggregate-quarterly-data (bash/python3)                     │
│       ↓                                                      │
│  compile-disclosure (calculator)                             │
│       ↓                                                      │
│  assess-progress (benchmarker)                               │
│       ↓                                                      │
│  generate-quarterly-report (reporter)                        │
└──────────────────────────────────────────────────────────────┘
```

## Quick Start

```bash
cd examples/carbon-tracker
ao daemon start

# Run the full monthly workflow
ao workflow run calculate-footprint

# Run quarterly reduction planning
ao workflow run reduction-planning

# Run quarterly report
ao workflow run quarterly-report

# Check status
ao status
ao daemon stream --pretty
```

## Agents

| Agent | Model | Role |
|---|---|---|
| **data-collector** | `claude-haiku-4-5` | Ingests raw utility bills, fuel records, travel logs, and procurement data; validates quality and flags anomalies |
| **calculator** | `claude-sonnet-4-6` | Applies GHG Protocol emission factors to activity data; produces Scope 1/2/3 inventories with methodology notes |
| **benchmarker** | `claude-sonnet-4-6` | Compares emissions against SBTi targets and annual budgets; issues on-track/behind/critical verdicts |
| **opportunity-finder** | `claude-opus-4-6` | Identifies reduction opportunities using MAC curve analysis; builds prioritized abatement roadmaps |
| **reporter** | `claude-sonnet-4-6` | Produces monthly summaries, quarterly reduction plans, and board-level sustainability reports |

## AO Features Demonstrated

- **Scheduled workflows** — 5 schedules: monthly ingest, monthly calculation, quarterly planning, quarterly reporting, weekly anomaly scan
- **Decision contracts** — `benchmark-against-targets` issues `on-track | behind-target | critical-overshoot` verdict with structured fields; `evaluate-feasibility` issues `sufficient | insufficient`
- **Phase routing** — All benchmark verdicts route to `generate-monthly-summary` (with different report content); `insufficient` feasibility loops back to `find-opportunities`
- **Rework loops** — `reduction-planning` retries `find-opportunities` up to 3× if proposed reductions don't close the gap
- **Command phases** — `bash scripts/` + embedded `python3` for data normalization, aggregation, hotspot analysis, and quarterly rollups
- **Multi-agent pipeline** — 5 specialized agents, 4 different model tiers
- **Output contracts** — Structured JSON outputs to `data/` directory, Markdown reports to `reports/`

## Requirements

### API Keys
None required — uses only local filesystem and embedded python3/bash scripts.

### MCP Servers
| Server | Package | Purpose |
|---|---|---|
| filesystem | `@modelcontextprotocol/server-filesystem` | Read/write all data and report files |
| sequential-thinking | `@modelcontextprotocol/server-sequential-thinking` | Multi-step GHG calculations and reduction strategy reasoning |

### Runtime Dependencies
- `python3` (3.8+) — emissions calculations and data aggregation scripts
- `bash` (3.x+) — script execution
- `npx` — MCP server startup

## Directory Structure

```
carbon-tracker/
├── .ao/workflows/
│   ├── agents.yaml          # 5 agents: data-collector, calculator, benchmarker,
│   │                        #           opportunity-finder, reporter
│   ├── phases.yaml          # 12 phases across 4 workflows
│   ├── workflows.yaml       # 5 workflows: ingest, calculate, reduction-planning,
│   │                        #              quarterly-report, anomaly-detection
│   ├── mcp-servers.yaml     # filesystem + sequential-thinking
│   └── schedules.yaml       # 5 cron schedules
├── config/
│   ├── organization.yaml    # Org profile, facilities, reporting boundary
│   ├── emission-factors.yaml # GHG Protocol factors by source type and eGRID region
│   ├── targets.yaml         # SBTi pathway, annual carbon budgets 2024–2030
│   └── categories.yaml      # Source categories mapped to Scope 1/2/3
├── data/
│   ├── sources/
│   │   ├── raw/             # Incoming CSV/JSON source files
│   │   ├── current.json     # Validated current-period records
│   │   └── anomalies.json   # Flagged quality issues
│   ├── emissions/
│   │   ├── current-period.json  # Latest calculated footprint
│   │   ├── inventory.json       # Running emissions history
│   │   └── history/             # Archived period snapshots
│   ├── benchmarks/
│   │   ├── target-status.json       # Latest benchmark assessment
│   │   └── industry-benchmarks.json # Sector comparisons
│   └── reductions/
│       ├── hotspots.json        # Ranked emission sources
│       ├── opportunities.json   # Evaluated reduction options
│       └── active-plan.json     # Current reduction action plan
├── reports/
│   ├── monthly/             # Monthly emissions summaries (YYYY-MM-summary.md)
│   ├── quarterly/           # Quarterly reports and reduction plans
│   └── annual/              # Annual disclosure documents
└── scripts/
    ├── parse-sources.sh         # Normalize raw CSV/JSON source files
    ├── aggregate-activities.sh  # Aggregate activity data by scope
    ├── analyze-hotspots.sh      # Rank emission sources by impact
    └── aggregate-quarterly.sh   # Roll up 3 months into quarterly totals
```

## Sample Data

The example ships with realistic sample data for **Greenfield Manufacturing Corp**:
- Q4 2025 monthly emissions history (Oct–Dec)
- Q1 2026 raw source files: utility bills, fleet fuel records, travel reports, procurement data
- Pre-populated `inventory.json` for trend analysis
- Industry benchmarks for the manufacturing sector
- SBTi 1.5°C-aligned targets through 2030
